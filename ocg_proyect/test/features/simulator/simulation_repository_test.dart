import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/simulator/data/models/simulation_model.dart';
import 'package:ocg_proyect/features/simulator/data/repositories/simulation_repository.dart';
import 'package:ocg_proyect/shared/constants/firestore_paths.dart';

void main() {
  late FakeFirebaseFirestore db;
  late SimulationRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = SimulationRepository(db);
  });

  SimulationModel base({
    required String id,
    required String patientId,
    String? resultUrl,
    SimulationStatus status = SimulationStatus.draft,
    bool shared = false,
  }) {
    return SimulationModel(
      id: id,
      patientId: patientId,
      originalUrl: 'https://x/original.jpg',
      resultUrl: resultUrl,
      mode: SimulationMode.manualDoctora,
      compartidaConPaciente: shared,
      createdAt: DateTime(2026, 3, 23, 12),
      updatedAt: null,
      creadoPor: 'admin',
      treatmentType: null,
      status: status,
      notes: null,
      mlKitUsed: false,
      detectedRegion: null,
      promptMetadata: null,
    );
  }

  test('saveSimulation guarda draft ligado a patientId', () async {
    final saved = await repo.saveSimulation(base(id: '', patientId: 'p-1'));

    expect(saved.id, isNotEmpty);
    expect(saved.status, SimulationStatus.draft);

    final doc = await db.collection(FirestorePaths.patientSimulations('p-1')).doc(saved.id).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['patientId'], 'p-1');
    expect(doc.data()!['status'], SimulationStatus.draft.name);
  });

  test('updateSimulation al poner resultUrl normaliza draft -> ready', () async {
    final saved = await repo.saveSimulation(base(id: 'sim-1', patientId: 'p-2'));

    await repo.updateSimulation(
      patientId: 'p-2',
      simulationId: saved.id,
      resultUrl: 'https://x/result.jpg',
    );

    final doc = await db.collection(FirestorePaths.patientSimulations('p-2')).doc(saved.id).get();
    expect(doc.data()!['resultUrl'], 'https://x/result.jpg');
    expect(doc.data()!['status'], SimulationStatus.ready.name);
  });

  test('toggleShare cambia ready <-> shared', () async {
    final saved = await repo.saveSimulation(
      base(
        id: 'sim-2',
        patientId: 'p-3',
        resultUrl: 'https://x/result.jpg',
        status: SimulationStatus.ready,
      ),
    );

    await repo.toggleShare(patientId: 'p-3', simulationId: saved.id, compartida: true);

    var doc = await db.collection(FirestorePaths.patientSimulations('p-3')).doc(saved.id).get();
    expect(doc.data()!['compartidaConPaciente'], true);
    expect(doc.data()!['status'], SimulationStatus.shared.name);

    await repo.toggleShare(patientId: 'p-3', simulationId: saved.id, compartida: false);

    doc = await db.collection(FirestorePaths.patientSimulations('p-3')).doc(saved.id).get();
    expect(doc.data()!['compartidaConPaciente'], false);
    expect(doc.data()!['status'], SimulationStatus.ready.name);
  });

  test('watchSimulations retorna ordenado por createdAt desc', () async {
    await db.collection(FirestorePaths.patientSimulations('p-4')).add({
      ...base(id: 'a', patientId: 'p-4').toJson(),
      'id': 'a',
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
    });
    await db.collection(FirestorePaths.patientSimulations('p-4')).add({
      ...base(id: 'b', patientId: 'p-4').toJson(),
      'id': 'b',
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 2)),
    });

    final list = await repo.watchSimulations('p-4').first;
    expect(list.length, 2);
    expect(list.first.id, 'b');
  });

  test('watchSharedSimulations solo retorna compartidas en status shared', () async {
    await db.collection(FirestorePaths.patientSimulations('p-5')).add({
      ...base(
        id: 'shared-ok',
        patientId: 'p-5',
        resultUrl: 'https://x/result.jpg',
        status: SimulationStatus.shared,
        shared: true,
      ).toJson(),
      'id': 'shared-ok',
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 2)),
    });

    await db.collection(FirestorePaths.patientSimulations('p-5')).add({
      ...base(
        id: 'ready-no-share',
        patientId: 'p-5',
        resultUrl: 'https://x/result.jpg',
        status: SimulationStatus.ready,
        shared: true,
      ).toJson(),
      'id': 'ready-no-share',
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
    });

    final list = await repo.watchSharedSimulations('p-5').first;
    expect(list.length, 1);
    expect(list.first.id, 'shared-ok');
  });
}
