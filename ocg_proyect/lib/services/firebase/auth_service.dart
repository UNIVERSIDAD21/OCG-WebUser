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

  Future<bool> currentPatientProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snap = await _db.collection(FirestorePaths.patients).doc(user.uid).get();
    if (!snap.exists) return false;

    final data = snap.data() ?? const <String, dynamic>{};
    final isDeleted = data['deletedAt'] != null || data['activo'] == false;
    return !isDeleted;
  }

  Future<bool> _emailExistsInFirestore(String cleanEmail) async {
    final patientSnap = await _db
        .collection(FirestorePaths.patients)
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();
    if (patientSnap.docs.isNotEmpty) {
      final data = patientSnap.docs.first.data();
      final isDeleted = data['deletedAt'] != null || data['activo'] == false;
      if (!isDeleted) return true;
    }

    final adminSnap = await _db
        .collection(FirestorePaths.admins)
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();
    return adminSnap.docs.isNotEmpty;
  }

  Future<void> registerPatientSelf({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = displayName?.trim() ?? '';

    try {
      final callable = _functions.httpsCallable('registerPatientSelf');
      await callable.call({
        'email': cleanEmail,
        'password': password,
        'displayName': cleanName,
      });
      return;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'Este correo ya está en uso.',
        );
      }
      // Si la función no está disponible o falla por entorno, usar fallback legacy.
      const fallbackCodes = {
        'not-found',
        'unimplemented',
        'unauthenticated',
        'permission-denied',
        'internal',
        'unavailable',
        'deadline-exceeded',
      };
      if (!fallbackCodes.contains(e.code)) {
        rethrow;
      }
    }

    await _registerPatientSelfLegacy(
      cleanEmail: cleanEmail,
      password: password,
      cleanName: cleanName,
    );
  }

  Future<void> _registerPatientSelfLegacy({
    required String cleanEmail,
    required String password,
    required String cleanName,
  }) async {
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
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'Este correo ya está en uso.',
        );
      }
      rethrow;
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  Future<String> createPatientByAdmin({
    required String email,
    required String password,
    String? displayName,
    String? treatmentType,
    double? totalTreatment,
  }) async {
    final callable = _functions.httpsCallable('createPatientAccount');
    final cleanEmail = email.trim().toLowerCase();
    if (await _emailExistsInFirestore(cleanEmail)) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'Este correo ya está en uso.',
      );
    }
    final cleanName = displayName?.trim() ?? '';
    final cleanTreatment = treatmentType?.trim();
    final cleanTotal = totalTreatment ?? 0;

    final HttpsCallableResult<dynamic> result;
    try {
      result = await callable.call({
        'email': cleanEmail,
        'password': password,
        'displayName': cleanName,
        'treatmentType': cleanTreatment,
        'totalTreatment': cleanTotal,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'Este correo ya está en uso.',
        );
      }
      rethrow;
    }

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

    // Refuerzo financiero inicial para que el monto quede visible de inmediato
    // en módulos que leen la colección de pagos.
    await _db.collection(FirestorePaths.payments).doc(uid).set({
      'id': uid,
      'patientId': uid,
      'totalTratamiento': cleanTotal,
      'montoPagado': 0,
      'saldoPendiente': cleanTotal,
      'fechaProximoPago': null,
      'estado': cleanTotal > 0 ? 'pendiente' : 'alDia',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return uid;
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
