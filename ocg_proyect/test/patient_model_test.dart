import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';

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
}
