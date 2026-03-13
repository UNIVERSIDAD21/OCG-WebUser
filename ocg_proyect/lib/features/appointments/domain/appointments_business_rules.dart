import '../data/models/appointment_model.dart';

class AppointmentTimeSlot {
  const AppointmentTimeSlot({required this.start, required this.isAvailable});

  final DateTime start;
  final bool isAvailable;
}

class AppointmentsBusinessRules {
  static const List<AppointmentType> patientAllowedTypes = [
    AppointmentType.valoracion,
    AppointmentType.control,
  ];

  /// Horario laboral: 8:00 a 17:00
  static const int workdayStartHour = 8;
  static const int workdayEndHour = 17;

  /// Buffer mínimo entre citas (en minutos)
  static const int bufferMinutesBetweenAppointments = 10;

  static bool isTypeAllowedForPatient(AppointmentType type) {
    return patientAllowedTypes.contains(type);
  }

  static bool isHistoricalStatus(AppointmentStatus status) {
    return status == AppointmentStatus.cancelada ||
        status == AppointmentStatus.noAsistio ||
        status == AppointmentStatus.reprogramada;
  }

  static bool isOperationalStatus(
    AppointmentStatus status, {
    bool includeCompleted = true,
  }) {
    if (isHistoricalStatus(status)) return false;
    if (!includeCompleted && status == AppointmentStatus.completada) return false;
    return true;
  }

  static bool shouldIncludeInDayAgenda(
    AppointmentStatus status, {
    bool includeCompleted = true,
  }) {
    return isOperationalStatus(status, includeCompleted: includeCompleted);
  }

  static String? validateNoSameDayAppointment({
    required List<AppointmentModel> existingAppointments,
    required DateTime newAppointmentDateTime,
  }) {
    final hasSameDayAppointment = existingAppointments.any((appointment) {
      if (appointment.estado == AppointmentStatus.cancelada ||
          appointment.estado == AppointmentStatus.noAsistio) {
        return false;
      }

      return _isSameCalendarDay(appointment.fechaHora, newAppointmentDateTime);
    });

    if (!hasSameDayAppointment) return null;
    return 'Ya tienes una cita ese día';
  }

  static String? validateWithinWorkingHours({
    required DateTime start,
    required int durationMinutes,
  }) {
    final dayStart = DateTime(start.year, start.month, start.day, workdayStartHour);
    final dayEnd = DateTime(start.year, start.month, start.day, workdayEndHour);
    final end = start.add(Duration(minutes: durationMinutes));

    if (start.isBefore(dayStart) || end.isAfter(dayEnd)) {
      return 'Solo se permiten citas entre 08:00 y 17:00';
    }
    return null;
  }

  static bool hasTimeConflict({
    required List<AppointmentModel> existingAppointments,
    required DateTime newStart,
    required int durationMinutes,
    String? excludeAppointmentId,
  }) {
    final newEnd = newStart.add(Duration(minutes: durationMinutes));

    for (final appointment in existingAppointments) {
      if (excludeAppointmentId != null && appointment.id == excludeAppointmentId) {
        continue;
      }

      if (appointment.estado == AppointmentStatus.cancelada ||
          appointment.estado == AppointmentStatus.noAsistio ||
          appointment.estado == AppointmentStatus.reprogramada) {
        continue;
      }

      final existingStart = appointment.fechaHora;
      final existingEnd = existingStart.add(
        Duration(minutes: appointment.duracionMinutos + bufferMinutesBetweenAppointments),
      );

      final overlaps = newStart.isBefore(existingEnd) && existingStart.isBefore(newEnd);
      if (overlaps) return true;
    }

    return false;
  }

  static List<AppointmentTimeSlot> buildDailySlots({
    required DateTime day,
    required List<AppointmentModel> existingAppointments,
    required int durationMinutes,
    String? excludeAppointmentId,
    int stepMinutes = 30,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day, workdayStartHour);
    final dayEnd = DateTime(day.year, day.month, day.day, workdayEndHour);

    final slots = <AppointmentTimeSlot>[];
    for (
      DateTime cursor = dayStart;
      !cursor.add(Duration(minutes: durationMinutes)).isAfter(dayEnd);
      cursor = cursor.add(Duration(minutes: stepMinutes))
    ) {
      final available = !hasTimeConflict(
        existingAppointments: existingAppointments,
        newStart: cursor,
        durationMinutes: durationMinutes,
        excludeAppointmentId: excludeAppointmentId,
      );
      slots.add(AppointmentTimeSlot(start: cursor, isAvailable: available));
    }

    return slots;
  }

  static bool canCancelAppointment(DateTime appointmentDateTime, {DateTime? now}) {
    final referenceNow = now ?? DateTime.now();
    final horasRestantes = appointmentDateTime.difference(referenceNow).inHours;
    return horasRestantes >= 24;
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
