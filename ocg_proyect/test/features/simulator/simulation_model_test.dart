import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/simulator/data/models/simulation_model.dart';

void main() {
  test('SimulationModel serializa y deserializa campos principales', () {
    final model = SimulationModel(
      id: 'sim-1',
      patientId: 'p-1',
      originalPath: 'simulations/p-1/sim-1/original.jpg',
      resultPath: null,
      compartidaConPaciente: false,
      createdAt: DateTime(2026, 3, 23, 12, 0),
      updatedAt: DateTime(2026, 3, 23, 12, 30),
      createdBy: 'admin-1',
      treatmentType: TreatmentType.alineadores,
      status: SimulationStatus.draft,
      notes: 'Primera carga',
      generationProvider: 'openai',
      modelUsed: 'gpt-image-2',
      attemptCount: 0,
      errorMessage: null,
      generatedAt: null,
      promptUsed: null,
      promptVersion: 'v1',
      mlKitUsed: false,
      detectedRegion: {'x': 0.2, 'y': 0.3, 'w': 0.4, 'h': 0.2},
      promptMetadata: {'version': 'v1'},
      fechaCompartida: null,
      // ── Nuevos campos ──────────────────────────────────
      treatmentProfileId: 'clear_aligners',
      visualGoal: 'show_appliance',
      doctorConfig: {'material': 'ceramico'},
      photoQuality: {'status': 'valid', 'score': 0.9},
      doctorReviewStatus: 'pending',
      approvedAttemptId: null,
    );

    final json = model.toJson();
    expect(json['createdAt'], isA<Timestamp>());
    expect(json['updatedAt'], isA<Timestamp>());

    final decoded = SimulationModel.fromJson(json);
    expect(decoded.id, 'sim-1');
    expect(decoded.patientId, 'p-1');
    expect(decoded.generationProvider, 'openai');
    expect(decoded.modelUsed, 'gpt-image-2');
    expect(decoded.treatmentType, TreatmentType.alineadores);
    expect(decoded.status, SimulationStatus.draft);
    expect(decoded.notes, 'Primera carga');
    expect(decoded.detectedRegion?['w'], 0.4);
    expect(decoded.promptMetadata?['version'], 'v1');

    // ── Nuevos campos ────────────────────────────────────
    expect(decoded.treatmentProfileId, 'clear_aligners');
    expect(decoded.visualGoal, 'show_appliance');
    expect(decoded.doctorConfig?['material'], 'ceramico');
    expect(decoded.photoQuality?['status'], 'valid');
    expect(decoded.photoQuality?['score'], 0.9);
    expect(decoded.doctorReviewStatus, 'pending');
    expect(decoded.approvedAttemptId, null);
  });

  test('SimulationModel mantiene compatibilidad con legacy'
      ' originalUrl/resultUrl/mode', () {
    final decoded = SimulationModel.fromJson({
      'id': 'legacy-1',
      'patientId': 'p-legacy',
      'originalUrl': 'https://x/original.jpg',
      'resultUrl': 'https://x/result.jpg',
      'mode': 'manualDoctora',
      'creadoPor': 'admin-legacy',
      'status': 'ready',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });

    expect(decoded.originalPath, 'https://x/original.jpg');
    expect(decoded.resultPath, 'https://x/result.jpg');
    expect(decoded.createdBy, 'admin-legacy');
    expect(decoded.status, SimulationStatus.ready);
  });

  test('documento legacy sin campos nuevos usa defaults correctos', () {
    final decoded = SimulationModel.fromJson({
      'id': 'legacy-no-new',
      'patientId': 'p-legacy',
      'originalPath': 'simulations/p-legacy/legacy-no-new/original.jpg',
      'status': 'draft',
      'compartidaConPaciente': false,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'createdBy': 'admin-legacy',
      'generationProvider': 'openai',
      'modelUsed': 'gpt-image-2',
      'attemptCount': 0,
      'mlKitUsed': false,
      // sin treatmentProfileId, visualGoal, doctorConfig,
      // photoQuality, doctorReviewStatus, approvedAttemptId
    });

    expect(decoded.treatmentProfileId, isNull);
    expect(decoded.visualGoal, isNull);
    expect(decoded.doctorConfig, isNull);
    expect(decoded.photoQuality, isNull);
    expect(decoded.doctorReviewStatus, 'pending');
    expect(decoded.approvedAttemptId, isNull);
  });

  test('doctorConfig y photoQuality aceptan y redondean mapas', () {
    final model = SimulationModel(
      id: 'map-test',
      patientId: 'p-1',
      originalPath: 'simulations/p-1/map-test/original.jpg',
      resultPath: null,
      compartidaConPaciente: false,
      createdAt: DateTime(2026, 5, 22),
      updatedAt: null,
      createdBy: 'admin-1',
      treatmentType: TreatmentType.convencional,
      status: SimulationStatus.draft,
      notes: null,
      generationProvider: 'openai',
      modelUsed: 'gpt-image-2',
      attemptCount: 0,
      errorMessage: null,
      generatedAt: null,
      promptUsed: null,
      promptVersion: null,
      mlKitUsed: false,
      detectedRegion: null,
      promptMetadata: null,
      fechaCompartida: null,
      doctorConfig: {
        'ligatureColor': 'gris',
        'arcada': 'superior',
      },
      photoQuality: {
        'status': 'usable_with_warning',
        'score': 0.72,
        'warnings': ['Luz baja'],
      },
      doctorReviewStatus: 'approved',
      approvedAttemptId: 'attempt_1',
    );

    final json = model.toJson();
    final decoded = SimulationModel.fromJson(json);

    expect(decoded.doctorConfig?['ligatureColor'], 'gris');
    expect(decoded.doctorConfig?['arcada'], 'superior');
    expect(decoded.photoQuality?['status'], 'usable_with_warning');
    expect(decoded.photoQuality?['score'], 0.72);
    expect(decoded.doctorReviewStatus, 'approved');
    expect(decoded.approvedAttemptId, 'attempt_1');
  });

  test('copyWith limpia y setea campos nuevos', () {
    final original = SimulationModel(
      id: 'sim-cw',
      patientId: 'p-cw',
      originalPath: 'simulations/p-cw/sim-cw/original.jpg',
      resultPath: null,
      compartidaConPaciente: false,
      createdAt: DateTime(2026, 5, 22),
      updatedAt: null,
      createdBy: 'admin-1',
      treatmentType: null,
      status: SimulationStatus.draft,
      notes: null,
      generationProvider: 'openai',
      modelUsed: 'gpt-image-2',
      attemptCount: 0,
      errorMessage: null,
      generatedAt: null,
      promptUsed: null,
      promptVersion: null,
      mlKitUsed: false,
      detectedRegion: null,
      promptMetadata: null,
      fechaCompartida: null,
      treatmentProfileId: 'metal_braces',
      visualGoal: 'show_appliance',
      doctorConfig: {'ligatureColor': 'gris'},
      photoQuality: {'status': 'valid'},
      doctorReviewStatus: 'pending',
      approvedAttemptId: null,
    );

    // Actualizar doctorReviewStatus
    final approved = original.copyWith(doctorReviewStatus: 'approved');
    expect(approved.doctorReviewStatus, 'approved');
    expect(approved.treatmentProfileId, 'metal_braces'); // no se perdió

    // Limpiar doctorConfig
    final cleared = original.copyWith(clearDoctorConfig: true);
    expect(cleared.doctorConfig, isNull);

    // Limpiar treatmentProfileId
    final clearedProfile =
        original.copyWith(clearTreatmentProfileId: true);
    expect(clearedProfile.treatmentProfileId, isNull);

    // Setear approvedAttemptId
    final withAttempt =
        original.copyWith(approvedAttemptId: 'attempt_1');
    expect(withAttempt.approvedAttemptId, 'attempt_1');
  });
}
