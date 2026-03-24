import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/before_after_slider.dart';
import '../../patients/data/models/patient_model.dart';
import '../data/models/simulation_model.dart';
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
    if (widget.initialSimulation?.id != oldWidget.initialSimulation?.id && widget.initialSimulation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(simulatorFlowProvider.notifier).loadExistingSimulation(widget.initialSimulation!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowAsync = ref.watch(simulatorFlowProvider);

    return flowAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: error.toString(),
        onRetry: () => ref.read(simulatorFlowProvider.notifier).resetFlow(),
      ),
      data: (flow) {
        if (flow.uiState == SimulatorUiState.error) {
          return _ErrorState(
            message: flow.errorMessage ?? 'No se pudo completar la operación.',
            onRetry: () => ref.read(simulatorFlowProvider.notifier).resetFlow(),
          );
        }

        final inPreview = flow.uiState == SimulatorUiState.previewReady ||
            flow.uiState == SimulatorUiState.saving ||
            flow.uiState == SimulatorUiState.saved ||
            flow.uiState == SimulatorUiState.generatingMock;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _disclaimer(),
              const SizedBox(height: 12),
              SegmentedButton<SimulationMode>(
                segments: const [
                  ButtonSegment(
                    value: SimulationMode.manualDoctora,
                    icon: Icon(Icons.edit_outlined),
                    label: Text('Manual doctora'),
                  ),
                  ButtonSegment(
                    value: SimulationMode.mock,
                    icon: Icon(Icons.auto_awesome_outlined),
                    label: Text('Mock interno'),
                  ),
                ],
                selected: {flow.selectedMode},
                onSelectionChanged: (sel) {
                  ref.read(simulatorFlowProvider.notifier).setMode(sel.first);
                },
              ),
              const SizedBox(height: 10),
              if (flow.uiState == SimulatorUiState.idle) ...[
                const Text(
                  'Paso 1: carga imagen original',
                  style: TextStyle(fontWeight: FontWeight.w700, color: OcgColors.espresso),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => ref.read(simulatorFlowProvider.notifier).pickOriginalFromGallery(
                            patientId: widget.patientId,
                            adminId: widget.adminId,
                            treatmentType: widget.treatmentType,
                          ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Subir desde galería'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ref.read(simulatorFlowProvider.notifier).pickOriginalFromCamera(
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
              if (flow.uiState == SimulatorUiState.generatingMock) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Generando simulación mock orientativa...'),
                    ),
                  ],
                ),
              ],
              if (inPreview) ...[
                const SizedBox(height: 12),
                if (flow.hasOriginal && flow.hasResult)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comparación visual',
                        style: TextStyle(fontWeight: FontWeight.w700, color: OcgColors.espresso),
                      ),
                      const SizedBox(height: 8),
                      BeforeAfterSlider(
                        before: Image.network(flow.originalUrl!, fit: BoxFit.cover),
                        after: Image.network(flow.resultUrl!, fit: BoxFit.cover),
                      ),
                    ],
                  )
                else ...[
                  _previewCard(
                    title: 'Imagen original',
                    imageUrl: flow.originalUrl,
                    emptyLabel: 'Aún no cargada',
                  ),
                  const SizedBox(height: 12),
                  _previewCard(
                    title: 'Imagen resultado',
                    imageUrl: flow.resultUrl,
                    emptyLabel: flow.selectedMode == SimulationMode.mock
                        ? 'Pendiente de generación mock'
                        : 'Pendiente por cargar manualmente',
                  ),
                ],
                if (flow.selectedMode == SimulationMode.manualDoctora) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Paso 2: carga o reemplaza imagen resultado manual',
                    style: TextStyle(fontWeight: FontWeight.w700, color: OcgColors.espresso),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: flow.uiState == SimulatorUiState.saving
                            ? null
                            : () => ref.read(simulatorFlowProvider.notifier).uploadOrReplaceManualResult(
                                  patientId: widget.patientId,
                                  fromCamera: false,
                                ),
                        icon: const Icon(Icons.upload_file),
                        label: Text(flow.hasResult ? 'Reemplazar resultado' : 'Subir resultado manual'),
                      ),
                      OutlinedButton.icon(
                        onPressed: flow.uiState == SimulatorUiState.saving
                            ? null
                            : () => ref.read(simulatorFlowProvider.notifier).uploadOrReplaceManualResult(
                                  patientId: widget.patientId,
                                  fromCamera: true,
                                ),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Tomar foto resultado'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _regionCard(flow),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Compartir con paciente al guardar'),
                  value: flow.shareWithPatient,
                  onChanged: flow.uiState == SimulatorUiState.saving
                      ? null
                      : (value) => ref.read(simulatorFlowProvider.notifier).setShareWithPatient(value),
                  contentPadding: EdgeInsets.zero,
                ),
                TextFormField(
                  initialValue: flow.notes,
                  enabled: flow.uiState != SimulatorUiState.saving,
                  onChanged: (value) => ref.read(simulatorFlowProvider.notifier).setNotes(value),
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas clínicas (opcional)',
                    hintText: 'Observaciones de la simulación orientativa',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: (!flow.hasResult || flow.uiState == SimulatorUiState.saving)
                      ? null
                      : () => ref.read(simulatorFlowProvider.notifier).saveFinalSimulation(patientId: widget.patientId),
                  icon: flow.uiState == SimulatorUiState.saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: OcgColors.ivory),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(flow.uiState == SimulatorUiState.saved ? 'Guardado' : 'Guardar simulación final'),
                ),
                if (flow.uiState == SimulatorUiState.saved) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Simulación guardada correctamente.',
                    style: TextStyle(color: OcgColors.success, fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () => ref.read(simulatorFlowProvider.notifier).resetFlow(),
                    child: const Text('Crear nueva simulación'),
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
        'Esta simulación es orientativa y no representa una promesa clínica exacta de resultado final.',
        style: TextStyle(
          color: OcgColors.warning,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
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
            onPressed: () => _openAdjustRegionDialog(flow),
            icon: const Icon(Icons.tune),
            label: const Text('Ajustar región manualmente'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAdjustRegionDialog(SimulatorFlowState flow) async {
    final region = flow.detectedRegion ?? {'x': 0.0, 'y': 0.0, 'w': 0.0, 'h': 0.0};

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
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Guardar')),
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
        Slider(value: value.clamp(0, 4000), min: 0, max: 4000, onChanged: onChanged),
      ],
    );
  }

  Widget _previewCard({
    required String title,
    required String? imageUrl,
    required String emptyLabel,
  }) {
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: OcgColors.espresso)),
          const SizedBox(height: 8),
          if ((imageUrl ?? '').isEmpty)
            Text(emptyLabel, style: const TextStyle(color: OcgColors.ink))
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 120,
                  child: Center(child: Text('No se pudo cargar la imagen.')),
                ),
              ),
            ),
        ],
      ),
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
