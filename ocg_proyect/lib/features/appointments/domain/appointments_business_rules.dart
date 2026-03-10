import '../data/models/appointment_model.dart';

class AppointmentsBusinessRules {
  static const List<AppointmentType> patientAllowedTypes = [
    AppointmentType.valoracion,
    AppointmentType.control,
  ];

  static bool isTypeAllowedForPatient(AppointmentType type) {
    return patientAllowedTypes.contains(type);
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

  static bool canCancelAppointment(DateTime appointmentDateTime, {DateTime? now}) {
    final referenceNow = now ?? DateTime.now();
    final horasRestantes = appointmentDateTime.difference(referenceNow).inHours;
    return horasRestantes >= 24;
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
