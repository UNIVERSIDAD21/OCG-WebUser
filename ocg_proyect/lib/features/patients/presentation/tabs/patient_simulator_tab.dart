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
  const PatientSimulatorTab({
    super.key,
    required this.patient,
    this.scrollable = true,
  });

  final PatientModel patient;
  final bool scrollable;

  @override
  ConsumerState<PatientSimulatorTab> createState() =>
      _PatientSimulatorTabState();
}

class _PatientSimulatorTabState extends ConsumerState<PatientSimulatorTab> {
  SimulationModel? _openedSimulation;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _activeFlowKey = GlobalKey();
  ProviderSubscription<AsyncValue<SimulatorFlowState>>? _flowSubscription;

  @override
  void initState() {
    super.initState();
    _flowSubscription = ref.listenManual(simulatorFlowProvider, (
      previous,
      next,
    ) {
      final prev = previous?.asData?.value;
      final curr = next.asData?.value;
      if (curr == null) return;

      final justPreparedDraft =
          prev?.uiState != SimulatorUiState.draftReady &&
          curr.uiState == SimulatorUiState.draftReady &&
          curr.hasOriginal;

      if (!justPreparedDraft || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto cargada correctamente. Revisa el borrador y continúa con Generar con IA.',
          ),
        ),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) => _focusActiveFlow());
    });
  }

  @override
  void dispose() {
    _flowSubscription?.close();
    _scrollController.dispose();
    super.dispose();
  }

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

  void _focusActiveFlow() {
    final context = _activeFlowKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
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
    final flow = ref.watch(simulatorFlowProvider).asData?.value;

    return simsAsync.when(
      loading: () => const OcgSkeletonList(items: 4),
      error: (e, _) =>
          Center(child: Text('No se pudieron cargar simulaciones: $e')),
      data: (items) {
        final latest = items.isEmpty ? null : items.first;
        final showActiveFlow = shouldPrioritizeActiveSimulation(
          flow: flow,
          openedSimulation: _openedSimulation,
        );
        return ListView(
          controller: widget.scrollable ? _scrollController : null,
          shrinkWrap: !widget.scrollable,
          physics: widget.scrollable
              ? null
              : const NeverScrollableScrollPhysics(),
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
                ref
                    .read(simulatorFlowProvider.notifier)
                    .pickOriginalFromCamera(
                      patientId: widget.patient.id,
                      adminId: adminId,
                      treatmentType: widget.patient.tipoTratamiento,
                    );
              },
              onGallery: () {
                setState(() => _openedSimulation = null);
                ref.read(simulatorFlowProvider.notifier).resetFlow();
                ref
                    .read(simulatorFlowProvider.notifier)
                    .pickOriginalFromGallery(
                      patientId: widget.patient.id,
                      adminId: adminId,
                      treatmentType: widget.patient.tipoTratamiento,
                    );
              },
            ),
            const SizedBox(height: 14),
            if (showActiveFlow) ...[
              Container(
                key: _activeFlowKey,
                child: SimulatorScreen(
                  patientId: widget.patient.id,
                  adminId: adminId,
                  treatmentType: widget.patient.tipoTratamiento,
                  initialSimulation: _openedSimulation,
                  embedded: true,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (items.isEmpty && !showActiveFlow)
              _SimulatorEmptyState(
                onCamera: () {
                  setState(() => _openedSimulation = null);
                  ref.read(simulatorFlowProvider.notifier).resetFlow();
                  ref
                      .read(simulatorFlowProvider.notifier)
                      .pickOriginalFromCamera(
                        patientId: widget.patient.id,
                        adminId: adminId,
                        treatmentType: widget.patient.tipoTratamiento,
                      );
                },
              )
            else if (items.isNotEmpty) ...[
              const Text(
                'Historial de simulaciones',
                key: ValueKey('simulation-history-title'),
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
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _focusActiveFlow(),
                    );
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3527), Color(0xFF9A7654)],
        ),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.ivory.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: OcgColors.ivory.withOpacity(0.20)),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: OcgColors.ivory,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Simulador de sonrisa',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: OcgColors.ivory,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Paciente: $patientName',
                      style: TextStyle(
                        color: OcgColors.ivory.withOpacity(0.82),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OcgColors.ivory.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: OcgColors.ivory.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestSimulation == null
                            ? 'Aún sin simulaciones'
                            : 'Última simulación: ${formatSimulationStatus(latestSimulation!.status)}',
                        style: const TextStyle(
                          color: OcgColors.ivory,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latestSimulation == null
                            ? 'Crea una referencia visual desde una foto frontal.'
                            : 'Creada el ${_fmtDate(latestSimulation!.createdAt)}',
                        style: TextStyle(
                          color: OcgColors.ivory.withOpacity(0.78),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: onNew,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva'),
                  style: FilledButton.styleFrom(
                    backgroundColor: OcgColors.ivory,
                    foregroundColor: OcgColors.espresso,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nueva simulación',
            style: TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSimulations
                ? 'Crea una nueva comparación con una foto actualizada del paciente.'
                : 'Inicia con una foto frontal bien iluminada para generar la referencia visual.',
            style: const TextStyle(color: OcgColors.bronze, height: 1.3),
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Tomar foto'),
                  style: FilledButton.styleFrom(
                    backgroundColor: OcgColors.espresso,
                    foregroundColor: OcgColors.ivory,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Subir desde galería'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OcgColors.espresso,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: OcgColors.bronze.withOpacity(0.28)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimulatorEmptyState extends StatelessWidget {
  const _SimulatorEmptyState({required this.onCamera});

  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: OcgColors.ivory,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              color: OcgColors.espresso,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aún no hay simulaciones',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OcgColors.espresso,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toma una foto frontal del paciente o sube una imagen desde galería para iniciar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: OcgColors.bronze, height: 1.3),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCamera,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Tomar foto'),
            style: FilledButton.styleFrom(
              backgroundColor: OcgColors.espresso,
              foregroundColor: OcgColors.ivory,
            ),
          ),
        ],
      ),
    );
  }
}

