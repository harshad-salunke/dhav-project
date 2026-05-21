import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/app_user.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn();

  Future<AppUser?> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return _verifyToken(userCredential.user);
  }

  Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return _verifyToken(result.user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        final result = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
        return _verifyToken(result.user);
      }
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<AppUser?> _verifyToken(User? user) async {
    if (user == null) return null;
    final token = await user.getIdToken(true); // forceRefresh — avoids expired cached tokens
    if (token == null) return null;
    final resp = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/verify-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return AppUser.fromJson({
        ...body,
        'uid': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? body['name'] ?? '',
        'photo_url': user.photoURL ?? body['photo_url'],
      });
    }
    return null;
  }

  Future<AppUser?> bootstrap() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _verifyToken(user);
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
