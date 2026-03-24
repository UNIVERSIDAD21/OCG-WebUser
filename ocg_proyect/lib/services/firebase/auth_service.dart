import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
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

  Future<void> ensureCurrentPatientProfileExists({
    String? email,
    String? displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _db.collection(FirestorePaths.patients).doc(user.uid);
    final snap = await docRef.get();
    final current = snap.data() ?? const <String, dynamic>{};

    final now = DateTime.now();
    final cleanEmail = (email ?? user.email ?? '').trim().toLowerCase();
    final cleanName = (displayName ?? user.displayName ?? '').trim();

    bool missingOrEmpty(String key) {
      final v = current[key];
      if (v == null) return true;
      if (v is String) return v.trim().isEmpty;
      return false;
    }

    final patch = <String, dynamic>{
      if (missingOrEmpty('id')) 'id': user.uid,
      if (missingOrEmpty('uid')) 'uid': user.uid,
      if (missingOrEmpty('nombre')) 'nombre': cleanName,
      if (missingOrEmpty('email')) 'email': cleanEmail,
      if (missingOrEmpty('telefono')) 'telefono': '',
      if (!current.containsKey('fechaNacimiento')) 'fechaNacimiento': Timestamp.fromDate(now),
      if (!current.containsKey('fotoUrl')) 'fotoUrl': null,
      if (!current.containsKey('tipoTratamiento')) 'tipoTratamiento': null,
      if (missingOrEmpty('etapaActual')) 'etapaActual': 'valoracionInicial',
      if (!current.containsKey('fechaInicio')) 'fechaInicio': Timestamp.fromDate(now),
      if (!current.containsKey('fechaEstimadaFin')) 'fechaEstimadaFin': null,
      if (!current.containsKey('notasClinicas')) 'notasClinicas': '',
      if (!current.containsKey('totalTratamiento')) 'totalTratamiento': 0,
      if (!current.containsKey('saldoPendiente')) 'saldoPendiente': 0,
      if (!current.containsKey('fechaProximoPago')) 'fechaProximoPago': null,
      if (!current.containsKey('proximaCita')) 'proximaCita': null,
      if (!current.containsKey('fcmToken')) 'fcmToken': '',
      if (!current.containsKey('createdAt')) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (patch.isNotEmpty) {
      await docRef.set(patch, SetOptions(merge: true));
    }
  }

  Future<void> registerPatientSelf({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = displayName?.trim() ?? '';

    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'ocg-register-${DateTime.now().microsecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final secondaryDb = FirebaseFirestore.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'unknown', message: 'No se pudo crear el usuario.');
      }

      if (cleanName.isNotEmpty) {
        await user.updateDisplayName(cleanName);
      }

      // Importante: escribir con la misma app secundaria (sesión del usuario recién creado)
      // para cumplir reglas de seguridad en /patients/{uid}.
      await secondaryDb.collection(FirestorePaths.patients).doc(user.uid).set({
        'id': user.uid,
        'uid': user.uid,
        'nombre': cleanName,
        'email': cleanEmail,
        'telefono': '',
        'fcmToken': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await secondaryAuth.signOut();
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  Future<void> createPatientByAdmin({
    required String email,
    required String password,
    String? displayName,
    String? treatmentType,
    double? totalTreatment,
  }) async {
    final callable = _functions.httpsCallable('createPatientAccount');
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = displayName?.trim() ?? '';
    final cleanTreatment = treatmentType?.trim();
    final cleanTotal = totalTreatment ?? 0;

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
      'tipoTratamiento': cleanTreatment,
      'etapaActual': 'valoracionInicial',
      'fechaInicio': Timestamp.fromDate(now),
      'fechaEstimadaFin': null,
      'notasClinicas': '',
      'totalTratamiento': cleanTotal,
      'saldoPendiente': cleanTotal,
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
