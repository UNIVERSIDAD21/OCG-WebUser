import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../patients/data/models/patient_model.dart';
import '../models/patient_treatment.dart';

class PatientTreatmentsRepository {
  PatientTreatmentsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _treatmentsRef(String patientId) =>
      _db.collection(FirestorePaths.patientTreatments(patientId));

  DocumentReference<Map<String, dynamic>> _patientRef(String patientId) =>
      _db.collection(FirestorePaths.patients).doc(patientId);

  DocumentReference<Map<String, dynamic>> _paymentRef(
    String patientId,
    String treatmentId,
  ) => _db.doc(FirestorePaths.treatmentPaymentDoc(patientId, treatmentId));

  DocumentReference<Map<String, dynamic>> _legacyPaymentRef(String patientId) =>
      _db.doc(FirestorePaths.paymentDoc(patientId));

  CollectionReference<Map<String, dynamic>> get _appointmentsRef =>
      _db.collection(FirestorePaths.appointments);

  Stream<List<PatientTreatment>> watchPatientTreatments(String patientId) {
    return _treatmentsRef(
      patientId,
    ).orderBy('updatedAt', descending: true).snapshots().map((snapshot) {
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

  Future<Map<String, dynamic>> verifyTreatmentPersistence({
    required String patientId,
    required String treatmentId,
  }) async {
    final path = FirestorePaths.patientTreatmentDoc(patientId, treatmentId);
    final doc = await _db.doc(path).get();
    return <String, dynamic>{
      'path': path,
      'exists': doc.exists,
      'data': doc.data(),
    };
  }

  Future<void> saveTreatment({
    required String patientId,
    required PatientTreatment treatment,
    String? previousPrimaryId,
  }) async {
    _validateTreatment(treatment);

    final now = DateTime.now();
    final docRef = _treatmentsRef(patientId).doc(treatment.id);
    final existingDoc = await docRef.get();
    final treatmentsSnapshot = await _treatmentsRef(patientId).get();
    final siblingTreatments = treatmentsSnapshot.docs
        .where((doc) => doc.id != treatment.id)
        .map((doc) => PatientTreatment.fromJson(doc.data(), id: doc.id))
        .toList();

    final currentPrimary = siblingTreatments
        .cast<PatientTreatment?>()
        .firstWhere((item) => item?.isPrimary == true, orElse: () => null);
    final isFirstTreatment =
        siblingTreatments.isEmpty &&
        !treatmentsSnapshot.docs.any((doc) => doc.id == treatment.id);
    final mustBePrimary = isFirstTreatment || currentPrimary == null;

    final defaultSubtype = _defaultSubtypeForBaseType(
      treatment.tipoBase.trim(),
    );
    final normalized = treatment.copyWith(
      patientId: patientId,
      subtipo: (treatment.subtipo?.trim().isNotEmpty ?? false)
          ? treatment.subtipo!.trim()
          : (defaultSubtype.isEmpty ? null : defaultSubtype),
      isPrimary: mustBePrimary ? true : treatment.isPrimary,
      nextCleaningDate:
          treatment.nextCleaningDate ??
          _addMonths(
            treatment.fechaInicio,
            treatment.suggestedCleaningEveryMonths,
          ),
      nextControlDate:
          treatment.nextControlDate ??
          _addMonths(
            treatment.fechaInicio,
            treatment.suggestedControlEveryMonths,
          ),
      updatedAt: now,
      updatedBy: treatment.updatedBy ?? treatment.createdBy,
    );

    await docRef.set(normalized.toJson(), SetOptions(merge: true));

    final batch = _db.batch();

    if (normalized.isPrimary) {
      final primaryRefs = await _treatmentsRef(
        patientId,
      ).where('isPrimary', isEqualTo: true).get();
      for (final doc in primaryRefs.docs) {
        if (doc.id == normalized.id) continue;
        batch.set(doc.reference, {
          'isPrimary': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (previousPrimaryId != null &&
          previousPrimaryId.isNotEmpty &&
          previousPrimaryId != normalized.id) {
        final previousRef = _treatmentsRef(patientId).doc(previousPrimaryId);
        batch.set(previousRef, {
          'isPrimary': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      batch.set(docRef, {
        'isPrimary': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(
        _patientRef(patientId),
        _patientProjection(normalized),
        SetOptions(merge: true),
      );
      batch.set(
        _legacyPaymentRef(patientId),
        _legacyPaymentMirror(patientId, normalized),
        SetOptions(merge: true),
      );
    } else {
      batch.set(docRef, {
        'isPrimary': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    batch.set(
      _paymentRef(patientId, normalized.id),
      _treatmentPaymentProjection(patientId, normalized),
      SetOptions(merge: true),
    );

    await batch.commit();
    await _syncRecurringAppointments(
      patientId: patientId,
      treatment: normalized,
      creatingFirstTime: !existingDoc.exists,
    );
  }

  Future<void> setPrimaryTreatment({
    required String patientId,
    required PatientTreatment treatment,
  }) async {
    final batch = _db.batch();
    final snapshot = await _treatmentsRef(patientId).get();
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {
        'isPrimary': doc.id == treatment.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    batch.set(
      _patientRef(patientId),
      _patientProjection(treatment.copyWith(isPrimary: true)),
      SetOptions(merge: true),
    );
    batch.set(
      _legacyPaymentRef(patientId),
      _legacyPaymentMirror(patientId, treatment.copyWith(isPrimary: true)),
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<bool> migrateLegacyPatientTreatmentIfNeeded({
    required PatientModel patient,
    String createdBy = 'system-migration',
  }) async {
    if (patient.tipoTratamiento == null) return false;

    final existing = await _treatmentsRef(patient.id).limit(1).get();
    if (existing.docs.isNotEmpty) return false;

    final migratedTreatment = PatientTreatment.fromLegacyPatient(patient)
        .copyWith(
          id: 'migrated-primary-${patient.id}',
          patientId: patient.id,
          createdAt: patient.createdAt ?? patient.fechaInicio,
          updatedAt: patient.updatedAt ?? patient.fechaInicio,
          createdBy: createdBy,
          updatedBy: createdBy,
          isPrimary: true,
        );

    await saveTreatment(patientId: patient.id, treatment: migratedTreatment);
    return true;
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
      patientId: patientId,
      estado: newStatus,
      updatedAt: DateTime.now(),
      fechaFin: (newStatus == 'finalizado' || newStatus == 'cancelado')
          ? DateTime.now()
          : null,
      updatedBy: treatment.updatedBy ?? treatment.createdBy,
    );

    final batch = _db.batch();
    batch.set(
      _treatmentsRef(patientId).doc(treatment.id),
      updated.toJson(),
      SetOptions(merge: true),
    );

    if (updated.isPrimary) {
      batch.set(
        _patientRef(patientId),
        _patientProjection(updated),
        SetOptions(merge: true),
      );
      batch.set(
        _legacyPaymentRef(patientId),
        _legacyPaymentMirror(patientId, updated),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> _syncRecurringAppointments({
    required String patientId,
    required PatientTreatment treatment,
    required bool creatingFirstTime,
  }) async {
    if (!treatment.isActive) return;

    final patientSnap = await _patientRef(patientId).get();
    final patientData = patientSnap.data() ?? const <String, dynamic>{};
    final patientName = (patientData['nombre'] ?? '').toString().trim();
    final patientPhone = (patientData['telefono'] ?? '').toString().trim();
    if (patientName.isEmpty) return;

    final definitions =
        <({String kind, DateTime? date, String notes, int duration})>[
          (
            kind: 'cleaning',
            date: treatment.nextCleaningDate,
            notes:
                'Limpieza automática del tratamiento ${treatment.displayName}',
            duration: 45,
          ),
          (
            kind: 'control',
            date: treatment.nextControlDate,
            notes:
                'Control automático del tratamiento ${treatment.displayName}',
            duration: 30,
          ),
        ];

    for (final item in definitions) {
      final when = item.date;
      if (when == null) continue;
      final existing = await _appointmentsRef
          .where('patientId', isEqualTo: patientId)
          .where('treatmentId', isEqualTo: treatment.id)
          .where('autoScheduleKind', isEqualTo: item.kind)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        final ref = _appointmentsRef.doc();
        final appointment = AppointmentModel(
          id: ref.id,
          patientId: patientId,
          patientName: patientName,
          patientPhone: patientPhone,
          treatmentId: treatment.id,
          tipo: AppointmentType.control,
          estado: AppointmentStatus.programada,
          fechaHora: when,
          duracionMinutos: item.duration,
          creadoPor: 'system',
          notas: item.notes,
          createdAt: DateTime.now(),
        );
        await ref.set({...appointment.toJson(), 'autoScheduleKind': item.kind});
      } else {
        final doc = existing.docs.first;
        await doc.reference.set({
          'fechaHora': Timestamp.fromDate(when),
          'duracionMinutos': item.duration,
          'tipo': AppointmentType.control.name,
          'estado': AppointmentStatus.programada.name,
          'notas': item.notes,
          'autoScheduleKind': item.kind,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  DateTime _addMonths(DateTime date, int months) {
    return DateTime(date.year, date.month + months, date.day, 9, 0);
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
      final inferredLegacySubtype = _defaultSubtypeForBaseType(tipoBase);
      if (!kTreatmentSubtypes.contains(subtype) &&
          !kTreatmentSubtypes.contains(inferredLegacySubtype)) {
        throw Exception('TREATMENT_SUBTYPE_REQUIRED');
      }
    }
  }

  String _defaultSubtypeForBaseType(String tipoBase) {
    if (!kSubtypeRequiredBaseTreatments.contains(tipoBase)) return '';
    return 'metalico';
  }

  Map<String, dynamic> _patientProjection(PatientTreatment treatment) {
    final total = treatment.totalTratamiento ?? 0;
    final saldo = treatment.saldoPendiente ?? total;
    final paid = (total - saldo).clamp(0, double.infinity).toDouble();
    return <String, dynamic>{
      'primaryTreatmentId': treatment.id,
      'treatmentOverview': {
        'mode': 'primary-treatment',
        'treatmentId': treatment.id,
        'treatmentName': treatment.displayName,
        'baseType': treatment.tipoBase,
        'subtype': treatment.subtipo,
        'currentStage': treatment.etapaActual.name,
        'status': treatment.estado,
        'financial': {
          'totalTratamiento': total,
          'montoPagado': paid,
          'saldoPendiente': saldo,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
      'legacyProjection': {
        'source': 'compatibility-only',
        'primaryTreatmentId': treatment.id,
        'tipoTratamiento': _legacyTreatmentTypeName(treatment),
        'etapaActual': treatment.etapaActual.name,
        'fechaInicio': Timestamp.fromDate(treatment.fechaInicio),
        'totalTratamiento': total,
        'saldoPendiente': saldo,
      },
      'tipoTratamiento': _legacyTreatmentTypeName(treatment),
      'etapaActual': treatment.etapaActual.name,
      'fechaInicio': Timestamp.fromDate(treatment.fechaInicio),
      'totalTratamiento': total,
      'saldoPendiente': saldo,
      if (treatment.notas != null) 'notasClinicas': treatment.notas,
    };
  }

  Map<String, dynamic> _treatmentPaymentProjection(
    String patientId,
    PatientTreatment treatment,
  ) {
    final total = treatment.totalTratamiento ?? 0;
    final saldo = (treatment.saldoPendiente ?? total)
        .clamp(0, double.infinity)
        .toDouble();
    final pagado = (total - saldo).clamp(0, double.infinity).toDouble();

    return <String, dynamic>{
      'id': treatment.id,
      'patientId': patientId,
      'treatmentId': treatment.id,
      'totalTratamiento': total,
      'montoPagado': pagado,
      'saldoPendiente': saldo,
      'estado': saldo <= 0 ? 'pagadoTotal' : 'pendiente',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 2,
      'legacyMigrated': false,
    };
  }

  Map<String, dynamic> _legacyPaymentMirror(
    String patientId,
    PatientTreatment treatment,
  ) {
    final total = treatment.totalTratamiento ?? 0;
    final saldo = (treatment.saldoPendiente ?? total)
        .clamp(0, double.infinity)
        .toDouble();
    final pagado = (total - saldo).clamp(0, double.infinity).toDouble();
    return <String, dynamic>{
      'id': patientId,
      'patientId': patientId,
      'treatmentId': treatment.id,
      'totalTratamiento': total,
      'montoPagado': pagado,
      'saldoPendiente': saldo,
      'updatedAt': FieldValue.serverTimestamp(),
      'legacyMirror': true,
      'schemaVersion': 1,
    };
  }

  String _legacyTreatmentTypeName(PatientTreatment treatment) {
    if (treatment.tipoBase == 'convencional' &&
        treatment.subtipo == 'estetico') {
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
