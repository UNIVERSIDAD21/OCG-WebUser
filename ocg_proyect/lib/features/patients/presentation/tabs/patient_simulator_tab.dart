import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/providers/auth_providers.dart';
import '../../../../features/simulator/data/models/simulation_model.dart';
import '../../../../features/simulator/presentation/simulator_screen.dart';
import '../../../../features/simulator/providers/simulation_provider.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../data/models/patient_model.dart';

class PatientSimulatorTab extends ConsumerStatefulWidget {
  const PatientSimulatorTab({super.key, required this.patient});

  final PatientModel patient;

  @override
  ConsumerState<PatientSimulatorTab> createState() => _PatientSimulatorTabState();
}

class _PatientSimulatorTabState extends ConsumerState<PatientSimulatorTab> {
  SimulationModel? _openedSimulation;

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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('No se pudieron cargar simulaciones: $e')),
      data: (items) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Simulador de sonrisa',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: OcgColors.espresso),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _openedSimulation = null);
                    ref.read(simulatorFlowProvider.notifier).resetFlow();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'La simulación es orientativa y no representa una promesa clínica exacta.',
              style: TextStyle(color: OcgColors.ink),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const OcgEmptyState(
                icon: Icons.auto_awesome_outlined,
                title: 'Sin simulaciones todavía',
                subtitle: 'Crea la primera simulación para este paciente.',
              )
            else
              ...items.map((s) => _AdminSimulationCard(
                    simulation: s,
                    onOpen: () {
                      setState(() => _openedSimulation = s);
                    },
                    onToggleShare: (value) async {
                      await ref.read(simulationRepositoryProvider).toggleShare(
                            patientId: widget.patient.id,
                            simulationId: s.id,
                            compartida: value,
                          );
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
                        await ref.read(simulationRepositoryProvider).deleteSimulation(
                              patientId: widget.patient.id,
                              simulationId: s.id,
                            );

                        if (_openedSimulation?.id == s.id) {
                          setState(() => _openedSimulation = null);
                          ref.read(simulatorFlowProvider.notifier).resetFlow();
                        }

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Simulación eliminada correctamente.')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('No se pudo eliminar la simulación: $e')),
                        );
                      }
                    },
                  )),
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
                Chip(label: Text(_statusLabel(simulation.status))),
              ],
            ),
            const SizedBox(height: 4),
            Text('Origen: ${_modeLabel(simulation.mode)}'),
            if ((simulation.notes ?? '').trim().isNotEmpty) Text('Notas: ${simulation.notes!.trim()}'),
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
                  icon: const Icon(Icons.delete_outline, color: OcgColors.error),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compartir'),
                    value: simulation.compartidaConPaciente,
                    onChanged: (simulation.status == SimulationStatus.draft || simulation.status == SimulationStatus.archived)
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

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _statusLabel(SimulationStatus s) {
    switch (s) {
      case SimulationStatus.draft:
        return 'Borrador';
      case SimulationStatus.ready:
        return 'Lista';
      case SimulationStatus.shared:
        return 'Compartida';
      case SimulationStatus.archived:
        return 'Archivada';
    }
  }

  String _modeLabel(SimulationMode m) {
    switch (m) {
      case SimulationMode.mock:
        return 'Mock interno';
      case SimulationMode.manualDoctora:
        return 'Manual doctora';
    }
  }
}
