import 'package:flutter/material.dart';

import '../../../patients/data/models/patient_model.dart';
import '../../data/models/stage_history_entry.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_button.dart';
import '../../../../shared/widgets/ocg_card.dart';

const Map<TreatmentStage, String> stageNames = {
  TreatmentStage.diagnostico: 'Diagnóstico',
  TreatmentStage.planificacion: 'Planificación',
  TreatmentStage.instalacion: 'Instalación',
  TreatmentStage.seguimientoActivo: 'Seguimiento activo',
  TreatmentStage.ajusteFinal: 'Ajuste final',
  TreatmentStage.retencion: 'Retención',
  TreatmentStage.alta: 'Alta',
};

const Map<TreatmentStage, String> stageDescriptions = {
  TreatmentStage.diagnostico:
      'Valoración inicial completa: radiografías panorámicas, fotografías clínicas y elaboración del plan de tratamiento personalizado.',
  TreatmentStage.planificacion:
      'Plan clínico detallado definido y aprobado. Presupuesto acordado y consentimiento informado firmado.',
  TreatmentStage.instalacion:
      'Colocación de brackets, alineadores o aparatología indicada. Inicio oficial del movimiento dental.',
  TreatmentStage.seguimientoActivo:
      'Fase de controles periódicos. Se realizan ajustes y se monitorea el movimiento dental.',
  TreatmentStage.ajusteFinal:
      'Refinamientos finales de la posición dental. Detallado estético y correcciones menores.',
  TreatmentStage.retencion:
      'Tratamiento activo completado. Retenedores instalados para estabilizar el resultado.',
  TreatmentStage.alta:
      'Tratamiento finalizado exitosamente. Se han logrado los objetivos clínicos y estéticos.',
};

enum _NodeState { completed, active, pending }

class TreatmentTimeline extends StatefulWidget {
  const TreatmentTimeline({
    super.key,
    required this.etapaActual,
    required this.historial,
    required this.isAdmin,
    this.onAdvanceStage,
  });

  final TreatmentStage etapaActual;
  final List<StageHistoryEntry> historial;
  final bool isAdmin;
  final VoidCallback? onAdvanceStage;

  @override
  State<TreatmentTimeline> createState() => _TreatmentTimelineState();
}

class _TreatmentTimelineState extends State<TreatmentTimeline> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _expandedIndex = TreatmentStage.values.indexOf(widget.etapaActual);
  }

  @override
  void didUpdateWidget(covariant TreatmentTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.etapaActual != widget.etapaActual) {
      _expandedIndex = TreatmentStage.values.indexOf(widget.etapaActual);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = TreatmentStage.values.indexOf(widget.etapaActual);

    return Column(
      children: List.generate(TreatmentStage.values.length, (index) {
        final stage = TreatmentStage.values[index];
        final state = _nodeState(index, currentIndex);
        final isExpanded = _expandedIndex == index;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Column(
                        children: [
                          _buildNode(state),
                          if (index != TreatmentStage.values.length - 1)
                            _buildConnector(state: state),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          stageNames[stage] ?? stage.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: OcgColors.espresso,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 10),
                child: _StageCard(
                  stage: stage,
                  state: state,
                  changedAt: _changedAtForStage(stage),
                  showAdvanceButton: widget.isAdmin && state == _NodeState.active,
                  onAdvanceStage: widget.onAdvanceStage,
                ),
              ),
          ],
        );
      }),
    );
  }

  _NodeState _nodeState(int index, int currentIndex) {
    if (index < currentIndex) return _NodeState.completed;
    if (index == currentIndex) return _NodeState.active;
    return _NodeState.pending;
  }

  DateTime? _changedAtForStage(TreatmentStage stage) {
    final match = widget.historial.where((h) => h.etapaNueva == stage);
    if (match.isEmpty) return null;
    return match.first.fechaCambio;
  }

  Widget _buildNode(_NodeState state) {
    IconData icon;
    Color color;

    switch (state) {
      case _NodeState.completed:
        icon = Icons.check_circle;
        color = OcgColors.success;
      case _NodeState.active:
        icon = Icons.access_time;
        color = OcgColors.bronze;
      case _NodeState.pending:
        icon = Icons.circle_outlined;
        color = const Color(0xFFCCC5BE);
    }

    final node = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color, size: 16),
    );

    if (state != _NodeState.active) return node;

    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1.0).animate(_pulseController),
      child: node,
    );
  }

  Widget _buildConnector({required _NodeState state}) {
    if (state == _NodeState.pending) {
      return Container(
        width: 2,
        height: 34,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (_) => Container(width: 2, height: 3, color: const Color(0xFFCCC5BE)),
          ),
        ),
      );
    }

    final color = state == _NodeState.completed ? OcgColors.success : OcgColors.bronze;

    return Container(
      width: 2,
      height: 34,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: color,
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.state,
    required this.changedAt,
    required this.showAdvanceButton,
    required this.onAdvanceStage,
  });

  final TreatmentStage stage;
  final _NodeState state;
  final DateTime? changedAt;
  final bool showAdvanceButton;
  final VoidCallback? onAdvanceStage;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (state) {
      _NodeState.completed => changedAt != null ? _formatDate(changedAt!) : 'Completada',
      _NodeState.active => 'En progreso',
      _NodeState.pending => 'Próximamente',
    };

    return OcgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stageNames[stage] ?? stage.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(stageDescriptions[stage] ?? ''),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OcgColors.bronze,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (showAdvanceButton && onAdvanceStage != null) ...[
            const SizedBox(height: 12),
            OcgButton(label: 'Avanzar etapa', onPressed: onAdvanceStage),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }
}
