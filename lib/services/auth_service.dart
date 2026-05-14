import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_service.dart';

/// Manages authentication state.
///
/// The app is fully usable without an account — auth is only prompted when
/// the user explicitly requests Sync & Backup or Pop Together.
///
/// States:
///   - AuthStatus.none     — never signed in, no account
///   - AuthStatus.signedIn — signed in with email/password
///
class AuthService extends ChangeNotifier {
  AuthService({required SyncService sync}) : _sync = sync {
    // React to Supabase auth state changes (e.g. token refresh, sign-out).
    Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthChange);
  }

  final SyncService _sync;
  SupabaseClient get _client => Supabase.instance.client;

  AuthStatus _status = AuthStatus.none;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  String? get error => _error;
  bool get loading => _loading;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  User? get currentUser => _client.auth.currentUser;
  String? get email => currentUser?.email;

  // ── Public API ────────────────────────────────────────────────────────────────

  Future<bool> signUp({required String email, required String password}) =>
      _run(() async {
        await _client.auth.signUp(email: email, password: password);
      });

  Future<bool> signIn({required String email, required String password}) =>
      _run(() async {
        await _client.auth.signInWithPassword(email: email, password: password);
      });

  Future<bool> signOut() => _run(() async {
        await _client.auth.signOut();
      });

  /// Sends a password-reset email. Returns true if the email was dispatched.
  Future<bool> sendPasswordReset({required String email}) =>
      _run(() async {
        await _client.auth.resetPasswordForEmail(email);
      });

  // ── Internal ──────────────────────────────────────────────────────────────────

  void _onAuthChange(AuthState state) {
    final prev = _status;
    _status = state.session != null ? AuthStatus.signedIn : AuthStatus.none;
    if (_status != prev) {
      notifyListeners();
      if (_status == AuthStatus.signedIn) {
        _sync.onSignedIn();
      } else {
        _sync.onSignedOut();
      }
    }
  }

  /// Runs [action], captures errors into [error], updates [loading].
  /// Returns true on success, false on failure.
  Future<bool> _run(Future<void> Function() action) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      _loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Something went wrong. Check your connection and try again.';
      _loading = false;
      debugPrint('[AuthService] unexpected error: $e');
      notifyListeners();
      return false;
    }
  }
}

enum AuthStatus { none, signedIn }
