import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firebase/face_detection_service.dart';
import '../../../services/firebase/image_picker_service.dart';
import '../../../services/simulator/mock_simulation_service.dart';
import '../../patients/data/models/patient_model.dart';
import '../data/models/simulation_model.dart';
import '../data/repositories/simulation_repository.dart';

final simulationRepositoryProvider = Provider<SimulationRepository>((ref) {
  return SimulationRepository(FirebaseFirestore.instance);
});

final imagePickerServiceProvider = Provider<ImagePickerService>((ref) {
  return ImagePickerService();
});

final mockSimulationServiceProvider = Provider<MockSimulationService>((ref) {
  return MockSimulationService();
});

final faceDetectionServiceProvider = Provider<FaceDetectionService>((ref) {
  return FaceDetectionService();
});

final patientSimulationsProvider = StreamProvider.family<List<SimulationModel>, String>((ref, patientId) {
  return ref.watch(simulationRepositoryProvider).watchSimulations(patientId);
});

final sharedSimulationsProvider = StreamProvider.family<List<SimulationModel>, String>((ref, patientId) {
  return ref.watch(simulationRepositoryProvider).watchSharedSimulations(patientId);
});

enum SimulatorUiState {
  idle,
  pickingImage,
  generatingMock,
  previewReady,
  saving,
  saved,
  error,
}

class SimulatorFlowState {
  const SimulatorFlowState({
    required this.uiState,
    this.patientId,
    this.selectedMode = SimulationMode.manualDoctora,
    this.simulationId,
    this.originalUrl,
    this.resultUrl,
    this.shareWithPatient = false,
    this.errorMessage,
    this.notes,
    this.detectedRegion,
    this.mlKitUsed = false,
    this.faceDetectionSource,
  });

  final SimulatorUiState uiState;
  final String? patientId;
  final SimulationMode selectedMode;
  final String? simulationId;
  final String? originalUrl;
  final String? resultUrl;
  final bool shareWithPatient;
  final String? errorMessage;
  final String? notes;
  final Map<String, dynamic>? detectedRegion;
  final bool mlKitUsed;
  final String? faceDetectionSource;

  bool get hasOriginal => (originalUrl ?? '').isNotEmpty;
  bool get hasResult => (resultUrl ?? '').isNotEmpty;

  SimulatorFlowState copyWith({
    SimulatorUiState? uiState,
    String? patientId,
    bool clearPatientId = false,
    SimulationMode? selectedMode,
    String? simulationId,
    bool clearSimulationId = false,
    String? originalUrl,
    bool clearOriginalUrl = false,
    String? resultUrl,
    bool clearResultUrl = false,
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
  }) {
    return SimulatorFlowState(
      uiState: uiState ?? this.uiState,
      patientId: clearPatientId ? null : (patientId ?? this.patientId),
      selectedMode: selectedMode ?? this.selectedMode,
      simulationId: clearSimulationId ? null : (simulationId ?? this.simulationId),
      originalUrl: clearOriginalUrl ? null : (originalUrl ?? this.originalUrl),
      resultUrl: clearResultUrl ? null : (resultUrl ?? this.resultUrl),
      shareWithPatient: shareWithPatient ?? this.shareWithPatient,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notes: clearNotes ? null : (notes ?? this.notes),
      detectedRegion: clearDetectedRegion ? null : (detectedRegion ?? this.detectedRegion),
      mlKitUsed: mlKitUsed ?? this.mlKitUsed,
      faceDetectionSource: clearFaceDetectionSource ? null : (faceDetectionSource ?? this.faceDetectionSource),
    );
  }
}

class SimulatorFlowNotifier extends AsyncNotifier<SimulatorFlowState> {
  @override
  Future<SimulatorFlowState> build() async {
    return const SimulatorFlowState(uiState: SimulatorUiState.idle);
  }

  SimulationRepository get _repo => ref.read(simulationRepositoryProvider);
  ImagePickerService get _picker => ref.read(imagePickerServiceProvider);
  MockSimulationService get _mock => ref.read(mockSimulationServiceProvider);
  FaceDetectionService get _face => ref.read(faceDetectionServiceProvider);

