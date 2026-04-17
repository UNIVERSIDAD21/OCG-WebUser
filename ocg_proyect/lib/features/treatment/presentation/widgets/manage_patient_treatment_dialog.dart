import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_button.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../payments/data/models/financial_item_model.dart';
import '../../../payments/data/models/treatment_financial_summary_model.dart';
import '../../../payments/providers/treatment_financial_provider.dart';
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
    this.patientName,
    this.initialTreatment,
  });

  final String patientId;
  final String? patientName;
  final PatientTreatment? initialTreatment;

  @override
  ConsumerState<ManagePatientTreatmentDialog> createState() => _ManagePatientTreatmentDialogState();
}

class _ManagePatientTreatmentDialogState extends ConsumerState<ManagePatientTreatmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: r'$ ', decimalDigits: 0);

  late final TextEditingController _customNameController;
  late final TextEditingController _notesController;
  late final TextEditingController _cleaningController;
  late final TextEditingController _controlController;

  late String _baseTreatment;
  late String _category;
  late String _status;
  String? _subtype;
  late TreatmentStage _stage;
  late bool _isPrimary;
  late DateTime _fechaInicio;
  late List<_FinancialItemDraft> _financialItems;

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
    _cleaningController = TextEditingController(
      text: (initial?.suggestedCleaningEveryMonths ?? 3).toString(),
    );
    _controlController = TextEditingController(
      text: (initial?.suggestedControlEveryMonths ?? 6).toString(),
    );

    _financialItems = _defaultDraftItemsForBaseTreatment(
      initial?.tipoBase ?? _effectiveBaseTreatment,
      previousItems: null,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final treatment = widget.initialTreatment;
      if (treatment == null) return;
      final itemsAsync = ref.read(
        treatmentFinancialItemsProvider((patientId: widget.patientId, treatmentId: treatment.id)),
      );
      itemsAsync.whenData((items) {
        if (!mounted || items.isEmpty) return;
        setState(() {
          _financialItems = items
              .map(_FinancialItemDraft.fromModel)
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
        });
      });
    });
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _notesController.dispose();
    _cleaningController.dispose();
    _controlController.dispose();
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

  int get _cleaningMonths => int.tryParse(_cleaningController.text.trim()) ?? 3;
  int get _controlMonths => int.tryParse(_controlController.text.trim()) ?? 6;

  bool get _isValid {
    if (_effectiveName.trim().isEmpty) return false;
    if (_effectiveBaseTreatment.trim().isEmpty) return false;
    if (_requiresSubtype && (_subtype == null || _subtype!.trim().isEmpty)) return false;
    if (_cleaningMonths <= 0 || _controlMonths <= 0) return false;
    if (_financialItems.isEmpty) return false;
    if (!_financialItems.any((item) => item.active && item.kind == 'initial')) return false;
    if (!_financialItems.any((item) => item.active && item.kind == 'controls')) return false;
    for (final item in _financialItems) {
      if (item.name.trim().isEmpty) return false;
      if (item.amount < 0) return false;
    }
    final activeNames = <String>{};
    for (final item in _financialItems.where((item) => item.active)) {
      final normalized = FinancialItemModel.normalizeName(item.name);
      if (normalized.isEmpty) return false;
      if (activeNames.contains(normalized)) return false;
      activeNames.add(normalized);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(savePatientTreatmentProvider);
    final saveFinancialState = ref.watch(saveTreatmentFinancialItemsProvider);
    final isLoading = saveState.isLoading || saveFinancialState.isLoading;
    final catalogItems = ref.watch(treatmentCatalogProvider).asData?.value ?? const <TreatmentCatalogItem>[];
    final visibleBaseOptions = <String>{...kBaseTreatmentOptions, ...catalogItems.map((item) => item.baseType)}.toList()
      ..sort((a, b) => PatientTreatment.labelForBaseTreatment(a).compareTo(PatientTreatment.labelForBaseTreatment(b)));

    final financialSummary = _buildFinancialSummary();
    final patientLabel = widget.patientName?.trim().isNotEmpty == true
        ? widget.patientName!.trim()
        : widget.patientId;

    final media = MediaQuery.of(context).size;
    final dialogWidth = media.width > 1240 ? 1160.0 : media.width - 48;
    final dialogHeight = media.height > 940 ? 900.0 : media.height - 48;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: dialogWidth.clamp(320.0, 1160.0),
        height: dialogHeight.clamp(420.0, 900.0),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, patientLabel),
                const SizedBox(height: 20),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: SingleChildScrollView(
                                primary: false,
                                child: _buildClinicalSection(context, visibleBaseOptions, isLoading),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 7,
                              child: SingleChildScrollView(
                                primary: false,
                                child: _buildFinancialSection(context, isLoading, financialSummary),
                              ),
                            ),
                          ],
                        );
                      }
                      return SingleChildScrollView(
                        primary: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildClinicalSection(context, visibleBaseOptions, isLoading),
                            const SizedBox(height: 18),
                            _buildFinancialSection(context, isLoading, financialSummary),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OcgButton(
                      label: 'Cancelar',
                      variant: OcgButtonVariant.outline,
                      onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                    ),
                    OcgButton(
                      label: widget.initialTreatment == null ? 'Guardar tratamiento' : 'Guardar cambios',
                      isLoading: isLoading,
                      onPressed: !_isValid || isLoading ? null : _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String patientLabel) {
    final firstTreatment = widget.initialTreatment == null;
    final principalLabel = firstTreatment
        ? 'Este tratamiento quedará como principal si es el primero del paciente.'
        : (_isPrimary ? 'Tratamiento principal activo.' : 'Tratamiento secundario.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.initialTreatment == null ? 'Crear tratamiento' : 'Editar tratamiento',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: OcgColors.espresso,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Paciente: $patientLabel',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: OcgColors.espresso,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configura el tratamiento clínico y su estructura de costos.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OcgColors.espresso.withValues(alpha: 0.82),
                ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OcgColors.ivory,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_isPrimary ? Icons.star : Icons.layers_outlined, color: OcgColors.bronze, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    principalLabel,
                    style: const TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w700,
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

  Widget _buildClinicalSection(
    BuildContext context,
    List<String> visibleBaseOptions,
    bool isLoading,
  ) {
    return _SectionCard(
      title: 'Configuración clínica',
      subtitle: 'Tipo, subtipo, estado, seguimiento y prioridad del tratamiento.',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _baseTreatment,
                  decoration: const InputDecoration(labelText: 'Tipo de tratamiento'),
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
                          final previousItems = List<_FinancialItemDraft>.from(_financialItems);
                          setState(() {
                            _baseTreatment = value;
                            if (!_requiresSubtype) _subtype = null;
                            _financialItems = _defaultDraftItemsForBaseTreatment(
                              _effectiveBaseTreatment,
                              previousItems: previousItems,
                            );
                          });
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: FilledButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() => _baseTreatment = '__custom__');
                            },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Agregar nuevo tratamiento'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isCustomBase) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customNameController,
              enabled: !isLoading,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre global del tratamiento',
                hintText: 'Ej. Obturación, Expansión rápida maxilar',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            runSpacing: 12,
            spacing: 12,
            children: [
              SizedBox(
                width: 260,
                child: TextFormField(
                  initialValue: _category,
                  enabled: !isLoading,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  onChanged: (value) =>
                      _category = _normalizeValue(value).isEmpty ? 'ortodoncia' : _normalizeValue(value),
                ),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Estado inicial'),
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
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<TreatmentStage>(
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
              ),
            ],
          ),
          if (_requiresSubtype) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _subtype,
              decoration: const InputDecoration(
                labelText: 'Subtipo obligatorio',
                helperText: 'Para Convencional y Autoligado debes elegir Estético o Metálico.',
              ),
              validator: (_) {
                if (_requiresSubtype && (_subtype == null || _subtype!.trim().isEmpty)) {
                  return 'Debes elegir un subtipo.';
                }
                return null;
              },
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
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cleaningController,
                  keyboardType: TextInputType.number,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Limpieza cada (meses)',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Ingresa un número válido';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _controlController,
                  keyboardType: TextInputType.number,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Control cada (meses)',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Ingresa un número válido';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _isPrimary,
            onChanged: isLoading ? null : (value) => setState(() => _isPrimary = value),
            title: const Text('Indicador de tratamiento principal'),
            subtitle: const Text('Si es el primer tratamiento del paciente, debe quedar marcado como principal.'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            enabled: !isLoading,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notas clínicas',
              hintText: 'Ej. Seguimiento sugerido, observaciones del caso, restricciones o contexto clínico.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSection(
    BuildContext context,
    bool isLoading,
    TreatmentFinancialSummaryModel summary,
  ) {
    return Column(
      children: [
        _SectionCard(
          title: 'Conceptos financieros base',
          subtitle: 'El total del tratamiento se calcula con la suma de conceptos activos.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._financialItems.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: entry.key == _financialItems.length - 1 ? 0 : 12),
                  child: _buildFinancialItemCard(context, entry.value, isLoading),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : _showAddConceptDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar nuevo concepto'),
                ),
              ),
              const SizedBox(height: 12),
              if (_activeNameConflict != null)
                Text(
                  _activeNameConflict!,
                  style: const TextStyle(
                    color: OcgColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (_switchWarning != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8B04F)),
                  ),
                  child: Text(
                    _switchWarning!,
                    style: const TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Monto total del tratamiento',
          subtitle: 'Resultado autocalculado con Inicial + Controles + concepto base + extras activos.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currency.format(summary.totalAmount),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: OcgColors.espresso,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Este valor no se edita manualmente. Se genera a partir de los conceptos financieros activos.',
                style: TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Resumen financiero',
          subtitle: 'Snapshot antes de guardar, separado de los pagos reales del paciente.',
          child: Column(
            children: [
              _summaryRow('Moneda', summary.currency),
              _summaryRow('Subtotal', _currency.format(summary.subtotalAmount)),
              _summaryRow('Descuento', _currency.format(summary.discountAmount)),
              _summaryRow('Total', _currency.format(summary.totalAmount), emphasize: true),
              _summaryRow('Pagado', _currency.format(summary.paidAmount)),
              _summaryRow('Saldo pendiente', _currency.format(summary.pendingAmount), emphasize: true),
              _summaryRow('Conceptos activos', '${summary.itemsCount}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialItemCard(
    BuildContext context,
    _FinancialItemDraft item,
    bool isLoading,
  ) {
    final required = item.isRequired;
    final effectiveDeleteAllowed = !required;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.active ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: required ? OcgColors.bronze.withValues(alpha: 0.42) : OcgColors.espresso.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: OcgColors.espresso,
                        decoration: item.active ? null : TextDecoration.lineThrough,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Renombrar concepto',
                onPressed: isLoading ? null : () => _showRenameConceptDialog(item),
                icon: const Icon(Icons.edit_outlined),
              ),
              if (effectiveDeleteAllowed)
                IconButton(
                  tooltip: item.active ? 'Desactivar concepto' : 'Activar concepto',
                  onPressed: isLoading
                      ? null
                      : () {
                          setState(() {
                            final index = _financialItems.indexWhere((draft) => draft.id == item.id);
                            if (index == -1) return;
                            _financialItems[index] = _financialItems[index].copyWith(active: !item.active);
                          });
                        },
                  icon: Icon(item.active ? Icons.delete_outline : Icons.restore_from_trash_outlined),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Valor: ${_currency.format(item.amount)} COP',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: OcgColors.espresso,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: isLoading ? null : () => _showAmountDialog(item),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Editar monto'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PillLabel(
                text: required ? 'Obligatorio' : 'Opcional',
                background: required ? const Color(0xFFFFF2DB) : const Color(0xFFF2F4F7),
                foreground: OcgColors.espresso,
              ),
              _PillLabel(
                text: item.active ? 'Activo' : 'Inactivo',
                background: item.active ? const Color(0xFFEAF7EE) : const Color(0xFFF0F0F0),
                foreground: item.active ? const Color(0xFF2E7D4C) : const Color(0xFF666666),
              ),
              _PillLabel(
                text: 'Orden ${item.order}',
                background: const Color(0xFFF4EFE7),
                foreground: OcgColors.espresso,
              ),
            ],
          ),
          if (required) ...[
            const SizedBox(height: 8),
            const Text(
              'Este concepto no se puede eliminar ni dejar vacío.',
              style: TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    final style = TextStyle(
      color: OcgColors.espresso,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
      fontSize: emphasize ? 15 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
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

  Future<void> _showAddConceptDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    try {
      final created = await showDialog<_FinancialItemDraft>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Agregar nuevo concepto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del concepto',
                  hintText: 'Ej. Blanqueamiento extra',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto en COP',
                  hintText: 'Ej. 200000',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? 0;
                if (name.isEmpty || amount < 0) return;
                Navigator.of(context).pop(
                  _FinancialItemDraft(
                    id: 'extra_${DateTime.now().microsecondsSinceEpoch}',
                    name: FinancialItemModel.humanize(name),
                    kind: 'extra',
                    amount: amount,
                    deletable: true,
                    editableName: true,
                    order: _nextOrder,
                    active: true,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );

      if (created == null) return;
      setState(() {
        _financialItems = [..._financialItems, created]..sort((a, b) => a.order.compareTo(b.order));
      });
    } finally {
      nameController.dispose();
      amountController.dispose();
    }
  }

  Future<void> _showRenameConceptDialog(_FinancialItemDraft item) async {
    final controller = TextEditingController(text: item.name);
    try {
      final renamed = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Renombrar concepto'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre del concepto'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (renamed == null || renamed.trim().isEmpty) return;
      setState(() {
        final index = _financialItems.indexWhere((draft) => draft.id == item.id);
        if (index == -1) return;
        _financialItems[index] = _financialItems[index].copyWith(
          name: FinancialItemModel.humanize(renamed),
        );
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showAmountDialog(_FinancialItemDraft item) async {
    final controller = TextEditingController(text: item.amount.toInt().toString());
    try {
      final updated = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Editar monto'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monto en COP',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(controller.text.trim());
                if (amount == null || amount < 0) return;
                Navigator.of(context).pop(amount);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (updated == null) return;
      setState(() {
        final index = _financialItems.indexWhere((draft) => draft.id == item.id);
        if (index == -1) return;
        _financialItems[index] = _financialItems[index].copyWith(amount: updated);
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() {});
      return;
    }

    final diagnostics = <String, dynamic>{
      'step': 'enter_submit',
      'patientId': widget.patientId,
      'initialTreatmentId': widget.initialTreatment?.id,
      'baseTreatment': _effectiveBaseTreatment,
      'subtype': _subtype,
      'itemsDraftCount': _financialItems.length,
      'activeItemsDraftCount': _financialItems.where((item) => item.active).length,
    };

    try {
      final authService = ref.read(authServiceProvider);
      final currentUser = ref.read(authStateProvider).asData?.value;
      diagnostics['currentUserUid'] = currentUser?.uid;
      diagnostics['currentUserEmail'] = currentUser?.email;
      if (currentUser == null) {
        throw Exception('AUTH_USER_MISSING');
      }

      final email = currentUser.email?.trim();
      if (email != null && email.isNotEmpty) {
        await authService.bootstrapAdminByEmailIfAllowed(email);
      }
      final session = await authService.inspectCurrentSession();
      diagnostics['session'] = session;
      diagnostics['resolvedRole'] = session['refreshedRole'] ?? session['cachedRole'];
      _debugSave('session_resolved', diagnostics);

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
      final treatmentId = widget.initialTreatment?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
      final summary = _buildFinancialSummary();
      final treatment = (widget.initialTreatment ??
              PatientTreatment(
                id: treatmentId,
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
        id: treatmentId,
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
        notas: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        suggestedCleaningEveryMonths: _cleaningMonths,
        suggestedControlEveryMonths: _controlMonths,
        totalTratamiento: summary.totalAmount,
        saldoPendiente: summary.pendingAmount,
        clearSubtype: !_requiresSubtype,
      );

      final previousBaseType = widget.initialTreatment?.tipoBase;
      if (previousBaseType != null && previousBaseType != treatment.tipoBase) {
        final confirmed = await _confirmBaseTypeChange(previousBaseType, treatment.tipoBase);
        if (!confirmed) return;
      }

      diagnostics['step'] = 'before_save_treatment';
      diagnostics['treatmentId'] = treatment.id;
      diagnostics['treatmentPayload'] = {
        'id': treatment.id,
        'patientId': treatment.patientId,
        'name': treatment.nombre,
        'baseType': treatment.tipoBase,
        'subtype': treatment.subtipo,
        'isPrimary': treatment.isPrimary,
        'totalTratamiento': treatment.totalTratamiento,
        'saldoPendiente': treatment.saldoPendiente,
      };
      _debugSave('before_save_treatment', diagnostics);

      await ref.read(savePatientTreatmentProvider.notifier).saveTreatment(
            patientId: widget.patientId,
            treatment: treatment,
            previousPrimaryId: widget.initialTreatment?.isPrimary == true ? widget.initialTreatment!.id : null,
          );

      diagnostics['step'] = 'after_save_treatment';
      _debugSave('after_save_treatment', diagnostics);

      final items = _financialItems
          .map(
            (draft) => draft.toModel(
              patientId: widget.patientId,
              treatmentId: treatment.id,
              updatedBy: adminId,
            ),
          )
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      diagnostics['step'] = 'before_replace_items';
      diagnostics['financialItemsPayload'] = items
          .map((item) => {
                'id': item.id,
                'name': item.name,
                'kind': item.kind,
                'amount': item.amount,
                'active': item.active,
                'order': item.order,
              })
          .toList();
      _debugSave('before_replace_items', diagnostics);

      await ref.read(saveTreatmentFinancialItemsProvider.notifier).replaceItems(
            patientId: widget.patientId,
            treatment: treatment,
            items: items,
            updatedBy: adminId,
          );

      diagnostics['step'] = 'save_completed';
      _debugSave('save_completed', diagnostics);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      diagnostics['step'] = 'save_failed';
      diagnostics['error'] = e.toString();
      diagnostics['errorType'] = e.runtimeType.toString();
      if (e is FirebaseException) {
        diagnostics['firebaseCode'] = e.code;
        diagnostics['firebaseMessage'] = e.message;
        diagnostics['plugin'] = e.plugin;
      }
      _debugSave('save_failed', diagnostics, stackTrace: st);
      if (!mounted) return;
      final message = _mapError(e, diagnostics: diagnostics);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
      );
      await _showTechnicalErrorDialog(message, diagnostics);
    }
  }

  Future<bool> _confirmBaseTypeChange(String from, String to) async {
    final fromOrthopedics = from == 'ortopedia';
    final toOrthopedics = to == 'ortopedia';
    if (fromOrthopedics == toOrthopedics) return true;

    final source = fromOrthopedics ? 'Aparato 1' : 'Retenedores';
    final target = toOrthopedics ? 'Aparato 1' : 'Retenedores';

    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cambio de tipo'),
        content: Text(
          'Al cambiar el tipo de tratamiento, el concepto base "$source" se convertirá en "$target" conservando su monto actual cuando sea posible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return decision ?? false;
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

  int _nextOrderFor(List<_FinancialItemDraft> items) {
    if (items.isEmpty) return 1;
    return items.map((item) => item.order).reduce((a, b) => a > b ? a : b) + 1;
  }

  int get _nextOrder => _nextOrderFor(_financialItems);

  List<_FinancialItemDraft> _defaultDraftItemsForBaseTreatment(
    String baseType, {
    List<_FinancialItemDraft>? previousItems,
  }) {
    final previous = previousItems ?? const <_FinancialItemDraft>[];
    final previousById = {for (final item in previous) item.id: item};
    final previousByKind = {for (final item in previous) item.kind: item};
    final wantsOrthopedics = baseType == 'ortopedia';

    _FinancialItemDraft resolveBase({
      required String id,
      required String kind,
      required String name,
      required int order,
      required bool deletable,
    }) {
      final existing = previousById[id] ?? previousByKind[kind];
      if (existing != null) {
        return existing.copyWith(id: id, kind: kind, name: existing.name.isEmpty ? name : existing.name, order: order);
      }

      final transformed = wantsOrthopedics
          ? previousById['retainers']
          : previousById['appliance_1'];
      if (transformed != null) {
        return transformed.copyWith(
          id: id,
          kind: kind,
          name: name,
          order: order,
          deletable: deletable,
          active: true,
        );
      }

      return _FinancialItemDraft(
        id: id,
        name: name,
        kind: kind,
        amount: 0,
        deletable: deletable,
        editableName: true,
        order: order,
        active: true,
      );
    }

    final requiredItems = <_FinancialItemDraft>[
      resolveBase(
        id: 'initial',
        kind: 'initial',
        name: 'Inicial',
        order: 1,
        deletable: false,
      ),
      resolveBase(
        id: 'controls',
        kind: 'controls',
        name: 'Controles',
        order: 2,
        deletable: false,
      ),
      resolveBase(
        id: wantsOrthopedics ? 'appliance_1' : 'retainers',
        kind: wantsOrthopedics ? 'appliance' : 'retainers',
        name: wantsOrthopedics ? 'Aparato 1' : 'Retenedores',
        order: 3,
        deletable: true,
      ),
    ];

    final extras = previous
        .where((item) => !{'initial', 'controls', 'retainers', 'appliance_1'}.contains(item.id))
        .map((item) => item.copyWith(order: item.order < 4 ? _nextOrderFor(previous) : item.order))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return [...requiredItems, ...extras];
  }

  TreatmentFinancialSummaryModel _buildFinancialSummary() {
    final active = _financialItems.where((item) => item.active).toList()..sort((a, b) => a.order.compareTo(b.order));
    final total = active.fold<double>(0, (sum, item) => sum + item.amount);
    final previousPaid = widget.initialTreatment == null
        ? 0.0
        : ((widget.initialTreatment!.totalTratamiento ?? 0) - (widget.initialTreatment!.saldoPendiente ?? 0))
            .clamp(0, double.infinity)
            .toDouble();
    final pending = (total - previousPaid).clamp(0, double.infinity).toDouble();
    return TreatmentFinancialSummaryModel(
      currency: 'COP',
      subtotalAmount: total,
      discountAmount: 0,
      totalAmount: total,
      paidAmount: previousPaid,
      pendingAmount: pending,
      itemsCount: active.length,
      lastPricingUpdateAt: DateTime.now(),
    );
  }

  String? get _activeNameConflict {
    final seen = <String>{};
    for (final item in _financialItems.where((item) => item.active)) {
      final normalized = FinancialItemModel.normalizeName(item.name);
      if (normalized.isEmpty) {
        return 'Todos los conceptos activos deben tener nombre válido.';
      }
      if (seen.contains(normalized)) {
        return 'No puede haber conceptos activos con el mismo nombre.';
      }
      seen.add(normalized);
    }
    return null;
  }

  String? get _switchWarning {
    if (_effectiveBaseTreatment == 'ortopedia') {
      return 'Si cambias a otro tipo, Aparato 1 se convertirá en Retenedores sin perder el monto actual.';
    }
    if (_financialItems.any((item) => item.id == 'retainers')) {
      return 'Si cambias a Ortopedia, Retenedores se convertirá en Aparato 1 sin perder el monto actual.';
    }
    return null;
  }

  String _mapError(Object error, {Map<String, dynamic>? diagnostics}) {
    final raw = error.toString();
    if (raw.contains('AUTH_USER_MISSING')) {
      return 'No hay usuario autenticado en la sesión actual al intentar guardar.';
    }
    if (raw.contains('permission-denied')) {
      final role = diagnostics?['resolvedRole'];
      return 'Firebase rechazó la escritura por permisos (permission-denied). Rol resuelto: $role.';
    }
    if (raw.contains('TREATMENT_SUBTYPE_REQUIRED')) {
      return 'Convencional y Autoligado requieren subtipo obligatorio.';
    }
    if (raw.contains('TREATMENT_NAME_REQUIRED')) {
      return 'Debes indicar el nombre del tratamiento.';
    }
    if (raw.contains('REQUIRED_FINANCIAL_ITEMS_MISSING')) {
      return 'Inicial y Controles son obligatorios y deben permanecer activos.';
    }
    if (raw.contains('FINANCIAL_ITEM_DUPLICATE_NAME')) {
      return 'No puedes guardar conceptos activos con nombres repetidos.';
    }
    if (raw.contains('FINANCIAL_ITEM_NEGATIVE_AMOUNT')) {
      return 'Ningún concepto puede tener monto negativo.';
    }
    return raw;
  }

  void _debugSave(String stage, Map<String, dynamic> diagnostics, {StackTrace? stackTrace}) {
    debugPrint('[ManagePatientTreatmentDialog][$stage] ${diagnostics.toString()}');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  Future<void> _showTechnicalErrorDialog(String message, Map<String, dynamic> diagnostics) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error al guardar tratamiento'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: SelectableText(
              '$message\n\nDiagnóstico:\n${const JsonEncoder.withIndent('  ').convert(diagnostics)}',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: OcgColors.espresso,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OcgColors.espresso.withValues(alpha: 0.78),
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FinancialItemDraft {
  const _FinancialItemDraft({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    required this.deletable,
    required this.editableName,
    required this.order,
    required this.active,
  });

  final String id;
  final String name;
  final String kind;
  final double amount;
  final bool deletable;
  final bool editableName;
  final int order;
  final bool active;

  bool get isRequired => kind == 'initial' || kind == 'controls';

  factory _FinancialItemDraft.fromModel(FinancialItemModel model) {
    return _FinancialItemDraft(
      id: model.id,
      name: model.name,
      kind: model.kind,
      amount: model.amount,
      deletable: model.deletable,
      editableName: model.editableName,
      order: model.order,
      active: model.active,
    );
  }

  _FinancialItemDraft copyWith({
    String? id,
    String? name,
    String? kind,
    double? amount,
    bool? deletable,
    bool? editableName,
    int? order,
    bool? active,
  }) {
    return _FinancialItemDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      deletable: deletable ?? this.deletable,
      editableName: editableName ?? this.editableName,
      order: order ?? this.order,
      active: active ?? this.active,
    );
  }

  FinancialItemModel toModel({
    required String patientId,
    required String treatmentId,
    required String updatedBy,
  }) {
    final now = DateTime.now();
    return FinancialItemModel(
      id: id,
      patientId: patientId,
      treatmentId: treatmentId,
      name: name.trim(),
      normalizedName: FinancialItemModel.normalizeName(name),
      kind: kind,
      amount: amount,
      deletable: deletable,
      editableName: editableName,
      order: order,
      active: active,
      createdByAdmin: true,
      createdBy: updatedBy,
      updatedBy: updatedBy,
      createdAt: now,
      updatedAt: now,
    );
  }
}
