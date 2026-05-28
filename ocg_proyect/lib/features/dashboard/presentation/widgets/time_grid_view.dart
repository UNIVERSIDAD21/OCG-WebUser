import 'package:flutter/material.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../appointments/data/models/appointment_model.dart';

/// Grilla de tiempo estilo Google Calendar con slots de 30 minutos.
///
/// Muestra las citas posicionadas en su franja horaria correspondiente.
/// Cada fila representa 30 minutos.
class TimeGridView extends StatelessWidget {
  const TimeGridView({
    super.key,
    required this.appointments,
    required this.selectedDate,
    this.showWeek = false,
    required this.onTapAppointment,
    required this.onTapSlot,
  });

  final List<AppointmentModel> appointments;
  final DateTime selectedDate;
  final bool showWeek;
  final ValueChanged<AppointmentModel> onTapAppointment;
  final ValueChanged<DateTime> onTapSlot;

  /// Hora de inicio del horario laboral
  static const int startHour = 8;

  /// Hora de fin del horario laboral
  static const int endHour = 18;

  /// Total de slots de 30 minutos
  static const int totalSlots = (endHour - startHour) * 2;

  static List<String> get timeLabels {
    return List.generate(totalSlots, (i) {
      final hour = startHour + (i ~/ 2);
      final minute = (i % 2) * 30;
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final suffix = hour >= 12 ? 'PM' : 'AM';
      if (minute == 0) {
        return '$hour12:00 $suffix';
      }
      return '$hour12:30';
    });
  }

  static int _appointmentSlotIndex(DateTime fechaHora) {
    final hour = fechaHora.hour;
    final minute = fechaHora.minute;
    if (hour < startHour || hour >= endHour) return -1;
    return (hour - startHour) * 2 + (minute < 30 ? 0 : 1);
  }

  static int _appointmentSlotSpan(int duracionMinutos) {
    final slots = (duracionMinutos / 30).ceil();
    return slots.clamp(1, totalSlots);
  }

  Color _appointmentColor(AppointmentModel a) {
    switch (a.estado) {
      case AppointmentStatus.confirmada:
        return const Color(0xFF10B981);
      case AppointmentStatus.completada:
        return const Color(0xFF6366F1);
      case AppointmentStatus.cancelada:
        return const Color(0xFF6B7280).withOpacity(0.5);
      case AppointmentStatus.noAsistio:
        return const Color(0xFF6B7280).withOpacity(0.3);
      case AppointmentStatus.reprogramada:
        return const Color(0xFFF59E0B);
      case AppointmentStatus.programada:
        return const Color(0xFF3B82F6);
    }
  }

  String _tipoLabel(AppointmentType t) => switch (t) {
        AppointmentType.valoracion => 'Valoración',
        AppointmentType.control => 'Control',
        AppointmentType.instalacion => 'Instalación',
        AppointmentType.urgencia => 'Urgencia',
        AppointmentType.alta => 'Alta',
      };

  Widget _buildDayColumn(
    BuildContext context,
    DateTime day,
    List<AppointmentModel> dayAppointments,
  ) {
    final isToday = _isSameDay(day, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header del día
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isToday
                ? OcgColors.espresso.withOpacity(0.06)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: OcgColors.espresso.withOpacity(0.08)),
            ),
          ),
          child: Text(
            _dayHeader(day),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isToday ? OcgColors.espresso : OcgColors.espresso.withOpacity(0.6),
            ),
          ),
        ),
        // Slots
        ...List.generate(totalSlots, (slotIndex) {
          final slotAppointments = dayAppointments.where((a) {
            return _isSameDay(a.fechaHora, day) &&
                _appointmentSlotIndex(a.fechaHora) == slotIndex;
          }).toList();

          return GestureDetector(
            onTap: () {
              final slotTime = DateTime(
                day.year,
                day.month,
                day.day,
                startHour + (slotIndex ~/ 2),
                (slotIndex % 2) * 30,
              );
              onTapSlot(slotTime);
            },
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: OcgColors.espresso.withOpacity(0.04),
                  ),
                ),
                color: isToday && slotIndex % 2 == 0
                    ? OcgColors.espresso.withOpacity(0.02)
                    : null,
              ),
              child: Stack(
                children: slotAppointments.map((a) {
                  final span = _appointmentSlotSpan(a.duracionMinutos);
                  final height = (span * 36.0).clamp(36.0, 36.0 * (totalSlots - slotIndex));
                  return Positioned(
                    top: 2,
                    left: 2,
                    right: 2,
                    height: height - 4,
                    child: GestureDetector(
                      onTap: () => onTapAppointment(a),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _appointmentColor(a),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: _appointmentColor(a).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a.patientName.split(' ').first,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                            ),
                            if (span >= 2)
                              Text(
                                _tipoLabel(a.tipo),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 9,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _dayHeader(DateTime day) {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final weekday = day.weekday - 1;
    return '${dias[weekday]} ${day.day}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DateTime> _getWeekDays(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final days = showWeek ? _getWeekDays(selectedDate) : [selectedDate];

    // Filtrar citas por día
    final dayAppointments = days.map((day) {
      return appointments.where((a) => _isSameDay(a.fechaHora, day)).toList();
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header con navegación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: OcgColors.ivory,
            border: Border(
              bottom: BorderSide(color: OcgColors.espresso.withOpacity(0.08)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () {
                  // Navegación handled by parent
                },
              ),
              Expanded(
                child: Text(
                  showWeek
                      ? 'Semana del ${_formatDate(days.first)}'
                      : _formatDate(selectedDate),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: OcgColors.espresso,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () {},
              ),
            ],
          ),
        ),
        // Grilla
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final hourColWidth = isWide ? 70.0 : 55.0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Columna de horas
                  SizedBox(
                    width: hourColWidth,
                    child: Column(
                      children: [
                        // Espacio para header del día
                        Container(
                          height: 36,
                          color: OcgColors.ivory,
                        ),
                        ...List.generate(totalSlots, (i) {
                          final isHour = i % 2 == 0;
                          return Container(
                            height: 36,
                            padding: const EdgeInsets.only(right: 8, top: 2),
                            alignment: Alignment.topRight,
                            child: isHour
                                ? Text(
                                    timeLabels[i],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: OcgColors.espresso.withOpacity(0.4),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : null,
                          );
                        }),
                      ],
                    ),
                  ),
                  // Línea divisora
                  Container(
                    width: 1,
                    color: OcgColors.espresso.withOpacity(0.08),
                  ),
                  // Columnas de días
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: days.asMap().entries.map((entry) {
                        final dayIndex = entry.key;
                        final day = entry.value;
                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: dayIndex < days.length - 1
                                    ? BorderSide(
                                        color: OcgColors.espresso.withOpacity(0.06),
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            child: _buildDayColumn(
                              context,
                              day,
                              dayAppointments[dayIndex],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }
}
