import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firebase/face_detection_service.dart';
import '../../../services/firebase/image_picker_service.dart';
import '../../patients/data/models/patient_model.dart';
import '../data/models/simulation_model.dart';
import '../data/repositories/simulation_repository.dart';

final simulationRepositoryProvider = Provider<SimulationRepository>((ref) {
  return SimulationRepository(FirebaseFirestore.instance);
});

final imagePickerServiceProvider = Provider<ImagePickerService>((ref) {
  return ImagePickerService();
});

final faceDetectionServiceProvider = Provider<FaceDetectionService>((ref) {
  return FaceDetectionService();
});

final patientSimulationsProvider =
    StreamProvider.family<List<SimulationModel>, String>((ref, patientId) {
      return ref.watch(simulationRepositoryProvider).watchSimulations(patientId);
    });

final sharedSimulationsProvider =
    StreamProvider.family<List<SimulationModel>, String>((ref, patientId) {
      return ref.watch(simulationRepositoryProvider).watchSharedSimulations(
        patientId,
      );
    });

enum SimulatorUiState {
  idle,
  pickingImage,
  draftReady,
  generating,
  ready,
  shared,
  saving,
  saved,
  error,
}

class SimulatorFlowState {
  const SimulatorFlowState({
    required this.uiState,
    this.patientId,
    this.simulationId,
    this.originalPath,
    this.resultPath,
    this.shareWithPatient = false,
    this.errorMessage,
    this.notes,
    this.detectedRegion,
    this.mlKitUsed = false,
    this.faceDetectionSource,
    this.status = SimulationStatus.draft,
    this.generationProvider = 'openai',
    this.modelUsed = 'gpt-image-2',
    this.attemptCount = 0,
    this.promptUsed,
    this.promptVersion,
  });

  final SimulatorUiState uiState;
  final String? patientId;
  final String? simulationId;
  final String? originalPath;
  final String? resultPath;
  final bool shareWithPatient;
  final String? errorMessage;
  final String? notes;
  final Map<String, dynamic>? detectedRegion;
  final bool mlKitUsed;
  final String? faceDetectionSource;
  final SimulationStatus status;
  final String generationProvider;
  final String modelUsed;
  final int attemptCount;
  final String? promptUsed;
  final String? promptVersion;

  bool get hasOriginal => (originalPath ?? '').isNotEmpty;
  bool get hasResult => (resultPath ?? '').isNotEmpty;
  bool get canGenerate =>
      hasOriginal &&
      (status == SimulationStatus.draft ||
          status == SimulationStatus.ready ||
          status == SimulationStatus.failed);
  bool get canShare =>
      hasResult &&
      status == SimulationStatus.ready &&
      !compartidaBloqueada;
  bool get compartidaBloqueada => status == SimulationStatus.archived;

  SimulatorFlowState copyWith({
    SimulatorUiState? uiState,
    String? patientId,
    bool clearPatientId = false,
    String? simulationId,
    bool clearSimulationId = false,
    String? originalPath,
    bool clearOriginalPath = false,
    String? resultPath,
    bool clearResultPath = false,
    bool? shareWithPatient,
    String? errorMessage,
    bool clearError = false,
    String? notes,
    bool clearNotes = false,
    Map<String, dynamic>? detectedRegion,
    bool clearDetectedRegion = false,
    bool? mlKitUsed,
    String? faceDetectionSource,
    bool clearFaceDetectionSource = false,
    SimulationStatus? status,
    String? generationProvider,
    String? modelUsed,
    int? attemptCount,
    String? promptUsed,
    bool clearPromptUsed = false,
    String? promptVersion,
    bool clearPromptVersion = false,
  }) {
    return SimulatorFlowState(
      uiState: uiState ?? this.uiState,
      patientId: clearPatientId ? null : (patientId ?? this.patientId),
      simulationId: clearSimulationId ? null : (simulationId ?? this.simulationId),
      originalPath: clearOriginalPath ? null : (originalPath ?? this.originalPath),
      resultPath: clearResultPath ? null : (resultPath ?? this.resultPath),
      shareWithPatient: shareWithPatient ?? this.shareWithPatient,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notes: clearNotes ? null : (notes ?? this.notes),
      detectedRegion: clearDetectedRegion ? null : (detectedRegion ?? this.detectedRegion),
      mlKitUsed: mlKitUsed ?? this.mlKitUsed,
      faceDetectionSource: clearFaceDetectionSource
          ? null
          : (faceDetectionSource ?? this.faceDetectionSource),
      status: status ?? this.status,
      generationProvider: generationProvider ?? this.generationProvider,
      modelUsed: modelUsed ?? this.modelUsed,
      attemptCount: attemptCount ?? this.attemptCount,
      promptUsed: clearPromptUsed ? null : (promptUsed ?? this.promptUsed),
      promptVersion: clearPromptVersion
          ? null
          : (promptVersion ?? this.promptVersion),
    );
  }
}

