import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/treatment/data/models/patient_treatment.dart';

void main() {
  group('PatientTreatment', () {
    test('fromLegacyPatient convierte estetico en convencional con subtipo', () {
      final patient = PatientModel(
        id: 'p1',
        nombre: 'Paciente Uno',
        email: 'p1@demo.com',
        telefono: '3000000000',
        fechaNacimiento: DateTime(2000, 1, 1),
        tipoTratamiento: TreatmentType.estetico,
        etapaActual: TreatmentStage.instalacion,
        fechaInicio: DateTime(2026, 4, 1),
        notasClinicas: 'Paciente estable',
        totalTratamiento: 5000000,
        saldoPendiente: 2500000,
      );

      final treatment = PatientTreatment.fromLegacyPatient(patient);

      expect(treatment.tipoBase, 'convencional');
      expect(treatment.subtipo, 'estetico');
      expect(treatment.isPrimary, isTrue);
      expect(treatment.etapaActual, TreatmentStage.instalacion);
    });

    test('toJson serializa fechas y valores clínicos', () {
      final treatment = PatientTreatment(
        id: 't1',
        nombre: 'Convencional',
        categoria: 'ortodoncia',
        tipoBase: 'convencional',
        subtipo: 'metalico',
        estado: 'activo',
        etapaActual: TreatmentStage.controles,
        fechaInicio: DateTime(2026, 4, 10),
        createdAt: DateTime(2026, 4, 10, 8),
        updatedAt: DateTime(2026, 4, 10, 9),
        isPrimary: true,
        totalTratamiento: 3000000,
        saldoPendiente: 1200000,
        notas: 'Control 3m/6m activo',
      );

      final json = treatment.toJson();

      expect(json['fechaInicio'], isA<Timestamp>());
      expect(json['createdAt'], isA<Timestamp>());
      expect(json['updatedAt'], isA<Timestamp>());
      expect(json['subtipo'], 'metalico');
      expect(json['estado'], 'activo');
    });
  });
}
