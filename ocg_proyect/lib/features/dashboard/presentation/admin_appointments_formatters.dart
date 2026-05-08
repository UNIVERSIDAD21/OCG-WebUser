import 'package:flutter/material.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../appointments/data/models/appointment_model.dart';

String appointmentFmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String appointmentFmtDateTime(DateTime d) =>
    '${appointmentFmtDate(d)} ${() {
      final h = d.hour == 0
          ? 12
          : d.hour > 12
          ? d.hour - 12
          : d.hour;
      final ap = d.hour < 12 ? 'AM' : 'PM';
      return '$h:${d.minute.toString().padLeft(2, '0')} $ap';
    }()}';

String appointmentDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

String appointmentTypeLabel(AppointmentType t) {
  switch (t) {
    case AppointmentType.valoracion:
      return 'Valoración';
    case AppointmentType.control:
      return 'Control';
    case AppointmentType.instalacion:
      return 'Instalación';
    case AppointmentType.urgencia:
      return 'Urgencia';
    case AppointmentType.alta:
      return 'Alta';
  }
}

String? autoScheduleLabel(AppointmentModel a) {
  final notes = (a.notas ?? '').trim().toLowerCase();
  if (notes.startsWith('limpieza automática')) return 'Limpieza automática';
  if (notes.startsWith('control automático')) return 'Control automático';
  return null;
}

Color autoScheduleBg(AppointmentModel a) {
  final label = autoScheduleLabel(a);
  if (label == 'Limpieza automática') return const Color(0xFFE7F6EF);
  if (label == 'Control automático') return const Color(0xFFFFF4D8);
  return const Color(0xFFF3ECE4);
}

Color autoScheduleFg(AppointmentModel a) {
  final label = autoScheduleLabel(a);
  if (label == 'Limpieza automática') return const Color(0xFF2E7D4C);
  if (label == 'Control automático') return const Color(0xFF9A6A00);
  return OcgColors.espresso;
}
