import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/constants/firestore_paths.dart';
import '../appointments/data/models/appointment_model.dart';
import '../clinical_files/data/models/clinical_file_model.dart';
import '../consultation/data/models/consultation_model.dart';
import '../patients/data/models/patient_model.dart';
import '../treatment/data/models/patient_treatment.dart';

/// Resultado de la migracion legacy para un paciente.
class LegacyMigrationResult {
  const LegacyMigrationResult({
    required this.patientId,
    required this.patientName,
    this.appointmentsAutoLinked = 0,
    this.appointmentsMarkedLegacy = 0,
    this.clinicalFilesAutoLinked = 0,
    this.clinicalFilesMarkedLegacy = 0,
    this.consultationsReviewed = 0,
    this.stageHistoryReviewed = 0,
    this.errors = const [],
  });

  final String patientId;
  final String patientName;
  final int appointmentsAutoLinked;
  final int appointmentsMarkedLegacy;
  final int clinicalFilesAutoLinked;
  final int clinicalFilesMarkedLegacy;
  final int consultationsReviewed;
  final int stageHistoryReviewed;
  final List<String> errors;

  int get totalActions =>
      appointmentsAutoLinked +
      appointmentsMarkedLegacy +
      clinicalFilesAutoLinked +
      clinicalFilesMarkedLegacy;

  bool get hasErrors => errors.isNotEmpty;
}

/// Servicio de migracion conservadora para datos legacy (Bloque 09).
///
/// Reglas:
/// 1. Citas sin treatmentId:
///    - si el paciente tiene un solo tratamiento activo, asociarlas a ese tratamiento
///    - si tiene varios tratamientos, marcar como legacy_unlinked
///    - si no tiene tratamientos, no tocar
/// 2. Stage history con treatmentId vacio:
///    - mantener en historial general (pacientes/{patientId}/stageHistory)
///    - no mover automaticamente si hay duda
/// 3. Documentos sin treatmentId:
///    - marcar como legacy si no se puede inferir
///    - ya se muestran en filtro "Sin tratamiento"
/// 4. Dictamenes existentes:
///    - revisar que tengan consultationId ligado
///    - no inventar treatmentId si el dato no es confiable
class LegacyMigrationService {
  LegacyMigrationService(this._db);

  final FirebaseFirestore _db;

  /// Ejecuta la migracion para TODOS los pacientes del sistema.
  ///
  /// Retorna una lista de resultados por paciente.
  Future<List<LegacyMigrationResult>> migrateAll({
    void Function(String message)? onProgress,
  }) async {
    final results = <LegacyMigrationResult>[];

    onProgress?.call('Obteniendo lista de pacientes...');
    final patientsSnapshot = await _db
        .collection(FirestorePaths.patients)
        .where('active', isEqualTo: true)
        .get();

    final patients = patientsSnapshot.docs
        .map((doc) => PatientModel.fromJson(doc.data(), id: doc.id))
        .toList();

    onProgress?.call('${patients.length} pacientes encontrados.');

    for (int i = 0; i < patients.length; i++) {
      final patient = patients[i];
      onProgress?.call(
        'Migrando ${i + 1}/${patients.length}: ${patient.nombre}',
      );
      final result = await _migratePatient(patient);
      if (result.totalActions > 0 || result.hasErrors) {
        results.add(result);
      }
    }

    onProgress?.call(
      'Migracion completada. ${results.length} pacientes con cambios.',
    );
    return results;
  }

  /// Ejecuta la migracion para UN solo paciente.
  Future<LegacyMigrationResult> migratePatient({
    required String patientId,
    PatientModel? patient,
  }) async {
    final resolvedPatient = patient ??
        await _fetchPatient(patientId);
    if (resolvedPatient == null) {
      return LegacyMigrationResult(
        patientId: patientId,
        patientName: 'Desconocido',
        errors: ['Paciente no encontrado: $patientId'],
      );
    }
    return _migratePatient(resolvedPatient);
  }

  // ─── Migracion por paciente ─────────────────────────────────────────────

