import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import 'api_client.dart';

/// Wraps Firebase Auth + Google Sign-In and exchanges the Firebase ID token
/// for a backend role via POST /auth/verify-token.
class AuthService {
  AuthService({ApiClient? api, GoogleSignIn? googleSignIn})
      : _api = api ?? ApiClient(),
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final ApiClient _api;
  final GoogleSignIn _googleSignIn;

  User? get currentFirebaseUser => FirebaseAuth.instance.currentUser;

  /// Triggers Google account picker, signs into Firebase, then calls backend
  /// /auth/verify-token to fetch the role.
  Future<AppUser> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthCancelledException();
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await FirebaseAuth.instance.signInWithCredential(credential);
    return verifyTokenWithBackend();
  }

  /// Sign in via email + password (used for admin-created store owner accounts).
  Future<AppUser> signInWithEmail(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return verifyTokenWithBackend();
  }

  /// Calls backend /auth/verify-token — creates the user record on first login.
  Future<AppUser> verifyTokenWithBackend() async {
    final res = await _api.post('/auth/verify-token') as Map<String, dynamic>;
    return AppUser.fromJson(res);
  }

  /// Self-onboard a store for the currently logged-in user.
  /// Backend flips the user's role to store_owner; we then re-verify to refresh it.
  Future<AppUser> registerStore({
    required String ownerName,
    required String shopName,
    required String phone,
    required String address,
    required double lat,
    required double lng,
    String? openTime,
    String? closeTime,
  }) async {
    final body = <String, dynamic>{
      'owner_name': ownerName,
      'shop_name': shopName,
      'phone': phone,
      'address': address,
      'lat': lat,
      'lng': lng,
    };
    if (openTime != null && closeTime != null) {
      body['operating_hours'] = {'open': openTime, 'close': closeTime};
    }
    await _api.post('/stores/register', body: body);
    // Force a fresh ID token so any custom claims propagate, then re-verify.
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    return verifyTokenWithBackend();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }
}

class AuthCancelledException implements Exception {
  @override
  String toString() => 'Sign-in cancelled by user';
}
