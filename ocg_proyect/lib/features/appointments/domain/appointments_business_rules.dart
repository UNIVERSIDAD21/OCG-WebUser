import '../data/models/appointment_model.dart';
import '../../patients/data/models/patient_model.dart';

const _bogotaUtcOffset = Duration(hours: 5);

DateTime _bogotaNowWallClock() {
  final b = DateTime.now().toUtc().subtract(_bogotaUtcOffset);
  return DateTime(
    b.year,
    b.month,
    b.day,
    b.hour,
    b.minute,
    b.second,
    b.millisecond,
  );
}

class AppointmentTimeSlot {
  const AppointmentTimeSlot({required this.start, required this.isAvailable});

  final DateTime start;
  final bool isAvailable;

  String get label {
    final hour12 = start.hour % 12 == 0 ? 12 : start.hour % 12;
    final suffix = start.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${start.minute.toString().padLeft(2, '0')} $suffix';
  }
}

/// Bloque horario: hora de inicio y hora de fin (exclusiva).
class ScheduleBlock {
  const ScheduleBlock({required this.startHour, required this.endHour});

  final int startHour;
  final int endHour;
}

class AppointmentsBusinessRules {
  static const List<AppointmentType> patientAllowedTypes = [
    AppointmentType.valoracion,
    AppointmentType.control,
  ];

  static const int bogotaUtcOffsetHours = 5;

  static DateTime toBogota(DateTime dateTime) {
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return utc.subtract(const Duration(hours: bogotaUtcOffsetHours));
  }

  static DateTime fromBogotaComponents({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
  }) {
    return DateTime(year, month, day, hour, minute);
  }

