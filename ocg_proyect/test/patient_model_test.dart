import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';

PatientModel _buildPatient({
  TreatmentStage etapaActual = TreatmentStage.valoracionInicial,
  DateTime? proximaCita,
  double totalTratamiento = 1000,
  double saldoPendiente = 500,
}) {
  return PatientModel(
    id: 'p1',
    nombre: 'Paciente Demo',
    email: 'demo@ocg.com',
    telefono: '3000000000',
    fechaNacimiento: DateTime(2000, 1, 1),
    tipoTratamiento: TreatmentType.convencional,
    etapaActual: etapaActual,
    fechaInicio: DateTime(2026, 3, 9),
    notasClinicas: '',
    totalTratamiento: totalTratamiento,
    saldoPendiente: saldoPendiente,
    proximaCita: proximaCita,
  );
}

void main() {
  group('PatientModel proximaCita', () {
    test('fromJson parsea proximaCita desde Timestamp', () {
      final now = DateTime(2026, 3, 9, 17, 0);
      final next = DateTime(2026, 3, 20, 9, 30);

      final model = PatientModel.fromJson({
        'id': 'p1',
        'nombre': 'Paciente Demo',
        'email': 'demo@ocg.com',
        'telefono': '3000000000',
        'fechaNacimiento': Timestamp.fromDate(DateTime(2000, 1, 1)),
        'tipoTratamiento': 'convencional',
        'etapaActual': 'valoracionInicial',
        'fechaInicio': Timestamp.fromDate(now),
        'notasClinicas': '',
        'totalTratamiento': 1000,
        'saldoPendiente': 500,
        'proximaCita': Timestamp.fromDate(next),
      });

      expect(model.proximaCita, equals(next));
    });

    test('toJson serializa proximaCita como Timestamp', () {
      final next = DateTime(2026, 3, 20, 9, 30);
      final model = PatientModel(
        id: 'p1',
        nombre: 'Paciente Demo',
        email: 'demo@ocg.com',
        telefono: '3000000000',
        fechaNacimiento: DateTime(2000, 1, 1),
        tipoTratamiento: TreatmentType.convencional,
        etapaActual: TreatmentStage.valoracionInicial,
        fechaInicio: DateTime(2026, 3, 9),
        notasClinicas: '',
        totalTratamiento: 1000,
        saldoPendiente: 500,
        proximaCita: next,
      );

      final json = model.toJson();
      expect(json['proximaCita'], isA<Timestamp>());
      expect((json['proximaCita'] as Timestamp).toDate(), equals(next));
    });
  });

  group('PatientModel lógica derivada para tratamientos', () {
    test(
      'marca como activo un tratamiento inicial si ya tiene próxima cita futura',
      () {
        final model = _buildPatient(
          etapaActual: TreatmentStage.valoracionInicial,
          proximaCita: DateTime.now().add(const Duration(days: 2)),
        );

        expect(model.treatmentStatus, TreatmentStatus.activo);
        expect(model.treatmentStatusLabel, 'Activo');
        expect(model.nextSessionStatus, NextSessionStatus.programada);
      },
    );

    test('marca como en espera un tratamiento inicial sin cita agendada', () {
      final model = _buildPatient(
        etapaActual: TreatmentStage.estudioPlaneacion,
      );

      expect(model.treatmentStatus, TreatmentStatus.enEspera);
      expect(model.nextSessionStatus, NextSessionStatus.sinAgendar);
      expect(model.nextSessionLabel, 'Sin sesión agendada');
    });

    test(
      'marca como vencida una próxima cita pasada y conserva tratamiento activo en curso',
      () {
        final model = _buildPatient(
          etapaActual: TreatmentStage.controles,
          proximaCita: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(model.treatmentStatus, TreatmentStatus.activo);
        expect(model.nextSessionStatus, NextSessionStatus.vencida);
        expect(model.nextSessionLabel, contains('Sesión vencida:'));
      },
    );

    test('calcula total pagado sin valores negativos', () {
      final model = _buildPatient(
        totalTratamiento: 9000000,
        saldoPendiente: 7800000,
      );

      expect(model.totalPagado, 1200000);
    });

    test('marca como finalizado cuando el paciente está en alta', () {
      final model = _buildPatient(etapaActual: TreatmentStage.alta);

      expect(model.treatmentStatus, TreatmentStatus.finalizado);
      expect(model.treatmentStatusLabel, 'Finalizado');
    });
  });
}
