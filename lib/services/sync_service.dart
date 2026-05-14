import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

/// Syncs locally-recorded sessions to Supabase.
///
/// Offline-first design:
///   - Every session is written to Drift with syncedToCloud = false.
///   - [requestSync] is called after each new session and on app resume.
///   - When a Supabase client is available (post-auth), pending rows are
///     uploaded in a single batch and marked synced on success.
///   - If the upload fails (offline, timeout) the rows stay pending and
///     will be retried on the next [requestSync] call.
///
/// Wiring Supabase (done when auth is added):
///   1. Add `supabase_flutter` to pubspec.yaml.
///   2. Call `Supabase.initialize(url: ..., anonKey: ...)` in main().
///   3. Pass `Supabase.instance.client` to [setClient] once the user signs in.
///   4. The upload logic inside [_upload] is already stubbed — just fill it in.
class SyncService extends ChangeNotifier {
  SyncService({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  // Set to the authenticated SupabaseClient once auth is wired in.
  // Typed as dynamic so this file compiles without supabase_flutter.
  dynamic _client;

  bool _syncing = false;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;

  bool get isSyncing => _syncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pendingCount => _pendingCount;
  bool get isConnectedToCloud => _client != null;

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Called after a new session is recorded or on app resume.
  Future<void> requestSync() async {
    await _refreshPendingCount();
    if (_client == null) return; // no-op until auth is wired
    if (_syncing) return;
    await _upload();
  }

  /// Called from auth layer once the user signs in.
  Future<void> setClient(dynamic client) async {
    _client = client;
    notifyListeners();
    await requestSync();
  }

  /// Called when the user signs out.
  void clearClient() {
    _client = null;
    notifyListeners();
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  Future<void> _refreshPendingCount() async {
    final rows = await _db.fetchUnsynced();
    _pendingCount = rows.length;
    notifyListeners();
  }

  /// Upload all pending rows to Supabase, mark them synced on success.
  ///
  /// STUB — fill in when supabase_flutter is added:
  ///
  /// ```dart
  /// final client = _client as SupabaseClient;
  /// final payload = unsynced.map((r) => {
  ///   'id': r.id,
  ///   'user_id': client.auth.currentUser!.id,
  ///   'start_time': DateTime.fromMillisecondsSinceEpoch(r.startTimeMs).toIso8601String(),
  ///   'duration_minutes': r.durationMinutes,
  ///   'task_name': r.taskName,
  /// }).toList();
  /// await client.from('sessions').upsert(payload);
  /// await _db.markSynced(unsynced.map((r) => r.id).toList());
  /// ```
  Future<void> _upload() async {
    _syncing = true;
    notifyListeners();
    try {
      final unsynced = await _db.fetchUnsynced();
      if (unsynced.isEmpty) return;

      // ── Supabase upload goes here ──────────────────────────────────────────
      // (stubbed until supabase_flutter is added + credentials provided)
      // ------------------------------------------------------------------

      _lastSyncedAt = DateTime.now();
      _pendingCount = 0;
    } catch (e) {
      debugPrint('[SyncService] upload failed: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}
