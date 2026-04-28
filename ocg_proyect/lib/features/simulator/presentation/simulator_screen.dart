import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/before_after_slider.dart';
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
  });

  final String patientId;
  final String adminId;
  final TreatmentType? treatmentType;
  final SimulationModel? initialSimulation;

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
        ref.read(simulatorFlowProvider.notifier).loadExistingSimulation(
              widget.initialSimulation!,
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowAsync = ref.watch(simulatorFlowProvider);
    final repo = ref.watch(simulationRepositoryProvider);

    return flowAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: error.toString(),
        onRetry: () => ref.read(simulatorFlowProvider.notifier).resetFlow(),
      ),
      data: (flow) {
        final showErrorCard = (flow.errorMessage ?? '').trim().isNotEmpty;
        final inPreview = flow.hasOriginal;
        final canGenerate = flow.canGenerate && flow.status != SimulationStatus.archived;
        final isGenerating = flow.status == SimulationStatus.generating;
        final canShare = flow.status == SimulationStatus.ready && flow.hasResult;
        final canArchive =
            flow.status == SimulationStatus.ready || flow.status == SimulationStatus.shared;
        final treatmentLabel = _treatmentLabel(widget.treatmentType);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
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
                    Expanded(child: Text('Procesando imagen original...')),
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
                    Expanded(
                      child: Text('Generando simulación con IA...'),
                    ),
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
                _regionCard(flow),
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
                                  .shareCurrentSimulation(patientId: widget.patientId),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Compartir con paciente'),
                      ),
                    if (canArchive)
                      OutlinedButton.icon(
                        onPressed: isGenerating
                            ? null
                            : () => ref
                                  .read(simulatorFlowProvider.notifier)
                                  .archiveCurrentSimulation(patientId: widget.patientId),
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
          ),
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

  Widget _regionCard(SimulatorFlowState flow) {
    final region = flow.detectedRegion;
    if (region == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OcgColors.sand),
        ),
        child: const Text(
          'No se detectó región facial automáticamente. Puedes continuar y ajustar manualmente si lo deseas.',
          style: TextStyle(color: OcgColors.ink),
        ),
      );
    }

    String f(num? v) => (v ?? 0).toStringAsFixed(1);

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
            flow.mlKitUsed
                ? 'Región sugerida por ML Kit · x:${f(region['x'] as num?)} y:${f(region['y'] as num?)} w:${f(region['w'] as num?)} h:${f(region['h'] as num?)}'
                : 'Región cargada manualmente · x:${f(region['x'] as num?)} y:${f(region['y'] as num?)} w:${f(region['w'] as num?)} h:${f(region['h'] as num?)}',
            style: const TextStyle(color: OcgColors.ink, fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: flow.status == SimulationStatus.generating ||
                    flow.status == SimulationStatus.archived
                ? null
                : () => _openAdjustRegionDialog(flow),
            icon: const Icon(Icons.tune),
            label: const Text('Ajustar región manualmente'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAdjustRegionDialog(SimulatorFlowState flow) async {
    final region =
        flow.detectedRegion ?? {'x': 0.0, 'y': 0.0, 'w': 0.0, 'h': 0.0};

    double x = (region['x'] as num?)?.toDouble() ?? 0;
    double y = (region['y'] as num?)?.toDouble() ?? 0;
    double w = (region['w'] as num?)?.toDouble() ?? 0;
    double h = (region['h'] as num?)?.toDouble() ?? 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Ajustar región sugerida'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _slider('X', x, (v) => setSt(() => x = v)),
                _slider('Y', y, (v) => setSt(() => y = v)),
                _slider('W', w, (v) => setSt(() => w = v)),
                _slider('H', h, (v) => setSt(() => h = v)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    await ref.read(simulatorFlowProvider.notifier).updateDetectedRegion(
          patientId: widget.patientId,
          x: x,
          y: y,
          w: w,
          h: h,
        );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)}'),
        Slider(
          value: value.clamp(0, 4000),
          min: 0,
          max: 4000,
          onChanged: onChanged,
        ),
      ],
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
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final url = snapshot.data;
                if ((url ?? '').isEmpty) {
                  return Text(emptyLabel, style: const TextStyle(color: OcgColors.ink));
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 220,
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
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
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
