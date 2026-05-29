import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/before_after_fullscreen_viewer.dart';
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
                        'Las simulaciones son orientativas y no representan'
                        ' una promesa clínica exacta del resultado final.',
                        style: TextStyle(fontSize: 13),
                      ),
                    );
                  }

                  final s = items[i - 1];
                  return _PatientSimulationCard(
                    simulation: s,
                    repository: repo,
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
                style: const TextStyle(
                  color: Color(0xFFF8F5F0),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isAdminViewer
                    ? 'Seguimiento visual del paciente'
                    : 'Compara evolución y resultados compartidos',
                style: const TextStyle(color: Color(0xCCF8F5F0), fontSize: 13),
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
}

class _PatientSimulationCard extends StatelessWidget {
  const _PatientSimulationCard({
    required this.simulation,
    required this.repository,
  });

  final SimulationModel simulation;
  final SimulationRepository repository;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OcgColors.success.withOpacity(0.24)),
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
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: OcgColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: OcgColors.success.withOpacity(0.24),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Simulación de sonrisa · ${_fmtDate(simulation.createdAt)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Simulación compartida por tu doctora.',
              style: TextStyle(color: OcgColors.bronze, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if ((simulation.originalPath).trim().isNotEmpty &&
                (simulation.resultPath ?? '').trim().isNotEmpty)
              _PatientBeforeAfter(
                key: ValueKey(
                  'patient-ba-${simulation.id}-${simulation.attemptCount}-${simulation.resultPath}',
                ),
                originalPath: simulation.originalPath,
                resultPath: simulation.resultPath!,
                repository: repository,
                cacheVersion: simulation.attemptCount.toString(),
              )
            else
              const SizedBox(
                height: 120,
                child: Center(child: Text('Imágenes no disponibles')),
              ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _PatientBeforeAfter extends StatelessWidget {
  const _PatientBeforeAfter({
    super.key,
    required this.originalPath,
    required this.resultPath,
    required this.repository,
    required this.cacheVersion,
  });

  final String originalPath;
  final String resultPath;
  final SimulationRepository repository;
  final String cacheVersion;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String?>>(
      future: Future.wait([
        repository.resolveMediaUrl(originalPath),
        repository.resolveMediaUrl(resultPath, cacheVersion: cacheVersion),
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
        return BeforeAfterFullscreenViewer(beforeUrl: before, afterUrl: after);
      },
    );
  }
}
