import 'package:flutter/material.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../appointments/data/models/appointment_model.dart';

/// Grilla de tiempo estilo Google Calendar con slots de 30 minutos.
///
/// Muestra las citas posicionadas en su franja horaria correspondiente.
/// Cada fila representa 30 minutos. Incluye navegación por fecha.
class TimeGridView extends StatefulWidget {
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

  @override
  State<TimeGridView> createState() => _TimeGridViewState();
}

class _TimeGridViewState extends State<TimeGridView> {
  late DateTime _cursorDate;

  @override
  void initState() {
    super.initState();
    _cursorDate = widget.selectedDate;
  }

  @override
  void didUpdateWidget(TimeGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _cursorDate = widget.selectedDate;
    }
  }

  void _navigate(int days) {
    setState(() {
      if (widget.showWeek) {
        _cursorDate = _cursorDate.add(Duration(days: days * 7));
      } else {
        _cursorDate = _cursorDate.add(Duration(days: days));
      }
    });
  }

  void _goToToday() {
    setState(() => _cursorDate = DateTime.now());
  }

  List<DateTime> get _days {
    if (widget.showWeek) {
      final monday = _cursorDate.subtract(Duration(days: _cursorDate.weekday - 1));
      return List.generate(7, (i) => monday.add(Duration(days: i)));
    }
    return [_cursorDate];
  }

  // ─── Constantes ─────────────────────────────────────────────
  static const int startHour = 8;
  static const int endHour = 18;
  static const int totalSlots = (endHour - startHour) * 2;
  static const double slotHeight = 40.0;

  // ─── Colores por estado ─────────────────────────────────────
  Color _appointmentColor(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.confirmada    => const Color(0xFF7C3AED), // Morado
      AppointmentStatus.noAsistio     => const Color(0xFFDC2626), // Rojo
      AppointmentStatus.cancelada     => const Color(0xFFDC2626), // Rojo
      AppointmentStatus.reprogramada  => const Color(0xFF2563EB), // Azul
      AppointmentStatus.completada    => const Color(0xFF6366F1), // Indigo
      AppointmentStatus.programada    => const Color(0xFF10B981), // Verde (activa)
    };
  }

  String _statusLabel(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.confirmada   => 'Confirmada',
      AppointmentStatus.noAsistio    => 'No asistió',
      AppointmentStatus.cancelada    => 'Cancelada',
      AppointmentStatus.reprogramada => 'Reprogramada',
      AppointmentStatus.completada   => 'Completada',
      AppointmentStatus.programada   => 'Programada',
    };
  }

  // ─── Helpers ────────────────────────────────────────────────
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _slotIndex(DateTime fechaHora) {
    final hour = fechaHora.hour;
    final minute = fechaHora.minute;
    if (hour < startHour || hour >= endHour) return -1;
    return (hour - startHour) * 2 + (minute < 30 ? 0 : 1);
  }

  int _slotSpan(int duracionMinutos) {
    return (duracionMinutos / 30).ceil().clamp(1, totalSlots);
  }

  String _formatDate(DateTime d) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${d.day} ${meses[d.month - 1]}';
  }

  String _dayHeader(DateTime day) {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final weekday = day.weekday - 1;
    return '${dias[weekday]}\n${day.day}';
  }

  String _tipoLabel(AppointmentType t) => switch (t) {
        AppointmentType.valoracion => 'Valoración',
        AppointmentType.control    => 'Control',
        AppointmentType.instalacion => 'Instalación',
        AppointmentType.urgencia   => 'Urgencia',
        AppointmentType.alta       => 'Alta',
      };

  List<String> get _timeLabels {
    return List.generate(totalSlots, (i) {
      final hour = startHour + (i ~/ 2);
      final minute = (i % 2) * 30;
      if (minute == 0) {
        final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$h:00';
      }
      return ':30';
    });
  }

  // ─── Columna de un día ─────────────────────────────────────
  Widget _buildDayColumn(DateTime day, List<AppointmentModel> dayAppts) {
    final isToday = _isSameDay(day, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header del día
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: isToday
                ? const Color(0xFF7C3AED).withOpacity(0.08)
                : OcgColors.ivory,
            border: Border(
              bottom: BorderSide(
                color: OcgColors.espresso.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _dayHeader(day),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isToday
                        ? const Color(0xFF7C3AED)
                        : OcgColors.espresso.withOpacity(0.7),
                    height: 1.2,
                  ),
                ),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 20,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Slots
        ...List.generate(totalSlots, (slotIndex) {
          final slotAppts = dayAppts.where((a) {
            return _slotIndex(a.fechaHora) == slotIndex;
          }).toList();

          final isHourMark = slotIndex % 2 == 0;
          final now = DateTime.now();
          final isCurrentSlot = isToday &&
              _slotIndex(now) == slotIndex;

          return GestureDetector(
            onTap: () {
              final slotTime = DateTime(
                day.year,
                day.month,
                day.day,
                startHour + (slotIndex ~/ 2),
                (slotIndex % 2) * 30,
              );
              widget.onTapSlot(slotTime);
            },
            child: Container(
              height: slotHeight,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isHourMark
                        ? OcgColors.espresso.withOpacity(0.1)
                        : OcgColors.espresso.withOpacity(0.04),
                    width: isHourMark ? 1 : 0.5,
                  ),
                ),
                color: isCurrentSlot
                    ? const Color(0xFF7C3AED).withOpacity(0.06)
                    : (isToday && slotIndex % 2 == 0
                        ? OcgColors.espresso.withOpacity(0.015)
                        : null),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: slotAppts.map((a) {
                  final span = _slotSpan(a.duracionMinutos);
                  final pxHeight = (span * slotHeight).clamp(
                    slotHeight - 2,
                    slotHeight * (totalSlots - slotIndex) - 2,
                  );
                  final color = _appointmentColor(a.estado);

                  return Positioned(
                    top: 2,
                    left: 3,
                    right: 3,
                    height: pxHeight,
                    child: GestureDetector(
                      onTap: () => widget.onTapAppointment(a),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  a.patientName.split(' ').first,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  maxLines: 1,
                                ),
                                if (span >= 2)
                                  Text(
                                    _tipoLabel(a.tipo),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 10,
                                      height: 1.2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    maxLines: 1,
                                  ),
                                if (span >= 3)
                                  Text(
                                    _statusLabel(a.estado),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 9,
                                      height: 1.2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    maxLines: 1,
                                  ),
                              ],
                            ),
                          ),
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

  // ─── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final days = _days;
    final isWide = MediaQuery.of(context).size.width > 600;
    final hourColWidth = isWide ? 60.0 : 48.0;

    // Filtrar citas por día
    final dayAppointments = days.map((day) {
      return widget.appointments
          .where((a) => _isSameDay(a.fechaHora, day))
          .toList();
    }).toList();

    // Título de navegación
    final navTitle = widget.showWeek
        ? 'Semana del ${_formatDate(days.first)}'
        : _formatDate(days.first);

    final isCurrentPeriod = widget.showWeek
        ? _isSameWeek(DateTime.now(), _cursorDate)
        : _isSameDay(DateTime.now(), _cursorDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header con navegación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: OcgColors.ivory,
            border: Border(
              bottom: BorderSide(
                color: OcgColors.espresso.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => _navigate(-1),
                tooltip: 'Anterior',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () => _navigate(1),
                tooltip: 'Siguiente',
              ),
              const SizedBox(width: 4),
              if (!isCurrentPeriod)
                TextButton.icon(
                  onPressed: _goToToday,
                  icon: const Icon(Icons.today, size: 16),
                  label: const Text('Hoy', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    foregroundColor: const Color(0xFF7C3AED),
                  ),
                ),
              Expanded(
                child: Text(
                  navTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: OcgColors.espresso,
                  ),
                ),
              ),
              // Indicador de cantidad de citas
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.appointments.where((a) => days.any((d) => _isSameDay(a.fechaHora, d))).length} citas',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Leyenda de colores
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: OcgColors.ivory.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(
                color: OcgColors.espresso.withOpacity(0.06),
              ),
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legendDot(const Color(0xFF7C3AED), 'Confirmada'),
              _legendDot(const Color(0xFF10B981), 'Activa'),
              _legendDot(const Color(0xFF2563EB), 'Reprogramada'),
              _legendDot(const Color(0xFFDC2626), 'No asistió/Cancelada'),
              _legendDot(const Color(0xFF6366F1), 'Completada'),
            ],
          ),
        ),
        // Grilla
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna de horas
              SizedBox(
                width: hourColWidth,
                child: Column(
                  children: [
                    // Espacio para header del día
                    Container(height: 48, color: OcgColors.ivory),
                    ...List.generate(totalSlots, (i) {
                      final label = _timeLabels[i];
                      return Container(
                        height: slotHeight,
                        padding: const EdgeInsets.only(right: 8, top: 2),
                        alignment: Alignment.topRight,
                        child: label.startsWith(':')
                            ? null
                            : Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: OcgColors.espresso.withOpacity(0.35),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      );
                    }),
                  ],
                ),
              ),
              // Línea divisora
              Container(
                width: 1,
                color: OcgColors.espresso.withOpacity(0.1),
              ),
              // Columnas de días
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final minWidthPerDay = 80.0;
                    final availableWidth = constraints.maxWidth;
                    final canShowAll = availableWidth >=
                        minWidthPerDay * days.length;

                    return SingleChildScrollView(
                      scrollDirection: canShowAll
                          ? Axis.vertical
                          : Axis.horizontal,
                      child: SizedBox(
                        width: canShowAll
                            ? null
                            : minWidthPerDay * days.length,
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
                                            color: OcgColors.espresso
                                                .withOpacity(0.06),
                                          )
                                        : BorderSide.none,
                                  ),
                                ),
                                child: _buildDayColumn(
                                  day,
                                  dayAppointments[dayIndex],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: OcgColors.espresso.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    final startOfWeekA = a.subtract(Duration(days: a.weekday - 1));
    final startOfWeekB = b.subtract(Duration(days: b.weekday - 1));
    return _isSameDay(startOfWeekA, startOfWeekB);
  }
}
