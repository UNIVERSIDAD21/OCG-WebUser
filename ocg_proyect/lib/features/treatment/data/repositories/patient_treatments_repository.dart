import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../../payments/data/models/payment_model.dart';
import '../models/patient_treatment.dart';

class PatientTreatmentsRepository {
  PatientTreatmentsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _treatmentsRef(String patientId) =>
      _db.collection(FirestorePaths.patientTreatments(patientId));

  DocumentReference<Map<String, dynamic>> _patientRef(String patientId) =>
      _db.collection(FirestorePaths.patients).doc(patientId);

  DocumentReference<Map<String, dynamic>> _paymentRef(String patientId) =>
      _db.collection(FirestorePaths.payments).doc(patientId);

  Stream<List<PatientTreatment>> watchPatientTreatments(String patientId) {
    return _treatmentsRef(patientId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => PatientTreatment.fromJson(doc.data(), id: doc.id))
          .toList();

      items.sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return items;
    });
  }

  Future<void> saveTreatment({
    required String patientId,
    required PatientTreatment treatment,
    String? previousPrimaryId,
  }) async {
    _validateTreatment(treatment);

    final now = DateTime.now();
    final batch = _db.batch();
    final docRef = _treatmentsRef(patientId).doc(treatment.id);
    final paymentSnapshot = treatment.isPrimary ? await _paymentRef(patientId).get() : null;

    if (treatment.isPrimary) {
      final primaryRefs = await _treatmentsRef(patientId).where('isPrimary', isEqualTo: true).get();
      for (final doc in primaryRefs.docs) {
        if (doc.id == treatment.id) continue;
        batch.update(doc.reference, {
          'isPrimary': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (previousPrimaryId != null && previousPrimaryId.isNotEmpty && previousPrimaryId != treatment.id) {
        batch.update(_treatmentsRef(patientId).doc(previousPrimaryId), {
          'isPrimary': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    batch.set(
      docRef,
      treatment.copyWith(updatedAt: now).toJson(),
      SetOptions(merge: true),
    );

    if (treatment.isPrimary) {
      batch.set(
        _patientRef(patientId),
        _legacyPatientMirror(patientId, treatment),
        SetOptions(merge: true),
      );
      batch.set(
        _paymentRef(patientId),
        _paymentMirror(patientId, treatment, paymentSnapshot?.data()),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> setPrimaryTreatment({
    required String patientId,
    required PatientTreatment treatment,
  }) async {
    final batch = _db.batch();
    final snapshot = await _treatmentsRef(patientId).get();
    final paymentSnapshot = await _paymentRef(patientId).get();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isPrimary': doc.id == treatment.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(
      _patientRef(patientId),
      _legacyPatientMirror(patientId, treatment),
      SetOptions(merge: true),
    );
    batch.set(
      _paymentRef(patientId),
      _paymentMirror(patientId, treatment, paymentSnapshot.data()),
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> updateTreatmentStatus({
    required String patientId,
    required PatientTreatment treatment,
    required String newStatus,
  }) async {
    if (!kTreatmentStatusOptions.contains(newStatus)) {
      throw Exception('TREATMENT_STATUS_INVALID');
    }

    final updated = treatment.copyWith(
      estado: newStatus,
      updatedAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(
      _treatmentsRef(patientId).doc(treatment.id),
      updated.toJson(),
      SetOptions(merge: true),
    );

    if (updated.isPrimary) {
      final paymentSnapshot = await _paymentRef(patientId).get();
      batch.set(
        _patientRef(patientId),
        _legacyPatientMirror(patientId, updated),
        SetOptions(merge: true),
      );
      batch.set(
        _paymentRef(patientId),
        _paymentMirror(patientId, updated, paymentSnapshot.data()),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  void _validateTreatment(PatientTreatment treatment) {
    final nombre = treatment.nombre.trim();
    final tipoBase = treatment.tipoBase.trim();
    final categoria = treatment.categoria.trim();

    if (nombre.isEmpty) throw Exception('TREATMENT_NAME_REQUIRED');
    if (tipoBase.isEmpty) throw Exception('TREATMENT_BASE_REQUIRED');
    if (categoria.isEmpty) throw Exception('TREATMENT_CATEGORY_REQUIRED');
    if (!kTreatmentStatusOptions.contains(treatment.estado)) {
      throw Exception('TREATMENT_STATUS_INVALID');
    }
    if (kSubtypeRequiredBaseTreatments.contains(tipoBase)) {
      final subtype = treatment.subtipo?.trim() ?? '';
      if (!kTreatmentSubtypes.contains(subtype)) {
        throw Exception('TREATMENT_SUBTYPE_REQUIRED');
      }
    }
  }

  Map<String, dynamic> _legacyPatientMirror(String patientId, PatientTreatment treatment) {
    return <String, dynamic>{
      'id': patientId,
      'uid': patientId,
      'primaryTreatmentId': treatment.id,
      'tipoTratamiento': _legacyTreatmentTypeName(treatment),
      'etapaActual': treatment.etapaActual.name,
      'fechaInicio': Timestamp.fromDate(treatment.fechaInicio),
      'updatedAt': FieldValue.serverTimestamp(),
      if (treatment.totalTratamiento != null) 'totalTratamiento': treatment.totalTratamiento,
      if (treatment.saldoPendiente != null) 'saldoPendiente': treatment.saldoPendiente,
      if (treatment.notas != null) 'notasClinicas': treatment.notas,
    };
  }

  Map<String, dynamic> _paymentMirror(
    String patientId,
    PatientTreatment treatment,
    Map<String, dynamic>? existingPayment,
  ) {
    final totalCandidate = treatment.totalTratamiento ?? _toNullableDouble(existingPayment?['totalTratamiento']) ?? 0;
    final existingPaid = _toNullableDouble(existingPayment?['montoPagado']) ?? 0;
    final saldoCandidate = treatment.saldoPendiente ?? (totalCandidate - existingPaid);
    final safeSaldo = saldoCandidate.clamp(0, totalCandidate).toDouble();
    final paidCandidate = (totalCandidate - safeSaldo).clamp(0, totalCandidate).toDouble();

    return <String, dynamic>{
      'id': patientId,
      'patientId': patientId,
      'totalTratamiento': totalCandidate,
      'montoPagado': paidCandidate,
      'saldoPendiente': safeSaldo,
      'estado': PaymentModel.calcularEstado(
        saldoPendiente: safeSaldo,
        fechaProximoPago: _parseNullableDate(existingPayment?['fechaProximoPago']),
      ).name,
      'fechaProximoPago': existingPayment?['fechaProximoPago'],
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': existingPayment?['createdAt'] ?? FieldValue.serverTimestamp(),
    };
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _legacyTreatmentTypeName(PatientTreatment treatment) {
    if (treatment.tipoBase == 'convencional' && treatment.subtipo == 'estetico') {
      return TreatmentType.estetico.name;
    }

    const directMap = <String, TreatmentType>{
      'convencional': TreatmentType.convencional,
      'autoligado': TreatmentType.autoligado,
      'alineadores': TreatmentType.alineadores,
      'ortopedia': TreatmentType.ortopedia,
      'interceptivo': TreatmentType.interceptivo,
      'retenedores': TreatmentType.retenedores,
    };

    return (directMap[treatment.tipoBase] ?? TreatmentType.convencional).name;
  }
}
