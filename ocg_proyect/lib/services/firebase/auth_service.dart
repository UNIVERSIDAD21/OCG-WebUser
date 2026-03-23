import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/constants/firestore_paths.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = db ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

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

  Future<void> registerPatientSelf({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    final cleanName = displayName?.trim() ?? '';
    if (user == null) return;

    if (cleanName.isNotEmpty) {
      await user.updateDisplayName(cleanName);
    }

    await _db.collection(FirestorePaths.patients).doc(user.uid).set({
      'id': user.uid,
      'nombre': cleanName,
      'email': email.trim().toLowerCase(),
      'telefono': '',
      'fcmToken': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> createPatientByAdmin({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final callable = _functions.httpsCallable('createPatientAccount');
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = displayName?.trim() ?? '';

    final result = await callable.call({
      'email': cleanEmail,
      'password': password,
      'displayName': cleanName,
    });

    final data = (result.data as Map?)?.cast<String, dynamic>() ?? const {};
    final uid = (data['uid'] ?? '').toString();

    if (uid.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'No se recibió uid al crear el paciente.',
      );
    }

    final now = DateTime.now();

    // Refuerzo local: dejamos el documento exactamente en el formato esperado
    // por el módulo de pacientes (igual que registro/autocreación).
    await _db.collection(FirestorePaths.patients).doc(uid).set({
      'id': uid,
      'uid': uid,
      'nombre': cleanName,
      'email': cleanEmail,
      'telefono': '',
      'fechaNacimiento': Timestamp.fromDate(now),
      'fotoUrl': null,
      'tipoTratamiento': null,
      'etapaActual': 'valoracionInicial',
      'fechaInicio': Timestamp.fromDate(now),
      'fechaEstimadaFin': null,
      'notasClinicas': '',
      'totalTratamiento': 0,
      'saldoPendiente': 0,
      'fechaProximoPago': null,
      'proximaCita': null,
      'fcmToken': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      final callable = _functions.httpsCallable('addAdminRole');
      await callable.call({'email': email.trim().toLowerCase()});
      await _auth.currentUser?.getIdTokenResult(true);
    } on FirebaseFunctionsException catch (_) {
      // Si no tiene permiso o no aplica, continuar sin bloquear login.
    } catch (_) {
      // Cualquier falla de red/función no debe bloquear autenticación.
    }
  }
}
