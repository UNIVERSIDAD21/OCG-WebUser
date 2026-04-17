import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_button.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../data/models/patient_treatment.dart';
import '../../data/models/treatment_catalog_item.dart';
import '../../data/repositories/treatment_catalog_repository.dart';
import '../../providers/patient_treatments_provider.dart';
import '../../providers/treatment_catalog_provider.dart';

class ManagePatientTreatmentDialog extends ConsumerStatefulWidget {
  const ManagePatientTreatmentDialog({
    super.key,
    required this.patientId,
    this.initialTreatment,
  });

  final String patientId;
  final PatientTreatment? initialTreatment;

  @override
  ConsumerState<ManagePatientTreatmentDialog> createState() => _ManagePatientTreatmentDialogState();
}

class _ManagePatientTreatmentDialogState extends ConsumerState<ManagePatientTreatmentDialog> {
  late final TextEditingController _customNameController;
  late final TextEditingController _notesController;
  late final TextEditingController _totalController;
  late final TextEditingController _balanceController;

  late String _baseTreatment;
  late String _category;
  late String _status;
  String? _subtype;
  late TreatmentStage _stage;
  late bool _isPrimary;
  late DateTime _fechaInicio;

  bool get _isCustomBase => _baseTreatment == '__custom__';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTreatment;
    final initialBase = initial?.tipoBase ?? 'convencional';
    final isKnownBase = kBaseTreatmentOptions.contains(initialBase);

    _baseTreatment = isKnownBase ? initialBase : '__custom__';
    _category = initial?.categoria ?? 'ortodoncia';
    _status = initial?.estado ?? 'activo';
    _subtype = initial?.subtipo;
    _stage = initial?.etapaActual ?? TreatmentStage.valoracionInicial;
    _isPrimary = initial?.isPrimary ?? true;
    _fechaInicio = initial?.fechaInicio ?? DateTime.now();

