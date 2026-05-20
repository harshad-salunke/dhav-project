import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiClient _api = ApiClient();

  AuthStatus _status = AuthStatus.unknown;
  String? _error;
  bool _isAdmin = false;

  AuthStatus get status => _status;
  String? get error => _error;
  bool get isAdmin => _isAdmin;

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _isAdmin = false;
    } else {
      // Verify role via backend
      try {
        final resp = await _api.post('/auth/verify-token');
        _isAdmin = resp['role'] == 'admin';
        _status = _isAdmin ? AuthStatus.authenticated : AuthStatus.unauthenticated;
        if (!_isAdmin) {
          _error = 'Access denied. Admin accounts only.';
          await _authService.signOut();
        }
      } catch (_) {
        _status = AuthStatus.unauthenticated;
      }
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithEmail(email, password);
      // _onAuthStateChanged will fire automatically
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No admin account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Login failed. Check your credentials.';
    }
  }
}
