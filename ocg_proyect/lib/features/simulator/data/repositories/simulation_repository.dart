import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../../../shared/constants/storage_paths.dart';
import '../models/simulation_model.dart';

class SimulationRepository {
  SimulationRepository(
    this._db, {
    FirebaseStorage? storage,
  }) : _storage = storage;

  final FirebaseFirestore _db;
  final FirebaseStorage? _storage;

  CollectionReference<Map<String, dynamic>> _simulationsRef(String patientId) {
    return _db.collection(FirestorePaths.patientSimulations(patientId));
  }

  Stream<List<SimulationModel>> watchSimulations(String patientId) {
    return _simulationsRef(patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SimulationModel.fromJson(d.data())).toList());
  }

  Stream<List<SimulationModel>> watchSharedSimulations(String patientId) {
    return _simulationsRef(patientId)
        .where('compartidaConPaciente', isEqualTo: true)
        .where('status', isEqualTo: SimulationStatus.shared.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SimulationModel.fromJson(d.data())).toList());
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
    return ref.getDownloadURL();
  }

  Future<String> uploadResultImage({
    required String patientId,
    required String simulationId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final path = StoragePaths.simulationResult(patientId, simulationId);
    final ref = (_storage ?? FirebaseStorage.instance).ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<SimulationModel> saveSimulation(SimulationModel simulation) async {
    if (simulation.patientId.trim().isEmpty) {
      throw Exception('SIMULATION_PATIENT_REQUIRED');
    }

    final now = DateTime.now();
    final ref = simulation.id.trim().isEmpty
        ? _simulationsRef(simulation.patientId).doc()
        : _simulationsRef(simulation.patientId).doc(simulation.id);

    final safeStatus = _normalizeStatus(simulation.status, simulation.resultUrl);

    final entity = simulation.copyWith(
      id: ref.id,
      status: safeStatus,
      createdAt: simulation.createdAt,
      updatedAt: now,
    );

    await ref.set(entity.toJson(), SetOptions(merge: true));
    return entity;
  }

  Future<void> updateSimulation({
    required String patientId,
    required String simulationId,
    String? resultUrl,
    bool clearResultUrl = false,
    SimulationMode? mode,
    SimulationStatus? status,
    String? notes,
    bool clearNotes = false,
    bool? compartidaConPaciente,
    Map<String, dynamic>? detectedRegion,
    bool clearDetectedRegion = false,
    Map<String, dynamic>? promptMetadata,
    bool clearPromptMetadata = false,
    bool? mlKitUsed,
  }) async {
    final ref = _simulationsRef(patientId).doc(simulationId);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('SIMULATION_NOT_FOUND');
    }

    final current = SimulationModel.fromJson(snap.data()!);

    final nextResultUrl = clearResultUrl ? null : (resultUrl ?? current.resultUrl);
    final nextStatus = _normalizeStatus(status ?? current.status, nextResultUrl);

    final next = current.copyWith(
      resultUrl: resultUrl,
      clearResultUrl: clearResultUrl,
      mode: mode,
      status: nextStatus,
      notes: notes,
      clearNotes: clearNotes,
      compartidaConPaciente: compartidaConPaciente,
      detectedRegion: detectedRegion,
      clearDetectedRegion: clearDetectedRegion,
      promptMetadata: promptMetadata,
      clearPromptMetadata: clearPromptMetadata,
      mlKitUsed: mlKitUsed,
      updatedAt: DateTime.now(),
    );

    await ref.set(next.toJson(), SetOptions(merge: true));
  }

  Future<void> toggleShare({
    required String patientId,
    required String simulationId,
    required bool compartida,
  }) async {
    final ref = _simulationsRef(patientId).doc(simulationId);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('SIMULATION_NOT_FOUND');
    }

    final current = SimulationModel.fromJson(snap.data()!);
    final newStatus = compartida
        ? (current.resultUrl == null ? SimulationStatus.draft : SimulationStatus.shared)
        : (current.resultUrl == null ? SimulationStatus.draft : SimulationStatus.ready);

    await ref.update({
      'compartidaConPaciente': compartida,
      'status': newStatus.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  SimulationStatus _normalizeStatus(SimulationStatus status, String? resultUrl) {
    if (resultUrl == null || resultUrl.trim().isEmpty) {
      return SimulationStatus.draft;
    }

    if (status == SimulationStatus.draft) {
      return SimulationStatus.ready;
    }

    return status;
  }
}
