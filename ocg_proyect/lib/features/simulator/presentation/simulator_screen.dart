import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../patients/data/models/patient_model.dart';
import '../providers/simulation_provider.dart';

class SimulatorScreen extends ConsumerWidget {
  const SimulatorScreen({
    super.key,
    required this.patientId,
    required this.adminId,
    this.treatmentType,
  });

  final String patientId;
  final String adminId;
  final TreatmentType? treatmentType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _disclaimer(),
              const SizedBox(height: 12),
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
                      onPressed: () => ref
                          .read(simulatorFlowProvider.notifier)
                          .pickOriginalFromGallery(patientId: patientId, adminId: adminId, treatmentType: treatmentType),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Subir desde galería'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(simulatorFlowProvider.notifier)
                          .pickOriginalFromCamera(patientId: patientId, adminId: adminId, treatmentType: treatmentType),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Usar cámara'),
                    ),
                  ],
                ),
              ],
              if (flow.uiState == SimulatorUiState.waitingManualResult ||
                  flow.uiState == SimulatorUiState.saving ||
                  flow.uiState == SimulatorUiState.saved) ...[
                _previewCard(
                  title: 'Imagen original',
                  imageUrl: flow.originalUrl,
                  emptyLabel: 'Aún no cargada',
                ),
                const SizedBox(height: 12),
                _previewCard(
                  title: 'Imagen resultado manual',
                  imageUrl: flow.resultUrl,
                  emptyLabel: 'Pendiente por cargar',
                ),
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
                          : () => ref
                              .read(simulatorFlowProvider.notifier)
                              .uploadOrReplaceManualResult(patientId: patientId, fromCamera: false),
                      icon: const Icon(Icons.upload_file),
                      label: Text(flow.hasResult ? 'Reemplazar resultado' : 'Subir resultado manual'),
                    ),
                    OutlinedButton.icon(
                      onPressed: flow.uiState == SimulatorUiState.saving
                          ? null
                          : () => ref
                              .read(simulatorFlowProvider.notifier)
                              .uploadOrReplaceManualResult(patientId: patientId, fromCamera: true),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Tomar foto resultado'),
                    ),
                  ],
                ),
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
                      : () => ref.read(simulatorFlowProvider.notifier).saveFinalSimulation(patientId: patientId),
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
