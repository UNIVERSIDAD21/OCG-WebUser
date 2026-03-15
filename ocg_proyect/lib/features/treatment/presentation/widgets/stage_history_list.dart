import 'package:flutter/material.dart';

import '../../data/models/stage_history_entry.dart';
import '../../../../../shared/theme/ocg_colors.dart';
import '../../../../../shared/widgets/ocg_card.dart';
import '../../../../../shared/widgets/ocg_empty_state.dart';
import 'treatment_timeline.dart';

class StageHistoryList extends StatelessWidget {
  const StageHistoryList({super.key, required this.historial});

  final List<StageHistoryEntry> historial;

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty) {
      return const OcgEmptyState(
        icon: Icons.history,
        title: 'Sin cambios de etapa registrados aún.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: historial.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = historial[index];
        final notes = entry.notas.trim();

        return OcgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(entry.fechaCambio),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OcgColors.bronze,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text(stageNames[entry.etapaAnterior] ?? entry.etapaAnterior.name)),
                  const Icon(Icons.arrow_forward, size: 16),
                  Expanded(
                    child: Text(
                      stageNames[entry.etapaNueva] ?? entry.etapaNueva.name,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (notes.length <= 80)
                Text(notes)
              else
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text('${notes.substring(0, 80)}...'),
                  children: [
                    Align(alignment: Alignment.centerLeft, child: Text(notes)),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                'Admin: ${entry.adminId}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7B746E),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    String two(int value) => value.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    return '${two(date.day)} $month ${date.year}, ${two(date.hour)}:${two(date.minute)}';
  }
}