class SimulatorFlowNotifier extends AsyncNotifier<SimulatorFlowState> {
  StreamSubscription<SimulationModel?>? _simulationSubscription;

  @override
  Future<SimulatorFlowState> build() async {
    ref.onDispose(() => _simulationSubscription?.cancel());
    return const SimulatorFlowState(uiState: SimulatorUiState.idle);
  }

  SimulationRepository get _repo => ref.read(simulationRepositoryProvider);
  ImagePickerService get _picker => ref.read(imagePickerServiceProvider);
  FaceDetectionService get _face => ref.read(faceDetectionServiceProvider);

  void loadExistingSimulation(SimulationModel simulation) {
    _applySimulation(simulation, preserveTransientError: false);
    _bindSimulation(simulation.patientId, simulation.id);
  }

  void _bindSimulation(String patientId, String simulationId) {
    _simulationSubscription?.cancel();
    _simulationSubscription = _repo
        .watchSimulation(patientId: patientId, simulationId: simulationId)
        .listen((simulation) {
          if (simulation == null) return;
          _applySimulation(simulation);
        });
  }

  void _applySimulation(
    SimulationModel simulation, {
    bool preserveTransientError = true,
  }) {
    final current = state.asData?.value;
    final nextError = preserveTransientError &&
            current != null &&
            (current.errorMessage ?? '').trim().isNotEmpty &&
            (simulation.errorMessage ?? '').trim().isEmpty
        ? current.errorMessage
        : simulation.errorMessage;

    state = AsyncData(
      SimulatorFlowState(
        uiState: _uiStateForStatus(simulation.status),
        patientId: simulation.patientId,
        simulationId: simulation.id,
        originalPath: simulation.originalPath,
        resultPath: simulation.resultPath,
        shareWithPatient: simulation.compartidaConPaciente,
        errorMessage: nextError,
        notes: simulation.notes,
        detectedRegion: simulation.detectedRegion,
        mlKitUsed: simulation.mlKitUsed,
        faceDetectionSource: simulation.promptMetadata?['faceDetectionSource']
            ?.toString(),
        status: simulation.status,
        generationProvider: simulation.generationProvider,
        modelUsed: simulation.modelUsed,
        attemptCount: simulation.attemptCount,
        promptUsed: simulation.promptUsed,
        promptVersion: simulation.promptVersion,
      ),
    );
  }

  Future<void> pickOriginalFromGallery({
    required String patientId,
    required String adminId,
    TreatmentType? treatmentType,
  }) async {
    await _pickAndCreateDraft(
      patientId: patientId,
      adminId: adminId,
      treatmentType: treatmentType,
      fromCamera: false,
    );
  }

  Future<void> pickOriginalFromCamera({
    required String patientId,
    required String adminId,
    TreatmentType? treatmentType,
  }) async {
    await _pickAndCreateDraft(
      patientId: patientId,
      adminId: adminId,
      treatmentType: treatmentType,
      fromCamera: true,
    );
  }

