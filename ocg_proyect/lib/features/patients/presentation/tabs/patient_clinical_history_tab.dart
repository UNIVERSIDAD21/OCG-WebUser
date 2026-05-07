import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../../../shared/widgets/ocg_segmented_tabs.dart';
import '../../../../presentation/web/common/web_layout_context.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../clinical_files/data/models/clinical_file_model.dart';
import '../../../clinical_files/providers/clinical_files_provider.dart';
import '../../../treatment/data/models/patient_treatment.dart';
import '../../../treatment/providers/patient_treatments_provider.dart';
import '../../data/models/patient_model.dart';

class PatientClinicalHistoryTab extends ConsumerStatefulWidget {
  const PatientClinicalHistoryTab({
    super.key,
    required this.patientId,
    required this.patient,
  });

  final String patientId;
  final PatientModel patient;

  @override
  ConsumerState<PatientClinicalHistoryTab> createState() =>
      _PatientClinicalHistoryTabState();
}

class _PatientClinicalHistoryTabState
    extends ConsumerState<PatientClinicalHistoryTab> {
  String? _selectedTreatmentId;
  String? _selectedCategory;

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Historial clínico por archivos',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: selectedTreatment == null || uploadState.isLoading
                    ? null
                    : () => _showUploadDialog(selectedTreatment),
                icon: const Icon(Icons.upload_file),
                label: Text(
                  uploadState.isLoading
                      ? 'Subiendo archivo...'
                      : 'Subir archivo',
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
          const SizedBox(height: 16),
          filesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('No se pudieron cargar archivos: $error'),
            data: (files) {
              final filtered = files.where((file) {
                if (_selectedCategory != null &&
                    file.category != _selectedCategory) {
                  return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const OcgEmptyState(
                  icon: Icons.folder_open,
                  title: 'Todavía no hay archivos clínicos',
                  subtitle:
                      'Sube PDFs, radiografías o imágenes clínicas desde este expediente.',
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

  Future<void> _showUploadDialog(PatientTreatment selectedTreatment) async {
    final displayCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = kClinicalFileCategories.first;
    bool linkToTreatment = !selectedTreatment.id.startsWith('legacy-primary-');
    bool visibleToPatient = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Subir archivo clínico'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: displayCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre visible',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Categoría'),
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
                  title: Text(
                    'Asociar al tratamiento ${selectedTreatment.displayName}',
                  ),
                  value: linkToTreatment,
                  onChanged: selectedTreatment.id.startsWith('legacy-primary-')
                      ? null
                      : (value) => setModalState(() => linkToTreatment = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible para el paciente'),
                  value: visibleToPatient,
                  onChanged: (value) =>
                      setModalState(() => visibleToPatient = value),
                ),
                TextFormField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notas'),
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
              child: const Text('Elegir archivo'),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            file.isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
            color: OcgColors.bronze,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.displayName,
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  file.originalName,
                  style: const TextStyle(color: OcgColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Categoría: ${file.category.replaceAll('_', ' ')} • ${dateFmt.format(file.uploadedAt)}',
                ),
                if ((file.treatmentNameSnapshot ?? '').isNotEmpty)
                  Text('Tratamiento: ${file.treatmentNameSnapshot}'),
                if ((file.notes ?? '').trim().isNotEmpty)
                  Text('Notas: ${file.notes!.trim()}'),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => _openFile(context, file.downloadUrl),
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Abrir',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Desactivar',
              ),
            ],
          ),
        ],
      ),
    );
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