  Future<LegacyMigrationResult> _migratePatient(PatientModel patient) async {
    final errors = <String>[];
    int appointmentsAutoLinked = 0;
    int appointmentsMarkedLegacy = 0;
    int clinicalFilesAutoLinked = 0;
    int clinicalFilesMarkedLegacy = 0;
    int consultationsReviewed = 0;
    int stageHistoryReviewed = 0;

    // Obtener tratamientos activos del paciente
    final treatments = await _getPatientTreatments(patient.id);
    final activeTreatments = treatments
        .where((t) => t.isActive && !t.id.startsWith('legacy-'))
        .toList();

    // Determinar el treatmentId canonico para auto-asociacion
    String? canonicalTreatmentId;
    String? canonicalTreatmentName;
    bool hasMultipleTreatments = activeTreatments.length > 1;

    if (activeTreatments.length == 1) {
      canonicalTreatmentId = activeTreatments.first.id;
      canonicalTreatmentName = activeTreatments.first.displayName;
    }

    try {
      // 1. Migrar citas
      final appointmentResult = await _migrateAppointments(
        patientId: patient.id,
        patientName: patient.nombre,
        canonicalTreatmentId: canonicalTreatmentId,
        canonicalTreatmentName: canonicalTreatmentName,
        hasMultipleTreatments: hasMultipleTreatments,
      );
      appointmentsAutoLinked = appointmentResult.$1;
      appointmentsMarkedLegacy = appointmentResult.$2;
    } catch (e) {
      errors.add('Citas: $e');
    }

    try {
      // 2. Migrar documentos clinicos
      final filesResult = await _migrateClinicalFiles(
        patientId: patient.id,
        canonicalTreatmentId: canonicalTreatmentId,
        canonicalTreatmentName: canonicalTreatmentName,
        hasMultipleTreatments: hasMultipleTreatments,
      );
      clinicalFilesAutoLinked = filesResult.$1;
      clinicalFilesMarkedLegacy = filesResult.$2;
    } catch (e) {
      errors.add('Documentos: $e');
    }

    try {
      // 3. Revisar stage history (solo lectura, no mover)
      stageHistoryReviewed = await _reviewStageHistory(patient.id);
    } catch (e) {
      errors.add('Stage history: $e');
    }

    try {
      // 4. Revisar dictamenes/consultas (solo lectura)
      consultationsReviewed = await _reviewConsultations(
        patient.id,
        treatments,
      );
    } catch (e) {
      errors.add('Consultas: $e');
    }

    return LegacyMigrationResult(
      patientId: patient.id,
      patientName: patient.nombre,
      appointmentsAutoLinked: appointmentsAutoLinked,
      appointmentsMarkedLegacy: appointmentsMarkedLegacy,
      clinicalFilesAutoLinked: clinicalFilesAutoLinked,
      clinicalFilesMarkedLegacy: clinicalFilesMarkedLegacy,
      consultationsReviewed: consultationsReviewed,
      stageHistoryReviewed: stageHistoryReviewed,
      errors: errors,
    );
  }

  // ─── Migracion de citas ─────────────────────────────────────────────────

  /// Migrar citas sin treatmentId.
  ///
  /// Reglas:
  /// - Si paciente tiene un solo tratamiento activo → asociar automaticamente
  /// - Si tiene varios → marcar como legacy_unlinked
  /// - Si no tiene → no tocar
  Future<(int autoLinked, int markedLegacy)> _migrateAppointments({
    required String patientId,
    required String patientName,
    String? canonicalTreatmentId,
    String? canonicalTreatmentName,
    required bool hasMultipleTreatments,
  }) async {
    int autoLinked = 0;
    int markedLegacy = 0;

    final snapshot = await _db
        .collection(FirestorePaths.appointments)
        .where('patientId', isEqualTo: patientId)
        .get();

    final batch = _db.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingTreatmentId = data['treatmentId'];

      // Solo procesar citas sin treatmentId
      if (existingTreatmentId != null &&
          existingTreatmentId.toString().isNotEmpty) {
        continue;
      }

      final updates = <String, dynamic>{};

      if (canonicalTreatmentId != null && !hasMultipleTreatments) {
        // Auto-asociar al unico tratamiento activo
        updates['treatmentId'] = canonicalTreatmentId;
        updates['treatmentNameSnapshot'] = canonicalTreatmentName;
        updates['migratedAt'] = FieldValue.serverTimestamp();
        updates['migratedBy'] = 'legacy-migration-service';
        updates['migrationNote'] = 'Auto-asociado por tener un solo tratamiento.';
        batch.update(doc.reference, updates);
        autoLinked++;
      } else if (hasMultipleTreatments) {
        // Marcar como legacy para revision manual
        updates['treatmentId'] = 'legacy_unlinked';
        updates['treatmentNameSnapshot'] =
            'Legacy — requiere revision manual (varios tratamientos).';
        updates['migratedAt'] = FieldValue.serverTimestamp();
        updates['migratedBy'] = 'legacy-migration-service';
        updates['migrationNote'] =
            'Paciente con varios tratamientos. Requiere asignacion manual.';
        batch.update(doc.reference, updates);
        markedLegacy++;
      }
      // Si no tiene tratamientos, no tocar la cita
    }