  static String dayKeyBogota(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}';
  }

  static String slotKeyFromDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static DateTime dateTimeFromDayAndSlotKeyBogota({
    required DateTime dayReference,
    required String slotKey,
  }) {
    final parts = slotKey.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return fromBogotaComponents(
      year: dayReference.year,
      month: dayReference.month,
      day: dayReference.day,
      hour: hour,
      minute: minute,
    );
  }

  static bool isSameBogotaCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String displayLabelFromSlotKey(String slotKey) {
    final parts = slotKey.split(':');
    var hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  /// Hora de inicio laboral — usada como valor por defecto al seleccionar fecha.
  static const int workdayStartHour = 8;

  /// Buffer mínimo entre citas (en minutos).
  static const int bufferMinutesBetweenAppointments = 10;

  /// Granularidad de slots de disponibilidad.
  static const int slotStepMinutes = 15;

  /// Devuelve los bloques horarios del día dado.
  /// Retorna lista vacía si el día está cerrado (domingo).
  static List<ScheduleBlock> scheduleBlocksForDay(DateTime day) {
    switch (day.weekday) {
      case DateTime.monday:
      case DateTime.tuesday:
      case DateTime.wednesday:
      case DateTime.thursday:
      case DateTime.friday:
        return const [
          ScheduleBlock(startHour: 8, endHour: 12),
          ScheduleBlock(startHour: 14, endHour: 18),
        ];
      case DateTime.saturday:
        return const [ScheduleBlock(startHour: 8, endHour: 12)];
      default:
        return const []; // Domingo cerrado
    }
  }

  /// Retorna true si la clínica trabaja ese día.
  static bool isWorkingDay(DateTime day) =>
      scheduleBlocksForDay(day).isNotEmpty;

  static bool isTypeAllowedForPatient(AppointmentType type) =>
      patientAllowedTypes.contains(type);

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
    if (!includeCompleted && status == AppointmentStatus.completada) {
      return false;
    }
    return true;
  }

  static bool shouldIncludeInDayAgenda(
    AppointmentStatus status, {
    bool includeCompleted = true,
  }) => isOperationalStatus(status, includeCompleted: includeCompleted);

  static String? validateNoSameDayAppointment({
    required List<AppointmentModel> existingAppointments,
    required DateTime newAppointmentDateTime,
  }) {
    final hasSameDayAppointment = existingAppointments.any((appointment) {
      if (appointment.estado == AppointmentStatus.cancelada ||
          appointment.estado == AppointmentStatus.noAsistio) {
        return false;
      }

      return isSameBogotaCalendarDay(
        appointment.fechaHora,
        newAppointmentDateTime,
      );
    });

    if (!hasSameDayAppointment) return null;
    return 'Ya tienes una cita ese día';
  }

  static String? validateWithinWorkingHours({
    required DateTime start,
    required int durationMinutes,
  }) {
    final blocks = scheduleBlocksForDay(start);
    if (blocks.isEmpty) {
      return 'La clínica está cerrada el día seleccionado';
    }

    final end = start.add(Duration(minutes: durationMinutes));

    final withinAnyBlock = blocks.any((block) {
      final blockStart = DateTime(
        start.year,
        start.month,
        start.day,
        block.startHour,
      );
      final blockEnd = DateTime(
        start.year,
        start.month,
        start.day,
        block.endHour,
      );
      return !start.isBefore(blockStart) && !end.isAfter(blockEnd);
    });

    if (!withinAnyBlock) {
      return 'Horario disponible: L-V 08:00-12:00 y 14:00-18:00, Sáb 08:00-12:00';
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
      if (excludeAppointmentId != null &&
          appointment.id == excludeAppointmentId) {
        continue;
      }

      if (appointment.estado == AppointmentStatus.cancelada ||
          appointment.estado == AppointmentStatus.noAsistio ||
          appointment.estado == AppointmentStatus.reprogramada) {
        continue;
      }

      final existingStart = appointment.fechaHora;
      final existingEnd = existingStart.add(
        Duration(
          minutes:
              appointment.duracionMinutos + bufferMinutesBetweenAppointments,
        ),
      );

      final overlaps =
          newStart.isBefore(existingEnd) && existingStart.isBefore(newEnd);
      if (overlaps) return true;
    }

    return false;
  }

  static List<AppointmentTimeSlot> buildAllWorkdaySlots({
    required DateTime day,
    int stepMinutes = slotStepMinutes,
  }) {
    final blocks = scheduleBlocksForDay(day);
    if (blocks.isEmpty) return const [];

    final slots = <AppointmentTimeSlot>[];

    for (final block in blocks) {
      final blockStart = DateTime(
        day.year,
        day.month,
        day.day,
        block.startHour,
      );
      final blockEnd = DateTime(day.year, day.month, day.day, block.endHour);

      for (
        DateTime cursor = blockStart;
        cursor.isBefore(blockEnd);
        cursor = cursor.add(Duration(minutes: stepMinutes))
      ) {
        slots.add(AppointmentTimeSlot(start: cursor, isAvailable: true));
      }
    }

    return slots;
  }

  static List<AppointmentTimeSlot> buildDailySlots({
    required DateTime day,
    required List<AppointmentModel> existingAppointments,
    required int durationMinutes,
    String? excludeAppointmentId,
    int stepMinutes = slotStepMinutes,
  }) {
    final blocks = scheduleBlocksForDay(day);
    if (blocks.isEmpty) return const [];

    final slots = <AppointmentTimeSlot>[];

    for (final block in blocks) {
      final blockStart = DateTime(
        day.year,
        day.month,
        day.day,
        block.startHour,
      );
      final blockEnd = DateTime(day.year, day.month, day.day, block.endHour);

      for (
        DateTime cursor = blockStart;
        !cursor.add(Duration(minutes: durationMinutes)).isAfter(blockEnd);
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
    }

    return slots;
  }

  static String? validateStartNotInPast({
    required DateTime start,
    DateTime? now,
  }) {
    final referenceNow = now ?? _bogotaNowWallClock();
    if (!start.isAfter(referenceNow)) {
      return 'No se pueden agendar citas en horarios que ya pasaron.';
    }
    return null;
  }

  static bool canCancelAppointment(
    DateTime appointmentDateTime, {
    DateTime? now,
  }) {
    final referenceNow = now ?? _bogotaNowWallClock();
    final horasRestantes = appointmentDateTime.difference(referenceNow).inHours;
    return horasRestantes >= 24;
  }

  static bool shouldMarkAsNoShow(
    AppointmentModel appointment, {
    DateTime? now,
  }) {
    return false;
  }

  /// Mapeo fase del tratamiento → tipo de cita correspondiente.
  /// Garantiza coherencia clínica: cada cita refleja la fase activa
  /// del paciente, creando auditoría trazable en consultación.
  static AppointmentType appointmentTypeForStage(TreatmentStage stage) {
    return switch (stage) {
      TreatmentStage.valoracionInicial => AppointmentType.valoracion,
      TreatmentStage.estudioPlaneacion => AppointmentType.control,
      TreatmentStage.instalacion => AppointmentType.instalacion,
      TreatmentStage.controles => AppointmentType.control,
      TreatmentStage.retencion => AppointmentType.control,
      TreatmentStage.alta => AppointmentType.alta,
    };
  }

  /// Etiqueta descriptiva del tipo de cita derivado de la fase.
  static String stageAppointmentTypeHint(TreatmentStage stage) {
    final tipo = appointmentTypeForStage(stage);
    final phaseName = stageNames[stage] ?? stage.name;
    final typeName = switch (tipo) {
      AppointmentType.valoracion => 'Valoración',
      AppointmentType.control => 'Control',
      AppointmentType.instalacion => 'Instalación',
      AppointmentType.urgencia => 'Urgencia',
      AppointmentType.alta => 'Alta',
    };
    return '$phaseName → $typeName';
  }
}