bool shouldPrioritizeActiveSimulation({
  required SimulatorFlowState? flow,
  required SimulationModel? openedSimulation,
}) {
  if (openedSimulation != null) return true;
  if (flow == null) return false;
  return flow.hasOriginal ||
      flow.status == SimulationStatus.generating ||
      flow.status == SimulationStatus.ready ||
      flow.status == SimulationStatus.shared ||
      flow.status == SimulationStatus.failed;
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
    final canShare =
        simulation.status != SimulationStatus.draft &&
        simulation.status != SimulationStatus.archived;
    final statusColor = _statusColor(simulation.status);
    final previewPath = _previewPath(simulation);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SimulationPreview(path: previewPath),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtDate(simulation.createdAt),
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SimulationChip(
                          label: formatSimulationStatus(simulation.status),
                          color: statusColor,
                        ),
                        if (simulation.compartidaConPaciente)
                          const _SimulationChip(
                            label: 'Compartida',
                            color: Color(0xFF2E7D32),
                          ),
                      ],
                    ),
                    if ((simulation.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        simulation.notes!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: OcgColors.bronze,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Abrir'),
                  style: FilledButton.styleFrom(
                    backgroundColor: OcgColors.espresso,
                    foregroundColor: OcgColors.ivory,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: simulation.compartidaConPaciente
                    ? 'Descompartir con paciente'
                    : 'Compartir con paciente',
                onPressed: canShare
                    ? () => onToggleShare(!simulation.compartidaConPaciente)
                    : null,
                icon: Icon(
                  simulation.compartidaConPaciente
                      ? Icons.person_remove_outlined
                      : Icons.ios_share_outlined,
                  size: 20,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Eliminar simulación',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: OcgColors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            canShare
                ? (simulation.compartidaConPaciente
                      ? 'Visible para el paciente.'
                      : 'Lista para compartir cuando el resultado esté revisado.')
                : 'Compartir no disponible en borradores o archivadas.',
            style: const TextStyle(
              color: OcgColors.bronze,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimulationPreview extends ConsumerWidget {
  const _SimulationPreview({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanPath = path?.trim();
    final placeholder = Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFFF6EFE7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: OcgColors.bronze,
        size: 28,
      ),
    );

    if (cleanPath == null || cleanPath.isEmpty) return placeholder;

    return FutureBuilder<String?>(
      future: ref.read(simulationRepositoryProvider).resolveMediaUrl(cleanPath),
      builder: (context, snapshot) {
        final url = snapshot.data?.trim();
        if (url == null || url.isEmpty) return placeholder;
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            url,
            width: 74,
            height: 74,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        );
      },
    );
  }
}

class _SimulationChip extends StatelessWidget {
  const _SimulationChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String? _previewPath(SimulationModel simulation) {
  final result = simulation.resultPath?.trim();
  if (result != null && result.isNotEmpty) return result;
  final original = simulation.originalPath.trim();
  if (original.isNotEmpty) return original;
  return null;
}

Color _statusColor(SimulationStatus status) => switch (status) {
  SimulationStatus.draft => OcgColors.bronze,
  SimulationStatus.generating => const Color(0xFF1565C0),
  SimulationStatus.ready => const Color(0xFF2E7D32),
  SimulationStatus.shared => const Color(0xFF2E7D32),
  SimulationStatus.failed => OcgColors.error,
  SimulationStatus.archived => const Color(0xFF6D6D6D),
};

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