    if (autoLinked > 0 || markedLegacy > 0) {
      await batch.commit();
    }

    return (autoLinked, markedLegacy);
  }

  // ─── Migracion de documentos clinicos ───────────────────────────────────

  /// Migrar documentos clinicos sin treatmentId.
  ///
  /// Reglas:
  /// - Si paciente tiene un solo tratamiento activo → asociar automaticamente
  /// - Si tiene varios → marcar categoria como 'legacy' para visibilidad
  /// - Si no tiene → no tocar
  Future<(int autoLinked, int markedLegacy)> _migrateClinicalFiles({
    required String patientId,
    String? canonicalTreatmentId,
    String? canonicalTreatmentName,
    required bool hasMultipleTreatments,
  }) async {
    int autoLinked = 0;
    int markedLegacy = 0;

    final snapshot = await _db
        .collection(FirestorePaths.patientClinicalFiles(patientId))
        .get();

    final batch = _db.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingTreatmentId = data['treatmentId'];

      // Solo procesar archivos sin treatmentId
      if (existingTreatmentId != null &&
          existingTreatmentId.toString().isNotEmpty) {
        continue;
      }

      final updates = <String, dynamic>{};

      if (canonicalTreatmentId != null && !hasMultipleTreatments) {
        // Auto-asociar al unico tratamiento activo
        updates['treatmentId'] = canonicalTreatmentId;
        updates['treatmentNameSnapshot'] = canonicalTreatmentName;
        updates['migratedAt'] = FieldValue.serverTimestamp();
        updates['migratedBy'] = 'legacy-migration-service';
        updates['migrationNote'] = 'Auto-asociado por tener un solo tratamiento.';
        batch.update(doc.reference, updates);
        autoLinked++;
      } else if (hasMultipleTreatments) {
        // Marcar como legacy para visibilidad en filtro "Sin tratamiento"
        updates['treatmentId'] = 'legacy_unlinked';
        updates['treatmentNameSnapshot'] =
            'Legacy — requiere revision manual.';
        updates['migratedAt'] = FieldValue.serverTimestamp();
        updates['migratedBy'] = 'legacy-migration-service';
        updates['migrationNote'] =
            'Paciente con varios tratamientos. Categoria legacy.';
        batch.update(doc.reference, updates);
        markedLegacy++;
      }
      // Si no tiene tratamientos, no tocar el archivo
    }

    if (autoLinked > 0 || markedLegacy > 0) {
      await batch.commit();
    }

    return (autoLinked, markedLegacy);
  }

  // ─── Revision de stage history ──────────────────────────────────────────

  /// Revisar stage history sin treatmentId.
  ///
  /// Solo cuenta los registros que necesitan revision.
  /// NO mueve ni modifica automaticamente.
  Future<int> _reviewStageHistory(String patientId) async {
    final snapshot = await _db
        .collection(FirestorePaths.stageHistory(patientId))
        .get();

    return snapshot.docs.length;
  }

  // ─── Revision de consultas/dictamenes ───────────────────────────────────

  /// Revisar consultas/dictamenes existentes.
  ///
  /// Solo cuenta los registros que necesitan revision.
  /// NO inventa treatmentId si el dato no es confiable.
  Future<int> _reviewConsultations(
    String patientId,
    List<PatientTreatment> treatments,
  ) async {
    final snapshot = await _db
        .collection(FirestorePaths.patientConsultations(patientId))
        .get();

    int withoutTreatment = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final treatmentId = data['treatmentId'];

      if (treatmentId == null || treatmentId.toString().isEmpty) {
        withoutTreatment++;
      }
    }

    return snapshot.docs.length;
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  Future<List<PatientTreatment>> _getPatientTreatments(
    String patientId,
  ) async {
    final snapshot = await _db
        .collection(FirestorePaths.patientTreatments(patientId))
        .get();

    return snapshot.docs
        .map((doc) => PatientTreatment.fromJson(doc.data(), id: doc.id))
        .toList();
  }

  Future<PatientModel?> _fetchPatient(String patientId) async {
    final doc = await _db
        .collection(FirestorePaths.patients)
        .doc(patientId)
        .get();

    if (!doc.exists) return null;
    return PatientModel.fromJson(doc.data()!, id: doc.id);
  }
}
