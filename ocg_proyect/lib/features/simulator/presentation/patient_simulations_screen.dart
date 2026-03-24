import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/widgets/before_after_slider.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../patient/presentation/web/shell/patient_web_shell.dart';
import '../../patient/presentation/web/components/simulation_preview_card.dart';
import '../../patient/presentation/web/components/highlight_card.dart';
import '../../../shared/widgets/ocg_skeleton.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/simulation_provider.dart';

class PatientSimulationsScreen extends ConsumerWidget {
  const PatientSimulationsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider).asData?.value?.uid ?? '';

    Widget body;
    if (userId.isEmpty) {
      body = const Center(
        child: OcgEmptyState(
          icon: Icons.person_off_outlined,
          title: 'No se pudo cargar tu perfil',
        ),
      );
    } else {
      body = ref
          .watch(sharedSimulationsProvider(userId))
          .when(
            loading: () => const OcgSkeletonList(items: 3),
            error: (e, _) => Center(child: Text('No se pudieron cargar simulaciones: $e')),
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: OcgEmptyState(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Sin simulaciones compartidas',
                    subtitle: 'Cuando la doctora comparta una simulación, aparecerá aquí.',
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return const HighlightCard(
                      title: 'Aviso importante',
                      child: Text(
                        'Las simulaciones son orientativas y no representan una promesa clínica exacta del resultado final.',
                      ),
                    );
                  }

                  final s = items[i - 1];
                  return SimulationPreviewCard(
                    title: 'Simulación ${_fmtDate(s.createdAt)}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Origen: ${formatSimulationMode(s.mode)}'),
                        if ((s.notes ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Notas: ${s.notes!.trim()}'),
                        ],
                        const SizedBox(height: 8),
                        if ((s.originalUrl).trim().isNotEmpty && (s.resultUrl ?? '').trim().isNotEmpty)
                          BeforeAfterSlider(
                            before: Image.network(
                              s.originalUrl,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                            ),
                            after: Image.network(
                              s.resultUrl!,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(child: _img(s.originalUrl, 'Original')),
                              const SizedBox(width: 8),
                              Expanded(child: _img(s.resultUrl ?? '', 'Resultado')),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
    }

    if (embedded) return body;

    if (WebLayoutContext.useDesktopShell(context)) {
      return PatientWebShell(
        currentRoute: RouteNames.patientSimulations,
        title: 'Mis simulaciones',
        child: body,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis simulaciones')),
      body: body,
    );
  }

  Widget _img(String url, String label) {
    if (url.trim().isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9C7B3))),
        child: Text('$label pendiente'),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 120,
        color: const Color(0xFFF7F3EE),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9C7B3))),
            child: Text('No se pudo cargar $label'),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