    _customNameController = TextEditingController(
      text: isKnownBase ? '' : (initial?.nombre ?? ''),
    );
    _notesController = TextEditingController(text: initial?.notas ?? '');
    _totalController = TextEditingController(
      text: initial?.totalTratamiento?.toStringAsFixed(0) ?? '',
    );
    _balanceController = TextEditingController(
      text: initial?.saldoPendiente?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _notesController.dispose();
    _totalController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  bool get _requiresSubtype => kSubtypeRequiredBaseTreatments.contains(_effectiveBaseTreatment);

  String get _effectiveBaseTreatment => _isCustomBase
      ? _normalizeValue(_customNameController.text)
      : _normalizeValue(_baseTreatment);

  String get _effectiveName {
    if (_isCustomBase) {
      return _normalizeHumanName(_customNameController.text);
    }
    return PatientTreatment.labelForBaseTreatment(_baseTreatment);
  }

  bool get _isValid {
    if (_effectiveName.trim().isEmpty) return false;
    if (_effectiveBaseTreatment.trim().isEmpty) return false;
    if (_requiresSubtype && (_subtype == null || _subtype!.trim().isEmpty)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(savePatientTreatmentProvider);
    final isLoading = saveState.isLoading;
    final catalogItems = ref.watch(treatmentCatalogProvider).asData?.value ?? const <TreatmentCatalogItem>[];
    final visibleBaseOptions = <String>{...kBaseTreatmentOptions, ...catalogItems.map((item) => item.baseType)}.toList()
      ..sort((a, b) => PatientTreatment.labelForBaseTreatment(a).compareTo(PatientTreatment.labelForBaseTreatment(b)));

    return AlertDialog(
      title: Text(widget.initialTreatment == null ? 'Nuevo tratamiento' : 'Editar tratamiento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _baseTreatment,
              decoration: const InputDecoration(labelText: 'Tipo base'),
              items: [
                ...visibleBaseOptions.map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(PatientTreatment.labelForBaseTreatment(value)),
                  ),
                ),
                const DropdownMenuItem<String>(
                  value: '__custom__',
                  child: Text('Agregar nuevo tratamiento'),
                ),
              ],
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _baseTreatment = value;
                        if (!_requiresSubtype) _subtype = null;
                      });
                    },
            ),
            if (_isCustomBase) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customNameController,
                enabled: !isLoading,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del tratamiento',
                  hintText: 'Ej. Obturación',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _category,
              enabled: !isLoading,
              decoration: const InputDecoration(labelText: 'Categoría'),
              onChanged: (value) => _category = _normalizeValue(value).isEmpty ? 'ortodoncia' : _normalizeValue(value),
            ),
            if (_requiresSubtype) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _subtype,
                decoration: const InputDecoration(labelText: 'Subtipo obligatorio'),
                items: kTreatmentSubtypes
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(PatientTreatment.labelForBaseTreatment(value)),
                      ),
                    )
                    .toList(),
                onChanged: isLoading ? null : (value) => setState(() => _subtype = value),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: kTreatmentStatusOptions
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(PatientTreatment.labelForBaseTreatment(value)),
                    ),
                  )
                  .toList(),
              onChanged: isLoading ? null : (value) => setState(() => _status = value ?? 'activo'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TreatmentStage>(
              value: _stage,
              decoration: const InputDecoration(labelText: 'Etapa actual'),
              items: TreatmentStage.values
                  .map(
                    (value) => DropdownMenuItem<TreatmentStage>(
                      value: value,
                      child: Text(stageNames[value] ?? value.name),
                    ),
                  )
                  .toList(),
              onChanged: isLoading ? null : (value) => setState(() => _stage = value ?? _stage),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Inicio: ${_fechaInicio.day.toString().padLeft(2, '0')}/${_fechaInicio.month.toString().padLeft(2, '0')}/${_fechaInicio.year}',
                  ),
                ),
                TextButton(
                  onPressed: isLoading ? null : _pickFechaInicio,
                  child: const Text('Cambiar fecha'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _isPrimary,
              onChanged: isLoading ? null : (value) => setState(() => _isPrimary = value),
              title: const Text('Marcar como principal'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _totalController,
              enabled: !isLoading,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor total del tratamiento'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _balanceController,
              enabled: !isLoading,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Saldo pendiente'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              enabled: !isLoading,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notas clínicas',
                hintText: 'Seguimiento sugerido: limpieza cada 3 meses, control cada 6 meses',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OcgColors.bronze.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OcgColors.bronze.withValues(alpha: 0.22)),
              ),
              child: const Text(
                'Seguimiento sugerido por defecto: limpieza cada 3 meses y control cada 6 meses.',
                style: TextStyle(color: OcgColors.espresso, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OcgButton(
          label: 'Cancelar',
          variant: OcgButtonVariant.outline,
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
        ),
        OcgButton(
          label: widget.initialTreatment == null ? 'Crear tratamiento' : 'Guardar cambios',
          isLoading: isLoading,
          onPressed: !_isValid || isLoading ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _pickFechaInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _fechaInicio = picked);
  }

  Future<void> _submit() async {
    try {
      final catalogRepo = ref.read(treatmentCatalogRepositoryProvider);
      String effectiveBaseType = _effectiveBaseTreatment;
      String effectiveName = _effectiveName;

      if (_isCustomBase) {
        final normalizedName = TreatmentCatalogRepository.normalizeCatalogName(_customNameController.text);
        final existing = await catalogRepo.findByNormalizedName(normalizedName);
        if (existing == null) {
          final confirmed = await _confirmCreateCatalogTreatment(_normalizeHumanName(_customNameController.text));
          if (!confirmed) return;
          final adminId = ref.read(authStateProvider).asData?.value?.uid ?? 'admin';
          final created = await catalogRepo.ensureCustomTreatmentExists(
            displayName: _customNameController.text,
            category: _category,
            createdBy: adminId,
          );
          effectiveBaseType = created.baseType;
          effectiveName = created.name;
        } else {
          effectiveBaseType = existing.baseType;
          effectiveName = existing.name;
        }
      }

      final adminId = ref.read(authStateProvider).asData?.value?.uid ?? 'admin';
      final treatment = (widget.initialTreatment ??
              PatientTreatment(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                patientId: widget.patientId,
                nombre: effectiveName,
                categoria: _category,
                tipoBase: effectiveBaseType,
                estado: _status,
                etapaActual: _stage,
                fechaInicio: _fechaInicio,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                isPrimary: _isPrimary,
                createdBy: adminId,
                updatedBy: adminId,
              ))
          .copyWith(
        nombre: effectiveName,
        categoria: _category,
        tipoBase: effectiveBaseType,
        subtipo: _requiresSubtype ? _subtype : null,
        estado: _status,
        etapaActual: _stage,
        patientId: widget.patientId,
        fechaInicio: _fechaInicio,
        fechaFin: (_status == 'finalizado' || _status == 'cancelado') ? DateTime.now() : null,
        isPrimary: _isPrimary,
        updatedBy: adminId,
        totalTratamiento: _parseDouble(_totalController.text),
        saldoPendiente: _parseDouble(_balanceController.text),
        notas: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        clearSubtype: !_requiresSubtype,
      );

      await ref.read(savePatientTreatmentProvider.notifier).saveTreatment(
            patientId: widget.patientId,
            treatment: treatment,
            previousPrimaryId: widget.initialTreatment?.isPrimary == true ? widget.initialTreatment!.id : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_mapError(e))));
    }
  }

  Future<bool> _confirmCreateCatalogTreatment(String treatmentName) async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar nuevo tratamiento'),
        content: Text('¿Confirmas crear este tratamiento global con el nombre "$treatmentName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return decision ?? false;
  }

  String _normalizeValue(String value) {
    return TreatmentCatalogRepository.normalizeCatalogName(value);
  }

  String _normalizeHumanName(String value) {
    return TreatmentCatalogRepository.normalizeHumanName(value);
  }

  double? _parseDouble(String value) {
    final clean = value.trim().replaceAll('.', '').replaceAll(',', '.');
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  String _mapError(Object error) {
    final raw = error.toString();
    if (raw.contains('TREATMENT_SUBTYPE_REQUIRED')) {
      return 'Convencional y Autoligado requieren subtipo obligatorio.';
    }
    if (raw.contains('TREATMENT_NAME_REQUIRED')) {
      return 'Debes indicar el nombre del tratamiento.';
    }
    return raw;
  }
}
