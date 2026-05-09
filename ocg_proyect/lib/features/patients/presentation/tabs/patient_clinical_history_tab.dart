import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_premium.dart';
import '../../../../shared/widgets/ocg_segmented_tabs.dart';
import '../../../../shared/widgets/ocg_confirm_dialog.dart';
import '../../../../shared/widgets/ocg_loading_state.dart';
import '../../../../presentation/web/common/web_layout_context.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../clinical_files/data/models/clinical_file_model.dart';
import '../../../clinical_files/providers/clinical_files_provider.dart';
import '../../../treatment/data/models/patient_treatment.dart';
import '../../../treatment/providers/patient_treatments_provider.dart';
import '../../data/models/patient_model.dart';

enum _ClinicalVisibilityFilter { all, patient, adminOnly }

class PatientClinicalHistoryTab extends ConsumerStatefulWidget {
  const PatientClinicalHistoryTab({
    super.key,
    required this.patientId,
    required this.patient,
    this.scrollable = true,
  });

  final String patientId;
  final PatientModel patient;
  final bool scrollable;

  @override
  ConsumerState<PatientClinicalHistoryTab> createState() =>
      _PatientClinicalHistoryTabState();
}

class _PatientClinicalHistoryTabState
    extends ConsumerState<PatientClinicalHistoryTab> {
  String? _selectedTreatmentId;
  String? _selectedCategory;
  _ClinicalVisibilityFilter _visibilityFilter = _ClinicalVisibilityFilter.all;

  @override
  Widget build(BuildContext context) {
    final treatments = ref.watch(
      effectivePatientTreatmentsProvider((
        patientId: widget.patientId,
        patient: widget.patient,
      )),
    );
    final uploadState = ref.watch(uploadClinicalFileProvider);
    final uploadProgress = ref.watch(clinicalFileUploadProgressProvider);
    final selectedTreatment = _resolveSelectedTreatment(treatments);
    final usePremiumFilters = !WebLayoutContext.useDesktopShell(context);
    final filesAsync = ref.watch(
      patientClinicalFilesProvider((
        patientId: widget.patientId,
        treatmentId: _selectedTreatmentId == '__all__'
            ? null
            : _selectedTreatmentId,
        onlyVisibleToPatient: false,
      )),
    );

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Documentos clínicos',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: selectedTreatment == null || uploadState.isLoading
                    ? null
                    : () => _showUploadDialog(
                        initialTreatment: selectedTreatment,
                        treatments: treatments,
                      ),
                icon: const Icon(Icons.upload_file),
                label: Text(
                  uploadState.isLoading ? 'Subiendo...' : 'Subir documento',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (uploadState.isLoading)
            _ClinicalUploadProgressCard(progress: uploadProgress ?? 0),
          if (uploadState.isLoading) const SizedBox(height: 12),
          if (treatments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OcgColors.mist,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: OcgColors.espresso.withValues(alpha: 0.10),
                ),
              ),
              child: const Text(
                'Todavía no hay tratamientos creados para asociar archivos clínicos.',
                style: TextStyle(
                  color: OcgColors.espresso,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (usePremiumFilters)
            OcgSegmentedTabs<String>(
              selectedValue: _selectedTreatmentId ?? '__all__',
              onChanged: (value) =>
                  setState(() => _selectedTreatmentId = value),
              compact: true,
              items: [
                const OcgSegmentedTabItem(
                  value: '__all__',
                  label: 'Todos',
                  icon: Icons.layers_outlined,
                ),
                for (final treatment in treatments)
                  OcgSegmentedTabItem(
                    value: treatment.id,
                    label: treatment.displayName,
                    icon: Icons.monitor_heart_outlined,
                  ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected:
                      _selectedTreatmentId == '__all__' ||
                      _selectedTreatmentId == null,
                  label: const Text('Todos los tratamientos'),
                  onSelected: (_) =>
                      setState(() => _selectedTreatmentId = '__all__'),
                ),
                for (final treatment in treatments)
                  ChoiceChip(
                    selected: treatment.id == _selectedTreatmentId,
                    label: Text(treatment.displayName),
                    onSelected: (_) =>
                        setState(() => _selectedTreatmentId = treatment.id),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (usePremiumFilters)
            OcgSegmentedTabs<String>(
              selectedValue: _selectedCategory ?? '__all__',
              onChanged: (value) => setState(
                () => _selectedCategory = value == '__all__' ? null : value,
              ),
              compact: true,
              items: [
                const OcgSegmentedTabItem(
                  value: '__all__',
                  label: 'Todas',
                  icon: Icons.folder_copy_outlined,
                ),
                for (final category in kClinicalFileCategories)
                  OcgSegmentedTabItem(
                    value: category,
                    label: _categoryLabel(category),
                    icon: Icons.description_outlined,
                  ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected: _selectedCategory == null,
                  label: const Text('Todas las categorías'),
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                for (final category in kClinicalFileCategories)
                  ChoiceChip(
                    selected: _selectedCategory == category,
                    label: Text(_categoryLabel(category)),
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          _buildVisibilityFilter(),
          const SizedBox(height: 16),
          _buildClinicalFilesHero(filesAsync.asData?.value ?? const []),
          const SizedBox(height: 16),
          filesAsync.when(
            loading: () => OcgLoadingState(),
            error: (error, _) => Text('No se pudieron cargar archivos: $error'),
            data: (files) {
              final filtered = files.where((file) {
                if (_selectedCategory != null &&
                    file.category != _selectedCategory) {
                  return false;
                }
                if (_visibilityFilter == _ClinicalVisibilityFilter.patient &&
                    !file.visibleToPatient) {
                  return false;
                }
                if (_visibilityFilter == _ClinicalVisibilityFilter.adminOnly &&
                    file.visibleToPatient) {
                  return false;
                }
                return true;
              }).toList()..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

              if (filtered.isEmpty) {
                return _buildClinicalFilesEmptyState(
                  canUpload:
                      selectedTreatment != null && !uploadState.isLoading,
                  onUpload: selectedTreatment == null
                      ? null
                      : () => _showUploadDialog(
                          initialTreatment: selectedTreatment,
                          treatments: treatments,
                        ),
                );
              }

              return Column(
                children: filtered
                    .map(
                      (file) => _ClinicalFileTile(
                        file: file,
                        onDelete: () => _deleteFile(file),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );

    if (!widget.scrollable) return content;
    return SingleChildScrollView(child: content);
  }

  String _visibilityLabel(_ClinicalVisibilityFilter filter) {
    return switch (filter) {
      _ClinicalVisibilityFilter.all => 'Todos',
      _ClinicalVisibilityFilter.patient => 'Paciente',
      _ClinicalVisibilityFilter.adminOnly => 'Solo admin',
    };
  }

  IconData _visibilityIcon(_ClinicalVisibilityFilter filter) {
    return switch (filter) {
      _ClinicalVisibilityFilter.all => Icons.layers_outlined,
      _ClinicalVisibilityFilter.patient => Icons.visibility_outlined,
      _ClinicalVisibilityFilter.adminOnly =>
        Icons.admin_panel_settings_outlined,
    };
  }

  Widget _buildVisibilityFilter() {
    final filters = _ClinicalVisibilityFilter.values;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final active = _visibilityFilter == filter;
          return ChoiceChip(
            selected: active,
            avatar: Icon(
              _visibilityIcon(filter),
              size: 16,
              color: active ? OcgColors.ivory : OcgColors.espresso,
            ),
            label: Text(_visibilityLabel(filter)),
            selectedColor: OcgColors.espresso,
            backgroundColor: OcgColors.ivory,
            labelStyle: TextStyle(
              color: active ? OcgColors.ivory : OcgColors.espresso,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            side: BorderSide(
              color: active
                  ? OcgColors.espresso
                  : OcgColors.bronze.withValues(alpha: 0.22),
            ),
            onSelected: (_) => setState(() => _visibilityFilter = filter),
          );
        },
      ),
    );
  }

  Widget _buildClinicalFilesEmptyState({
    required bool canUpload,
    VoidCallback? onUpload,
  }) {
    final hasFilters =
        _selectedCategory != null ||
        (_selectedTreatmentId != null && _selectedTreatmentId != '__all__') ||
        _visibilityFilter != _ClinicalVisibilityFilter.all;

    return OcgPremiumEmptyState(
      title: hasFilters
          ? 'Sin documentos para estos filtros'
          : 'Todavía no hay documentos clínicos',
      subtitle: hasFilters
          ? 'Limpia filtros o sube un documento con la categoría y visibilidad correctas.'
          : 'Sube PDFs, radiografías, imágenes clínicas o soportes desde este expediente.',
      icon: Icons.folder_open_outlined,
      actionLabel: hasFilters ? 'Limpiar filtros' : null,
      actionIcon: Icons.filter_alt_off_outlined,
      onAction: hasFilters
          ? () => setState(() {
              _selectedTreatmentId = '__all__';
              _selectedCategory = null;
              _visibilityFilter = _ClinicalVisibilityFilter.all;
            })
          : null,
      secondaryActionLabel: canUpload ? 'Subir documento' : null,
      secondaryActionIcon: Icons.upload_file_outlined,
      onSecondaryAction: canUpload ? onUpload : null,
    );
  }

  Widget _buildClinicalFilesHero(List<ClinicalFileModel> files) {
    final visibles = files.where((file) => file.visibleToPatient).length;
    final vinculados = files
        .where((file) => (file.treatmentId ?? '').trim().isNotEmpty)
        .length;
    final imagenes = files.where((file) => file.isImage).length;
    final pdfs = files.where((file) => file.isPdf).length;

    return OcgPremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      backgroundColor: const Color(0xFFFFFAF2),
      borderColor: OcgColors.bronze.withValues(alpha: 0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OcgSectionHeader(
            title: 'Expediente clínico digital',
            subtitle:
                'Organiza soportes por tratamiento, categoría y visibilidad para paciente.',
            icon: Icons.folder_shared_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OcgInfoTile(
                  label: 'Archivos',
                  value: '${files.length}',
                  icon: Icons.description_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OcgInfoTile(
                  label: 'Paciente',
                  value: '$visibles',
                  icon: Icons.visibility_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OcgInfoTile(
                  label: 'Vinculados',
                  value: '$vinculados',
                  icon: Icons.monitor_heart_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OcgInfoTile(
                  label: 'Img/PDF',
                  value: '$imagenes/$pdfs',
                  icon: Icons.image_search_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PatientTreatment? _resolveSelectedTreatment(
    List<PatientTreatment> treatments,
  ) {
    if (_selectedTreatmentId != null && _selectedTreatmentId != '__all__') {
      for (final treatment in treatments) {
        if (treatment.id == _selectedTreatmentId) return treatment;
      }
    }
    for (final treatment in treatments) {
      if (treatment.isPrimary) return treatment;
    }
    if (treatments.isEmpty) return null;
    return treatments.first;
  }

  Future<void> _showUploadDialog({
    required PatientTreatment initialTreatment,
    required List<PatientTreatment> treatments,
  }) async {
    final displayCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    PatientTreatment selectedTreatment = initialTreatment;
    String category = kClinicalFileCategories.first;
    bool linkToTreatment = !selectedTreatment.id.startsWith('legacy-primary-');
    bool visibleToPatient = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Subir documento clínico'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7EF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: OcgColors.bronze.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.assignment_turned_in_outlined,
                        color: OcgColors.espresso,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tratamiento base: ${selectedTreatment.displayName}. Define nombre, categoría y visibilidad antes de elegir el archivo.',
                          style: const TextStyle(
                            color: OcgColors.espresso,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedTreatment.id,
                  decoration: const InputDecoration(
                    labelText: 'Tratamiento asociado',
                    prefixIcon: Icon(Icons.monitor_heart_outlined),
                  ),
                  items: treatments
                      .map(
                        (treatment) => DropdownMenuItem(
                          value: treatment.id,
                          child: Text(treatment.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    final next = treatments.firstWhere(
                      (treatment) => treatment.id == value,
                      orElse: () => selectedTreatment,
                    );
                    setModalState(() {
                      selectedTreatment = next;
                      linkToTreatment = !selectedTreatment.id.startsWith(
                        'legacy-primary-',
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: displayCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre visible',
                    prefixIcon: Icon(Icons.badge_outlined),
                    helperText:
                        'Si lo dejas vacío se usará el nombre del archivo.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: kClinicalFileCategories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_categoryLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setModalState(() => category = value ?? category),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.link_outlined),
                  title: Text(
                    'Asociar al tratamiento ${selectedTreatment.displayName}',
                  ),
                  subtitle: const Text(
                    'Recomendado para mantener trazabilidad clínica.',
                  ),
                  value: linkToTreatment,
                  onChanged: selectedTreatment.id.startsWith('legacy-primary-')
                      ? null
                      : (value) => setModalState(() => linkToTreatment = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.visibility_outlined),
                  title: const Text('Visible para el paciente'),
                  subtitle: const Text(
                    'Actívalo solo si la clínica quiere compartir el soporte.',
                  ),
                  value: visibleToPatient,
                  onChanged: (value) =>
                      setModalState(() => visibleToPatient = value),
                ),
                TextFormField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Elegir archivo y subir'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final adminId = ref.read(authStateProvider).asData?.value?.uid ?? '';
    if (adminId.isEmpty) return;

    try {
      await ref
          .read(uploadClinicalFileProvider.notifier)
          .upload(
            patientId: widget.patientId,
            uploadedBy: adminId,
            category: category,
            displayName: displayCtrl.text,
            notes: notesCtrl.text,
            treatment: linkToTreatment ? selectedTreatment : null,
            visibleToPatient: visibleToPatient,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapError(error))));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Archivo clínico subido correctamente.')),
    );
  }

  Future<void> _deleteFile(ClinicalFileModel file) async {
    final confirm = await OcgConfirmDialog.show(
      context,
      type: OcgConfirmDialogType.danger,
      title: 'Desactivar documento',
      message: '¿Deseas desactivar "${file.displayName}"? El archivo dejará de aparecer en el expediente activo.',
      confirmLabel: 'Desactivar',
      onConfirm: () {},
    );
    if (confirm != true) return;
    final adminId = ref.read(authStateProvider).asData?.value?.uid ?? '';
    if (adminId.isEmpty) return;
    await ref
        .read(uploadClinicalFileProvider.notifier)
        .softDelete(
          patientId: widget.patientId,
          fileId: file.id,
          deletedBy: adminId,
        );
  }

  String _categoryLabel(String category) => category
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');

  String _mapError(Object error) {
    final raw = error.toString();
    if (raw.contains('CLINICAL_FILE_PICK_CANCELLED')) {
      return 'No se seleccionó ningún archivo.';
    }
    if (raw.contains('CLINICAL_FILE_TOO_LARGE')) {
      return 'El archivo supera el tamaño máximo permitido.';
    }
    if (raw.contains('CLINICAL_FILE_EXTENSION_NOT_ALLOWED')) {
      return 'Tipo de archivo no permitido.';
    }
    if (raw.contains('CLINICAL_FILE_STORAGE_PERMISSION_DENIED')) {
      return 'Falló la subida del archivo a Storage por permisos. Ruta de upload clínica revisada.';
    }
    if (raw.contains('CLINICAL_FILE_METADATA_PERMISSION_DENIED')) {
      return 'El archivo pudo subirse, pero falló el guardado de metadata en Firestore por permisos.';
    }
    if (raw.contains('firebase_storage') || raw.contains('object-not-found')) {
      return 'Falló la subida del archivo en Storage.';
    }
    if (raw.contains('cloud_firestore') || raw.contains('permission-denied')) {
      return 'Falló la persistencia de metadata del archivo en Firestore.';
    }
    return raw;
  }
}

class _ClinicalUploadProgressCard extends StatelessWidget {
  const _ClinicalUploadProgressCard({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0, 1).toDouble();
    final percent = (clamped * 100).round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_upload_outlined,
                color: OcgColors.espresso,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Subiendo archivo clínico... $percent%',
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 250),
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: value,
                backgroundColor: OcgColors.ivory,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  OcgColors.espresso,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            clamped >= 1
                ? 'Finalizando guardado de metadata...'
                : 'No cierres esta pantalla mientras termina la subida.',
            style: const TextStyle(
              color: OcgColors.bronze,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicalFileTile extends StatelessWidget {
  const _ClinicalFileTile({required this.file, required this.onDelete});

  final ClinicalFileModel file;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final accent = _fileAccentColor(file);
    final icon = _fileIcon(file);
    final category = _categoryLabel(file.category);
    final size = _formatBytes(file.sizeBytes);

    return OcgPremiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderColor: accent.withValues(alpha: 0.20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      file.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: OcgColors.ink.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              OcgStatusPill(
                label: file.visibleToPatient ? 'Paciente' : 'Solo admin',
                icon: file.visibleToPatient
                    ? Icons.visibility_outlined
                    : Icons.admin_panel_settings_outlined,
                color: file.visibleToPatient
                    ? const Color(0xFF2E7D4C)
                    : OcgColors.bronze,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OcgStatusPill(
                label: category,
                icon: Icons.folder_outlined,
                color: accent,
              ),
              OcgStatusPill(label: size, icon: Icons.data_object_outlined),
              OcgStatusPill(
                label: dateFmt.format(file.uploadedAt),
                icon: Icons.schedule_outlined,
              ),
              if ((file.treatmentNameSnapshot ?? '').isNotEmpty)
                OcgStatusPill(
                  label: file.treatmentNameSnapshot!,
                  icon: Icons.monitor_heart_outlined,
                  color: OcgColors.espresso,
                ),
            ],
          ),
          if ((file.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F1EA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                file.notes!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: OcgColors.ink.withValues(alpha: 0.76),
                  height: 1.25,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _openFile(context, file.downloadUrl),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Abrir'),
                style: FilledButton.styleFrom(
                  backgroundColor: OcgColors.espresso,
                  foregroundColor: OcgColors.ivory,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openFile(context, file.downloadUrl),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Descargar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OcgColors.espresso,
                  side: BorderSide(
                    color: OcgColors.espresso.withValues(alpha: 0.42),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Desactivar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(ClinicalFileModel file) {
    if (file.isPdf) return Icons.picture_as_pdf_outlined;
    if (file.isImage) return Icons.image_outlined;
    if (file.category == 'soporte_pago') return Icons.receipt_long_outlined;
    if (file.category == 'consentimiento') return Icons.fact_check_outlined;
    return Icons.description_outlined;
  }

  Color _fileAccentColor(ClinicalFileModel file) {
    if (file.category == 'radiografia') return const Color(0xFF3268A8);
    if (file.category.contains('foto')) return const Color(0xFF7A8A20);
    if (file.category == 'consentimiento') return const Color(0xFF7E3AF2);
    if (file.category == 'soporte_pago') return const Color(0xFFC56B16);
    if (file.isPdf) return const Color(0xFFB3261E);
    return OcgColors.bronze;
  }

  String _categoryLabel(String category) => category
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');

  String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Sin tamaño';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openFile(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivo sin URL disponible.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo.')),
      );
    }
  }
}
