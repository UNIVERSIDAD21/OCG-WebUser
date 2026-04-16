import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/treatment/data/models/stage_history_entry.dart';
import 'package:ocg_proyect/features/treatment/data/repositories/treatment_repository.dart';
import 'package:ocg_proyect/shared/constants/firestore_paths.dart';

void main() {
  group('StageHistoryEntry', () {
    test('toJson / fromJson serializa esRetroceso y campos opcionales', () {
      final entry = StageHistoryEntry(
        id: 'h1',
        etapaAnterior: TreatmentStage.instalacion,
        etapaNueva: TreatmentStage.controles,
        esRetroceso: false,
        notas: 'Control realizado sin novedades',
        motivoCambio: 'Cronograma clínico',
        diagnosticoBreve: 'Evolución favorable',
        planSiguienteEtapa: 'Continuar controles mensuales',
        adjuntosDescripcion: 'Foto intraoral + panorámica',
        fechaEfectiva: DateTime(2026, 3, 1),
        adminId: 'admin-1',
        fechaCambio: DateTime(2026, 3, 2),
      );

      final json = entry.toJson();

      expect(json['id'], 'h1');
      expect(json['etapaAnterior'], TreatmentStage.instalacion.name);
      expect(json['etapaNueva'], TreatmentStage.controles.name);
      expect(json['esRetroceso'], false);
      expect(json['motivoCambio'], 'Cronograma clínico');
      expect(json['fechaEfectiva'], isA<Timestamp>());
      expect(json['fechaCambio'], isA<Timestamp>());

      final decoded = StageHistoryEntry.fromJson({
        ...json,
        'fechaCambio': Timestamp.fromDate(DateTime(2026, 3, 2)),
      });

      expect(decoded.esRetroceso, isFalse);
      expect(decoded.motivoCambio, 'Cronograma clínico');
      expect(decoded.fechaEfectiva, DateTime(2026, 3, 1));
    });
  });

  group('TreatmentRepository.updateStage', () {
    test('bloquea retrocesos de etapa', () async {
      final db = FakeFirebaseFirestore();
      final repo = TreatmentRepository(db);
      const patientId = 'p-1';

      await db.collection(FirestorePaths.patients).doc(patientId).set({
        'id': patientId,
        'etapaActual': TreatmentStage.controles.name,
      });

      expect(
        () => repo.updateStage(
          patientId: patientId,
          etapaActual: TreatmentStage.controles,
          nuevaEtapa: TreatmentStage.instalacion,
          notas: 'Retroceso por pérdida de aparatología y nueva instalación clínica',
          adminId: 'admin-3',
        ),
        throwsA(
          predicate(
            (e) => e is Exception && e.toString().contains('STAGE_REGRESSION'),
          ),
        ),
      );
    });

    test('lanza STAGE_SAME cuando nueva etapa == etapa actual', () async {
      final repo = TreatmentRepository(FakeFirebaseFirestore());
      expect(
        () => repo.updateStage(
          patientId: 'p-2',
          etapaActual: TreatmentStage.controles,
          nuevaEtapa: TreatmentStage.controles,
          notas: 'nota suficientemente larga',
          adminId: 'admin',
        ),
        throwsA(
          predicate(
            (e) => e is Exception && e.toString().contains('STAGE_SAME'),
          ),
        ),
      );
    });

    test('lanza NOTES_TOO_SHORT cuando nota 1-9 caracteres', () async {
      final repo = TreatmentRepository(FakeFirebaseFirestore());
      expect(
        () => repo.updateStage(
          patientId: 'p-2',
          etapaActual: TreatmentStage.controles,
          nuevaEtapa: TreatmentStage.retencion,
          notas: 'corta',
          adminId: 'admin',
        ),
        throwsA(
          predicate(
            (e) => e is Exception && e.toString().contains('NOTES_TOO_SHORT'),
          ),
        ),
      );
    });
  });
}
