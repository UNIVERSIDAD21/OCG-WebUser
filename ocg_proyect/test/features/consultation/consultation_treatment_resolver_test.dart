import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/appointments/data/models/appointment_model.dart';
import 'package:ocg_proyect/features/consultation/domain/consultation_treatment_resolver.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/treatment/data/models/patient_treatment.dart';

void main() {
  group('ConsultationTreatmentResolver', () {
    test(
      'prioriza el treatmentId de la cita sobre el tratamiento principal',
      () {
        final primary = _treatment(
          id: 'tx-primary',
          isPrimary: true,
          stage: TreatmentStage.valoracionInicial,
        );
        final secondary = _treatment(
          id: 'tx-secondary',
          isPrimary: false,
          stage: TreatmentStage.controles,
        );

        final resolution = const ConsultationTreatmentResolver().resolve(
          appointment: _appointment(treatmentId: 'tx-secondary'),
          treatments: [primary, secondary],
        );

        expect(resolution.treatment?.id, 'tx-secondary');
        expect(
          resolution.source,
          ConsultationTreatmentResolutionSource.appointment,
        );
        expect(resolution.cameFromAppointment, isTrue);
        expect(resolution.appointmentTreatmentWasMissing, isFalse);
      },
    );

    test('usa el tratamiento primario si la cita no trae treatmentId', () {
      final resolution = const ConsultationTreatmentResolver().resolve(
        appointment: _appointment(),
        treatments: [
          _treatment(id: 'tx-secondary', isPrimary: false),
          _treatment(id: 'tx-primary', isPrimary: true),
        ],
      );

      expect(resolution.treatment?.id, 'tx-primary');
      expect(resolution.source, ConsultationTreatmentResolutionSource.primary);
    });

    test('marca fallback cuando el treatmentId de la cita no existe', () {
      final resolution = const ConsultationTreatmentResolver().resolve(
        appointment: _appointment(treatmentId: 'tx-missing'),
        treatments: [_treatment(id: 'tx-primary', isPrimary: true)],
      );

      expect(resolution.treatment?.id, 'tx-primary');
      expect(resolution.appointmentTreatmentWasMissing, isTrue);
    });
  });
}

AppointmentModel _appointment({String? treatmentId}) {
  return AppointmentModel(
    id: 'appt-1',
    patientId: 'patient-1',
    patientName: 'Paciente Demo',
    patientPhone: '3001234567',
    treatmentId: treatmentId,
    tipo: AppointmentType.control,
    estado: AppointmentStatus.programada,
    fechaHora: DateTime(2026, 5, 16, 10),
    duracionMinutos: 30,
    creadoPor: 'admin',
  );
}

PatientTreatment _treatment({
  required String id,
  bool isPrimary = false,
  TreatmentStage stage = TreatmentStage.estudioPlaneacion,
}) {
  final now = DateTime(2026, 5, 15);
  return PatientTreatment(
    id: id,
    patientId: 'patient-1',
    nombre: id,
    categoria: 'ortodoncia',
    tipoBase: 'convencional',
    subtipo: 'metalico',
    estado: 'activo',
    etapaActual: stage,
    fechaInicio: now,
    createdAt: now,
    updatedAt: now,
    isPrimary: isPrimary,
  );
}