  Future<void> _pickAndCreateDraft({
    required String patientId,
    required String adminId,
    required TreatmentType? treatmentType,
    required bool fromCamera,
  }) async {
    final current =
        state.asData?.value ??
        const SimulatorFlowState(uiState: SimulatorUiState.idle);
    state = AsyncData(
      current.copyWith(uiState: SimulatorUiState.pickingImage, clearError: true),
    );

    try {
      final picked = fromCamera
          ? await _picker.pickFromCamera()
          : await _picker.pickFromGallery();

      if (picked == null) {
        state = AsyncData(
          current.copyWith(uiState: SimulatorUiState.idle, clearError: true),
        );
        return;
      }

      final simulationId = 'sim_${DateTime.now().microsecondsSinceEpoch}';
      final originalPath = await _repo.uploadOriginalImage(
        patientId: patientId,
        simulationId: simulationId,
        bytes: picked.bytes,
        contentType: picked.mimeType,
      );

      final detection = await _face.detectSmileRegion(imagePath: picked.filePath);
      final simulation = await _repo.createDraftSimulation(
        patientId: patientId,
        createdBy: adminId,
        treatmentType: treatmentType,
        originalPath: originalPath,
        notes: current.notes,
        mlKitUsed: detection.hasFace,
        detectedRegion: detection.detectedRegion,
        promptVersion: 'gpt-image-2-preflight',
        promptMetadata: {
          'faceDetectionSource': detection.source,
          'generationProvider': 'openai',
          'modelUsed': 'gpt-image-2',
        },
      );

      _applySimulation(
        simulation.copyWith(
          detectedRegion: detection.detectedRegion,
          mlKitUsed: detection.hasFace,
          promptMetadata: {
            'faceDetectionSource': detection.source,
            'generationProvider': 'openai',
            'modelUsed': 'gpt-image-2',
          },
        ),
        preserveTransientError: false,
      );
      _bindSimulation(patientId, simulation.id);
    } catch (e) {
      state = AsyncData(
        current.copyWith(
          uiState: SimulatorUiState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> generateWithAi({
    required String patientId,
    required String treatmentType,
  }) async {
    final current = state.asData?.value;
    if (current == null) return;
    if ((current.patientId ?? patientId).trim().isEmpty) return;
    if ((current.simulationId ?? '').trim().isEmpty || !current.hasOriginal) {
      return;
    }
    if (!current.canGenerate || current.status == SimulationStatus.generating) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        uiState: SimulatorUiState.generating,
        status: SimulationStatus.generating,
        clearError: true,
      ),
    );

    try {
      await _repo.generateWithAi(
        patientId: patientId,
        simulationId: current.simulationId!,
        treatmentType: treatmentType,
        notes: current.notes,
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(
          uiState: SimulatorUiState.error,
          status: current.status,
          errorMessage: _friendlyGenerateError(e),
        ),
      );
    }
  }

  String _friendlyGenerateError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw == 'OPENAI_API_KEY no está configurada en backend.' ||
        raw == 'La generación con IA aún no está configurada en el backend.' ||
        raw ==
            'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.') {
      return 'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.';
    }
    if (raw == 'La generación con IA no está habilitada.' ||
        raw == 'La generación con IA está temporalmente desactivada.' ||
        raw ==
            'El simulador IA está instalado, pero está desactivado en Firebase Functions.') {
      return 'El simulador IA está instalado, pero está desactivado en Firebase Functions.';
    }
    if (raw == 'La simulación superó el máximo de intentos permitidos.' ||
        raw == 'La simulación ya alcanzó el máximo de intentos permitidos.') {
      return 'La simulación ya alcanzó el máximo de intentos permitidos.';
    }
    if (raw.isEmpty) return 'No se pudo iniciar la generación con IA.';
    return raw;
  }

  void setShareWithPatient(bool value) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(shareWithPatient: value));
  }

  void setNotes(String value) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(notes: value));
  }

  Future<void> updateDetectedRegion({
    required String patientId,
    required double x,
    required double y,
    required double w,
    required double h,
  }) async {
    final current = state.asData?.value;
    if (current == null || (current.simulationId ?? '').isEmpty) return;

    final region = {
      'x': x,
      'y': y,
      'w': w,
      'h': h,
      'unit': 'pixels',
      'kind': 'manual_adjusted_region',
    };

    await _repo.updateSimulation(
      patientId: patientId,
      simulationId: current.simulationId!,
      detectedRegion: region,
      mlKitUsed: current.mlKitUsed,
      promptMetadata: {
        'faceDetectionSource': current.faceDetectionSource,
        'generationProvider': current.generationProvider,
        'modelUsed': current.modelUsed,
        'regionAdjusted': true,
      },
    );
  }

  Future<void> shareCurrentSimulation({required String patientId}) async {
    final current = state.asData?.value;
    if (current == null || (current.simulationId ?? '').isEmpty) return;
    await _repo.shareSimulationWithPatient(patientId, current.simulationId!);
  }

  Future<void> archiveCurrentSimulation({required String patientId}) async {
    final current = state.asData?.value;
    if (current == null || (current.simulationId ?? '').isEmpty) return;
    await _repo.archiveSimulation(patientId, current.simulationId!);
  }

  void resetFlow() {
    _simulationSubscription?.cancel();
    _simulationSubscription = null;
    state = const AsyncData(SimulatorFlowState(uiState: SimulatorUiState.idle));
  }

  SimulatorUiState _uiStateForStatus(SimulationStatus status) {
    switch (status) {
      case SimulationStatus.draft:
        return SimulatorUiState.draftReady;
      case SimulationStatus.generating:
        return SimulatorUiState.generating;
      case SimulationStatus.ready:
        return SimulatorUiState.ready;
      case SimulationStatus.shared:
        return SimulatorUiState.shared;
      case SimulationStatus.failed:
      case SimulationStatus.archived:
        return SimulatorUiState.error;
    }
  }
}

final simulatorFlowProvider =
    AsyncNotifierProvider<SimulatorFlowNotifier, SimulatorFlowState>(
      SimulatorFlowNotifier.new,
    );
