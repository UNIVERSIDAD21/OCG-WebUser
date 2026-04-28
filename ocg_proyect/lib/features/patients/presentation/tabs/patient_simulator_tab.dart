import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/providers/auth_providers.dart';
import '../../../../features/simulator/data/models/simulation_model.dart';
import '../../../../features/simulator/presentation/simulator_screen.dart';
import '../../../../features/simulator/providers/simulation_provider.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/utils/ui_formatters.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../../../shared/widgets/ocg_skeleton.dart';
import '../../data/models/patient_model.dart';

class PatientSimulatorTab extends ConsumerStatefulWidget {
  const PatientSimulatorTab({super.key, required this.patient});

  final PatientModel patient;

  @override
  ConsumerState<PatientSimulatorTab> createState() =>
      _PatientSimulatorTabState();
}

class _PatientSimulatorTabState extends ConsumerState<PatientSimulatorTab> {
  SimulationModel? _openedSimulation;

  @override
  void didUpdateWidget(covariant PatientSimulatorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patient.id != widget.patient.id) {
      _openedSimulation = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(simulatorFlowProvider.notifier).resetFlow();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminId = ref.watch(authStateProvider).asData?.value?.uid ?? '';

    if (adminId.isEmpty) {
      return const Center(
        child: OcgEmptyState(
          icon: Icons.lock_outline,
          title: 'Sesión no disponible',
          subtitle: 'Inicia sesión nuevamente para usar el simulador.',
        ),
      );
    }

    final simsAsync = ref.watch(patientSimulationsProvider(widget.patient.id));

    return simsAsync.when(
      loading: () => const OcgSkeletonList(items: 4),
      error: (e, _) =>
          Center(child: Text('No se pudieron cargar simulaciones: $e')),
      data: (items) {
        final latest = items.isEmpty ? null : items.first;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SimulatorMobileHeader(
              patientName: widget.patient.nombre,
              latestSimulation: latest,
              onNew: () {
                setState(() => _openedSimulation = null);
                ref.read(simulatorFlowProvider.notifier).resetFlow();
              },
            ),
            const SizedBox(height: 14),
            _SimulatorPrimaryActionsCard(
              hasSimulations: items.isNotEmpty,
              onCamera: () {
                setState(() => _openedSimulation = null);
                ref.read(simulatorFlowProvider.notifier).resetFlow();
                ref.read(simulatorFlowProvider.notifier).pickOriginalFromCamera(
                  patientId: widget.patient.id,
                  adminId: adminId,
                  treatmentType: widget.patient.tipoTratamiento,
                );
              },
              onGallery: () {
                setState(() => _openedSimulation = null);
                ref.read(simulatorFlowProvider.notifier).resetFlow();
                ref.read(simulatorFlowProvider.notifier).pickOriginalFromGallery(
                  patientId: widget.patient.id,
                  adminId: adminId,
                  treatmentType: widget.patient.tipoTratamiento,
                );
              },
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const OcgEmptyState(
                icon: Icons.auto_awesome_outlined,
                title: 'Todavía no hay simulaciones para este paciente.',
                subtitle: 'Toma una foto frontal o súbela desde galería para iniciar una simulación.',
              )
            else ...[
              const Text(
                'Historial de simulaciones',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OcgColors.espresso,
                ),
              ),
              const SizedBox(height: 10),
              ...items.map(
                (s) => _AdminSimulationCard(
                  simulation: s,
                  onOpen: () {
                    setState(() => _openedSimulation = s);
                  },
                  onToggleShare: (value) async {
                    try {
                      await ref
                          .read(simulationRepositoryProvider)
                          .unshareSimulationWithPatient(
                            widget.patient.id,
                            s.id,
                          );
                      if (value) {
                        await ref
                            .read(simulationRepositoryProvider)
                            .shareSimulationWithPatient(
                              widget.patient.id,
                              s.id,
                            );
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Simulación compartida con paciente.'
                                : 'Simulación descompartida correctamente.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'No se pudo actualizar el estado de compartir: $e',
                          ),
                        ),
                      );
                    }
                  },
                  onDelete: () async {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar simulación'),
                        content: const Text(
                          '¿Seguro que deseas eliminar esta simulación? Esta acción no se puede deshacer.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );

                    if (confirmar != true) return;

                    try {
                      await ref
                          .read(simulationRepositoryProvider)
                          .deleteSimulation(
                            patientId: widget.patient.id,
                            simulationId: s.id,
                          );

                      if (_openedSimulation?.id == s.id) {
                        setState(() => _openedSimulation = null);
                        ref.read(simulatorFlowProvider.notifier).resetFlow();
                      }

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Simulación eliminada correctamente.'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'No se pudo eliminar la simulación: $e',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            SimulatorScreen(
              patientId: widget.patient.id,
              adminId: adminId,
              treatmentType: widget.patient.tipoTratamiento,
              initialSimulation: _openedSimulation,
            ),
          ],
        );
      },
    );
  }
}

class _SimulatorMobileHeader extends StatelessWidget {
  const _SimulatorMobileHeader({
    required this.patientName,
    required this.latestSimulation,
    required this.onNew,
  });

  final String patientName;
  final SimulationModel? latestSimulation;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8DED2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Simulador de sonrisa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: OcgColors.espresso,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add),
                label: const Text('Nueva simulación'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            patientName,
            style: const TextStyle(
              color: OcgColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latestSimulation == null
                ? 'Crea una simulación de sonrisa a partir de una foto del paciente.'
                : 'Estado más reciente: ${formatSimulationStatus(latestSimulation!.status)}',
            style: const TextStyle(color: OcgColors.bronze),
          ),
        ],
      ),
    );
  }
}

class _SimulatorPrimaryActionsCard extends StatelessWidget {
  const _SimulatorPrimaryActionsCard({
    required this.hasSimulations,
    required this.onCamera,
    required this.onGallery,
  });

  final bool hasSimulations;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8DED2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acción principal',
            style: TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSimulations
                ? 'Toma una nueva foto o sube otra desde galería para crear una nueva simulación.'
                : 'Toma una foto frontal del paciente para iniciar la simulación.',
            style: const TextStyle(color: OcgColors.ink),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Tomar foto'),
              ),
              OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Subir desde galería'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminSimulationCard extends StatelessWidget {
  const _AdminSimulationCard({
    required this.simulation,
    required this.onOpen,
    required this.onToggleShare,
    required this.onDelete,
  });

  final SimulationModel simulation;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggleShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Creada: ${_fmtDate(simulation.createdAt)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(label: Text(formatSimulationStatus(simulation.status))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Provider: ${simulation.generationProvider} · Modelo: ${simulation.modelUsed}',
            ),
            if ((simulation.notes ?? '').trim().isNotEmpty)
              Text('Notas: ${simulation.notes!.trim()}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Eliminar simulación',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: OcgColors.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compartir'),
                    value: simulation.compartidaConPaciente,
                    onChanged:
                        (simulation.status == SimulationStatus.draft ||
                            simulation.status == SimulationStatus.archived)
                        ? null
                        : onToggleShare,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
