import '../../appointments/data/models/appointment_model.dart';

/// Filtros principales del inbox de agenda admin.
enum AgendaFilter {
  hoy,
  activas,
  completadas,
  perdidas,
  canceladas,
  incidencias,
}

/// Tabs internas del módulo agenda admin.
enum AgendaInnerTab { hoy, mes, historial }

/// Filtros rápidos del detalle móvil de agenda.
enum AgendaDayQuickFilter { dia, manana, pendientes, vencidas, historicas }

bool isLostAppointment(AppointmentModel appointment) {
  if (appointment.estado == AppointmentStatus.noAsistio) return true;
  if (appointment.estado == AppointmentStatus.programada) {
    final limit = DateTime.now().subtract(const Duration(days: 1));
    return appointment.fechaHora.isBefore(limit);
  }
  return false;
}

bool isAgendaIncident(AppointmentModel appointment) =>
    appointment.estado == AppointmentStatus.cancelada ||
    appointment.estado == AppointmentStatus.noAsistio ||
    appointment.estado == AppointmentStatus.reprogramada ||
    isLostAppointment(appointment);

bool isAgendaHistoryCandidate(AppointmentModel appointment, DateTime now) =>
    appointment.fechaHora.isBefore(now) ||
    appointment.estado == AppointmentStatus.completada ||
    appointment.estado == AppointmentStatus.cancelada ||
    appointment.estado == AppointmentStatus.noAsistio ||
    appointment.estado == AppointmentStatus.reprogramada;
