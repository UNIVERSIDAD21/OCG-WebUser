import 'package:flutter/material.dart';

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
