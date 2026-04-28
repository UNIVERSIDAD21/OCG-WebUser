import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/before_after_slider.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../../shared/widgets/ocg_skeleton.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/repositories/simulation_repository.dart';
import '../providers/simulation_provider.dart';
import '../../patients/presentation/patient_viewer_mode.dart';

class PatientSimulationsScreen extends ConsumerWidget {
  const PatientSimulationsScreen({
    super.key,
    this.embedded = false,
    this.patientIdOverride,
    this.viewerMode = PatientViewerMode.patient,
  });

  final bool embedded;
  final String? patientIdOverride;
  final PatientViewerMode viewerMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminViewer = viewerMode == PatientViewerMode.adminViewer;
    final authUid = ref.watch(authStateProvider).asData?.value?.uid ?? '';
    final userId = (patientIdOverride?.isNotEmpty == true) ? patientIdOverride! : authUid;

    final repo = ref.watch(simulationRepositoryProvider);

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
                return Center(
                  child: OcgEmptyState(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Sin simulaciones compartidas',
                    subtitle: isAdminViewer
                        ? 'Cuando se comparta una simulación para este paciente, aparecerá aquí.'
                        : 'Cuando la doctora comparta una simulación, aparecerá aquí.',
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD9C7B3)),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFFFF7EF),
                      ),
                      child: const Text(
                        'Las simulaciones son orientativas y no representan una promesa clínica exacta del resultado final.',
                      ),
                    );
                  }

                  final s = items[i - 1];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Simulación ${_fmtDate(s.createdAt)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Provider: ${s.generationProvider} · Modelo: ${s.modelUsed}'),
                          if ((s.notes ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Notas: ${s.notes!.trim()}'),
                          ],
                          const SizedBox(height: 8),
                          if ((s.originalPath).trim().isNotEmpty && (s.resultPath ?? '').trim().isNotEmpty)
                            _PatientBeforeAfter(
                              originalPath: s.originalPath,
                              resultPath: s.resultPath!,
                              repository: repo,
                            )
                          else
                            Row(
                              children: [
                                Expanded(child: _img(repo, s.originalPath, 'Original')),
                                const SizedBox(width: 8),
                                Expanded(child: _img(repo, s.resultPath ?? '', 'Resultado')),
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

    final decoratedBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 16,
            20,
            14,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2C2016), Color(0xFF8A6F59)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdminViewer ? 'Simulador del paciente' : 'Mis simulaciones',
                style: TextStyle(
                  color: Color(0xFFF8F5F0),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                isAdminViewer
                    ? 'Seguimiento visual del paciente'
                    : 'Compara evolución y resultados compartidos',
                style: TextStyle(
                  color: Color(0xCCF8F5F0),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );

    if (embedded) return decoratedBody;

    return Scaffold(
      appBar: AppBar(title: Text(isAdminViewer ? 'Simulador del paciente' : 'Mis simulaciones')),
      body: decoratedBody,
    );
  }

  Widget _img(SimulationRepository repo, String url, String label) {
    if (url.trim().isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9C7B3))),
        child: Text('$label pendiente'),
      );
    }
    return FutureBuilder<String?>(
      future: repo.resolveMediaUrl(url),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final resolved = snapshot.data ?? '';
        if (resolved.isEmpty) {
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
              resolved,
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
      },
    );
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _PatientBeforeAfter extends StatelessWidget {
  const _PatientBeforeAfter({
    required this.originalPath,
    required this.resultPath,
    required this.repository,
  });

  final String originalPath;
  final String resultPath;
  final SimulationRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String?>>(
      future: Future.wait([
        repository.resolveMediaUrl(originalPath),
        repository.resolveMediaUrl(resultPath),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final before = snapshot.data![0] ?? '';
        final after = snapshot.data![1] ?? '';
        if (before.isEmpty || after.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(child: Text('No se pudieron cargar las imágenes.')),
          );
        }
        return BeforeAfterSlider(
          before: Image.network(before, fit: BoxFit.contain, alignment: Alignment.center),
          after: Image.network(after, fit: BoxFit.contain, alignment: Alignment.center),
        );
      },
    );
  }
}
