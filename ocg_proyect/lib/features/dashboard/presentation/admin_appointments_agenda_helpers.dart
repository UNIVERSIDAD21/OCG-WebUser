import 'package:flutter/material.dart';

import '../../../shared/theme/ocg_colors.dart';
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

({Color dot, Color line, String label}) appointmentStatusUi(
  AppointmentModel appointment,
) {
  if (isLostAppointment(appointment)) {
    return (dot: OcgColors.error, line: OcgColors.error, label: 'Perdida');
  }

  return switch (appointment.estado) {
    AppointmentStatus.programada => (
      dot: const Color(0xFFBA7517),
      line: const Color(0xFFBA7517),
      label: 'Activa',
    ),
    AppointmentStatus.confirmada => (
      dot: const Color(0xFF639922),
      line: const Color(0xFF639922),
      label: 'Confirmada',
    ),
    AppointmentStatus.completada => (
      dot: const Color(0xFF1B45A0),
      line: const Color(0xFF1B45A0),
      label: 'Completada',
    ),
    AppointmentStatus.cancelada => (
      dot: const Color(0xFF888780),
      line: const Color(0xFF888780),
      label: 'Cancelada',
    ),
    AppointmentStatus.noAsistio => (
      dot: OcgColors.error,
      line: OcgColors.error,
      label: 'Perdida',
    ),
    AppointmentStatus.reprogramada => (
      dot: const Color(0xFF7E3AF2),
      line: const Color(0xFF7E3AF2),
      label: 'Reprogramada',
    ),
  };
}

IconData agendaStatusIcon(AppointmentModel appointment) {
  if (isLostAppointment(appointment)) return Icons.person_off_outlined;
  return switch (appointment.estado) {
    AppointmentStatus.programada => Icons.schedule_outlined,
    AppointmentStatus.confirmada => Icons.verified_outlined,
    AppointmentStatus.completada => Icons.done_all_outlined,
    AppointmentStatus.cancelada => Icons.cancel_outlined,
    AppointmentStatus.noAsistio => Icons.person_off_outlined,
    AppointmentStatus.reprogramada => Icons.edit_calendar_outlined,
  };
}

String agendaOperationalHint(AppointmentModel appointment) {
  final now = DateTime.now();
  if (isLostAppointment(appointment)) return 'Requiere seguimiento del equipo.';
  if (appointment.estado == AppointmentStatus.programada &&
      appointment.fechaHora.isBefore(now)) {
    return 'Cita vencida: confirma asistencia o reprograma.';
  }
  if (appointment.estado == AppointmentStatus.programada) {
    return 'Pendiente por confirmar con el paciente.';
  }
  if (appointment.estado == AppointmentStatus.confirmada) {
    return 'Lista para completar al finalizar atención.';
  }
  if (appointment.estado == AppointmentStatus.completada) {
    return 'Atención registrada en historial.';
  }
  if (appointment.estado == AppointmentStatus.reprogramada) {
    return 'Cita movida; revisar nueva fecha asociada.';
  }
  return 'Cita cerrada administrativamente.';
}

bool isAgendaHistoryCandidate(AppointmentModel appointment, DateTime now) =>
    appointment.fechaHora.isBefore(now) ||
    appointment.estado == AppointmentStatus.completada ||
    appointment.estado == AppointmentStatus.cancelada ||
    appointment.estado == AppointmentStatus.noAsistio ||
    appointment.estado == AppointmentStatus.reprogramada;

