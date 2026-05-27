import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/simulator/data/models/simulation_model.dart';
import 'package:ocg_proyect/features/simulator/data/repositories/simulation_repository.dart';
import 'package:ocg_proyect/features/simulator/providers/simulation_provider.dart';

class _FakeSimulationRepository extends SimulationRepository {
  _FakeSimulationRepository() : super(FakeFirebaseFirestore());

  String? generateError;
  int generateCalls = 0;
  String? lastPatientId;
  String? lastSimulationId;
  // ── Nuevos campos Bloque 01 ────────────────────────────
  String? lastTreatmentProfileId;
  String? lastVisualGoal;
  Map<String, dynamic>? lastDoctorConfig;
  String? lastDoctorOverride;
  Map<String, dynamic>? lastPhotoQuality;
  String? lastPreviousResultPath;

  @override
  Stream<SimulationModel?> watchSimulation({
    required String patientId,
    required String simulationId,
  }) => const Stream.empty();

  @override
  Future<void> generateWithAi({
    required String patientId,
    required String simulationId,
    required String treatmentType,
    String? notes,
    String? treatmentProfileId,
    String? visualGoal,
    Map<String, dynamic>? doctorConfig,
    String? doctorOverride,
    Map<String, dynamic>? photoQuality,
    String? previousResultPath,
  }) async {
    generateCalls += 1;
    lastPatientId = patientId;
    lastSimulationId = simulationId;
    lastTreatmentProfileId = treatmentProfileId;
    lastVisualGoal = visualGoal;
    lastDoctorConfig = doctorConfig;
    lastDoctorOverride = doctorOverride;
    lastPhotoQuality = photoQuality;
    lastPreviousResultPath = previousResultPath;
    if (generateError != null) throw Exception(generateError!);
  }
}

