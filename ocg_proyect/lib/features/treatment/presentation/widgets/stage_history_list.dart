import 'package:flutter/material.dart';

import '../../data/models/stage_history_entry.dart';
import '../../../../../shared/theme/ocg_colors.dart';
import '../../../../../shared/widgets/ocg_card.dart';
import '../../../../../shared/widgets/ocg_empty_state.dart';
import '../../../patients/data/models/patient_model.dart';

class StageHistoryList extends StatelessWidget {
  const StageHistoryList({
    super.key,
    required this.historial,
    required this.isAdmin,
  });

  final List<StageHistoryEntry> historial;
  final bool isAdmin;

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
        final isClinicalAction =
            (entry.consultationId?.trim().isNotEmpty ?? false) ||
            (entry.signatureUrl?.trim().isNotEmpty ?? false) ||
            notes.toLowerCase().contains('consulta clinica');

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
              if (isClinicalAction)
                Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      size: 16,
                      color: OcgColors.espresso,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Consulta clinica',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(stageNames[entry.etapaNueva] ?? entry.etapaNueva.name),
                  ],
                )
              else
                Row(
                  children: [
                    if (entry.esRetroceso) ...[
                      const Icon(
                        Icons.undo,
                        size: 14,
                        color: OcgColors.warning,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Retroceso',
                        style: TextStyle(
                          color: OcgColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        stageNames[entry.etapaAnterior] ??
                            entry.etapaAnterior.name,
                      ),
                    ),
                    const Icon(Icons.arrow_forward, size: 16),
                    Expanded(
                      child: Text(
                        stageNames[entry.etapaNueva] ?? entry.etapaNueva.name,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                if (notes.length <= 120)
                  Text(notes)
                else
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text('${notes.substring(0, 120)}...'),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(notes),
                      ),
                    ],
                  ),
              ],
              if ((entry.signatureUrl ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _SignaturePreview(url: entry.signatureUrl!.trim()),
              ],
              if (isAdmin) ...[
                if (_hasInternalFields(entry)) ...[
                  const SizedBox(height: 8),
                  _AdminField(
                    label: 'Diagnóstico',
                    value: entry.diagnosticoBreve,
                  ),
                  _AdminField(
                    label: 'Plan siguiente etapa',
                    value: entry.planSiguienteEtapa,
                  ),
                  _AdminField(
                    label: 'Adjuntos',
                    value: entry.adjuntosDescripcion,
                  ),
                  _AdminField(
                    label: 'Fecha efectiva',
                    value: entry.fechaEfectiva == null
                        ? null
                        : _formatDate(entry.fechaEfectiva!),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  bool _hasInternalFields(StageHistoryEntry e) {
    return (e.diagnosticoBreve?.trim().isNotEmpty ?? false) ||
        (e.planSiguienteEtapa?.trim().isNotEmpty ?? false) ||
        (e.adjuntosDescripcion?.trim().isNotEmpty ?? false) ||
        e.fechaEfectiva != null;
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

class _AdminField extends StatelessWidget {
  const _AdminField({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        '$label: $clean',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6C655E)),
      ),
    );
  }
}

class _SignaturePreview extends StatelessWidget {
  const _SignaturePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1EA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Firma del paciente',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OcgColors.bronze,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: 120,
              color: Colors.white,
              alignment: Alignment.center,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text(
                  'No se pudo cargar la firma.',
                  style: TextStyle(color: OcgColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
