import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final patientSimulationsProvider = StreamProvider.family<List<SimulationModel>, String>((ref, patientId) {
  return ref.watch(simulationRepositoryProvider).watchSimulations(patientId);
});

final sharedSimulationsProvider = StreamProvider.family<List<SimulationModel>, String>((ref, patientId) {
  return ref.watch(simulationRepositoryProvider).watchSharedSimulations(patientId);
});

enum SimulatorUiState {
  idle,
  pickingImage,
  waitingManualResult,
  saving,
  saved,
  error,
}

class SimulatorFlowState {
  const SimulatorFlowState({
    required this.uiState,
    this.patientId,
    this.simulationId,
    this.originalUrl,
    this.resultUrl,
    this.shareWithPatient = false,
    this.errorMessage,
    this.notes,
  });

  final SimulatorUiState uiState;
  final String? patientId;
  final String? simulationId;
  final String? originalUrl;
  final String? resultUrl;
  final bool shareWithPatient;
  final String? errorMessage;
  final String? notes;

  bool get hasOriginal => (originalUrl ?? '').isNotEmpty;
  bool get hasResult => (resultUrl ?? '').isNotEmpty;

  SimulatorFlowState copyWith({
    SimulatorUiState? uiState,
    String? patientId,
    bool clearPatientId = false,
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
  }) {
    return SimulatorFlowState(
      uiState: uiState ?? this.uiState,
      patientId: clearPatientId ? null : (patientId ?? this.patientId),
      simulationId: clearSimulationId ? null : (simulationId ?? this.simulationId),
      originalUrl: clearOriginalUrl ? null : (originalUrl ?? this.originalUrl),
      resultUrl: clearResultUrl ? null : (resultUrl ?? this.resultUrl),
      shareWithPatient: shareWithPatient ?? this.shareWithPatient,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notes: clearNotes ? null : (notes ?? this.notes),
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

  void loadExistingSimulation(SimulationModel simulation) {
    state = AsyncData(
      SimulatorFlowState(
        uiState: SimulatorUiState.waitingManualResult,
        patientId: simulation.patientId,
        simulationId: simulation.id,
        originalUrl: simulation.originalUrl,
        resultUrl: simulation.resultUrl,
        shareWithPatient: simulation.compartidaConPaciente,
        notes: simulation.notes,
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
      final originalUrl = await _repo.uploadOriginalImage(
        patientId: patientId,
        simulationId: simulationId,
        bytes: picked.bytes,
        contentType: picked.mimeType,
      );

      await _repo.saveSimulation(
        SimulationModel(
          id: simulationId,
          patientId: patientId,
          originalUrl: originalUrl,
          resultUrl: null,
          mode: SimulationMode.manualDoctora,
          compartidaConPaciente: false,
          createdAt: DateTime.now(),
          updatedAt: null,
          creadoPor: adminId,
          treatmentType: treatmentType,
          status: SimulationStatus.draft,
          notes: null,
          mlKitUsed: false,
          detectedRegion: null,
          promptMetadata: null,
        ),
      );

      state = AsyncData(
        SimulatorFlowState(
          uiState: SimulatorUiState.waitingManualResult,
          patientId: patientId,
          simulationId: simulationId,
          originalUrl: originalUrl,
          resultUrl: null,
          shareWithPatient: false,
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
        state = AsyncData(current.copyWith(uiState: SimulatorUiState.waitingManualResult, clearError: true));
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
        resultUrl: resultUrl,
        status: current.shareWithPatient ? SimulationStatus.shared : SimulationStatus.ready,
      );

      state = AsyncData(
        current.copyWith(
          uiState: SimulatorUiState.waitingManualResult,
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

  Future<void> saveFinalSimulation({required String patientId}) async {
    final current = state.asData?.value;
    if (current == null || (current.simulationId ?? '').isEmpty || !current.hasResult) {
      state = AsyncData(
        (current ?? const SimulatorFlowState(uiState: SimulatorUiState.idle)).copyWith(
          uiState: SimulatorUiState.error,
          errorMessage: 'Debes cargar una imagen resultado antes de guardar.',
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
        status: status,
        notes: current.notes,
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