  void setMode(SimulationMode mode) {
    final current = state.asData?.value ?? const SimulatorFlowState(uiState: SimulatorUiState.idle);
    state = AsyncData(current.copyWith(selectedMode: mode));
  }

  void loadExistingSimulation(SimulationModel simulation) {
    state = AsyncData(
      SimulatorFlowState(
        uiState: SimulatorUiState.previewReady,
        patientId: simulation.patientId,
        selectedMode: simulation.mode,
        simulationId: simulation.id,
        originalUrl: simulation.originalUrl,
        resultUrl: simulation.resultUrl,
        shareWithPatient: simulation.compartidaConPaciente,
        notes: simulation.notes,
        detectedRegion: simulation.detectedRegion,
        mlKitUsed: simulation.mlKitUsed,
        faceDetectionSource: simulation.promptMetadata?['faceDetectionSource']?.toString(),
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
    final current = state.asData?.value ?? const SimulatorFlowState(uiState: SimulatorUiState.idle);
    state = AsyncData(current.copyWith(uiState: SimulatorUiState.pickingImage, clearError: true));

    try {
      final picked = fromCamera ? await _picker.pickFromCamera() : await _picker.pickFromGallery();

      if (picked == null) {
        state = AsyncData(current.copyWith(uiState: SimulatorUiState.idle, clearError: true));
        return;
      }

      final simulationId = 'sim_${DateTime.now().microsecondsSinceEpoch}';
      final selectedMode = current.selectedMode;

      final originalUrl = await _repo.uploadOriginalImage(
        patientId: patientId,
        simulationId: simulationId,
        bytes: picked.bytes,
        contentType: picked.mimeType,
      );

      final detection = await _face.detectSmileRegion(imagePath: picked.filePath);

      await _repo.saveSimulation(
        SimulationModel(
          id: simulationId,
          patientId: patientId,
          originalUrl: originalUrl,
          resultUrl: null,
          mode: selectedMode,
          compartidaConPaciente: false,
          createdAt: DateTime.now(),
          updatedAt: null,
          creadoPor: adminId,
          treatmentType: treatmentType,
          status: SimulationStatus.draft,
          notes: null,
          mlKitUsed: detection.hasFace,
          detectedRegion: detection.detectedRegion,
          promptMetadata: {
            'faceDetectionSource': detection.source,
          },
        ),
      );

      if (selectedMode == SimulationMode.mock) {
        state = AsyncData(
          current.copyWith(
            uiState: SimulatorUiState.generatingMock,
            patientId: patientId,
            simulationId: simulationId,
            originalUrl: originalUrl,
            clearResultUrl: true,
            clearError: true,
            detectedRegion: detection.detectedRegion,
            mlKitUsed: detection.hasFace,
            faceDetectionSource: detection.source,
          ),
        );

        final mockBytes = _mock.generateMockResult(picked.bytes);
        final mockUrl = await _repo.uploadResultImage(
          patientId: patientId,
          simulationId: simulationId,
          bytes: mockBytes,
          contentType: picked.mimeType,
        );

        await _repo.updateSimulation(
          patientId: patientId,
          simulationId: simulationId,
          mode: SimulationMode.mock,
          resultUrl: mockUrl,
          status: SimulationStatus.ready,
          mlKitUsed: detection.hasFace,
          detectedRegion: detection.detectedRegion,
          promptMetadata: {
            'source': 'internal_mock',
            'version': 'v1',
            'note': 'Ajuste visual orientativo sin IA externa',
            'faceDetectionSource': detection.source,
          },
        );

        state = AsyncData(
          SimulatorFlowState(
            uiState: SimulatorUiState.previewReady,
            patientId: patientId,
            selectedMode: SimulationMode.mock,
            simulationId: simulationId,
            originalUrl: originalUrl,
            resultUrl: mockUrl,
            shareWithPatient: false,
            detectedRegion: detection.detectedRegion,
            mlKitUsed: detection.hasFace,
            faceDetectionSource: detection.source,
          ),
        );
      } else {
        state = AsyncData(
          SimulatorFlowState(
            uiState: SimulatorUiState.previewReady,
            patientId: patientId,
            selectedMode: SimulationMode.manualDoctora,
            simulationId: simulationId,
            originalUrl: originalUrl,
            resultUrl: null,
            shareWithPatient: false,
            detectedRegion: detection.detectedRegion,
            mlKitUsed: detection.hasFace,
            faceDetectionSource: detection.source,
          ),
        );
      }
    } catch (e) {
      state = AsyncData(
        current.copyWith(
          uiState: SimulatorUiState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> uploadOrReplaceManualResult({
    required String patientId,
    required bool fromCamera,
  }) async {
    final current = state.asData?.value;
    if (current == null || (current.simulationId ?? '').isEmpty) return;

    state = AsyncData(current.copyWith(uiState: SimulatorUiState.pickingImage, clearError: true));

    try {
      final picked = fromCamera ? await _picker.pickFromCamera() : await _picker.pickFromGallery();
      if (picked == null) {
        state = AsyncData(current.copyWith(uiState: SimulatorUiState.previewReady, clearError: true));
        return;
      }

      final resultUrl = await _repo.uploadResultImage(
        patientId: patientId,
        simulationId: current.simulationId!,
        bytes: picked.bytes,
        contentType: picked.mimeType,
      );

      await _repo.updateSimulation(
        patientId: patientId,
        simulationId: current.simulationId!,
        mode: SimulationMode.manualDoctora,
        resultUrl: resultUrl,
        status: current.shareWithPatient ? SimulationStatus.shared : SimulationStatus.ready,
        mlKitUsed: current.mlKitUsed,
        detectedRegion: current.detectedRegion,
        promptMetadata: {
          'faceDetectionSource': current.faceDetectionSource,
          'source': 'manual_doctora',
        },
      );

      state = AsyncData(
        current.copyWith(
          uiState: SimulatorUiState.previewReady,
          selectedMode: SimulationMode.manualDoctora,
          resultUrl: resultUrl,
          clearError: true,
        ),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(
          uiState: SimulatorUiState.error,
          errorMessage: e.toString(),
        ),
      );
    }
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
        'regionAdjusted': true,
      },
    );

    state = AsyncData(current.copyWith(detectedRegion: region));
  }

  Future<void> saveFinalSimulation({required String patientId}) async {
    final current = state.asData?.value;
    if (current == null || (current.simulationId ?? '').isEmpty || !current.hasResult) {
      state = AsyncData(
        (current ?? const SimulatorFlowState(uiState: SimulatorUiState.idle)).copyWith(
          uiState: SimulatorUiState.error,
          errorMessage: 'Debes tener resultado antes de guardar.',
        ),
      );
      return;
    }

    state = AsyncData(current.copyWith(uiState: SimulatorUiState.saving, clearError: true));

    try {
      final status = current.shareWithPatient ? SimulationStatus.shared : SimulationStatus.ready;

      await _repo.updateSimulation(
        patientId: patientId,
        simulationId: current.simulationId!,
        mode: current.selectedMode,
        status: status,
        notes: current.notes,
        mlKitUsed: current.mlKitUsed,
        detectedRegion: current.detectedRegion,
        promptMetadata: {
          'faceDetectionSource': current.faceDetectionSource,
          'source': current.selectedMode.name,
        },
      );

      await _repo.toggleShare(
        patientId: patientId,
        simulationId: current.simulationId!,
        compartida: current.shareWithPatient,
      );

      state = AsyncData(current.copyWith(uiState: SimulatorUiState.saved, clearError: true));
    } catch (e) {
      state = AsyncData(current.copyWith(uiState: SimulatorUiState.error, errorMessage: e.toString()));
    }
  }

  void resetFlow() {
    state = const AsyncData(SimulatorFlowState(uiState: SimulatorUiState.idle));
  }
}

final simulatorFlowProvider = AsyncNotifierProvider<SimulatorFlowNotifier, SimulatorFlowState>(
  SimulatorFlowNotifier.new,
);
