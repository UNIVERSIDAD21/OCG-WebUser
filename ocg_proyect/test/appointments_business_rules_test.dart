import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/appointments/data/models/appointment_model.dart';
import 'package:ocg_proyect/features/appointments/domain/appointments_business_rules.dart';

AppointmentModel _appt({
  required String id,
  required DateTime at,
  required AppointmentStatus status,
  int duration = 30,
}) {
  return AppointmentModel(
    id: id,
    patientId: 'p1',
    patientName: 'Paciente',
    patientPhone: '3000000000',
    tipo: AppointmentType.control,
    estado: status,
    fechaHora: at,
    duracionMinutos: duration,
    creadoPor: 'admin',
  );
}

void main() {
  group('AppointmentsBusinessRules status domain', () {
    test('históricos: cancelada/noAsistio/reprogramada', () {
      expect(AppointmentsBusinessRules.isHistoricalStatus(AppointmentStatus.cancelada), isTrue);
      expect(AppointmentsBusinessRules.isHistoricalStatus(AppointmentStatus.noAsistio), isTrue);
      expect(AppointmentsBusinessRules.isHistoricalStatus(AppointmentStatus.reprogramada), isTrue);
      expect(AppointmentsBusinessRules.isHistoricalStatus(AppointmentStatus.programada), isFalse);
    });

    test('operativos excluyen históricos y opcionalmente completadas', () {
      expect(AppointmentsBusinessRules.isOperationalStatus(AppointmentStatus.programada), isTrue);
      expect(AppointmentsBusinessRules.isOperationalStatus(AppointmentStatus.confirmada), isTrue);
      expect(AppointmentsBusinessRules.isOperationalStatus(AppointmentStatus.completada), isTrue);
      expect(
        AppointmentsBusinessRules.isOperationalStatus(
          AppointmentStatus.completada,
          includeCompleted: false,
        ),
        isFalse,
      );
      expect(AppointmentsBusinessRules.isOperationalStatus(AppointmentStatus.reprogramada), isFalse);
    });
  });

  group('AppointmentsBusinessRules conflicts', () {
    test('reprogramada no bloquea conflicto', () {
      final existing = [
        _appt(
          id: 'a1',
          at: DateTime(2026, 3, 13, 8, 0),
          status: AppointmentStatus.reprogramada,
        ),
      ];

      final hasConflict = AppointmentsBusinessRules.hasTimeConflict(
        existingAppointments: existing,
        newStart: DateTime(2026, 3, 13, 8, 0),
        durationMinutes: 30,
      );

      expect(hasConflict, isFalse);
    });

    test('buffer de 10 min bloquea slot siguiente inmediato', () {
      final existing = [
        _appt(
          id: 'a1',
          at: DateTime(2026, 3, 13, 8, 0),
          status: AppointmentStatus.programada,
          duration: 30,
        ),
      ];

      final hasConflictAt830 = AppointmentsBusinessRules.hasTimeConflict(
        existingAppointments: existing,
        newStart: DateTime(2026, 3, 13, 8, 30),
        durationMinutes: 30,
      );

      final hasConflictAt840 = AppointmentsBusinessRules.hasTimeConflict(
        existingAppointments: existing,
        newStart: DateTime(2026, 3, 13, 8, 40),
        durationMinutes: 30,
      );

      expect(hasConflictAt830, isTrue);
      expect(hasConflictAt840, isFalse);
    });
  });

  group('AppointmentsBusinessRules working hours', () {
    test('rechaza cuando cruza bloque de almuerzo', () {
      final error = AppointmentsBusinessRules.validateWithinWorkingHours(
        start: DateTime(2026, 3, 13, 11, 50),
        durationMinutes: 30,
      );
      expect(error, isNotNull);
    });

    test('rechaza domingo por clínica cerrada', () {
      final error = AppointmentsBusinessRules.validateWithinWorkingHours(
        start: DateTime(2026, 3, 15, 8, 0),
        durationMinutes: 30,
      );
      expect(error, isNotNull);
    });

    test('acepta dentro del rango de mañana', () {
      final error = AppointmentsBusinessRules.validateWithinWorkingHours(
        start: DateTime(2026, 3, 13, 8, 0),
        durationMinutes: 30,
      );
      expect(error, isNull);
    });

    test('acepta dentro del rango de tarde', () {
      final error = AppointmentsBusinessRules.validateWithinWorkingHours(
        start: DateTime(2026, 3, 13, 14, 30),
        durationMinutes: 30,
      );
      expect(error, isNull);
    });
  });
}
