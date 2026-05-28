import 'package:flutter/material.dart';

import '../../../appointments/data/models/appointment_model.dart';
import '../../../../../../shared/theme/ocg_colors.dart';
import '../admin_appointments_agenda_helpers.dart';

typedef DayTapCallback = void Function(DateTime day, List<AppointmentModel> dayItems);

/// Widget del calendario mensual con navegación y dots de citas.
/// Reutilizable en sidebar y vistas mobile.
class MonthCalendarWidget extends StatelessWidget {
  const MonthCalendarWidget({
    super.key,
    required this.monthCursor,
    this.selectedDay,
    required this.appointments,
    required this.onMonthChange,
    required this.onDayTap,
    this.compact = false,
  });

  final DateTime monthCursor;
  final DateTime? selectedDay;
  final List<AppointmentModel> appointments;
  final void Function(int delta) onMonthChange;
  final DayTapCallback onDayTap;
  final bool compact;

  List<AppointmentModel> _appointmentsForDay(
    List<AppointmentModel> all,
    DateTime date,
  ) {
    return all.where((a) {
      return a.fechaHora.year == date.year &&
          a.fechaHora.month == date.month &&
          a.fechaHora.day == date.day;
    }).toList();
  }

  String _monthLabel(DateTime d) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${meses[d.month - 1]} ${d.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstWeekday = DateTime(monthCursor.year, monthCursor.month, 1).weekday % 7;
    final daysInMonth = DateTime(monthCursor.year, monthCursor.month + 1, 0).day;

    final cells = <Widget>[];
    const dow = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    cells.addAll(
      dow.map(
        (d) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              d,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: OcgColors.ink.withOpacity(0.56),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthCursor.year, monthCursor.month, day);
      final isToday = _isSameDay(date, now);
      final isSelected = selectedDay != null && _isSameDay(date, selectedDay!);
      final dayItems = _appointmentsForDay(appointments, date);

      cells.add(
        InkWell(
          onTap: () => onDayTap(date, dayItems),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? OcgColors.espresso : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isToday
                    ? OcgColors.espresso
                    : OcgColors.bronze.withOpacity(0.15),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? OcgColors.ivory : OcgColors.ink,
                  ),
                ),
                if (dayItems.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 2,
                    children: dayItems.take(3).map((a) {
                      final ui = appointmentStatusUi(a);
                      return Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? OcgColors.ivory.withOpacity(0.8)
                              : ui.dot,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => onMonthChange(-1),
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Expanded(
                child: Text(
                  _monthLabel(monthCursor),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: OcgColors.espresso,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onMonthChange(1),
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: compact ? 1.15 : 1.12,
            children: cells,
          ),
        ],
      ),
    );
  }
}
