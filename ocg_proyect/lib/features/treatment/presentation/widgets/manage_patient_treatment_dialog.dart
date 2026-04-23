import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_providers.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../data/models/patient_treatment.dart';
import '../../providers/patient_treatments_provider.dart';

class ManagePatientTreatmentDialog extends ConsumerStatefulWidget {
  const ManagePatientTreatmentDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    this.initialTreatment,
  });

  final String patientId;
  final String patientName;
  final PatientTreatment? initialTreatment;

  @override
  ConsumerState<ManagePatientTreatmentDialog> createState() =>
      _ManagePatientTreatmentDialogState();
}

class _ManagePatientTreatmentDialogState
    extends ConsumerState<ManagePatientTreatmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  late String _baseType;
  String? _subtype;
  late String _status;
  late TreatmentStage _stage;
  late DateTime _startDate;
  bool _isPrimary = false;

  bool get _requiresSubtype =>
      kSubtypeRequiredBaseTreatments.contains(_baseType);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTreatment;
    _nameCtrl = TextEditingController(text: initial?.nombre ?? '');
    _notesCtrl = TextEditingController(text: initial?.notas ?? '');
    _baseType = initial?.tipoBase ?? 'convencional';
    _subtype = initial?.subtipo;
    _status = initial?.estado ?? 'activo';
    _stage = initial?.etapaActual ?? TreatmentStage.valoracionInicial;
    _startDate = initial?.fechaInicio ?? DateTime.now();
    _isPrimary = initial?.isPrimary ?? true;
    if (_requiresSubtype && (_subtype == null || _subtype!.trim().isEmpty)) {
      _subtype = 'metalico';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(savePatientTreatmentProvider);
    final editing = widget.initialTreatment != null;

    ref.listen<AsyncValue<void>>(savePatientTreatmentProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        data: (_) {
          if (previous?.isLoading == true && mounted) {
            Navigator.of(context).pop(true);
          }
        },
        error: (error, _) {
          final message = _mapTreatmentError(error);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
      );
    });

    return AlertDialog(
      title: Text(editing ? 'Editar tratamiento' : 'Crear tratamiento'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patientName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del tratamiento',
                    hintText: 'Ej. Brackets metálicos',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Ingresa el nombre del tratamiento';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _baseType,
                  decoration: const InputDecoration(labelText: 'Tipo base'),
                  items: kBaseTreatmentOptions
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(
                            PatientTreatment.labelForBaseTreatment(item),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: saveState.isLoading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _baseType = value;
                            if (!_requiresSubtype) {
                              _subtype = null;
                            } else {
                              _subtype ??= 'metalico';
                            }
                          });
                        },
                ),
                if (_requiresSubtype) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: (_subtype != null && _subtype!.isNotEmpty)
                        ? _subtype
                        : 'metalico',
                    decoration: const InputDecoration(labelText: 'Subtipo'),
                    items: kTreatmentSubtypes
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(
                              PatientTreatment.labelForBaseTreatment(item),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: saveState.isLoading
                        ? null
                        : (value) => setState(() => _subtype = value),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: kTreatmentStatusOptions
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(
                            PatientTreatment.labelForBaseTreatment(item),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: saveState.isLoading
                      ? null
                      : (value) {
                          if (value != null) setState(() => _status = value);
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TreatmentStage>(
                  initialValue: _stage,
                  decoration: const InputDecoration(labelText: 'Etapa actual'),
                  items: TreatmentStage.values
                      .map(
                        (stage) => DropdownMenuItem<TreatmentStage>(
                          value: stage,
                          child: Text(stageNames[stage] ?? stage.name),
                        ),
                      )
                      .toList(),
                  onChanged: saveState.isLoading
                      ? null
                      : (value) {
                          if (value != null) setState(() => _stage = value);
                        },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de inicio'),
                  subtitle: Text(_formatDate(_startDate)),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: saveState.isLoading ? null : _pickStartDate,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isPrimary,
                  onChanged: saveState.isLoading
                      ? null
                      : (value) => setState(() => _isPrimary = value ?? false),
                  title: const Text('Marcar como tratamiento principal'),
                  subtitle: const Text(
                    'Si es el primer tratamiento del paciente, se guardará como principal automáticamente.',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesCtrl,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notas clínicas',
                    hintText:
                        'Observaciones, recomendaciones o contexto inicial',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saveState.isLoading
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saveState.isLoading ? null : _submit,
          child: Text(saveState.isLoading ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final authUser = ref.read(authStateProvider).asData?.value;
    final previous = widget.initialTreatment;
    final treatmentId =
        previous?.id ??
        'treatment-${now.millisecondsSinceEpoch}-${widget.patientId.substring(0, widget.patientId.length.clamp(0, 6))}';

    final treatment = PatientTreatment(
      id: treatmentId,
      patientId: widget.patientId,
      nombre: _nameCtrl.text.trim(),
      categoria: 'ortodoncia',
      tipoBase: _baseType,
      subtipo: _requiresSubtype ? _subtype : null,
      estado: _status,
      etapaActual: _stage,
      fechaInicio: _startDate,
      fechaFin: (_status == 'finalizado' || _status == 'cancelado')
          ? now
          : null,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
      isPrimary: _isPrimary,
      createdBy: previous?.createdBy ?? authUser?.uid ?? 'system',
      updatedBy: authUser?.uid ?? previous?.updatedBy ?? 'system',
      suggestedCleaningEveryMonths: previous?.suggestedCleaningEveryMonths ?? 3,
      suggestedControlEveryMonths: previous?.suggestedControlEveryMonths ?? 6,
      totalTratamiento: previous?.totalTratamiento,
      saldoPendiente: previous?.saldoPendiente,
      notas: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    String? previousPrimaryId;
    if (previous != null && previous.isPrimary != treatment.isPrimary) {
      previousPrimaryId = previous.id;
    }

    await ref
        .read(savePatientTreatmentProvider.notifier)
        .saveTreatment(
          patientId: widget.patientId,
          treatment: treatment,
          previousPrimaryId: previousPrimaryId,
        );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _mapTreatmentError(Object error) {
    final raw = error.toString();
    if (raw.contains('TREATMENT_NAME_REQUIRED')) {
      return 'Debes ingresar el nombre del tratamiento.';
    }
    if (raw.contains('TREATMENT_BASE_REQUIRED')) {
      return 'Debes seleccionar el tipo base del tratamiento.';
    }
    if (raw.contains('TREATMENT_CATEGORY_REQUIRED')) {
      return 'La categoría del tratamiento es obligatoria.';
    }
    if (raw.contains('TREATMENT_SUBTYPE_REQUIRED')) {
      return 'Debes seleccionar el subtipo para este tratamiento.';
    }
    if (raw.contains('TREATMENT_STATUS_INVALID')) {
      return 'El estado seleccionado no es válido.';
    }
    return 'No se pudo guardar el tratamiento. Intenta de nuevo.';
  }
}
