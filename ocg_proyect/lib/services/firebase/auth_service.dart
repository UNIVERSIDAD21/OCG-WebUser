import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/constants/firestore_paths.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    Dio? http,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _http = http ?? Dio();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final Dio _http;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    String? role;

    final cachedToken = await user.getIdTokenResult();
    role = cachedToken.claims?['role'] as String?;
    if (role == 'admin' || role == 'patient') return role;

    final refreshedToken = await user.getIdTokenResult(true);
    role = refreshedToken.claims?['role'] as String?;
    if (role == 'admin' || role == 'patient') return role;

    return null;
  }

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> registerPatient({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;

    if (displayName != null && displayName.trim().isNotEmpty) {
      await user?.updateDisplayName(displayName.trim());
    }

    if (user != null) {
      await _db.collection(FirestorePaths.patients).doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName?.trim().isEmpty ?? true
            ? null
            : displayName?.trim(),
        'role': 'patient',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return credential;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resetPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateFcmToken(String uid, String role, String token) async {
    final collection = role == 'admin' ? 'admins' : 'patients';
    await _db.collection(collection).doc(uid).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> bootstrapAdminByEmailIfAllowed(String email) async {
    try {
      final token = await _auth.currentUser?.getIdToken();
      if (token == null || token.isEmpty) return;

      await _http.post(
        'https://us-central1-ocg-humanbionics.cloudfunctions.net/addAdminRole',
        data: {
          'data': {'email': email.trim().toLowerCase()},
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      await _auth.currentUser?.getIdTokenResult(true);
    } catch (_) {
      // Si no tiene permiso, no aplica o hay fallo de red, no bloquear login.
    }
  }
}
