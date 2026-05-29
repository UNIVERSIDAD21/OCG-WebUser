import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../admin_appointments_agenda_helpers.dart';

/// Grilla de tiempo estilo Google Calendar con slots de 30 minutos.
///
/// Features:
/// - Navegación día/semana con auto-scroll a hora actual
/// - Indicador "Ahora" (línea roja)
/// - Citas superpuestas lado a lado
/// - Hora visible en cada cita
/// - Pasado atenuado
/// - Sección "Todo el día"
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

class _TimeGridViewState extends State<TimeGridView>
    with SingleTickerProviderStateMixin {
  late DateTime _cursorDate;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _nowLineAnimation;
  Timer? _nowLineTimer;

  @override
  void initState() {
    super.initState();
    _cursorDate = widget.selectedDate;
    _nowLineAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    // Auto-scroll a hora actual después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    // Actualizar línea "Ahora" cada minuto
    _nowLineTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(TimeGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _cursorDate = widget.selectedDate;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nowLineAnimation.dispose();
    _nowLineTimer?.cancel();
    super.dispose();
  }

  void _scrollToNow() {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now();
    final minutesSinceStart = (now.hour - startHour) * 60 + now.minute;
    final targetOffset =
        dayHeaderHeight +
        allDaySectionHeight +
        (minutesSinceStart / 30) * slotHeight -
        120;
    if (targetOffset > 0) {
      _scrollController.animateTo(
        targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _navigate(int days) {
    setState(() {
      _cursorDate = widget.showWeek
          ? _cursorDate.add(Duration(days: days * 7))
          : _cursorDate.add(Duration(days: days));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  void _goToToday() {
    setState(() => _cursorDate = DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  List<DateTime> get _days {
    if (widget.showWeek) {
      final monday = _cursorDate.subtract(
        Duration(days: _cursorDate.weekday - 1),
      );
      return List.generate(7, (i) => monday.add(Duration(days: i)));
    }
    return [_cursorDate];
  }

  // ─── Constantes ─────────────────────────────────────────────
  static const int startHour = 7;
  static const int endHour = 20;
  static const int totalSlots = (endHour - startHour) * 2;
  static const double slotHeight = 44.0;
  static const double hourColWidth = 52.0;
  static const double dayHeaderHeight = 48.0;
  static const double allDaySectionHeight = 36.0;

  // ─── Colores por estado ─────────────────────────────────────
  Color _appointmentColor(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.confirmada => agendaConfirmedColor,
      AppointmentStatus.noAsistio => agendaRejectedColor,
      AppointmentStatus.cancelada => agendaRejectedColor,
      AppointmentStatus.reprogramada => agendaRescheduledColor,
      AppointmentStatus.completada => const Color(0xFF6366F1),
      AppointmentStatus.programada => const Color(0xFF10B981),
    };
  }

  Color _appointmentBgColor(AppointmentStatus status) {
    // Versión más clara para el fondo del card
    return switch (status) {
      AppointmentStatus.confirmada => const Color(0xFFEDE9FE),
      AppointmentStatus.noAsistio => const Color(0xFFFEE2E2),
      AppointmentStatus.cancelada => const Color(0xFFFEE2E2),
      AppointmentStatus.reprogramada => const Color(0xFFDBEAFE),
      AppointmentStatus.completada => const Color(0xFFE0E7FF),
      AppointmentStatus.programada => const Color(0xFFD1FAE5),
    };
  }

  Color _appointmentTextColor(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.confirmada => const Color(0xFF5B21B6),
      AppointmentStatus.noAsistio => const Color(0xFF991B1B),
      AppointmentStatus.cancelada => const Color(0xFF991B1B),
      AppointmentStatus.reprogramada => const Color(0xFF1E40AF),
      AppointmentStatus.completada => const Color(0xFF3730A3),
      AppointmentStatus.programada => const Color(0xFF065F46),
    };
  }

  String _statusLabel(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.confirmada => 'Confirmada',
      AppointmentStatus.noAsistio => 'No asistió',
      AppointmentStatus.cancelada => 'Cancelada',
      AppointmentStatus.reprogramada => 'Reprogramada',
      AppointmentStatus.completada => 'Completada',
      AppointmentStatus.programada => 'Programada',
    };
  }

  // ─── Helpers ────────────────────────────────────────────────
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    final startA = a.subtract(Duration(days: a.weekday - 1));
    final startB = b.subtract(Duration(days: b.weekday - 1));
    return _isSameDay(startA, startB);
  }

  int _slotIndex(DateTime fechaHora) {
    final hour = fechaHora.hour;
    final minute = fechaHora.minute;
    if (hour < startHour || hour >= endHour) return -1;
    return (hour - startHour) * 2 + (minute < 30 ? 0 : 1);
  }

  double _slotSpanMinutes(int duracionMinutos) {
    return (duracionMinutos / 30) * slotHeight;
  }

  String _formatTimeShort(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:${d.minute.toString().padLeft(2, '0')} $suffix';
  }

  String _formatHourLabel(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '$h $suffix';
  }

  String _formatDate(DateTime d) {
    const meses = [
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
    return '${d.day} ${meses[d.month - 1]}';
  }

  String _dayHeader(DateTime day) {
    const diasCorto = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const diasLargo = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final wd = day.weekday - 1;
    return widget.showWeek
        ? '${diasCorto[wd]} ${day.day}'
        : '${diasLargo[wd]} ${day.day}';
  }

  String _tipoLabel(AppointmentType t) => switch (t) {
    AppointmentType.valoracion => 'Valoración',
    AppointmentType.control => 'Control',
    AppointmentType.instalacion => 'Instalación',
    AppointmentType.urgencia => 'Urgencia',
    AppointmentType.alta => 'Alta',
  };

  /// Posición X de la línea "Ahora" según el día actual.
  double _nowLineLeft(DateTime now, List<DateTime> days, double dayWidth) {
    final idx = days.indexWhere((d) => _isSameDay(d, now));
    return idx >= 0 ? idx * dayWidth : 0;
  }

  double _dayWidthFor(double availableWidth, int dayCount) {
    if (!widget.showWeek) return availableWidth;
    final minTotalWidth = dayCount * 90.0;
    return (availableWidth < minTotalWidth ? 90.0 : availableWidth / dayCount);
  }

  // ─── Calcular columnas para citas superpuestas ─────────────
  /// Calcula posición X y ancho para cada cita considerando solapamientos.
  /// Retorna lista de (left, width) para cada cita.
  List<({double left, double width})> _computeOverlapLayout(
    List<AppointmentModel> appts,
  ) {
    if (appts.isEmpty) return [];
    if (appts.length == 1) return [const (left: 4.0, width: double.infinity)];

    // Ordenar por hora de inicio
    final sorted = [...appts]
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

    // Calcular grupos de solapamiento
    final columns = <List<AppointmentModel>>[];

    for (final appt in sorted) {
      int? placedColumn;
      for (int i = 0; i < columns.length; i++) {
        final lastInCol = columns[i].last;
        final lastEnd = lastInCol.fechaHora.add(
          Duration(minutes: lastInCol.duracionMinutos),
        );
        if (!appt.fechaHora.isBefore(lastEnd)) {
          placedColumn = i;
          break;
        }
      }
      if (placedColumn != null) {
        columns[placedColumn].add(appt);
      } else {
        columns.add([appt]);
      }
    }

    final maxCols = columns.length;
    final colWidth =
        (1.0 - (maxCols * 2 - 1) * 0.02) / maxCols; // 2% gap entre columnas

    // Para cada cita, determinar su columna y posición
    final result = List<({double left, double width})>.filled(appts.length, (
      left: 0.0,
      width: 0.0,
    ));
    for (int i = 0; i < sorted.length; i++) {
      final appt = sorted[i];
      int colIndex = 0;
      for (int c = 0; c < columns.length; c++) {
        if (columns[c].contains(appt)) {
          colIndex = c;
          break;
        }
      }
      // Si hay más de 1 columna pero esta cita no se solapa con ninguna otra
      // activa al mismo tiempo, expandirla
      final apptEnd = appt.fechaHora.add(
        Duration(minutes: appt.duracionMinutos),
      );
      bool overlapsAny = false;
      for (final other in sorted) {
        if (other == appt) continue;
        final otherEnd = other.fechaHora.add(
          Duration(minutes: other.duracionMinutos),
        );
        if (appt.fechaHora.isBefore(otherEnd) &&
            other.fechaHora.isBefore(apptEnd)) {
          overlapsAny = true;
          break;
        }
      }

      final origIndex = appts.indexOf(appt);
      if (!overlapsAny && maxCols > 1) {
        result[origIndex] = (left: 4.0, width: double.infinity);
      } else {
        final left = colIndex * (colWidth + 0.02);
        result[origIndex] = (left: left, width: colWidth);
      }
    }

    return result;
  }

  // ─── Sección "Todo el día" ─────────────────────────────────
  Widget _buildAllDaySection(DateTime day, List<AppointmentModel> allAppts) {
    // Citas que duran todo el día o son de tipo especial
    final allDayAppts = allAppts.where((a) {
      return a.duracionMinutos >= 480;
    }).toList();

    return Container(
      height: allDaySectionHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        border: Border(
          bottom: BorderSide(color: OcgColors.espresso.withOpacity(0.1)),
        ),
      ),
      child: allDayAppts.isEmpty
          ? const SizedBox.shrink()
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allDayAppts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 3),
              itemBuilder: (context, index) {
                final a = allDayAppts[index];
                final color = _appointmentColor(a.estado);
                return GestureDetector(
                  onTap: () => widget.onTapAppointment(a),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      a.patientName.split(' ').first,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHourColumn() {
    return Column(
      children: List.generate(totalSlots, (i) {
        final isHour = i % 2 == 0;
        final label = isHour
            ? _formatHourLabel(DateTime(0, 1, 1, startHour + (i ~/ 2)))
            : '';
        return Container(
          height: slotHeight,
          padding: const EdgeInsets.only(right: 6, top: 2),
          alignment: Alignment.topRight,
          child: isHour
              ? Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: OcgColors.espresso.withOpacity(0.35),
                    fontWeight: FontWeight.w500,
                  ),
                )
              : null,
        );
      }),
    );
  }

  Widget _buildHourHeaderColumn() {
    return Column(
      children: [
        Container(height: dayHeaderHeight, color: OcgColors.ivory),
        Container(
          height: allDaySectionHeight,
          decoration: BoxDecoration(
            color: OcgColors.ivory,
            border: Border(
              bottom: BorderSide(color: OcgColors.espresso.withOpacity(0.1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeaderCell(DateTime day) {
    final isToday = _isSameDay(day, DateTime.now());
    return Container(
      height: dayHeaderHeight,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: isToday
            ? agendaConfirmedColor.withOpacity(0.08)
            : Colors.transparent,
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
                fontSize: widget.showWeek ? 11 : 12,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday
                    ? agendaConfirmedColor
                    : OcgColors.espresso.withOpacity(0.7),
                height: 1.2,
              ),
            ),
            if (isToday)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 24,
                height: 3,
                decoration: BoxDecoration(
                  color: agendaConfirmedColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Columna de un día ─────────────────────────────────────
  Widget _buildStickyDaysHeader(
    List<DateTime> days,
    List<List<AppointmentModel>> dayAppointments,
  ) {
    final height = dayHeaderHeight + allDaySectionHeight;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: hourColWidth,
            height: height,
            child: _buildHourHeaderColumn(),
          ),
          Container(
            width: 1,
            height: height,
            color: OcgColors.espresso.withOpacity(0.1),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dayWidth = _dayWidthFor(
                  constraints.maxWidth,
                  days.length,
                );
                return SizedBox(
                  width: constraints.maxWidth,
                  height: height,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ...days.asMap().entries.map((entry) {
                        final dayIndex = entry.key;
                        final day = entry.value;
                        return Positioned(
                          top: 0,
                          left: dayIndex * dayWidth,
                          width: dayWidth,
                          height: height,
                          child: Container(
                            color: OcgColors.ivory,
                            child: Column(
                              children: [
                                _buildDayHeaderCell(day),
                                _buildAllDaySection(
                                  day,
                                  dayAppointments[dayIndex],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(DateTime day, List<AppointmentModel> dayAppts) {
    final isToday = _isSameDay(day, DateTime.now());
    final now = DateTime.now();

    final normalAppts = dayAppts.where((a) => a.duracionMinutos < 480).toList();

    // Calcular layout de superposición
    final layouts = _computeOverlapLayout(normalAppts);

    return SizedBox(
      height: totalSlots * slotHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget slotCell(int slotIndex) {
            final isHourMark = slotIndex % 2 == 0;
            final slotHour = startHour + (slotIndex ~/ 2);
            final slotMinute = slotIndex % 2 == 0 ? 0 : 30;
            final slotTime = DateTime(
              day.year,
              day.month,
              day.day,
              slotHour,
              slotMinute,
            );
            final isCurrentSlot =
                isToday &&
                slotHour == now.hour &&
                ((slotIndex % 2 == 0 && now.minute < 30) ||
                    (slotIndex % 2 == 1 && now.minute >= 30));
            final isPast =
                isToday &&
                (slotHour < now.hour ||
                    (slotHour == now.hour && slotMinute < now.minute));

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTapSlot(slotTime),
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
                  color: isPast
                      ? OcgColors.espresso.withOpacity(0.02)
                      : (isCurrentSlot
                            ? agendaRejectedColor.withOpacity(0.04)
                            : null),
                ),
              ),
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Column(children: List.generate(totalSlots, slotCell)),
              for (final entry in normalAppts.asMap().entries)
                _buildAppointmentCard(
                  entry.value,
                  layouts[entry.key],
                  constraints.maxWidth,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard(
    AppointmentModel appt,
    ({double left, double width}) layout,
    double availableWidth,
  ) {
    final slotIdx = _slotIndex(appt.fechaHora);
    if (slotIdx < 0) return const SizedBox.shrink();

    final minutesIntoSlot = appt.fechaHora.minute % 30;
    final topOffset =
        (slotIdx * slotHeight) + (minutesIntoSlot / 30) * slotHeight + 2;
    final height = _slotSpanMinutes(appt.duracionMinutos) - 4;
    final color = _appointmentColor(appt.estado);
    final bgColor = _appointmentBgColor(appt.estado);
    final textColor = _appointmentTextColor(appt.estado);
    final showRescheduledSplit =
        appt.wasRescheduled && appt.estado == AppointmentStatus.programada;
    final rescheduledBgColor = _appointmentBgColor(
      AppointmentStatus.reprogramada,
    );
    final borderColor = showRescheduledSplit
        ? agendaRescheduledColor.withOpacity(0.5)
        : color.withOpacity(0.4);
    final usableWidth = (availableWidth - 8)
        .clamp(0.0, double.infinity)
        .toDouble();
    final isFullWidth = layout.width == double.infinity;
    final minCardWidth = usableWidth < 28 ? usableWidth : 28.0;
    final cardWidth = isFullWidth
        ? null
        : (layout.width * usableWidth)
              .clamp(minCardWidth, usableWidth)
              .toDouble();

    return Positioned(
      top: topOffset,
      left: isFullWidth ? 4.0 : 4.0 + layout.left * usableWidth,
      right: isFullWidth ? 4.0 : null,
      width: cardWidth,
      height: height < 30 ? 30.0 : height,
      child: GestureDetector(
        onTap: () => widget.onTapAppointment(appt),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: showRescheduledSplit ? null : bgColor,
              gradient: showRescheduledSplit
                  ? LinearGradient(
                      colors: [bgColor, rescheduledBgColor],
                      stops: const [0.5, 0.5],
                    )
                  : null,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: height > 50 ? 8 : 6,
                vertical: height > 50 ? 4 : 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Línea 1: Hora + Nombre
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '${_formatTimeShort(appt.fechaHora)} ${appt.patientName.split(' ').first}',
                          style: TextStyle(
                            color: textColor,
                            fontSize: height > 40 ? 12 : 10,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  // Línea 2: Tipo (si hay espacio)
                  if (height > 38)
                    Text(
                      _tipoLabel(appt.tipo),
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: height > 50 ? 10 : 9,
                        height: 1.2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  // Línea 3: Estado (si hay mucho espacio)
                  if (height > 60)
                    Text(
                      _statusLabel(appt.estado),
                      style: TextStyle(
                        color: textColor.withOpacity(0.55),
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
  }

  // ─── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final days = _days;
    final now = DateTime.now();

    // Filtrar citas por día
    final dayAppointments = days.map((day) {
      return widget.appointments
          .where(
            (a) =>
                _isSameDay(a.fechaHora, day) &&
                a.estado != AppointmentStatus.reprogramada,
          )
          .toList();
    }).toList();

    final navTitle = widget.showWeek
        ? 'Semana del ${_formatDate(days.first)}'
        : _formatDate(days.first);

    final isCurrentPeriod = widget.showWeek
        ? _isSameWeek(now, _cursorDate)
        : _isSameDay(now, _cursorDate);

    final totalCitas = widget.appointments
        .where((a) => days.any((d) => _isSameDay(a.fechaHora, d)))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header con navegación ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: OcgColors.ivory,
            border: Border(
              bottom: BorderSide(color: OcgColors.espresso.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => _navigate(-1),
                tooltip: 'Anterior',
                splashRadius: 18,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () => _navigate(1),
                tooltip: 'Siguiente',
                splashRadius: 18,
              ),
              if (!isCurrentPeriod)
                TextButton.icon(
                  onPressed: _goToToday,
                  icon: const Icon(Icons.today, size: 15),
                  label: const Text('Hoy', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    foregroundColor: const Color(0xFF7C3AED),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Expanded(
                child: Text(
                  navTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: OcgColors.espresso,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event, size: 13, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 4),
                    Text(
                      '$totalCitas',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── Leyenda de colores ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: OcgColors.ivory.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(color: OcgColors.espresso.withOpacity(0.06)),
            ),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _legendDot(agendaConfirmedColor, 'Confirmada'),
              _legendDot(const Color(0xFF10B981), 'Activa'),
              _legendDot(agendaRescheduledColor, 'Reprogramada'),
              _legendDot(agendaRejectedColor, 'No asistió'),
              _legendDot(const Color(0xFF6366F1), 'Completada'),
            ],
          ),
        ),
        // ── Grilla principal ──
        Expanded(
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              // Altura total del contenido scrollable (header + todo-el-día + slots)
              final gridHeight = totalSlots * slotHeight;
              final stickyHeaderHeight = dayHeaderHeight + allDaySectionHeight;

              return Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: EdgeInsets.only(top: stickyHeaderHeight),
                        child: SizedBox(
                          width: viewportConstraints.maxWidth,
                          height: gridHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Columna de horas
                              SizedBox(
                                width: hourColWidth,
                                height: gridHeight,
                                child: _buildHourColumn(),
                              ),
                              // Línea divisora
                              Container(
                                width: 1,
                                height: gridHeight,
                                color: OcgColors.espresso.withOpacity(0.1),
                              ),
                              // Columnas de días
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Calcular ancho de días para modo semana
                                    final dayWidth = _dayWidthFor(
                                      constraints.maxWidth,
                                      days.length,
                                    );

                                    return SizedBox(
                                      width: constraints.maxWidth,
                                      height: gridHeight,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          // Columnas de días
                                          ...days.asMap().entries.map((entry) {
                                            final dayIndex = entry.key;
                                            final day = entry.value;
                                            return Positioned(
                                              top: 0,
                                              left: dayIndex * dayWidth,
                                              width: dayWidth,
                                              height: gridHeight,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    right:
                                                        dayIndex <
                                                            days.length - 1
                                                        ? BorderSide(
                                                            color: OcgColors
                                                                .espresso
                                                                .withOpacity(
                                                                  0.06,
                                                                ),
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
                                          }),
                                          // Línea "Ahora" (encima de todas las columnas)
                                          if (_isSameDay(now, days.first) ||
                                              (widget.showWeek &&
                                                  days.any(
                                                    (d) => _isSameDay(d, now),
                                                  )))
                                            Positioned(
                                              top:
                                                  (now.hour - startHour) *
                                                      2 *
                                                      slotHeight +
                                                  (now.minute / 30) *
                                                      slotHeight,
                                              left: _nowLineLeft(
                                                now,
                                                days,
                                                dayWidth,
                                              ),
                                              width: dayWidth,
                                              child: IgnorePointer(
                                                child: Container(
                                                  height: 2,
                                                  decoration: const BoxDecoration(
                                                    color: agendaRejectedColor,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color:
                                                            agendaRejectedColor,
                                                        blurRadius: 4,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: stickyHeaderHeight,
                    child: _buildStickyDaysHeader(days, dayAppointments),
                  ),
                ],
              );
            },
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
}
