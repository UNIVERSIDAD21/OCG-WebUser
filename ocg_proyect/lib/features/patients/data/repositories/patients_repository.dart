import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../../payments/data/models/payment_model.dart';
import '../../../payments/data/repositories/payments_repository.dart';
import '../models/patient_model.dart';

class PatientsRepository {
  PatientsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _patientsRef =>
      _db.collection(FirestorePaths.patients);

  PaymentsRepository get _paymentsRepository => PaymentsRepository(_db);

  Stream<List<PatientModel>> watchAllPatients() {
    return _patientsRef
        .orderBy('nombre')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => PatientModel.fromJson(doc.data())).toList());
  }

  Stream<PatientModel?> watchPatient(String patientId) {
    return _patientsRef.doc(patientId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return PatientModel.fromJson(data);
    });
  }

  Future<void> createPatient(PatientModel patient) async {
    await _patientsRef.doc(patient.id).set(patient.toJson(), SetOptions(merge: true));

    await _paymentsRepository.initializePaymentDocument(
      patientId: patient.id,
      totalTratamiento: patient.totalTratamiento,
    );
  }

  Future<void> updatePatientClinicalData(String patientId, Map<String, dynamic> data) async {
    await _patientsRef.doc(patientId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePatientBasicData(String patientId, Map<String, dynamic> data) async {
    await _patientsRef.doc(patientId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final rawTotal = data['totalTratamiento'];
    double totalTratamiento;

    if (rawTotal is num) {
      totalTratamiento = rawTotal.toDouble();
    } else {
      final snap = await _patientsRef.doc(patientId).get();
      final stored = snap.data()?['totalTratamiento'];
      totalTratamiento = stored is num ? stored.toDouble() : 0;
    }

    await _paymentsRepository.initializePaymentDocument(
      patientId: patientId,
      totalTratamiento: totalTratamiento,
    );
  }

  Future<void> updatePatientContactData(
    String patientId, {
    String? telefono,
    String? fotoUrl,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (telefono != null) data['telefono'] = telefono;
    if (fotoUrl != null) data['fotoUrl'] = fotoUrl;

    await _patientsRef.doc(patientId).update(data);
  }

  Future<void> defineInitialTreatmentPlanAndFinance({
    required String patientId,
    required TreatmentType tipoTratamiento,
    required double totalTratamiento,
    required TreatmentStage etapaActual,
    required String notasClinicas,
    DateTime? fechaProximoPago,
  }) async {
    if (totalTratamiento <= 0) {
      throw Exception('TOTAL_INVALID');
    }

    final patientRef = _patientsRef.doc(patientId);
    final paymentRef = _db.collection(FirestorePaths.payments).doc(patientId);

    final paymentSnap = await paymentRef.get();
    final paymentData = paymentSnap.data() ?? <String, dynamic>{};

    final montoPagado = (paymentData['montoPagado'] as num?)?.toDouble() ?? 0;
    final saldoPendiente = (totalTratamiento - montoPagado).clamp(0, double.infinity).toDouble();
    final estado = PaymentModel.calcularEstado(
      saldoPendiente: saldoPendiente,
      fechaProximoPago: fechaProximoPago,
    );

    final batch = _db.batch();

    batch.update(patientRef, {
      'tipoTratamiento': tipoTratamiento.name,
      'etapaActual': etapaActual.name,
      'notasClinicas': notasClinicas,
      'totalTratamiento': totalTratamiento,
      'saldoPendiente': saldoPendiente,
      'fechaProximoPago': fechaProximoPago == null ? null : Timestamp.fromDate(fechaProximoPago),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(paymentRef, {
      'id': patientId,
      'patientId': patientId,
      'totalTratamiento': totalTratamiento,
      'montoPagado': montoPagado,
      'saldoPendiente': saldoPendiente,
      'fechaProximoPago': fechaProximoPago == null ? null : Timestamp.fromDate(fechaProximoPago),
      'estado': estado.name,
      'createdAt': paymentSnap.exists ? paymentData['createdAt'] : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> deletePatient(String patientId) async {
    final callable = _functions.httpsCallable('deletePatientAccount');
    await callable.call(<String, dynamic>{'patientId': patientId});
  }

  Future<void> updateTreatmentStage({
    required String patientId,
    required TreatmentStage newStage,
    required String notas,
    required String adminId,
  }) async {
    final batch = _db.batch();

    batch.update(_patientsRef.doc(patientId), {
      'etapaActual': newStage.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final historyRef = _db.collection(FirestorePaths.stageHistory(patientId)).doc();
    batch.set(historyRef, {
      'id': historyRef.id,
      'etapa': newStage.name,
      'fecha': FieldValue.serverTimestamp(),
      'notas': notas,
      'cambiadoPor': adminId,
      'fotosIds': <String>[],
    });

    await batch.commit();
  }
}
  'fotosIds': <String>[],
    });

    await batch.commit();
  }
}
