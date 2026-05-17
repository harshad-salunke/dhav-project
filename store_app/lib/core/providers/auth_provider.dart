import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? service}) : _service = service ?? AuthService();

  final AuthService _service;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get error => _error;
  bool get busy => _busy;

  Future<void> bootstrap() async {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    try {
      _user = await _service.verifyTokenWithBackend();
      _status = AuthStatus.signedIn;
    } catch (e) {
      // Token invalid or backend unreachable; force re-login.
      await _service.signOut();
      _status = AuthStatus.signedOut;
      _error = 'Session expired. Please sign in again.';
    }
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.signInWithGoogle();
      _status = AuthStatus.signedIn;
      return true;
    } on AuthCancelledException {
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.signInWithEmail(email, password);
      _status = AuthStatus.signedIn;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Self-onboarding: creates a store for the currently logged-in user and
  /// refreshes the local user so role flips to store_owner.
  Future<bool> registerStore({
    required String ownerName,
    required String shopName,
    required String phone,
    required String address,
    required double lat,
    required double lng,
    String? openTime,
    String? closeTime,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.registerStore(
        ownerName: ownerName,
        shopName: shopName,
        phone: phone,
        address: address,
        lat: lat,
        lng: lng,
        openTime: openTime,
        closeTime: closeTime,
      );
      _status = AuthStatus.signedIn;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Re-fetches the current role from the backend (used after admin verifies, etc.).
  Future<void> refreshUser() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      _user = await _service.verifyTokenWithBackend();
      _status = AuthStatus.signedIn;
      notifyListeners();
    } catch (_) {
      // Silent — keep existing state.
    }
  }
}
