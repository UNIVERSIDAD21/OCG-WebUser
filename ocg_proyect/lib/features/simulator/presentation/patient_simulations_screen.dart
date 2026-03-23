import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/before_after_slider.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
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
            loading: () => const Center(child: CircularProgressIndicator()),
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
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final s = items[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Simulación ${_fmtDate(s.createdAt)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Origen: ${s.mode.name}'),
                          if ((s.notes ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Notas: ${s.notes!.trim()}'),
                          ],
                          const SizedBox(height: 8),
                          if ((s.originalUrl).trim().isNotEmpty && (s.resultUrl ?? '').trim().isNotEmpty)
                            BeforeAfterSlider(
                              before: Image.network(s.originalUrl, fit: BoxFit.cover),
                              after: Image.network(s.resultUrl!, fit: BoxFit.cover),
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
                    ),
                  );
                },
              );
            },
          );
    }

    if (embedded) return body;

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
      child: Image.network(
        url,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9C7B3))),
          child: Text('No se pudo cargar $label'),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
