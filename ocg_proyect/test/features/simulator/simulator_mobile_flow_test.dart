import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/auth/providers/auth_providers.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/patients/presentation/tabs/patient_simulator_tab.dart';
import 'package:ocg_proyect/features/simulator/data/models/simulation_model.dart';
import 'package:ocg_proyect/features/simulator/data/repositories/simulation_repository.dart';
import 'package:ocg_proyect/features/simulator/presentation/simulator_screen.dart';
import 'package:ocg_proyect/features/simulator/providers/simulation_provider.dart';
import 'package:ocg_proyect/services/firebase/face_detection_service.dart';
import 'package:ocg_proyect/services/firebase/image_picker_service.dart';

class _FakeUser implements User {
  @override
  final String uid;

  _FakeUser(this.uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FlowFakeRepository extends SimulationRepository {
  _FlowFakeRepository() : super(FakeFirebaseFirestore());

  SimulationModel? lastCreated;
  String? generateError;
  List<SimulationModel> simulations = const [];

  @override
  Stream<List<SimulationModel>> watchSimulations(String patientId) {
    return Stream.value(
      simulations.where((s) => s.patientId == patientId).toList(),
    );
  }

  @override
  Stream<SimulationModel?> watchSimulation({
    required String patientId,
    required String simulationId,
  }) {
    if (lastCreated != null &&
        lastCreated!.patientId == patientId &&
        lastCreated!.id == simulationId) {
      return Stream.value(lastCreated);
    }
    final existing = simulations.where(
      (s) => s.patientId == patientId && s.id == simulationId,
    );
    if (existing.isNotEmpty) return Stream.value(existing.first);
    return const Stream.empty();
  }

  @override
  Future<String> uploadOriginalImage({
    required String patientId,
    required String simulationId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    return 'simulations/$patientId/$simulationId/original.jpg';
  }

  @override
  Future<SimulationModel> createDraftSimulation({
    required String patientId,
    required String createdBy,
    required String originalPath,
    String? simulationId,
    TreatmentType? treatmentType,
    String? notes,
    bool mlKitUsed = false,
    Map<String, dynamic>? detectedRegion,
    String? promptUsed,
    String? promptVersion,
    Map<String, dynamic>? promptMetadata,
  }) async {
    lastCreated = SimulationModel(
      id: simulationId ?? 'sim-draft',
      patientId: patientId,
      originalPath: originalPath,
      resultPath: null,
      compartidaConPaciente: false,
      createdAt: DateTime(2026, 5, 4),
      updatedAt: DateTime(2026, 5, 4),
      createdBy: createdBy,
      treatmentType: treatmentType,
      status: SimulationStatus.draft,
      notes: notes,
      generationProvider: 'openai',
      modelUsed: 'gpt-image-2',
      attemptCount: 0,
      errorMessage: null,
      generatedAt: null,
      promptUsed: promptUsed,
      promptVersion: promptVersion,
      mlKitUsed: mlKitUsed,
      detectedRegion: detectedRegion,
      promptMetadata: promptMetadata,
      fechaCompartida: null,
    );
    return lastCreated!;
  }

  @override
  Future<void> generateWithAi({
    required String patientId,
    required String simulationId,
    required String treatmentType,
    String? notes,
  }) async {
    if (generateError != null) throw Exception(generateError!);
  }

  @override
  Future<String?> resolveMediaUrl(String? pathOrUrl) async =>
      'https://example.com/image.jpg';
}

class _FakePickerService extends ImagePickerService {
  _FakePickerService() : super();

  @override
  Future<PickedImageData?> pickFromCamera() async {
    return PickedImageData(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'demo.jpg',
      mimeType: 'image/jpeg',
      filePath: '/tmp/demo.jpg',
    );
  }

  @override
  Future<PickedImageData?> pickFromGallery() => pickFromCamera();
}

class _FakeFaceDetectionService extends FaceDetectionService {
  @override
  Future<FaceDetectionResult> detectSmileRegion({
    required String imagePath,
  }) async {
    return const FaceDetectionResult(
      hasFace: true,
      detectedRegion: {'x': 10.0, 'y': 20.0, 'w': 30.0, 'h': 40.0},
      source: 'fake_mlkit',
    );
  }
}

SimulationModel _sim({
  required String id,
  required SimulationStatus status,
  bool shared = false,
  String? resultPath,
}) {
  return SimulationModel(
    id: id,
    patientId: 'p1',
    originalPath: 'simulations/p1/$id/original.jpg',
    resultPath: resultPath,
    compartidaConPaciente: shared,
    createdAt: DateTime(2026, 5, 4),
    updatedAt: DateTime(2026, 5, 4),
    createdBy: 'admin-1',
    treatmentType: TreatmentType.convencional,
    status: status,
    notes: 'demo',
    generationProvider: 'openai',
    modelUsed: 'gpt-image-2',
    attemptCount: 0,
    errorMessage: status == SimulationStatus.failed ? 'falló' : null,
    generatedAt: null,
    promptUsed: null,
    promptVersion: null,
    mlKitUsed: false,
    detectedRegion: const {'x': 1.0, 'y': 2.0, 'w': 3.0, 'h': 4.0},
    promptMetadata: const {'faceDetectionSource': 'manual'},
    fechaCompartida: null,
  );
}

PatientModel _patient() {
  return PatientModel(
    id: 'p1',
    nombre: 'Paciente Demo',
    email: 'demo@test.com',
    telefono: '300',
    fechaNacimiento: DateTime(2000, 1, 1),
    tipoTratamiento: TreatmentType.convencional,
    etapaActual: TreatmentStage.controles,
    fechaInicio: DateTime(2026, 1, 1),
    notasClinicas: 'demo',
    totalTratamiento: 0,
    saldoPendiente: 0,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Widget _wrap(Widget child, {List overrides = const []}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  test(
    'después de pickOriginalFromCamera el estado queda draftReady',
    () async {
      final repo = _FlowFakeRepository();
      final container = ProviderContainer(
        overrides: [
          simulationRepositoryProvider.overrideWith((ref) => repo),
          imagePickerServiceProvider.overrideWith(
            (ref) => _FakePickerService(),
          ),
          faceDetectionServiceProvider.overrideWith(
            (ref) => _FakeFaceDetectionService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(simulatorFlowProvider.notifier)
          .pickOriginalFromCamera(
            patientId: 'p1',
            adminId: 'admin-1',
            treatmentType: TreatmentType.convencional,
          );

      final state = container.read(simulatorFlowProvider).requireValue;
      expect(state.uiState, SimulatorUiState.draftReady);
      expect(state.status, SimulationStatus.draft);
      expect(state.simulationId, startsWith('sim_'));
      expect(
        state.originalPath,
        'simulations/p1/${state.simulationId}/original.jpg',
      );
      expect(state.detectedRegion, isNotNull);
    },
  );

  testWidgets('SimulatorScreen embebido no crea scroll anidado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FlowFakeRepository();
    final flow = SimulatorFlowState(
      uiState: SimulatorUiState.draftReady,
      patientId: 'p1',
      simulationId: 'sim-draft',
      originalPath: 'simulations/p1/sim-draft/original.jpg',
      status: SimulationStatus.draft,
      notes: 'demo',
      detectedRegion: const {'x': 1.0, 'y': 2.0, 'w': 3.0, 'h': 4.0},
    );

    await tester.pumpWidget(
      _wrap(
        SimulatorScreen(
          patientId: 'p1',
          adminId: 'admin-1',
          treatmentType: TreatmentType.convencional,
          embedded: true,
        ),
        overrides: [
          simulationRepositoryProvider.overrideWith((ref) => repo),
          simulatorFlowProvider.overrideWith(() => _StaticFlowNotifier(flow)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('Generar con IA'), findsOneWidget);
    expect(find.text('Ajustar región manualmente'), findsNothing);
    expect(find.text('X:'), findsNothing);
    expect(find.text('Y:'), findsNothing);
    expect(find.text('W:'), findsNothing);
    expect(find.text('H:'), findsNothing);
  });

  testWidgets('preview de imagen ofrece Ver foto completa en draft', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FlowFakeRepository();
    final flow = SimulatorFlowState(
      uiState: SimulatorUiState.draftReady,
      patientId: 'p1',
      simulationId: 'sim-draft',
      originalPath: 'simulations/p1/sim-draft/original.jpg',
      status: SimulationStatus.draft,
      notes: 'demo',
      detectedRegion: const {'x': 1.0, 'y': 2.0, 'w': 3.0, 'h': 4.0},
    );

    await tester.pumpWidget(
      _wrap(
        SimulatorScreen(
          patientId: 'p1',
          adminId: 'admin-1',
          treatmentType: TreatmentType.convencional,
          embedded: true,
        ),
        overrides: [
          simulationRepositoryProvider.overrideWith((ref) => repo),
          simulatorFlowProvider.overrideWith(() => _StaticFlowNotifier(flow)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ver foto completa'), findsOneWidget);
  });

  testWidgets('si falta API key se muestra mensaje claro al intentar generar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FlowFakeRepository()
      ..generateError =
          'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.';
    final flow = SimulatorFlowState(
      uiState: SimulatorUiState.draftReady,
      patientId: 'p1',
      simulationId: 'sim-draft',
      originalPath: 'simulations/p1/sim-draft/original.jpg',
      status: SimulationStatus.draft,
      notes: 'demo',
      detectedRegion: const {'x': 1.0, 'y': 2.0, 'w': 3.0, 'h': 4.0},
    );

    await tester.pumpWidget(
      _wrap(
        SimulatorScreen(
          patientId: 'p1',
          adminId: 'admin-1',
          treatmentType: TreatmentType.convencional,
          embedded: true,
        ),
        overrides: [
          simulationRepositoryProvider.overrideWith((ref) => repo),
          simulatorFlowProvider.overrideWith(
            () => _MutableFlowNotifier(flow, repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Generar con IA'));
    await tester.tap(find.text('Generar con IA'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('botón Nueva del encabezado abre flujo de nueva simulación', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FlowFakeRepository();
    final patient = _patient();
    final sims = [
      _sim(
        id: 'sim-old',
        status: SimulationStatus.ready,
        resultPath: 'simulations/p1/sim-old/result.jpg',
      ),
    ];

    await tester.pumpWidget(
      _wrap(
        PatientSimulatorTab(patient: patient),
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('admin-1')),
          ),
          simulationRepositoryProvider.overrideWith((ref) => repo),
          patientSimulationsProvider(
            'p1',
          ).overrideWith((ref) => Stream.value(sims)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('simulator-active-flow')), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Nueva'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('simulator-active-flow')), findsOneWidget);
    expect(find.text('Paso 1: subir foto original'), findsOneWidget);
  });

  testWidgets(
    'con borrador activo el flujo activo se muestra antes del historial',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FlowFakeRepository();
      final patient = _patient();
      final activeFlow = SimulatorFlowState(
        uiState: SimulatorUiState.draftReady,
        patientId: 'p1',
        simulationId: 'sim-draft',
        originalPath: 'simulations/p1/sim-draft/original.jpg',
        status: SimulationStatus.draft,
        notes: 'demo',
        detectedRegion: const {'x': 1.0, 'y': 2.0, 'w': 3.0, 'h': 4.0},
      );
      final sims = [
        _sim(
          id: 'sim-old',
          status: SimulationStatus.ready,
          resultPath: 'simulations/p1/sim-old/result.jpg',
        ),
        _sim(
          id: 'sim-older',
          status: SimulationStatus.shared,
          shared: true,
          resultPath: 'simulations/p1/sim-older/result.jpg',
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          PatientSimulatorTab(patient: patient),
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(_FakeUser('admin-1')),
            ),
            simulationRepositoryProvider.overrideWith((ref) => repo),
            patientSimulationsProvider(
              'p1',
            ).overrideWith((ref) => Stream.value(sims)),
            simulatorFlowProvider.overrideWith(
              () => _StaticFlowNotifier(activeFlow),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final activeFlowFinder = find.byKey(
        const ValueKey('simulator-active-flow'),
      );
      final historyFinder = find.byKey(
        const ValueKey('simulation-history-title'),
      );

      expect(activeFlowFinder, findsOneWidget);
      expect(historyFinder, findsOneWidget);
      expect(
        tester.getTopLeft(activeFlowFinder).dy,
        lessThan(tester.getTopLeft(historyFinder).dy),
      );
    },
  );
}

class _StaticFlowNotifier extends SimulatorFlowNotifier {
  _StaticFlowNotifier(this.value);

  final SimulatorFlowState value;

  @override
  Future<SimulatorFlowState> build() async => value;
}

class _MutableFlowNotifier extends SimulatorFlowNotifier {
  _MutableFlowNotifier(this.initial, this.repo);

  final SimulatorFlowState initial;
  final _FlowFakeRepository repo;

  @override
  Future<SimulatorFlowState> build() async => initial;

  @override
  Future<void> generateWithAi({
    required String patientId,
    required String treatmentType,
  }) async {
    final current = state.asData!.value;
    try {
      await repo.generateWithAi(
        patientId: patientId,
        simulationId: current.simulationId!,
        treatmentType: treatmentType,
      );
    } catch (_) {
      state = AsyncData(
        current.copyWith(
          uiState: SimulatorUiState.error,
          errorMessage:
              'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.',
        ),
      );
    }
  }
}
