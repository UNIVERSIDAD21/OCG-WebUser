import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/before_after_slider.dart';
import '../../../shared/widgets/ocg_skeleton.dart';
import '../../patients/data/models/patient_model.dart';
import '../data/models/simulation_model.dart';
import '../data/repositories/simulation_repository.dart';
import '../providers/simulation_provider.dart';

class SimulatorScreen extends ConsumerStatefulWidget {
  const SimulatorScreen({
    super.key,
    required this.patientId,
    required this.adminId,
    this.treatmentType,
    this.initialSimulation,
    this.embedded = false,
  });

  final String patientId;
  final String adminId;
  final TreatmentType? treatmentType;
  final SimulationModel? initialSimulation;
  final bool embedded;

  @override
  ConsumerState<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends ConsumerState<SimulatorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sim = widget.initialSimulation;
      if (sim != null) {
        ref.read(simulatorFlowProvider.notifier).loadExistingSimulation(sim);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SimulatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.patientId != oldWidget.patientId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(simulatorFlowProvider.notifier).resetFlow();
      });
      return;
    }

    if (widget.initialSimulation?.id != oldWidget.initialSimulation?.id &&
        widget.initialSimulation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(simulatorFlowProvider.notifier)
            .loadExistingSimulation(widget.initialSimulation!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowAsync = ref.watch(simulatorFlowProvider);
    final repo = ref.watch(simulationRepositoryProvider);

    return flowAsync.when(
      loading: () =>
          const OcgSkeletonList(items: 2, cardHeight: 160, showAvatar: false),
      error: (error, _) => _ErrorState(
        message: error.toString(),
        onRetry: () => ref.read(simulatorFlowProvider.notifier).resetFlow(),
      ),
      data: (flow) {
        final showErrorCard = (flow.errorMessage ?? '').trim().isNotEmpty;
        final inPreview = flow.hasOriginal;
        final canGenerate =
            flow.canGenerate && flow.status != SimulationStatus.archived;
        final isGenerating = flow.status == SimulationStatus.generating;
        final canShare =
            flow.status == SimulationStatus.ready && flow.hasResult;
        final canArchive =
            flow.status == SimulationStatus.ready ||
            flow.status == SimulationStatus.shared;
        final treatmentLabel = _treatmentLabel(widget.treatmentType);

        final content = Column(
          key: const ValueKey('simulator-active-flow'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _disclaimer(),
            const SizedBox(height: 12),
            _statusBanner(flow),
            const SizedBox(height: 12),
            if (!inPreview) ...[
              const Text(
                'Paso 1: subir foto original',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: OcgColors.espresso,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tipo de simulación/tratamiento: $treatmentLabel',
                style: const TextStyle(color: OcgColors.ink),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(simulatorFlowProvider.notifier)
                        .pickOriginalFromGallery(
                          patientId: widget.patientId,
                          adminId: widget.adminId,
                          treatmentType: widget.treatmentType,
                        ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Subir foto original'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref
                        .read(simulatorFlowProvider.notifier)
                        .pickOriginalFromCamera(
                          patientId: widget.patientId,
                          adminId: widget.adminId,
                          treatmentType: widget.treatmentType,
                        ),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Usar cámara'),
                  ),
                ],
              ),
            ],
            if (flow.uiState == SimulatorUiState.pickingImage) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text('Preparando foto original...')),
                ],
              ),
            ],
            if (isGenerating) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text('Generando simulación con IA...')),
                ],
              ),
            ],
            if (showErrorCard) ...[
              const SizedBox(height: 12),
              _inlineError(flow.errorMessage!),
            ],
            if (inPreview) ...[
              const SizedBox(height: 12),
              if (flow.hasOriginal && flow.hasResult)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comparación visual',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: OcgColors.espresso,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _BeforeAfterFromStorage(
                      originalPath: flow.originalPath!,
                      resultPath: flow.resultPath!,
                      repository: repo,
                    ),
                  ],
                )
              else
                _StoragePreviewCard(
                  title: 'Imagen original',
                  path: flow.originalPath,
                  emptyLabel: 'Aún no cargada',
                  repository: repo,
                ),
              const SizedBox(height: 12),
              _flowStateHint(flow),
              const SizedBox(height: 12),
              _autoAnalysisHint(flow),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('sim-notes-${flow.simulationId ?? 'new'}'),
                initialValue: flow.notes,
                enabled: !isGenerating,
                onChanged: (value) =>
                    ref.read(simulatorFlowProvider.notifier).setNotes(value),
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas clínicas (opcional)',
                  hintText: 'Observaciones de la simulación orientativa',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (flow.status == SimulationStatus.draft)
                    ElevatedButton.icon(
                      onPressed: !canGenerate || isGenerating
                          ? null
                          : () => ref
                                .read(simulatorFlowProvider.notifier)
                                .generateWithAi(
                                  patientId: widget.patientId,
                                  treatmentType: treatmentLabel,
                                ),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Generar con IA'),
                    ),
                  if (flow.status == SimulationStatus.failed)
                    OutlinedButton.icon(
                      onPressed: isGenerating
                          ? null
                          : () => ref
                                .read(simulatorFlowProvider.notifier)
                                .resetFlow(),
                      icon: const Icon(Icons.photo_camera_back_outlined),
                      label: const Text('Cambiar foto'),
                    ),
                  if (flow.status == SimulationStatus.failed)
                    ElevatedButton.icon(
                      onPressed: !canGenerate || isGenerating
                          ? null
                          : () => ref
                                .read(simulatorFlowProvider.notifier)
                                .generateWithAi(
                                  patientId: widget.patientId,
                                  treatmentType: treatmentLabel,
                                ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar generación'),
                    ),
                  if (flow.status == SimulationStatus.ready)
                    ElevatedButton.icon(
                      onPressed: !canGenerate || isGenerating
                          ? null
                          : () => ref
                                .read(simulatorFlowProvider.notifier)
                                .generateWithAi(
                                  patientId: widget.patientId,
                                  treatmentType: treatmentLabel,
                                ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Regenerar'),
                    ),
                  if (canShare)
                    OutlinedButton.icon(
                      onPressed: isGenerating
                          ? null
                          : () => ref
                                .read(simulatorFlowProvider.notifier)
                                .shareCurrentSimulation(
                                  patientId: widget.patientId,
                                ),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartir con paciente'),
                    ),
                  if (canArchive)
                    OutlinedButton.icon(
                      onPressed: isGenerating
                          ? null
                          : () => ref
                                .read(simulatorFlowProvider.notifier)
                                .archiveCurrentSimulation(
                                  patientId: widget.patientId,
                                ),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archivar'),
                    ),
                ],
              ),
              if (flow.status == SimulationStatus.shared) ...[
                const SizedBox(height: 10),
                const Text(
                  'La simulación ya fue compartida con el paciente.',
                  style: TextStyle(
                    color: OcgColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (flow.status == SimulationStatus.archived) ...[
                const SizedBox(height: 10),
                const Text(
                  'La simulación está archivada y ya no permite nuevas acciones.',
                  style: TextStyle(
                    color: OcgColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ],
        );

        if (widget.embedded) {
          return content;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: content,
        );
      },
    );
  }

  Widget _disclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OcgColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.warning.withOpacity(0.30)),
      ),
      child: const Text(
        'Esta simulación es una referencia visual orientativa para apoyar la explicación del tratamiento. No representa una promesa exacta del resultado final.',
        style: TextStyle(
          color: OcgColors.warning,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusBanner(SimulatorFlowState flow) {
    final text = switch (flow.status) {
      SimulationStatus.draft => 'Estado: Borrador',
      SimulationStatus.generating => 'Estado: Generando',
      SimulationStatus.ready => 'Estado: Lista',
      SimulationStatus.shared => 'Estado: Compartida',
      SimulationStatus.failed => 'Estado: Error',
      SimulationStatus.archived => 'Estado: Archivada',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.sand),
        color: const Color(0xFFF9F5F0),
      ),
      child: Text(
        '$text · Provider: ${flow.generationProvider} · Modelo: ${flow.modelUsed} · Intentos: ${flow.attemptCount}',
        style: const TextStyle(
          color: OcgColors.espresso,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _inlineError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OcgColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.error.withOpacity(0.25)),
      ),
      child: Text(message, style: const TextStyle(color: OcgColors.error)),
    );
  }

  Widget _flowStateHint(SimulatorFlowState flow) {
    final text = switch (flow.status) {
      SimulationStatus.draft => 'Foto lista para generar simulación.',
      SimulationStatus.generating => 'Generando simulación con IA...',
      SimulationStatus.ready => 'Simulación lista para revisión.',
      SimulationStatus.failed =>
        'La simulación falló. Revisa el mensaje y vuelve a intentarlo.',
      SimulationStatus.shared =>
        'Esta simulación ya fue compartida con el paciente.',
      SimulationStatus.archived =>
        'La simulación está archivada y no permite nuevas acciones.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3ED),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: OcgColors.bronze,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _autoAnalysisHint(SimulatorFlowState flow) {
    final message = flow.detectedRegion != null
        ? 'La foto fue analizada automáticamente para orientar la simulación.'
        : 'La simulación puede continuar aunque no se haya detectado una región automática.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.sand),
        color: const Color(0xFFF8F3ED),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: OcgColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _treatmentLabel(TreatmentType? type) {
    if (type == null) return 'No definido';
    switch (type) {
      case TreatmentType.convencional:
        return 'Ortodoncia convencional';
      case TreatmentType.estetico:
        return 'Ortodoncia estética';
      case TreatmentType.autoligado:
        return 'Ortodoncia autoligado';
      case TreatmentType.alineadores:
        return 'Alineadores';
      case TreatmentType.ortopedia:
        return 'Ortopedia';
      case TreatmentType.interceptivo:
        return 'Interceptivo';
      case TreatmentType.retenedores:
        return 'Retenedores';
    }
  }
}

class _StoragePreviewCard extends StatelessWidget {
  const _StoragePreviewCard({
    required this.title,
    required this.path,
    required this.emptyLabel,
    required this.repository,
  });

  final String title;
  final String? path;
  final String emptyLabel;
  final SimulationRepository repository;

  Future<void> _openFullPreview(
    BuildContext context,
    String url,
    String title,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: OcgColors.espresso,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFFF7F3EE),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('No se pudo cargar la imagen.'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 8),
          if ((path ?? '').isEmpty)
            Text(emptyLabel, style: const TextStyle(color: OcgColors.ink))
          else
            FutureBuilder<String?>(
              future: repository.resolveMediaUrl(path),
              builder: (context, snapshot) {
                final previewHeight = MediaQuery.of(context).size.width < 600
                    ? 300.0
                    : 220.0;
                if (!snapshot.hasData) {
                  return OcgSkeletonBox(height: previewHeight, radius: 16);
                }
                final url = snapshot.data;
                if ((url ?? '').isEmpty) {
                  return Text(
                    emptyLabel,
                    style: const TextStyle(color: OcgColors.ink),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _openFullPreview(context, url!, title),
                        icon: const Icon(Icons.open_in_full),
                        label: const Text('Ver foto completa'),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: previewHeight,
                        width: double.infinity,
                        color: const Color(0xFFF7F3EE),
                        child: Image.network(
                          url!,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            height: 120,
                            child: Center(
                              child: Text('No se pudo cargar la imagen.'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BeforeAfterFromStorage extends StatelessWidget {
  const _BeforeAfterFromStorage({
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
        final originalUrl = snapshot.data![0];
        final resultUrl = snapshot.data![1];
        if ((originalUrl ?? '').isEmpty || (resultUrl ?? '').isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('No se pudieron resolver las imágenes.')),
          );
        }
        return BeforeAfterSlider(
          before: Image.network(
            originalUrl!,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
          after: Image.network(
            resultUrl!,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: OcgColors.error),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
