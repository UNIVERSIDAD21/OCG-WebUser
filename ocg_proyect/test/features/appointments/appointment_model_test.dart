import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/appointments/data/models/appointment_model.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';

void main() {
  group('AppointmentModel', () {
    test('serializa snapshots de tratamiento y etapa', () {
      final appointment = AppointmentModel(
        id: 'appt-1',
        patientId: 'patient-1',
        patientName: 'Paciente Demo',
        patientPhone: '3001234567',
        treatmentId: 'tx-1',
        treatmentNameSnapshot: 'Ortodoncia - Metalico',
        tipo: AppointmentType.control,
        estado: AppointmentStatus.programada,
        fechaHora: DateTime(2026, 5, 16, 10),
        duracionMinutos: 30,
        creadoPor: 'admin',
        stageId: TreatmentStage.controles,
        stageNameSnapshot: 'Controles',
      );

      final json = appointment.toJson();
      final restored = AppointmentModel.fromJson({
        ...json,
        'fechaHora': appointment.fechaHora,
        'createdAt': appointment.fechaHora,
        'updatedAt': appointment.fechaHora,
      });

      expect(json['treatmentId'], 'tx-1');
      expect(json['treatmentNameSnapshot'], 'Ortodoncia - Metalico');
      expect(json['stageId'], 'controles');
      expect(json['stageNameSnapshot'], 'Controles');
      expect(restored.treatmentId, 'tx-1');
      expect(restored.treatmentNameSnapshot, 'Ortodoncia - Metalico');
      expect(restored.stageId, TreatmentStage.controles);
      expect(restored.stageNameSnapshot, 'Controles');
      expect(restored.stageName, 'Controles');
    });

    test('tolera citas legacy sin tratamiento asociado', () {
      final restored = AppointmentModel.fromJson({
        'id': 'legacy-appt',
        'patientId': 'patient-1',
        'patientName': 'Paciente Demo',
        'tipo': 'control',
        'estado': 'programada',
        'fechaHora': DateTime(2026, 5, 16, 10),
        'duracionMinutos': 30,
        'stageId': 'diagnostico',
      });

      expect(restored.treatmentId, isNull);
      expect(restored.treatmentNameSnapshot, isNull);
      expect(restored.stageId, TreatmentStage.valoracionInicial);
      expect(restored.stageNameSnapshot, isNull);
      expect(restored.patientPhone, isEmpty);
      expect(restored.creadoPor, 'admin');
    });
  });
}