String agendaMonthLabel(DateTime date) {
  const months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

List<AppointmentModel> historyItemsForAgenda(
  List<AppointmentModel> all, {
  required AgendaFilter filter,
  required int page,
  int pageSize = 12,
}) {
  final now = DateTime.now();
  final past = all.where((item) => isAgendaHistoryCandidate(item, now)).toList()
    ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

  final filtered = filterHistoryItems(past, filter);
  final max = page * pageSize;
  return filtered.take(max).toList();
}

int historyCountByFilter(List<AppointmentModel> all, AgendaFilter filter) {
  final now = DateTime.now();
  final past = all
      .where((item) => isAgendaHistoryCandidate(item, now))
      .toList();
  return filterHistoryItems(past, filter).length;
}

List<AppointmentModel> filterHistoryItems(
  List<AppointmentModel> past,
  AgendaFilter filter,
) {
  return switch (filter) {
    AgendaFilter.completadas =>
      past
          .where((item) => item.estado == AppointmentStatus.completada)
          .toList(),
    AgendaFilter.perdidas => past.where(isLostAppointment).toList(),
    AgendaFilter.canceladas =>
      past.where((item) => item.estado == AppointmentStatus.cancelada).toList(),
    AgendaFilter.incidencias => past.where(isAgendaIncident).toList(),
    _ => past,
  };
}

List<AppointmentModel> appointmentsForDay(
  List<AppointmentModel> all,
  DateTime day,
) {
  final list =
      all
          .where(
            (appointment) =>
                appointment.fechaHora.year == day.year &&
                appointment.fechaHora.month == day.month &&
                appointment.fechaHora.day == day.day &&
                appointment.estado != AppointmentStatus.reprogramada,
          )
          .toList()
        ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
  return list;
}

String quickFilterLabel(AgendaDayQuickFilter filter) {
  return switch (filter) {
    AgendaDayQuickFilter.dia => 'Día',
    AgendaDayQuickFilter.manana => 'Mañana',
    AgendaDayQuickFilter.pendientes => 'Pendientes',
    AgendaDayQuickFilter.vencidas => 'Vencidas',
    AgendaDayQuickFilter.historicas => 'Históricas',
  };
}

IconData quickFilterIcon(AgendaDayQuickFilter filter) {
  return switch (filter) {
    AgendaDayQuickFilter.dia => Icons.today_outlined,
    AgendaDayQuickFilter.manana => Icons.wb_twilight_outlined,
    AgendaDayQuickFilter.pendientes => Icons.pending_actions_outlined,
    AgendaDayQuickFilter.vencidas => Icons.warning_amber_outlined,
    AgendaDayQuickFilter.historicas => Icons.history_toggle_off_outlined,
  };
}

int quickFilterCount(
  AgendaDayQuickFilter filter,
  List<AppointmentModel> appointments,
  DateTime selectedDate,
) {
  return quickFilteredItems(filter, appointments, selectedDate).length;
}

List<AppointmentModel> quickFilteredItems(
  AgendaDayQuickFilter filter,
  List<AppointmentModel> appointments,
  DateTime selectedDate,
) {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final items = switch (filter) {
    AgendaDayQuickFilter.dia => appointmentsForDay(appointments, selectedDate),
    AgendaDayQuickFilter.manana => appointmentsForDay(appointments, tomorrow),
    AgendaDayQuickFilter.pendientes =>
      appointments
          .where(
            (appointment) =>
                (appointment.estado == AppointmentStatus.programada ||
                    appointment.estado == AppointmentStatus.confirmada) &&
                !isLostAppointment(appointment) &&
                appointment.fechaHora.isAfter(
                  now.subtract(const Duration(minutes: 1)),
                ),
          )
          .toList(),
    AgendaDayQuickFilter.vencidas =>
      appointments
          .where(
            (appointment) =>
                appointment.estado == AppointmentStatus.programada &&
                appointment.fechaHora.isBefore(now),
          )
          .toList(),
    AgendaDayQuickFilter.historicas =>
      appointments
          .where(
            (appointment) =>
                appointment.estado == AppointmentStatus.cancelada ||
                appointment.estado == AppointmentStatus.noAsistio ||
                appointment.estado == AppointmentStatus.reprogramada,
          )
          .toList(),
  };

  items.sort((a, b) {
    if (filter == AgendaDayQuickFilter.historicas ||
        filter == AgendaDayQuickFilter.vencidas) {
      return b.fechaHora.compareTo(a.fechaHora);
    }
    return a.fechaHora.compareTo(b.fechaHora);
  });
  return items;
}
