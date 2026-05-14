import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';

/// Syncs locally-recorded sessions to Supabase.
///
/// Fully offline-first — the app never requires an account.
/// Sync only activates after the user explicitly signs in (via AuthService).
///
/// Flow:
///   1. Session completes → written to SQLite (synced_to_cloud = false).
///   2. [requestSync] is called → no-op if user is not signed in.
///   3. User signs in → [requestSync] is called → all pending rows upload.
///   4. Future sessions sync immediately after being recorded.
class SyncService extends ChangeNotifier {
  SyncService({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  SupabaseClient get _client => Supabase.instance.client;

  bool _syncing = false;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;
  String? _lastError;

  bool get isSyncing => _syncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pendingCount => _pendingCount;
  String? get lastError => _lastError;
  bool get isSignedIn => _client.auth.currentUser != null;

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Refreshes the pending count from the DB. Call when the account screen opens.
  Future<void> refreshPendingCount() => _refreshPendingCount();

  /// Called after each new session and on app resume.
  /// No-op when the user is not signed in.
  Future<void> requestSync() async {
    await _refreshPendingCount();
    if (!isSignedIn || _syncing) return;
    await _upload();
  }

  /// Called by AuthService after successful sign-in to flush the backlog.
  Future<void> onSignedIn() async {
    notifyListeners();
    await _upload();
  }

  /// Called by AuthService on sign-out.
  void onSignedOut() {
    notifyListeners();
  }

  // ── Internal ──────────────────────────────────────────────────────────────────

  Future<void> _refreshPendingCount() async {
    final rows = await _db.fetchUnsynced();
    _pendingCount = rows.length;
    notifyListeners();
  }

  Future<void> _upload() async {
    final unsynced = await _db.fetchUnsynced();
    if (unsynced.isEmpty) return;

    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final userId = _client.auth.currentUser!.id;

      final payload = unsynced
          .map((r) => {
                'id': r.id,
                'user_id': userId,
                'start_time': DateTime.fromMillisecondsSinceEpoch(r.startTimeMs)
                    .toUtc()
                    .toIso8601String(),
                'duration_minutes': r.durationMinutes,
                if (r.taskName != null) 'task_name': r.taskName,
              })
          .toList();

      await _client.from('sessions').upsert(payload);
      await _db.markSynced(unsynced.map((r) => r.id).toList());

      _pendingCount = 0;
      _lastSyncedAt = DateTime.now();
    } on AuthException catch (e) {
      _lastError = e.message;
      debugPrint('[SyncService] auth error: $e');
    } on PostgrestException catch (e) {
      _lastError = e.message;
      debugPrint('[SyncService] db error: $e');
    } catch (e) {
      // Network error — rows stay pending, will retry on next requestSync.
      debugPrint('[SyncService] upload failed (offline?): $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}
