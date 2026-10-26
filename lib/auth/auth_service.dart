import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Email + password authentication with password reset and automatic
/// session restore (spec 6.1 and the section 11 default).
///
/// Every method returns a user-facing error message, or null on success.
class AuthService extends ChangeNotifier {
  AuthService(SupabaseClient client) : _client = client.auth {
    _client.onAuthStateChange.listen((event) {
      // Fires for signedIn, signedOut, tokenRefreshed, passwordRecovery…
      notifyListeners();
    });
  }

  final GoTrueClient _client;

  Session? get session => _client.currentSession;
  User? get user => _client.currentUser;
  bool get isSignedIn => session != null;
  String? get email => user?.email;

  // supabase_flutter restores the persisted web session automatically during
  // Supabase.initialize(), so no manual recovery call is needed here.

  Future<String?> signIn(String email, String password) async {
    try {
      await _client.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return _friendly(e);
    } catch (e) {
      return 'Could not sign in. Check your connection and try again.';
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      final res = await _client.signUp(email: email, password: password);
      if (res.session == null && res.user != null) {
        return 'Check your inbox: confirm your email address to finish '
            'creating the account.';
      }
      return null;
    } on AuthException catch (e) {
      return _friendly(e);
    } catch (e) {
      return 'Could not create the account. Check your connection.';
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _client.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return _friendly(e);
    } catch (e) {
      return 'Could not send the reset email. Check your connection.';
    }
  }

  Future<void> signOut() async {
    try {
      await _client.signOut();
    } finally {
      notifyListeners();
    }
  }

  String _friendly(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) {
      return 'Wrong email or password.';
    }
    if (m.contains('already registered')) {
      return 'That email already has an account. Try signing in.';
    }
    if (m.contains('password should be')) {
      return 'The password is too weak — use at least 8 characters.';
    }
    if (m.contains('rate limit')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    if (m.contains('email not confirmed')) {
      return 'Confirm your email address first — check your inbox.';
    }
    return e.message;
  }
}
