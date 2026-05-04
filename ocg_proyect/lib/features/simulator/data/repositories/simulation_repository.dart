import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../../../shared/constants/storage_paths.dart';
import '../../../patients/data/models/patient_model.dart';
import '../models/simulation_model.dart';

class SimulationRepository {
  SimulationRepository(
    this._db, {
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _storage = storage,
       _functions = functions;

  final FirebaseFirestore _db;
  final FirebaseStorage? _storage;
  final FirebaseFunctions? _functions;

  CollectionReference<Map<String, dynamic>> _simulationsRef(String patientId) {
    return _db.collection(FirestorePaths.patientSimulations(patientId));
  }

  Stream<List<SimulationModel>> watchSimulations(String patientId) {
    return _simulationsRef(patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SimulationModel.fromJson(d.data()))
              .toList(),
        );
  }

  Stream<List<SimulationModel>> watchSharedSimulations(String patientId) {
    return _simulationsRef(patientId)
        .where('compartidaConPaciente', isEqualTo: true)
        .where('status', isEqualTo: SimulationStatus.shared.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SimulationModel.fromJson(d.data()))
              .toList(),
        );
  }

  Stream<SimulationModel?> watchSimulation({
    required String patientId,
    required String simulationId,
  }) {
    return _simulationsRef(patientId).doc(simulationId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return SimulationModel.fromJson(data);
    });
  }

  Future<String> uploadOriginalImage({
    required String patientId,
    required String simulationId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final path = StoragePaths.simulationOriginal(patientId, simulationId);
    final ref = (_storage ?? FirebaseStorage.instance).ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return path;
  }

  Future<String?> resolveMediaUrl(String? pathOrUrl) async {
    final raw = (pathOrUrl ?? '').trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return (_storage ?? FirebaseStorage.instance).ref(raw).getDownloadURL();
  }

  Future<SimulationModel> createDraftSimulation({
    required String patientId,
    required String createdBy,
    required String originalPath,
    TreatmentType? treatmentType,
    String? notes,
    bool mlKitUsed = false,
    Map<String, dynamic>? detectedRegion,
    String? promptUsed,
    String? promptVersion,
    Map<String, dynamic>? promptMetadata,
  }) async {
    if (patientId.trim().isEmpty) throw Exception('SIMULATION_PATIENT_REQUIRED');
    if (originalPath.trim().isEmpty) throw Exception('SIMULATION_ORIGINAL_REQUIRED');

    final now = DateTime.now();
    final ref = _simulationsRef(patientId).doc();
    final entity = SimulationModel(
      id: ref.id,
      patientId: patientId,
      originalPath: originalPath,
      resultPath: null,
      compartidaConPaciente: false,
      createdAt: now,
      updatedAt: now,
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

    await ref.set(entity.toJson(), SetOptions(merge: true));
    return entity;
  }

  Future<void> generateWithAi({
    required String patientId,
    required String simulationId,
    required String treatmentType,
    String? notes,
  }) async {
    final callable = (_functions ?? FirebaseFunctions.instance)
        .httpsCallable('generateSmileSimulation');

    try {
      await callable.call(<String, dynamic>{
        'patientId': patientId,
        'simulationId': simulationId,
        'treatmentType': treatmentType,
        'notes': notes,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_mapCallableError(error));
    }
  }

  String _mapCallableError(FirebaseFunctionsException error) {
    final message = (error.message ?? '').trim();
    if (message == 'OPENAI_API_KEY no está configurada en backend.' ||
        message ==
            'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.') {
      return 'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.';
    }
    if (message == 'La generación con IA no está habilitada.' ||
        message ==
            'El simulador IA está instalado, pero está desactivado en Firebase Functions.') {
      return 'El simulador IA está instalado, pero está desactivado en Firebase Functions.';
    }
    if (message == 'La simulación superó el máximo de intentos permitidos.') {
      return 'La simulación ya alcanzó el máximo de intentos permitidos.';
    }
    if (message.isNotEmpty) return message;
    return 'No se pudo iniciar la generación con IA.';
  }

  Future<SimulationModel> updateSimulation({
    required String patientId,
    required String simulationId,
    SimulationStatus? status,
    String? notes,
    bool clearNotes = false,
    bool? compartidaConPaciente,
    String? resultPath,
    bool clearResultPath = false,
    int? attemptCount,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? generatedAt,
    bool clearGeneratedAt = false,
    String? promptUsed,
    bool clearPromptUsed = false,
    String? promptVersion,
    bool clearPromptVersion = false,
    bool? mlKitUsed,
    Map<String, dynamic>? detectedRegion,
    bool clearDetectedRegion = false,
    Map<String, dynamic>? promptMetadata,
    bool clearPromptMetadata = false,
    DateTime? fechaCompartida,
    bool clearFechaCompartida = false,
  }) async {
    final ref = _simulationsRef(patientId).doc(simulationId);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('SIMULATION_NOT_FOUND');
    }

    final current = SimulationModel.fromJson(snap.data()!);
    final next = current.copyWith(
      status: status,
      notes: notes,
      clearNotes: clearNotes,
      compartidaConPaciente: compartidaConPaciente,
      resultPath: resultPath,
      clearResultPath: clearResultPath,
      attemptCount: attemptCount,
      errorMessage: errorMessage,
      clearErrorMessage: clearErrorMessage,
      generatedAt: generatedAt,
      clearGeneratedAt: clearGeneratedAt,
      promptUsed: promptUsed,
      clearPromptUsed: clearPromptUsed,
      promptVersion: promptVersion,
      clearPromptVersion: clearPromptVersion,
      mlKitUsed: mlKitUsed,
      detectedRegion: detectedRegion,
      clearDetectedRegion: clearDetectedRegion,
      promptMetadata: promptMetadata,
      clearPromptMetadata: clearPromptMetadata,
      fechaCompartida: fechaCompartida,
      clearFechaCompartida: clearFechaCompartida,
      updatedAt: DateTime.now(),
    );

    await ref.set(next.toJson(), SetOptions(merge: true));
    return next;
  }

  Future<SimulationModel> updateSimulationStatus({
    required String patientId,
    required String simulationId,
    required SimulationStatus status,
    String? errorMessage,
    int? attemptCount,
  }) {
    final shouldClearError = errorMessage == null || errorMessage.trim().isEmpty;
    return updateSimulation(
      patientId: patientId,
      simulationId: simulationId,
      status: status,
      errorMessage: shouldClearError ? null : errorMessage,
      clearErrorMessage: shouldClearError,
      attemptCount: attemptCount,
      generatedAt: status == SimulationStatus.ready ? DateTime.now() : null,
      clearGeneratedAt: status != SimulationStatus.ready,
    );
  }

  Future<void> shareSimulationWithPatient(
    String patientId,
    String simulationId,
  ) async {
    await _simulationsRef(patientId).doc(simulationId).update({
      'compartidaConPaciente': true,
      'status': SimulationStatus.shared.name,
      'fechaCompartida': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unshareSimulationWithPatient(
    String patientId,
    String simulationId,
  ) async {
    await _simulationsRef(patientId).doc(simulationId).update({
      'compartidaConPaciente': false,
      'status': SimulationStatus.ready.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveSimulation(
    String patientId,
    String simulationId,
  ) async {
    await _simulationsRef(patientId).doc(simulationId).update({
      'status': SimulationStatus.archived.name,
      'compartidaConPaciente': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSimulation({
    required String patientId,
    required String simulationId,
  }) async {
    await _simulationsRef(patientId).doc(simulationId).delete();

    final storage = _storage ?? FirebaseStorage.instance;
    final paths = [
      StoragePaths.simulationOriginal(patientId, simulationId),
      StoragePaths.simulationResult(patientId, simulationId),
      StoragePaths.simulationThumbOriginal(patientId, simulationId),
      StoragePaths.simulationThumbResult(patientId, simulationId),
    ];

    for (final path in paths) {
      try {
        await storage.ref(path).delete();
      } catch (_) {}
    }
  }
}
