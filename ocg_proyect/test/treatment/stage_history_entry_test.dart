import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/treatment/data/models/stage_history_entry.dart';
import 'package:ocg_proyect/features/treatment/data/repositories/treatment_repository.dart';
import 'package:ocg_proyect/shared/constants/firestore_paths.dart';

void main() {
  group('StageHistoryEntry', () {
    test('toJson produce los campos correctos', () {
      final entry = StageHistoryEntry(
        id: 'h1',
        etapaAnterior: TreatmentStage.diagnostico,
        etapaNueva: TreatmentStage.planificacion,
        notas: 'avance',
        adminId: 'admin-1',
        fechaCambio: DateTime(2026, 1, 1),
      );

      final json = entry.toJson();

      expect(json['id'], 'h1');
      expect(json['etapaAnterior'], TreatmentStage.diagnostico.name);
      expect(json['etapaNueva'], TreatmentStage.planificacion.name);
      expect(json['notas'], 'avance');
      expect(json['adminId'], 'admin-1');
      expect(json['fechaCambio'], isA<FieldValue>());
    });

    test('fromJson deserializa etapaAnterior y etapaNueva correctamente', () {
      final json = {
        'id': 'h2',
        'etapaAnterior': TreatmentStage.instalacion.name,
        'etapaNueva': TreatmentStage.seguimientoActivo.name,
        'notas': 'ok',
        'adminId': 'admin-2',
        'fechaCambio': Timestamp.fromDate(DateTime(2026, 2, 2)),
      };

      final entry = StageHistoryEntry.fromJson(json);

      expect(entry.id, 'h2');
      expect(entry.etapaAnterior, TreatmentStage.instalacion);
      expect(entry.etapaNueva, TreatmentStage.seguimientoActivo);
      expect(entry.notas, 'ok');
      expect(entry.adminId, 'admin-2');
      expect(entry.fechaCambio, DateTime(2026, 2, 2));
    });
  });

  group('TreatmentRepository', () {
    test('updateStage lanza Exception("STAGE_REGRESSION") en regresión', () async {
      final db = FakeFirebaseFirestore();
      final repo = TreatmentRepository(db);
      const patientId = 'p-1';

      await db.collection(FirestorePaths.patients).doc(patientId).set({
        'id': patientId,
        'etapaActual': TreatmentStage.seguimientoActivo.name,
      });

      expect(
        () => repo.updateStage(
          patientId: patientId,
          etapaAnterior: TreatmentStage.seguimientoActivo,
          nuevaEtapa: TreatmentStage.planificacion,
          notas: 'retroceso inválido',
          adminId: 'admin-3',
        ),
        throwsA(
          predicate((e) =>
              e is Exception && e.toString().contains('STAGE_REGRESSION')),
        ),
      );
    });
  });
}
