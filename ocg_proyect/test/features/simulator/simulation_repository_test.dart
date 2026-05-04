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
    String? resultPath,
    SimulationStatus status = SimulationStatus.draft,
    bool shared = false,
  }) {
    return SimulationModel(
      id: id,
      patientId: patientId,
      originalPath: 'simulations/$patientId/$id/original.jpg',
      resultPath: resultPath,
      compartidaConPaciente: shared,
      createdAt: DateTime(2026, 3, 23, 12),
      updatedAt: null,
      createdBy: 'admin',
      treatmentType: null,
      status: status,
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
    );
  }

  test('createDraftSimulation guarda draft ligado a patientId', () async {
    final saved = await repo.createDraftSimulation(
      patientId: 'p-1',
      createdBy: 'admin-1',
      originalPath: 'simulations/p-1/sim-1/original.jpg',
    );

    expect(saved.id, isNotEmpty);
    expect(saved.status, SimulationStatus.draft);

    final doc = await db
        .collection(FirestorePaths.patientSimulations('p-1'))
        .doc(saved.id)
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['patientId'], 'p-1');
    expect(doc.data()!['status'], SimulationStatus.draft.name);
    expect(doc.data()!['originalPath'], 'simulations/p-1/sim-1/original.jpg');
  });

  test('createDraftSimulation usa el mismo simulationId para Firestore cuando se entrega explícitamente', () async {
    final saved = await repo.createDraftSimulation(
      patientId: 'p-1',
      createdBy: 'admin-1',
      simulationId: 'sim-consistente',
      originalPath: 'simulations/p-1/sim-consistente/original.jpg',
    );

    expect(saved.id, 'sim-consistente');

    final doc = await db
        .collection(FirestorePaths.patientSimulations('p-1'))
        .doc('sim-consistente')
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['originalPath'], 'simulations/p-1/sim-consistente/original.jpg');
  });

  test('updateSimulationStatus cambia draft -> generating', () async {
    final saved = await repo.createDraftSimulation(
      patientId: 'p-2',
      createdBy: 'admin-2',
      originalPath: 'simulations/p-2/sim-2/original.jpg',
    );

    await repo.updateSimulationStatus(
      patientId: 'p-2',
      simulationId: saved.id,
      status: SimulationStatus.generating,
      attemptCount: 1,
    );

    final doc = await db
        .collection(FirestorePaths.patientSimulations('p-2'))
        .doc(saved.id)
        .get();
    expect(doc.data()!['status'], SimulationStatus.generating.name);
    expect(doc.data()!['attemptCount'], 1);
  });

  test('share/unshare cambia ready <-> shared', () async {
    final saved = await repo.updateSimulation(
      patientId: 'p-3',
      simulationId: (await repo.createDraftSimulation(
        patientId: 'p-3',
        createdBy: 'admin-3',
        originalPath: 'simulations/p-3/sim-3/original.jpg',
      )).id,
      resultPath: 'simulations/p-3/sim-3/result.jpg',
      status: SimulationStatus.ready,
    );

    await repo.shareSimulationWithPatient('p-3', saved.id);

    var doc = await db
        .collection(FirestorePaths.patientSimulations('p-3'))
        .doc(saved.id)
        .get();
    expect(doc.data()!['compartidaConPaciente'], true);
    expect(doc.data()!['status'], SimulationStatus.shared.name);

    await repo.unshareSimulationWithPatient('p-3', saved.id);

    doc = await db
        .collection(FirestorePaths.patientSimulations('p-3'))
        .doc(saved.id)
        .get();
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
        resultPath: 'simulations/p-5/shared-ok/result.jpg',
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
        resultPath: 'simulations/p-5/ready-no-share/result.jpg',
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
