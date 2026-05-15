import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/before_after_slider.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../../shared/widgets/ocg_app_bar.dart';
import '../../../shared/widgets/ocg_skeleton.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/models/simulation_model.dart';
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
    final userId = (patientIdOverride?.isNotEmpty == true)
        ? patientIdOverride!
        : authUid;

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
            error: (e, _) =>
                Center(child: Text('No se pudieron cargar simulaciones: $e')),
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
                  final statusColor = _statusColor(s.status);
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withOpacity(0.24)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x102C2016),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _StatusDot(color: statusColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Simulación ${_fmtDate(s.createdAt)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_statusLabel(s.status)} · ${s.generationProvider} · ${s.modelUsed}',
                          ),
                          if ((s.notes ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Notas: ${s.notes!.trim()}'),
                          ],
                          const SizedBox(height: 8),
                          if ((s.originalPath).trim().isNotEmpty &&
                              (s.resultPath ?? '').trim().isNotEmpty)
                            _PatientBeforeAfter(
                              originalPath: s.originalPath,
                              resultPath: s.resultPath!,
                              repository: repo,
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: _img(repo, s.originalPath, 'Original'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _img(
                                    repo,
                                    s.resultPath ?? '',
                                    'Resultado',
                                  ),
                                ),
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
                style: TextStyle(color: Color(0xCCF8F5F0), fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );

    if (embedded) return decoratedBody;

    return Scaffold(
      appBar: OcgAppBar(
        title: isAdminViewer ? 'Simulador del paciente' : 'Mis simulaciones',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: decoratedBody,
    );
  }

  Widget _img(SimulationRepository repo, String url, String label) {
    if (url.trim().isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD9C7B3)),
        ),
        child: Text('$label pendiente'),
      );
    }
    return FutureBuilder<String?>(
      future: repo.resolveMediaUrl(url),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const OcgSkeletonBox(height: 120, radius: 12);
        }
        final resolved = snapshot.data ?? '';
        if (resolved.isEmpty) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD9C7B3)),
            ),
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
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD9C7B3)),
                ),
                child: Text('No se pudo cargar $label'),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(SimulationStatus status) => switch (status) {
    SimulationStatus.draft => OcgColors.bronze,
    SimulationStatus.generating => const Color(0xFF1565C0),
    SimulationStatus.ready => OcgColors.success,
    SimulationStatus.shared => OcgColors.success,
    SimulationStatus.failed => OcgColors.error,
    SimulationStatus.archived => const Color(0xFF6D6D6D),
  };

  String _statusLabel(SimulationStatus status) => switch (status) {
    SimulationStatus.draft => 'Borrador',
    SimulationStatus.generating => 'Generando',
    SimulationStatus.ready => 'Lista',
    SimulationStatus.shared => 'Compartida',
    SimulationStatus.failed => 'Error',
    SimulationStatus.archived => 'Archivada',
  };

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.24),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
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
          return const OcgSkeletonBox(height: 220, radius: 16);
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
          before: Image.network(
            before,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
          after: Image.network(
            after,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        );
      },
    );
  }
}
