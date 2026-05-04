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
  }) async {
    generateCalls += 1;
    lastPatientId = patientId;
    lastSimulationId = simulationId;
    if (generateError != null) throw Exception(generateError!);
  }
}

void main() {
  SimulationModel baseSimulation({SimulationStatus status = SimulationStatus.draft}) {
    final now = DateTime(2026, 5, 4);
    return SimulationModel(
      id: 's1',
      patientId: 'p1',
      originalPath: 'simulations/p1/s1/original.jpg',
      resultPath: status == SimulationStatus.ready ? 'simulations/p1/s1/result.jpg' : null,
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
    );
  }

  test('mapea falta de API KEY a mensaje claro', () async {
    final repo = _FakeSimulationRepository()..generateError = 'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.';
    final container = ProviderContainer(
      overrides: [simulationRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(simulatorFlowProvider.notifier);
    notifier.loadExistingSimulation(baseSimulation());
    await notifier.generateWithAi(patientId: 'p1', treatmentType: 'Ortodoncia convencional');

    final state = container.read(simulatorFlowProvider).requireValue;
    expect(state.errorMessage, 'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.');
    expect(state.status, SimulationStatus.draft);
  });

  test('mapea simulador deshabilitado a mensaje claro', () async {
    final repo = _FakeSimulationRepository()..generateError = 'El simulador IA está instalado, pero está desactivado en Firebase Functions.';
    final container = ProviderContainer(
      overrides: [simulationRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(simulatorFlowProvider.notifier);
    notifier.loadExistingSimulation(baseSimulation());
    await notifier.generateWithAi(patientId: 'p1', treatmentType: 'Ortodoncia convencional');

    final state = container.read(simulatorFlowProvider).requireValue;
    expect(state.errorMessage, 'El simulador IA está instalado, pero está desactivado en Firebase Functions.');
    expect(repo.generateCalls, 1);
  });
}
