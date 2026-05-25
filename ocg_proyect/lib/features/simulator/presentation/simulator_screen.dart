import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/before_after_slider.dart';
import '../../../shared/widgets/ocg_skeleton.dart';
import '../../patients/data/models/patient_model.dart';
import '../data/models/simulation_model.dart';
import '../data/repositories/simulation_repository.dart';
import '../domain/dental_treatment_profile.dart';
import '../providers/simulation_provider.dart';
import 'widgets/doctor_config_form.dart';
import 'widgets/treatment_profile_selector.dart';

class SimulatorScreen extends ConsumerStatefulWidget {
  const SimulatorScreen({
    super.key,
    required this.patientId,
    required this.adminId,
    this.treatmentType,
    this.initialSimulation,
    this.embedded = false,
    this.autoSelectProfile = false,
  });

  final String patientId;
  final String adminId;
  final TreatmentType? treatmentType;
  final SimulationModel? initialSimulation;
  final bool embedded;

  /// If true, auto-selects the default profile from [treatmentType] on first build.
  final bool autoSelectProfile;

  @override
  ConsumerState<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends ConsumerState<SimulatorScreen> {
  bool _profileAutoSelected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sim = widget.initialSimulation;
      if (sim != null) {
        ref
            .read(simulatorFlowProvider.notifier)
            .loadExistingSimulation(sim);
      } else if (widget.autoSelectProfile && !_profileAutoSelected) {
        _autoSelectDefaultProfile();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SimulatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.patientId != oldWidget.patientId) {
      _profileAutoSelected = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(simulatorFlowProvider.notifier).resetFlow();
        if (widget.autoSelectProfile) {
          _autoSelectDefaultProfile();
        }
      });
      return;
    }

    if (widget.initialSimulation?.id !=
            oldWidget.initialSimulation?.id &&
        widget.initialSimulation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(simulatorFlowProvider.notifier)
            .loadExistingSimulation(widget.initialSimulation!);
      });
    }
  }

  void _autoSelectDefaultProfile() {
    _profileAutoSelected = true;
    final defaultId = defaultProfileIdFromTreatmentType(
      widget.treatmentType?.name,
    );
    if (defaultId != null) {
      ref
          .read(simulatorFlowProvider.notifier)
          .setTreatmentProfile(defaultId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowAsync = ref.watch(simulatorFlowProvider);
    final repo = ref.watch(simulationRepositoryProvider);

    return flowAsync.when(
      loading: () => const OcgSkeletonList(
        items: 2,
        cardHeight: 160,
        showAvatar: false,
      ),
      error: (error, _) => _ErrorState(
        message: error.toString(),
        onRetry: () =>
            ref.read(simulatorFlowProvider.notifier).resetFlow(),
      ),
      data: (flow) {
        final showErrorCard =
            (flow.errorMessage ?? '').trim().isNotEmpty;
        final inPreview = flow.hasOriginal;
        final canGenerate = flow.canGenerate &&
            flow.status != SimulationStatus.archived;
        final isGenerating =
            flow.status == SimulationStatus.generating;
        final canShare = flow.status == SimulationStatus.ready &&
            flow.hasResult &&
            flow.doctorReviewStatus == 'approved';
        final canArchive = flow.status == SimulationStatus.ready ||
            flow.status == SimulationStatus.shared;
        final treatmentLabel =
            _treatmentLabel(widget.treatmentType);
        final hasProfile = flow.hasProfile;
        final activeProfile = hasProfile
            ? lookupProfile(flow.treatmentProfileId!)
            : null;
        final isConfigurable = flow.isConfigurable;

        final content = Column(
          key: const ValueKey('simulator-active-flow'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _disclaimer(),
            const SizedBox(height: 12),
            _statusBanner(flow, activeProfile),
            // ── Setup: Treatment selector + Config ────────
            if (isConfigurable) ...[
              const SizedBox(height: 16),
              _SetupSection(
                selectedProfileId: flow.treatmentProfileId,
                activeProfile: activeProfile,
                config: flow.doctorConfig ?? const {},
                isGenerating: isGenerating,
                onProfileSelected: (id) => ref
                    .read(simulatorFlowProvider.notifier)
                    .setTreatmentProfile(id),
                onConfigChanged: (cfg) => ref
                    .read(simulatorFlowProvider.notifier)
                    .updateDoctorConfig(cfg),
              ),
            ],
            // ── Photo step ─────────────────────────────────
            if (!inPreview && hasProfile) ...[
              const SizedBox(height: 18),
              const Text(
                'Paso 3: subir foto original',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: OcgColors.espresso,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tratamiento: ${activeProfile?.label ?? treatmentLabel}',
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
            if (!inPreview && !hasProfile) ...[
              const SizedBox(height: 12),
              const Text(
                'Selecciona un tratamiento antes de continuar.',
                style: TextStyle(
                  color: OcgColors.bronze,
                  fontWeight: FontWeight.w600,
                ),
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
                  Expanded(
                    child: Text('Preparando foto original...'),
                  ),
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
                    child:
                        Text('Generando simulación con IA...'),
                  ),
                ],
              ),
            ],
            if (showErrorCard) ...[
              const SizedBox(height: 12),
              _inlineError(flow.errorMessage!),
            ],
            // ── Photo quality feedback ────────────────────
            if (inPreview && flow.photoQuality != null) ...[
              const SizedBox(height: 12),
              _PhotoQualityCard(photoQuality: flow.photoQuality!),
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
                key: ValueKey(
                  'sim-notes-${flow.simulationId ?? 'new'}',
                ),
                initialValue: flow.notes,
                enabled: !isGenerating,
                onChanged: (value) => ref
                    .read(simulatorFlowProvider.notifier)
                    .setNotes(value),
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas clínicas (opcional)',
                  hintText:
                      'Observaciones de la simulación orientativa',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // ── Approve / Reject (doctor review) ─────
                  if (flow.status == SimulationStatus.ready &&
                      flow.doctorReviewStatus == 'pending') ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: OcgColors.success,
                      ),
                      onPressed: isGenerating
                          ? null
                          : () => ref
                                .read(simulatorFlowProvider.notifier)
                                .approveCurrentResult(
                                  patientId: widget.patientId,
                                ),
                      icon: const Icon(Icons.verified, size: 18),
                      label: const Text('Aprobar resultado'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OcgColors.error,
                        side: const BorderSide(color: OcgColors.error),
                      ),
                      onPressed: isGenerating
                          ? null
                          : () => ref
                                .read(simulatorFlowProvider.notifier)
                                .rejectCurrentResult(
                                  patientId: widget.patientId,
                                  reason:
                                      'Rechazado por el doctor.',
                                ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Rechazar'),
                    ),
                  ],
                  if (flow.status == SimulationStatus.ready &&
                      flow.doctorReviewStatus == 'approved') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: OcgColors.success.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: OcgColors.success.withOpacity(0.30),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 16, color: OcgColors.success),
                          SizedBox(width: 6),
                          Text(
                            'Resultado aprobado',
                            style: TextStyle(
                              color: OcgColors.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (flow.status == SimulationStatus.ready &&
                      flow.doctorReviewStatus == 'rejected') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: OcgColors.error.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: OcgColors.error.withOpacity(0.30),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cancel, size: 16, color: OcgColors.error),
                          SizedBox(width: 6),
                          Text(
                            'Resultado rechazado',
                            style: TextStyle(
                              color: OcgColors.error,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (flow.status == SimulationStatus.draft)
                    ElevatedButton.icon(
                      onPressed:
                          !canGenerate || isGenerating
                              ? null
                              : () => ref
                                    .read(
                                      simulatorFlowProvider
                                          .notifier,
                                    )
                                    .generateWithAi(
                                      patientId:
                                          widget.patientId,
                                      treatmentType:
                                          treatmentLabel,
                                    ),
                      icon: const Icon(
                        Icons.auto_awesome_outlined,
                      ),
                      label: const Text('Generar con IA'),
                    ),
                  if (flow.status == SimulationStatus.failed)
                    OutlinedButton.icon(
                      onPressed: isGenerating
                          ? null
                          : () => ref
                                .read(
                                  simulatorFlowProvider
                                      .notifier,
                                )
                                .resetFlow(),
                      icon: const Icon(
                        Icons.photo_camera_back_outlined,
                      ),
                      label: const Text('Cambiar foto'),
                    ),
                  if (flow.status == SimulationStatus.failed)
                    ElevatedButton.icon(
                      onPressed:
                          !canGenerate || isGenerating
                              ? null
                              : () => ref
                                    .read(
                                      simulatorFlowProvider
                                          .notifier,
                                    )
                                    .generateWithAi(
                                      patientId:
                                          widget.patientId,
                                      treatmentType:
                                          treatmentLabel,
                                    ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  if (flow.status == SimulationStatus.ready)
                    ElevatedButton.icon(
                      onPressed:
                          !canGenerate || isGenerating
                              ? null
                              : () => ref
                                    .read(
                                      simulatorFlowProvider
                                          .notifier,
                                    )
                                    .generateWithAi(
                                      patientId:
                                          widget.patientId,
                                      treatmentType:
                                          treatmentLabel,
                                    ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Regenerar'),
                    ),
                  if (canShare)
                    OutlinedButton.icon(
                      onPressed: isGenerating
                          ? null
                          : () => ref
                                .read(
                                  simulatorFlowProvider
                                      .notifier,
                                )
                                .shareCurrentSimulation(
                                  patientId:
                                      widget.patientId,
                                ),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text(
                        'Compartir con paciente',
                      ),
                    ),
                  if (canArchive)
                    OutlinedButton.icon(
                      onPressed: isGenerating
                          ? null
                          : () => ref
                                .read(
                                  simulatorFlowProvider
                                      .notifier,
                                )
                                .archiveCurrentSimulation(
                                  patientId:
                                      widget.patientId,
                                ),
                      icon: const Icon(
                        Icons.archive_outlined,
                      ),
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

        if (widget.embedded) return content;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: content,
        );
      },
    );
  }

  // ── Reused helpers ────────────────────────────────────

  Widget _disclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OcgColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: OcgColors.warning.withOpacity(0.30),
        ),
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

  Widget _statusBanner(
    SimulatorFlowState flow,
    DentalTreatmentProfile? profile,
  ) {
    final text = switch (flow.status) {
      SimulationStatus.draft => 'Estado: Borrador',
      SimulationStatus.generating => 'Estado: Generando',
      SimulationStatus.ready => 'Estado: Lista',
      SimulationStatus.shared => 'Estado: Compartida',
      SimulationStatus.failed => 'Estado: Error',
      SimulationStatus.archived => 'Estado: Archivada',
    };

    final reviewLabel = switch (flow.doctorReviewStatus) {
      'approved' => ' · Aprobado',
      'rejected' => ' · Rechazado',
      _ => flow.status == SimulationStatus.ready ? ' · Pendiente revisión' : '',
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
        '$text · Perfil: ${profile?.label ?? '—'}$reviewLabel · Intentos: ${flow.attemptCount}',
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
        border: Border.all(
          color: OcgColors.error.withOpacity(0.25),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(color: OcgColors.error),
      ),
    );
  }

  Widget _flowStateHint(SimulatorFlowState flow) {
    final String text;
    if (flow.status == SimulationStatus.ready) {
      text = switch (flow.doctorReviewStatus) {
        'approved' =>
          'Simulación aprobada. Puedes compartirla con el paciente.',
        'rejected' =>
          'Simulación rechazada. Puedes regenerar con ajustes.',
        _ =>
          'Simulación lista. Revisa y aprueba el resultado antes de compartir.',
      };
    } else {
      text = _statusText(flow.status);
    }

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

  String _statusText(SimulationStatus status) => switch (status) {
    SimulationStatus.draft => 'Foto lista para generar simulación.',
    SimulationStatus.generating => 'Generando simulación con IA...',
    SimulationStatus.ready => '', // handled above
    SimulationStatus.failed =>
      'La simulación falló. Revisa el mensaje e intenta de nuevo.',
    SimulationStatus.shared =>
      'Esta simulación fue compartida con el paciente.',
    SimulationStatus.archived => 'La simulación está archivada.',
  };

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

/// ── Setup section (treatment selector + config form) ────

class _SetupSection extends StatelessWidget {
  const _SetupSection({
    required this.selectedProfileId,
    required this.activeProfile,
    required this.config,
    required this.isGenerating,
    required this.onProfileSelected,
    required this.onConfigChanged,
  });

  final String? selectedProfileId;
  final DentalTreatmentProfile? activeProfile;
  final Map<String, dynamic> config;
  final bool isGenerating;
  final ValueChanged<String> onProfileSelected;
  final ValueChanged<Map<String, dynamic>> onConfigChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: OcgColors.bronze.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: OcgColors.espresso),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Configurar simulación',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: OcgColors.espresso,
                    fontSize: 16,
                  ),
                ),
              ),
              if (isGenerating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Paso 1: elegir tratamiento',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: OcgColors.bronze,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          TreatmentProfileSelector(
            selectedProfileId: selectedProfileId,
            onSelected: isGenerating ? (_) {} : onProfileSelected,
            compact: MediaQuery.of(context).size.width < 400,
          ),
          if (activeProfile != null) ...[
            const SizedBox(height: 14),
            const Text(
              'Paso 2: ajustar parámetros',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: OcgColors.bronze,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            DoctorConfigForm(
              profile: activeProfile!,
              config: config,
              enabled: !isGenerating,
              onChanged: onConfigChanged,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Reused storage widgets ──────────────────────────────

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
            Text(
              emptyLabel,
              style: const TextStyle(color: OcgColors.ink),
            )
          else
            FutureBuilder<String?>(
              future: repository.resolveMediaUrl(path),
              builder: (context, snapshot) {
                final previewHeight =
                    MediaQuery.of(context).size.width < 600
                        ? 300.0
                        : 220.0;
                if (!snapshot.hasData) {
                  return OcgSkeletonBox(
                    height: previewHeight,
                    radius: 16,
                  );
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
                        onPressed: () =>
                            _openFullPreview(context, url!, title),
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
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(
                            height: 120,
                            child: Center(
                              child: Text(
                                'No se pudo cargar la imagen.',
                              ),
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

  Widget _buildSlider({
    required BuildContext context,
    required String originalUrl,
    required String resultUrl,
    required double height,
  }) {
    return Stack(
      children: [
        BeforeAfterSlider(
          height: height,
          before: Image.network(
            originalUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => SizedBox(
              height: height,
              child: const Center(child: Text('No se pudo cargar la imagen.')),
            ),
          ),
          after: Image.network(
            resultUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => SizedBox(
              height: height,
              child: const Center(child: Text('No se pudo cargar la imagen.')),
            ),
          ),
        ),
        // Etiquetas "Antes" / "Después" sobre las imágenes
        Positioned(
          top: 10,
          left: 12,
          child: _labelChip('Antes', OcgColors.bronze),
        ),
        Positioned(
          top: 10,
          right: 12,
          child: _labelChip('Después', OcgColors.success),
        ),
      ],
    );
  }

  static Widget _labelChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Future<void> _openFullscreen(
    BuildContext context,
    String originalUrl,
    String resultUrl,
  ) async {
    final screenHeight = MediaQuery.of(context).size.height;
    // Usar ~85% de la pantalla para el slider
    final sliderHeight = screenHeight * 0.82;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      'Comparación Antes / Después',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: OcgColors.espresso,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              // Slider a pantalla completa
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildSlider(
                  context: context,
                  originalUrl: originalUrl,
                  resultUrl: resultUrl,
                  height: sliderHeight,
                ),
              ),
              // Hint
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Desliza para comparar',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
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
    // Altura base del slider en la vista normal: ~40% de la pantalla
    final normalHeight = (MediaQuery.of(context).size.height * 0.4).clamp(280.0, 500.0);

    return FutureBuilder<List<String?>>(
      future: Future.wait([
        repository.resolveMediaUrl(originalPath),
        repository.resolveMediaUrl(resultPath),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return OcgSkeletonBox(height: normalHeight, radius: 16);
        }
        final originalUrl = snapshot.data![0];
        final resultUrl = snapshot.data![1];
        if ((originalUrl ?? '').isEmpty || (resultUrl ?? '').isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(
              child: Text('No se pudieron resolver las imágenes.'),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botón pantalla completa arriba
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openFullscreen(context, originalUrl!, resultUrl!),
                  icon: const Icon(Icons.open_in_full, size: 18),
                  label: const Text('Pantalla completa'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            // Slider
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              child: _buildSlider(
                context: context,
                originalUrl: originalUrl!,
                resultUrl: resultUrl!,
                height: normalHeight,
              ),
            ),
          ],
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
            const Icon(
              Icons.error_outline,
              size: 32,
              color: OcgColors.error,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoQualityCard extends StatelessWidget {
  const _PhotoQualityCard({required this.photoQuality});

  final Map<String, dynamic> photoQuality;

  @override
  Widget build(BuildContext context) {
    final status = (photoQuality['status'] ?? '').toString();
    final warnings = (photoQuality['warnings'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    final blockingReasons =
        (photoQuality['blockingReasons'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [];

    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    switch (status) {
      case 'valid':
        statusColor = OcgColors.success;
        statusIcon = Icons.check_circle_outline;
        statusLabel = 'Foto válida';
        break;
      case 'usable_with_warning':
        statusColor = OcgColors.warning;
        statusIcon = Icons.warning_amber_rounded;
        statusLabel = 'Foto aceptable con advertencias';
        break;
      case 'rejected':
        statusColor = OcgColors.error;
        statusIcon = Icons.cancel_outlined;
        statusLabel = 'Foto no apta';
        break;
      default:
        statusColor = OcgColors.bronze;
        statusIcon = Icons.help_outline;
        statusLabel = 'Calidad de foto';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 20, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...warnings.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 28),
                    Expanded(
                      child: Text(
                        '⚠️ $w',
                        style: const TextStyle(
                          color: OcgColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (blockingReasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...blockingReasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 28),
                    Expanded(
                      child: Text(
                        '🚫 $r',
                        style: const TextStyle(
                          color: OcgColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
