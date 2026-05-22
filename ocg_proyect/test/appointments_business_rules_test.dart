import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/appointments/data/models/appointment_model.dart';
import 'package:ocg_proyect/features/appointments/domain/appointments_business_rules.dart';
import 'package:ocg_proyect/features/dashboard/presentation/admin_appointments_agenda_helpers.dart';

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
      expect(
        AppointmentsBusinessRules.isHistoricalStatus(
          AppointmentStatus.cancelada,
        ),
        isTrue,
      );
      expect(
        AppointmentsBusinessRules.isHistoricalStatus(
          AppointmentStatus.noAsistio,
        ),
        isTrue,
      );
      expect(
        AppointmentsBusinessRules.isHistoricalStatus(
          AppointmentStatus.reprogramada,
        ),
        isTrue,
      );
      expect(
        AppointmentsBusinessRules.isHistoricalStatus(
          AppointmentStatus.programada,
        ),
        isFalse,
      );
    });

    test('operativos excluyen históricos y opcionalmente completadas', () {
      expect(
        AppointmentsBusinessRules.isOperationalStatus(
          AppointmentStatus.programada,
        ),
        isTrue,
      );
      expect(
        AppointmentsBusinessRules.isOperationalStatus(
          AppointmentStatus.confirmada,
        ),
        isTrue,
      );
      expect(
        AppointmentsBusinessRules.isOperationalStatus(
          AppointmentStatus.completada,
        ),
        isTrue,
      );
      expect(
        AppointmentsBusinessRules.isOperationalStatus(
          AppointmentStatus.completada,
          includeCompleted: false,
        ),
        isFalse,
      );
      expect(
        AppointmentsBusinessRules.isOperationalStatus(
          AppointmentStatus.reprogramada,
        ),
        isFalse,
      );
    });

    test('no marca automaticamente citas abiertas como no asistidas', () {
      final appointment = _appt(
        id: 'a1',
        at: DateTime(2026, 3, 13, 8, 0),
        status: AppointmentStatus.confirmada,
      );

      expect(
        AppointmentsBusinessRules.shouldMarkAsNoShow(
          appointment,
          now: DateTime(2026, 3, 14, 12, 0),
        ),
        isFalse,
      );
    });
  });

  group('Admin agenda completion rule', () {
    test('cita abierta vencida mas de 24h sigue en pendientes', () {
      final now = DateTime(2026, 3, 14, 12, 0);
      final appointment = _appt(
        id: 'a1',
        at: DateTime(2026, 3, 13, 8, 0),
        status: AppointmentStatus.confirmada,
      );

      expect(isLostAppointment(appointment), isFalse);
      expect(isPendingAdminCompletion(appointment, now: now), isTrue);
      expect(isPastAdminCompletionWindow(appointment, now: now), isTrue);

      final pending = quickFilteredItems(AgendaDayQuickFilter.pendientes, [
        appointment,
      ], now);

      expect(pending, [appointment]);
    });

    test('resumen del dia filtra por estado operativo', () {
      final items = [
        _appt(
          id: 'a1',
          at: DateTime(2026, 3, 13, 8, 0),
          status: AppointmentStatus.programada,
        ),
        _appt(
          id: 'a2',
          at: DateTime(2026, 3, 13, 9, 0),
          status: AppointmentStatus.confirmada,
        ),
        _appt(
          id: 'a3',
          at: DateTime(2026, 3, 13, 10, 0),
          status: AppointmentStatus.completada,
        ),
        _appt(
          id: 'a4',
          at: DateTime(2026, 3, 13, 11, 0),
          status: AppointmentStatus.noAsistio,
        ),
        _appt(
          id: 'a5',
          at: DateTime(2026, 3, 13, 12, 0),
          status: AppointmentStatus.cancelada,
        ),
      ];

      expect(
        filterSummaryItems(items, AgendaSummaryFilter.total),
        hasLength(5),
      );
      expect(
        filterSummaryItems(
          items,
          AgendaSummaryFilter.activas,
        ).map((item) => item.id),
        ['a1'],
      );
      expect(
        filterSummaryItems(
          items,
          AgendaSummaryFilter.confirmadas,
        ).map((item) => item.id),
        ['a2'],
      );
      expect(
        filterSummaryItems(
          items,
          AgendaSummaryFilter.completadas,
        ).map((item) => item.id),
        ['a3'],
      );
      expect(
        filterSummaryItems(
          items,
          AgendaSummaryFilter.perdidas,
        ).map((item) => item.id),
        ['a4'],
      );
      expect(
        filterSummaryItems(
          items,
          AgendaSummaryFilter.canceladas,
        ).map((item) => item.id),
        ['a5'],
      );
    });

    test('filtro rapido historicas incluye completadas', () {
      final items = [
        _appt(
          id: 'a1',
          at: DateTime(2026, 3, 13, 8, 0),
          status: AppointmentStatus.completada,
        ),
        _appt(
          id: 'a2',
          at: DateTime(2026, 3, 13, 9, 0),
          status: AppointmentStatus.cancelada,
        ),
        _appt(
          id: 'a3',
          at: DateTime(2026, 3, 13, 10, 0),
          status: AppointmentStatus.noAsistio,
        ),
        _appt(
          id: 'a4',
          at: DateTime(2026, 3, 13, 11, 0),
          status: AppointmentStatus.reprogramada,
        ),
        _appt(
          id: 'a5',
          at: DateTime(2026, 3, 13, 12, 0),
          status: AppointmentStatus.programada,
        ),
      ];

      final historicas = quickFilteredItems(
        AgendaDayQuickFilter.historicas,
        items,
        DateTime(2026, 3, 13),
      );

      expect(historicas.map((item) => item.id), ['a4', 'a3', 'a2', 'a1']);
      expect(
        filterSummaryItems(historicas, AgendaSummaryFilter.completadas),
        hasLength(1),
      );
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