void main() {
  SimulationModel baseSimulation({
    SimulationStatus status = SimulationStatus.draft,
    String? treatmentProfileId,
    String? visualGoal,
    Map<String, dynamic>? doctorConfig,
    Map<String, dynamic>? photoQuality,
    String doctorReviewStatus = 'pending',
    String? approvedAttemptId,
  }) {
    final now = DateTime(2026, 5, 4);
    return SimulationModel(
      id: 's1',
      patientId: 'p1',
      originalPath: 'simulations/p1/s1/original.jpg',
      resultPath: status == SimulationStatus.ready
          ? 'simulations/p1/s1/result.jpg'
          : null,
      compartidaConPaciente: false,
      createdAt: now,
      updatedAt: now,
      createdBy: 'admin-1',
      treatmentType: TreatmentType.convencional,
      status: status,
      notes: 'demo',
      generationProvider: 'openai',
      modelUsed: 'gpt-image-2',
      attemptCount: 0,
      errorMessage: null,
      generatedAt: null,
      promptUsed: null,
      promptVersion: null,
      mlKitUsed: false,
      detectedRegion: null,
      promptMetadata: const {'faceDetectionSource': 'manual'},
      fechaCompartida: null,
      treatmentProfileId: treatmentProfileId,
      visualGoal: visualGoal,
      doctorConfig: doctorConfig,
      photoQuality: photoQuality,
      doctorReviewStatus: doctorReviewStatus,
      approvedAttemptId: approvedAttemptId,
    );
  }

  test('mapea falta de API KEY a mensaje claro', () async {
    final repo = _FakeSimulationRepository()
      ..generateError =
          'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.';
    final container = ProviderContainer(
      overrides: [simulationRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(simulatorFlowProvider.notifier);
    notifier.loadExistingSimulation(baseSimulation());
    await notifier.generateWithAi(
      patientId: 'p1',
      treatmentType: 'Ortodoncia convencional',
    );

    final state = container.read(simulatorFlowProvider).requireValue;
    expect(
      state.errorMessage,
      'El simulador IA está instalado, pero falta configurar'
      ' la API KEY en Firebase Functions.',
    );
    expect(state.status, SimulationStatus.draft);
  });

  test('mapea simulador deshabilitado a mensaje claro', () async {
    final repo = _FakeSimulationRepository()
      ..generateError =
          'El simulador IA está instalado, pero está desactivado'
          ' en Firebase Functions.';
    final container = ProviderContainer(
      overrides: [simulationRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(simulatorFlowProvider.notifier);
    notifier.loadExistingSimulation(baseSimulation());
    await notifier.generateWithAi(
      patientId: 'p1',
      treatmentType: 'Ortodoncia convencional',
    );

    final state = container.read(simulatorFlowProvider).requireValue;
    expect(
      state.errorMessage,
      'El simulador IA está instalado, pero está desactivado'
      ' en Firebase Functions.',
    );
    expect(repo.generateCalls, 1);
  });

  test('_applySimulation propaga treatmentProfileId, doctorConfig'
      ' y photoQuality', () {
    final repo = _FakeSimulationRepository();
    final container = ProviderContainer(
      overrides: [simulationRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);

    final sim = baseSimulation(
      treatmentProfileId: 'metal_braces',
      visualGoal: 'show_appliance',
      doctorConfig: {'ligatureColor': 'gris'},
      photoQuality: {'status': 'valid', 'score': 0.85},
      doctorReviewStatus: 'pending',
      approvedAttemptId: null,
    );

    final notifier = container.read(simulatorFlowProvider.notifier);
    notifier.loadExistingSimulation(sim);

    final state = container.read(simulatorFlowProvider).requireValue;
    expect(state.treatmentProfileId, 'metal_braces');
    expect(state.visualGoal, 'show_appliance');
    expect(state.doctorConfig?['ligatureColor'], 'gris');
    expect(state.photoQuality?['status'], 'valid');
    expect(state.photoQuality?['score'], 0.85);
    expect(state.doctorReviewStatus, 'pending');
    expect(state.approvedAttemptId, null);
  });

  test('generateWithAi envia campos nuevos al repo', () async {
    final repo = _FakeSimulationRepository();
    final container = ProviderContainer(
      overrides: [simulationRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);

    final sim = baseSimulation(
      treatmentProfileId: 'esthetic_braces',
      visualGoal: 'show_appliance',
      doctorConfig: {'material': 'zafiro'},
      photoQuality: {'status': 'valid'},
    );

    final notifier = container.read(simulatorFlowProvider.notifier);
    notifier.loadExistingSimulation(sim);
    await notifier.generateWithAi(
      patientId: 'p1',
      treatmentType: 'Ortodoncia estética',
    );

    expect(repo.lastTreatmentProfileId, 'esthetic_braces');
    expect(repo.lastVisualGoal, 'show_appliance');
    expect(repo.lastDoctorConfig?['material'], 'zafiro');
    expect(repo.lastPhotoQuality?['status'], 'valid');
    expect(repo.generateCalls, 1);
  });

  test('al regenerar limpia resultado anterior y pasa path previo', () async {
    final repo = _FakeSimulationRepository();
    final container = ProviderContainer(
      overrides: [simulationRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);

    await container.read(simulatorFlowProvider.future);
    final notifier = container.read(simulatorFlowProvider.notifier);
    notifier.loadExistingSimulation(
      baseSimulation(status: SimulationStatus.ready).copyWith(
        attemptCount: 1,
        resultPath: 'simulations/p1/s1/attempts/attempt_1/result.jpg',
      ),
    );

    await notifier.generateWithAi(
      patientId: 'p1',
      treatmentType: 'Ortodoncia convencional',
    );

    final state = container.read(simulatorFlowProvider).requireValue;
    expect(
      repo.lastPreviousResultPath,
      'simulations/p1/s1/attempts/attempt_1/result.jpg',
    );
    expect(state.status, SimulationStatus.generating);
    expect(state.resultPath, isNull);
    expect(state.doctorReviewStatus, 'pending');
  });
}
