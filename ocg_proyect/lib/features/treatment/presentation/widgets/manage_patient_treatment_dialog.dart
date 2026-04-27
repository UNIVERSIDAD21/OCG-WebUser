import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/utils/currency_input_formatter.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../payments/data/models/financial_item_model.dart';
import '../../../payments/data/models/treatment_financial_summary_model.dart';
import '../../../payments/providers/treatment_financial_provider.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../data/models/patient_treatment.dart';
import '../../data/models/treatment_catalog_item.dart';
import '../../providers/patient_treatments_provider.dart';
import '../../providers/treatment_catalog_provider.dart';

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
  final _currency = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  late final TextEditingController _visibleNameCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _cleaningMonthsCtrl;
  late final TextEditingController _controlMonthsCtrl;
  late final TextEditingController _initialAmountCtrl;
  late final TextEditingController _controlsUnitCtrl;
  late final TextEditingController _controlsQtyCtrl;
  late final TextEditingController _thirdConceptCtrl;

  late String _status;
  late TreatmentStage _stage;
  late DateTime _startDate;
  late DateTime _nextCleaningDate;
  late DateTime _nextControlDate;
  late bool _isPrimary;
  String? _selectedCatalogId;
  String? _clinicalTreatmentName;
  late String _baseType;
  String? _subtype;

  final Map<String, TextEditingController> _financialNameCtrls = {};
  final Map<String, TextEditingController> _financialAmountCtrls = {};
  final Map<String, TextEditingController> _financialQtyCtrls = {};

  List<FinancialItemModel>? _draftFinancialItems;
  bool _saving = false;
  bool _creatingCatalogItem = false;
  bool _didSyncInitialFinancialItems = false;
  bool _updatingControllers = false;

  bool get _editing => widget.initialTreatment != null;
  bool get _isOrtopedia => _baseType == 'ortopedia';
  bool get _requiresSubtype =>
      _baseType == 'convencional' || _baseType == 'autoligado';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTreatment;
    _visibleNameCtrl = TextEditingController(
      text: initial?.visibleName ?? initial?.nombre ?? '',
    );
    _notesCtrl = TextEditingController(text: initial?.notas ?? '');
    _cleaningMonthsCtrl = TextEditingController(
      text: (initial?.suggestedCleaningEveryMonths ?? 3).toString(),
    );
    _controlMonthsCtrl = TextEditingController(
      text: (initial?.suggestedControlEveryMonths ?? 6).toString(),
    );
    _initialAmountCtrl = TextEditingController();
    _controlsUnitCtrl = TextEditingController();
    _controlsQtyCtrl = TextEditingController(text: '10');
    _thirdConceptCtrl = TextEditingController();
    _status = initial?.estado ?? 'activo';
    _stage = initial?.etapaActual ?? TreatmentStage.valoracionInicial;
    _startDate = initial?.fechaInicio ?? DateTime.now();
    _nextCleaningDate = initial?.nextCleaningDate ?? _addMonths(_startDate, 3);
    _nextControlDate = initial?.nextControlDate ?? _addMonths(_startDate, 6);
    _isPrimary = initial?.isPrimary ?? true;
    _selectedCatalogId = initial?.catalogTreatmentId;
    _clinicalTreatmentName = initial?.clinicalTreatmentName ?? initial?.nombre;
    _baseType = initial?.tipoBase ?? 'convencional';
    _subtype = initial?.subtipo ?? (_requiresSubtype ? 'metalico' : null);

    for (final controller in [
      _initialAmountCtrl,
      _controlsUnitCtrl,
      _controlsQtyCtrl,
      _thirdConceptCtrl,
    ]) {
      controller.addListener(_onFinancialFieldChanged);
    }
  }

  @override
  void dispose() {
    _visibleNameCtrl.dispose();
    _notesCtrl.dispose();
    _cleaningMonthsCtrl.dispose();
    _controlMonthsCtrl.dispose();
    _initialAmountCtrl.dispose();
    _controlsUnitCtrl.dispose();
    _controlsQtyCtrl.dispose();
    _thirdConceptCtrl.dispose();
    for (final controller in _financialNameCtrls.values) {
      controller.dispose();
    }
    for (final controller in _financialAmountCtrls.values) {
      controller.dispose();
    }
    for (final controller in _financialQtyCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFinancialFieldChanged() {
    if (_updatingControllers || !mounted) return;
    setState(() {
      _draftFinancialItems = _mergeInlineValuesIntoItems(
        _currentFinancialItems(const <FinancialItemModel>[]),
        _previewTreatment(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(treatmentCatalogProvider);
    final existingTreatments =
        ref.watch(patientTreatmentsProvider(widget.patientId)).asData?.value ??
        const <PatientTreatment>[];
    final otherPrimary = existingTreatments
        .where((t) => t.id != widget.initialTreatment?.id && t.isPrimary)
        .cast<PatientTreatment?>()
        .firstWhere((t) => t != null, orElse: () => null);
    final canTogglePrimary = !_editing || !_isPrimary || otherPrimary != null;

    final remoteItemsAsync = widget.initialTreatment == null
        ? AsyncValue<List<FinancialItemModel>>.data(
            _draftFinancialItems ??
                _defaultDraftFinancialItems(_previewTreatment()),
          )
        : ref.watch(
            treatmentFinancialItemsProvider((
              patientId: widget.patientId,
              treatmentId: widget.initialTreatment!.id,
            )),
          );

    final remoteItems =
        remoteItemsAsync.asData?.value ?? const <FinancialItemModel>[];
    if (_editing && remoteItems.isNotEmpty && !_didSyncInitialFinancialItems) {
      _draftFinancialItems = remoteItems.map((item) => item.copyWith()).toList();
      _syncFinancialItemControllers(_draftFinancialItems!);
      _syncFinancialControllers(_draftFinancialItems!);
      _didSyncInitialFinancialItems = true;
    }

    final previewTreatment = widget.initialTreatment ?? _previewTreatment();
    final effectiveFinancialItems = _mergeInlineValuesIntoItems(
      _currentFinancialItems(remoteItems),
      previewTreatment,
    );
    final summary = _buildFinancialSummary(effectiveFinancialItems);

    final media = MediaQuery.sizeOf(context);
    final wide = media.width >= 980;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: wide ? 1120 : media.width - 32,
        constraints: BoxConstraints(maxHeight: media.height - 48),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFCF8), Color(0xFFF7F0E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFE7DDD2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x262C2016),
              blurRadius: 36,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(otherPrimary),
                const SizedBox(height: 20),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 900) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildClinicalColumn(
                                  canTogglePrimary,
                                  otherPrimary,
                                  catalogAsync,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 4,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(left: 8),
                                child: _buildFinancialColumn(
                                  remoteItemsAsync,
                                  effectiveFinancialItems,
                                  summary,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildClinicalColumn(
                              canTogglePrimary,
                              otherPrimary,
                              catalogAsync,
                            ),
                            const SizedBox(height: 18),
                            _buildFinancialColumn(
                              remoteItemsAsync,
                              effectiveFinancialItems,
                              summary,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFD9CCBE)),
                        foregroundColor: OcgColors.espresso,
                        backgroundColor: Colors.white.withOpacity(0.7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _saving
                          ? null
                          : () => _submit(effectiveFinancialItems, summary),
                      style: FilledButton.styleFrom(
                        backgroundColor: OcgColors.espresso,
                        foregroundColor: OcgColors.ivory,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _saving
                            ? 'Guardando...'
                            : (_editing
                                  ? 'Guardar cambios'
                                  : 'Guardar tratamiento'),
                      ),
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

  Widget _buildHeader(PatientTreatment? otherPrimary) {
    final badgeText = _isPrimary
        ? 'Tratamiento principal activo'
        : (otherPrimary != null
              ? 'Secundario · Principal actual: ${otherPrimary.displayName}'
              : 'Tratamiento secundario');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7EFE6), Color(0xFFFDF9F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5D8CA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: OcgColors.espresso,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.biotech_outlined,
              color: OcgColors.ivory,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editing ? 'Editar tratamiento' : 'Crear tratamiento',
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Paciente: ${widget.patientName}',
                  style: const TextStyle(
                    color: Color(0xFF6E5644),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Configura el tratamiento clínico y su estructura de costos.',
                  style: TextStyle(color: Color(0xFF8A6F59), height: 1.4),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEE1D3),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE0C7AF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: OcgColors.espresso,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: OcgColors.espresso,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalColumn(
    bool canTogglePrimary,
    PatientTreatment? otherPrimary,
    AsyncValue<List<TreatmentCatalogItem>> catalogAsync,
  ) {
    return Column(
      children: [
        _sectionCard(
          title: 'Configuración clínica',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              catalogAsync.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (_, __) => _buildCatalogFallbackSelector(),
                data: (rawCatalog) {
                  final catalog = _catalogOrDefaults(rawCatalog);
                  final selected = _resolveCatalogSelection(catalog);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCatalogSelectorField(catalog, selected),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selected == null
                                  ? 'Selecciona un tratamiento del catálogo o crea uno nuevo.'
                                  : 'Catálogo activo: ${selected.name} · ${_categoryLabel(selected.category)}',
                              style: const TextStyle(
                                color: Color(0xFF8A6F59),
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: (_saving || _creatingCatalogItem)
                                ? null
                                : () => _openCreateCatalogTreatmentDialog(catalog),
                            icon: _creatingCatalogItem
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_business_outlined, size: 18),
                            label: Text(
                              _creatingCatalogItem
                                  ? 'Creando...'
                                  : 'Nuevo tratamiento',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _visibleNameCtrl,
                        decoration: _inputDecoration(
                          'Nombre visible para este paciente',
                          hint:
                              selected?.name ??
                              'Autogenerado si lo dejas vacío',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              if (_requiresSubtype)
                DropdownButtonFormField<String>(
                  key: ValueKey('subtype-$_subtype'),
                  initialValue: _subtype,
                  decoration: _inputDecoration('Subtipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'metalico',
                      child: Text('Metálico'),
                    ),
                    DropdownMenuItem(
                      value: 'estetico',
                      child: Text('Estético'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _subtype = value),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Selecciona subtipo'
                      : null,
                ),
              if (_requiresSubtype) const SizedBox(height: 14),
              DropdownButtonFormField<TreatmentStage>(
                key: ValueKey('stage-${_stage.name}'),
                initialValue: _stage,
                decoration: _inputDecoration('Etapa actual'),
                items: TreatmentStage.values
                    .map(
                      (stage) => DropdownMenuItem<TreatmentStage>(
                        value: stage,
                        child: Text(stageNames[stage] ?? stage.name),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _stage = value);
                      },
              ),
              const SizedBox(height: 14),
              _dateRow('Inicio', _startDate, _saving, _pickStartDate),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cleaningMonthsCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration('Limpieza cada (meses)'),
                      validator: _positiveIntValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _controlMonthsCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration('Control cada (meses)'),
                      validator: _positiveIntValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _dateRow(
                'Próxima limpieza',
                _nextCleaningDate,
                _saving,
                () => _pickRecurringDate(isCleaning: true),
              ),
              const SizedBox(height: 10),
              _dateRow(
                'Próximo control',
                _nextControlDate,
                _saving,
                () => _pickRecurringDate(isCleaning: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionCard(
          title: 'Indicador de tratamiento principal',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _isPrimary && !canTogglePrimary
                      ? 'Este es el único tratamiento principal actual. Para cambiarlo, marca otro tratamiento como principal.'
                      : 'Activa este switch si deseas que este tratamiento sea el principal del paciente.',
                  style: const TextStyle(
                    color: Color(0xFF8A6F59),
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: _isPrimary,
                onChanged: (!canTogglePrimary || _saving)
                    ? null
                    : (value) => setState(() => _isPrimary = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionCard(
          title: 'Notas clínicas',
          child: TextFormField(
            controller: _notesCtrl,
            minLines: 5,
            maxLines: 7,
            decoration: _inputDecoration(
              'Notas clínicas',
              hint: 'Notas clínicas',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialColumn(
    AsyncValue<List<FinancialItemModel>> financialItemsAsync,
    List<FinancialItemModel> effectiveItems,
    TreatmentFinancialSummaryModel summary,
  ) {
    final activeCount = effectiveItems.where((item) => item.active).length;
    final orderedItems = _orderedFinancialItems(effectiveItems);
    _syncFinancialItemControllers(orderedItems);

    return Column(
      children: [
        _sectionCard(
          title: 'Conceptos financieros del tratamiento',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edita aquí mismo los conceptos. Inicial y Controles son obligatorios; Retenedores, Aparato 1 y extras pueden activarse, desactivarse o eliminarse.',
                style: TextStyle(color: Color(0xFF8A6F59), height: 1.4),
              ),
              const SizedBox(height: 14),
              financialItemsAsync.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No se pudo cargar el detalle financiero.',
                    style: TextStyle(color: Color(0xFF8A6F59)),
                  ),
                ),
                data: (_) => const SizedBox.shrink(),
              ),
              ...orderedItems.map(_buildFinancialItemCard),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _addExtraFinancialItem,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar concepto financiero'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$activeCount concepto(s) financiero(s) activo(s).',
                style: const TextStyle(
                  color: Color(0xFF8A6F59),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF201611), Color(0xFF3B2A20), Color(0xFF6E5644)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x242C2016),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resultado autocalculado',
                style: TextStyle(
                  color: OcgColors.ivory,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isOrtopedia
                    ? 'Resultado con Inicial + Controles + Aparato 1 + extras activos.'
                    : 'Resultado con Inicial + Controles + Retenedores + extras activos.',
                style: const TextStyle(color: Color(0xFFE4D6CA), height: 1.45),
              ),
              const SizedBox(height: 18),
              Text(
                _currency.format(summary.totalAmount),
                style: const TextStyle(
                  color: OcgColors.ivory,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.ivory.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OcgColors.ivory.withOpacity(0.08)),
                ),
                child: const Text(
                  'Este valor no se edita manualmente. Se genera a partir de los conceptos financieros activos.',
                  style: TextStyle(color: Color(0xFFE4D6CA), height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionCard(
          title: 'Resumen financiero',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Snapshot antes de guardar, separado de los pagos reales del paciente.',
                style: TextStyle(color: Color(0xFF8A6F59), height: 1.4),
              ),
              const SizedBox(height: 14),
              _summaryRow('Moneda', summary.currency),
              _summaryRow('Subtotal', _currency.format(summary.subtotalAmount)),
              _summaryRow(
                'Descuento',
                _currency.format(summary.discountAmount),
              ),
              _summaryRow(
                'Total',
                _currency.format(summary.totalAmount),
                emphasized: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogFallbackSelector() {
    return DropdownButtonFormField<String>(
      key: ValueKey('base-$_baseType'),
      initialValue: _baseType,
      decoration: _inputDecoration('Tratamiento clínico'),
      items: kBaseTreatmentOptions
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(PatientTreatment.labelForBaseTreatment(item)),
            ),
          )
          .toList(),
      onChanged: _saving
          ? null
          : (value) {
              if (value == null) return;
              setState(() {
                _baseType = value;
                _clinicalTreatmentName = PatientTreatment.labelForBaseTreatment(
                  value,
                );
                _selectedCatalogId = value;
                _subtype = _requiresSubtype ? (_subtype ?? 'metalico') : null;
                _adaptThirdConceptForBaseType();
              });
            },
    );
  }

  Widget _buildCatalogSelectorField(
    List<TreatmentCatalogItem> catalog,
    TreatmentCatalogItem? selected,
  ) {
    return FormField<String>(
      initialValue: selected?.id,
      validator: (_) {
        if (((_selectedCatalogId ?? '').trim().isEmpty) && selected == null) {
          return 'Selecciona el tratamiento clínico';
        }
        return null;
      },
      builder: (field) {
        final text = selected?.name ?? _clinicalTreatmentName ?? 'Seleccionar';
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: (_saving || _creatingCatalogItem)
              ? null
              : () async {
                  final picked = await _showCatalogPickerSheet(catalog);
                  if (picked != null) {
                    _handleCatalogSelection(picked.id, catalog);
                    field.didChange(picked.id);
                  }
                },
          child: InputDecorator(
            decoration: _inputDecoration(
              'Tratamiento clínico',
              hint: 'Busca o selecciona un tratamiento',
            ).copyWith(
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.search_rounded),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: text == 'Seleccionar'
                    ? const Color(0xFF8A6F59)
                    : OcgColors.espresso,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinancialItemCard(FinancialItemModel item) {
    final isControls = item.kind == 'controls';
    final lockedRequired = item.kind == 'initial' || item.kind == 'controls';
    final nameController = _financialNameCtrls[item.id]!;
    final amountController = _financialAmountCtrls[item.id]!;
    final qtyController = _financialQtyCtrls[item.id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.active ? Colors.white : const Color(0xFFF8F2EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: lockedRequired
              ? const Color(0xFFD9C3AD)
              : const Color(0xFFE8D8C8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                lockedRequired
                    ? Icons.lock_outline_rounded
                    : Icons.tune_outlined,
                color: lockedRequired ? OcgColors.bronze : OcgColors.espresso,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lockedRequired
                      ? '${item.name} · obligatorio'
                      : item.active
                      ? '${item.name} · activo'
                      : '${item.name} · inactivo',
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Switch.adaptive(
                value: lockedRequired ? true : item.active,
                onChanged: lockedRequired || _saving
                    ? null
                    : (value) => _updateFinancialItem(
                        item.copyWith(active: value),
                      ),
              ),
              if (!lockedRequired && item.deletable)
                IconButton(
                  tooltip: 'Eliminar concepto',
                  onPressed: _saving ? null : () => _removeFinancialItem(item),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final nameField = TextFormField(
                controller: nameController,
                enabled: item.editableName && !lockedRequired && !_saving,
                decoration: _inputDecoration('Nombre del concepto'),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Obligatorio';
                  return null;
                },
                onChanged: (value) => _updateFinancialItemName(item, value),
              );
              final amountField = _moneyField(
                controller: amountController,
                label: isControls ? 'Valor unitario' : 'Monto',
                validator: lockedRequired ? _requiredMoneyValidator : null,
                onChanged: (value) => _updateFinancialItemAmount(item, value),
              );
              final qtyField = TextFormField(
                controller: qtyController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration('Cantidad'),
                validator: isControls ? _positiveIntValidator : null,
                onChanged: (value) => _updateFinancialItemQuantity(item, value),
              );

              if (compact) {
                return Column(
                  children: [
                    nameField,
                    const SizedBox(height: 10),
                    amountField,
                    if (isControls) ...[
                      const SizedBox(height: 10),
                      qtyField,
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: nameField),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: amountField),
                  if (isControls) ...[
                    const SizedBox(width: 10),
                    Expanded(child: qtyField),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            isControls
                ? 'Fórmula: ${_currency.format(item.effectiveUnitAmount)} × ${item.effectiveQuantity} = ${_currency.format(item.computedAmount)}'
                : 'Total: ${_currency.format(item.computedAmount)}',
            style: const TextStyle(
              color: Color(0xFF8A6F59),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9DED2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2C2016),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: OcgColors.bronze,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: 42,
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFFE6D7C7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _dateRow(
    String label,
    DateTime value,
    bool isLoading,
    Future<void> Function() onTap,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8F3ED), Color(0xFFFEFBF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DBCF)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7DBCF)),
            ),
            child: const Icon(
              Icons.event_outlined,
              size: 18,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8A6F59),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(value),
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: isLoading ? null : onTap,
            icon: const Icon(Icons.edit_calendar_outlined, size: 16),
            label: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6E5644),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: emphasized
                  ? const Color(0xFFF1E5D8)
                  : const Color(0xFFF8F3ED),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: emphasized ? OcgColors.espresso : OcgColors.bronze,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        CurrencyInputFormatter(),
      ],
      decoration: _inputDecoration(label),
      validator: validator,
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFCF8F3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE4D8CB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE4D8CB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: OcgColors.bronze, width: 1.4),
      ),
    );
  }

  List<TreatmentCatalogItem> _catalogOrDefaults(
    List<TreatmentCatalogItem> raw,
  ) {
    final active = raw.where((item) => item.active).toList();
    return active.isEmpty ? TreatmentCatalogItem.defaults : active;
  }

  TreatmentCatalogItem? _resolveCatalogSelection(
    List<TreatmentCatalogItem> catalog,
  ) {
    if (_selectedCatalogId != null) {
      for (final item in catalog) {
        if (item.id == _selectedCatalogId) return item;
      }
    }
    if (_clinicalTreatmentName != null) {
      for (final item in catalog) {
        if (item.name.toLowerCase() == _clinicalTreatmentName!.toLowerCase()) {
          return item;
        }
      }
    }
    for (final item in catalog) {
      if (item.baseType == _baseType) return item;
    }
    return catalog.isEmpty ? null : catalog.first;
  }

  void _handleCatalogSelection(
    String? value,
    List<TreatmentCatalogItem> catalog,
  ) {
    if (value == null) return;
    final selected = catalog.firstWhere((item) => item.id == value);
    setState(() {
      _selectedCatalogId = selected.id;
      _clinicalTreatmentName = selected.name;
      _baseType = selected.baseType;
      _subtype = selected.requiresSubtype
          ? ((_subtype != null && selected.allowedSubtypes.contains(_subtype))
                ? _subtype
                : (selected.allowedSubtypes.isNotEmpty
                      ? selected.allowedSubtypes.first
                      : 'metalico'))
          : null;
      if (_visibleNameCtrl.text.trim().isEmpty) {
        _visibleNameCtrl.text = selected.name;
      }
      _adaptThirdConceptForBaseType();
    });
  }

  void _adaptThirdConceptForBaseType() {
    final current =
        _draftFinancialItems ??
        _defaultDraftFinancialItems(_previewTreatment());
    final amount =
        CurrencyInputFormatter.parseToDouble(_thirdConceptCtrl.text) ??
        _findThirdConcept(current)?.amount ??
        0;
    final active = _findThirdConcept(current)?.active ?? true;
    final treatment = _previewTreatment();
    final base = _defaultDraftFinancialItems(treatment);
    final baseThirdIndex = base.indexWhere((item) => _isThirdConcept(item));
    if (baseThirdIndex != -1) {
      base[baseThirdIndex] = base[baseThirdIndex].copyWith(
        amount: amount,
        active: active,
      );
    }
    _draftFinancialItems = _mergeExtras(current, base);
    _syncFinancialControllers(_draftFinancialItems!);
  }

  List<FinancialItemModel> _mergeExtras(
    List<FinancialItemModel> oldItems,
    List<FinancialItemModel> baseItems,
  ) {
    final extras = oldItems.where((item) {
      return item.kind != 'initial' &&
          item.kind != 'controls' &&
          !_isThirdConcept(item);
    }).toList();
    return <FinancialItemModel>[...baseItems, ...extras];
  }

  List<FinancialItemModel> _currentFinancialItems(
    List<FinancialItemModel> remoteItems,
  ) {
    if (_draftFinancialItems != null) return _draftFinancialItems!;
    if (widget.initialTreatment != null && remoteItems.isNotEmpty) {
      return remoteItems;
    }
    return _defaultDraftFinancialItems(_previewTreatment());
  }

  List<FinancialItemModel> _mergeInlineValuesIntoItems(
    List<FinancialItemModel> items,
    PatientTreatment treatment,
  ) {
    final normalized = _ensureRequiredFinancialItems(items, treatment);
    return _sanitizeFinancialItems(
      normalized,
      treatment,
      allowInvalidDrafts: true,
    );
  }

  List<FinancialItemModel> _ensureRequiredFinancialItems(
    List<FinancialItemModel> items,
    PatientTreatment treatment,
  ) {
    final result = items.toList();
    final defaults = _defaultDraftFinancialItems(treatment);
    for (final defaultItem in defaults) {
      final exists = result.any(
        (item) =>
            item.id == defaultItem.id ||
            item.kind == defaultItem.kind && item.kind != 'extra',
      );
      if (!exists) result.add(defaultItem);
    }
    result.sort((a, b) => a.order.compareTo(b.order));
    return result;
  }

  List<FinancialItemModel> _defaultDraftFinancialItems(
    PatientTreatment treatment,
  ) {
    final now = DateTime.now();
    final thirdIsAppliance = treatment.tipoBase == 'ortopedia';
    final controlsQty = int.tryParse(_controlsQtyCtrl.text.trim()) ?? 1;
    final controlsUnit =
        CurrencyInputFormatter.parseToDouble(_controlsUnitCtrl.text) ?? 0;

    return <FinancialItemModel>[
      FinancialItemModel(
        id: 'initial',
        patientId: widget.patientId,
        treatmentId: treatment.id,
        name: 'Inicial',
        normalizedName: 'inicial',
        kind: 'initial',
        amount:
            CurrencyInputFormatter.parseToDouble(_initialAmountCtrl.text) ?? 0,
        deletable: false,
        editableName: false,
        order: 1,
        active: true,
        createdByAdmin: true,
        createdBy: _currentAdminId(),
        updatedBy: _currentAdminId(),
        createdAt: now,
        updatedAt: now,
      ),
      FinancialItemModel(
        id: 'controls',
        patientId: widget.patientId,
        treatmentId: treatment.id,
        name: 'Controles',
        normalizedName: 'controles',
        kind: 'controls',
        amount: controlsUnit * (controlsQty <= 0 ? 1 : controlsQty),
        unitAmount: controlsUnit,
        quantity: controlsQty <= 0 ? 1 : controlsQty,
        deletable: false,
        editableName: false,
        order: 2,
        active: true,
        createdByAdmin: true,
        createdBy: _currentAdminId(),
        updatedBy: _currentAdminId(),
        createdAt: now,
        updatedAt: now,
      ),
      FinancialItemModel(
        id: thirdIsAppliance ? 'appliance_1' : 'retainers',
        patientId: widget.patientId,
        treatmentId: treatment.id,
        name: thirdIsAppliance ? 'Aparato 1' : 'Retenedores',
        normalizedName: thirdIsAppliance ? 'aparato_1' : 'retenedores',
        kind: thirdIsAppliance ? 'appliance' : 'retainers',
        amount:
            CurrencyInputFormatter.parseToDouble(_thirdConceptCtrl.text) ?? 0,
        deletable: true,
        editableName: true,
        order: 3,
        active: true,
        createdByAdmin: true,
        createdBy: _currentAdminId(),
        updatedBy: _currentAdminId(),
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  List<FinancialItemModel> _rebindFinancialItems(
    List<FinancialItemModel> items,
    String treatmentId,
  ) {
    final now = DateTime.now();
    return items.map((item) {
      return item.copyWith(
        patientId: widget.patientId,
        treatmentId: treatmentId,
        updatedBy: _currentAdminId(),
        updatedAt: now,
      );
    }).toList();
  }

  List<FinancialItemModel> _orderedFinancialItems(List<FinancialItemModel> items) {
    final ordered = items.toList();
    ordered.sort((a, b) => _financialSortKey(a).compareTo(_financialSortKey(b)));
    return ordered;
  }

  int _financialSortKey(FinancialItemModel item) {
    if (item.kind == 'initial') return 10;
    if (item.kind == 'controls') return 20;
    if (item.id == 'appliance_1' || item.kind == 'appliance') return 30;
    if (item.id == 'retainers' || item.kind == 'retainers') return 40;
    return 100 + item.order;
  }

  void _syncFinancialItemControllers(List<FinancialItemModel> items) {
    for (final item in items) {
      _financialNameCtrls.putIfAbsent(
        item.id,
        () => TextEditingController(text: item.name),
      );
      _financialAmountCtrls.putIfAbsent(
        item.id,
        () => TextEditingController(
          text: _formatInputMoney(
            item.kind == 'controls' ? item.effectiveUnitAmount : item.amount,
          ),
        ),
      );
      _financialQtyCtrls.putIfAbsent(
        item.id,
        () => TextEditingController(text: item.effectiveQuantity.toString()),
      );
    }
  }

  void _updateFinancialItem(FinancialItemModel updated) {
    final treatment = _previewTreatment();
    final normalized = _ensureRequiredFinancialItems(
      _currentFinancialItems(const <FinancialItemModel>[]),
      treatment,
    ).map((item) {
      if (item.id != updated.id) return item;
      if (updated.kind == 'initial' || updated.kind == 'controls') {
        return updated.copyWith(active: true, deletable: false);
      }
      return updated;
    }).toList();

    setState(() {
      _draftFinancialItems = normalized;
    });
  }

  void _updateFinancialItemName(FinancialItemModel item, String value) {
    _updateFinancialItem(
      item.copyWith(
        name: value.trimLeft(),
        normalizedName: FinancialItemModel.normalizeName(value),
      ),
    );
  }

  void _updateFinancialItemAmount(FinancialItemModel item, String value) {
    final parsed = CurrencyInputFormatter.parseToDouble(value) ?? 0;
    _updateFinancialItem(
      item.kind == 'controls'
          ? item.copyWith(unitAmount: parsed)
          : item.copyWith(amount: parsed),
    );
  }

  void _updateFinancialItemQuantity(FinancialItemModel item, String value) {
    final parsed = int.tryParse(value.trim()) ?? 1;
    _updateFinancialItem(item.copyWith(quantity: parsed <= 0 ? 1 : parsed));
  }

  void _addExtraFinancialItem() {
    final now = DateTime.now();
    final treatment = _previewTreatment();
    final current = _orderedFinancialItems(
      _ensureRequiredFinancialItems(
        _currentFinancialItems(const <FinancialItemModel>[]),
        treatment,
      ),
    );
    final extraIndex = current.where((item) => item.kind == 'extra').length + 1;
    final item = FinancialItemModel(
      id: 'extra_${now.microsecondsSinceEpoch}',
      patientId: widget.patientId,
      treatmentId: treatment.id,
      name: 'Concepto $extraIndex',
      normalizedName: FinancialItemModel.normalizeName('Concepto $extraIndex'),
      kind: 'extra',
      amount: 0,
      deletable: true,
      editableName: true,
      order: current.length + 1,
      active: true,
      createdByAdmin: true,
      createdBy: _currentAdminId(),
      updatedBy: _currentAdminId(),
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _draftFinancialItems = [...current, item];
      _syncFinancialItemControllers(_draftFinancialItems!);
      _syncFinancialControllers(_draftFinancialItems!);
    });
  }

  void _removeFinancialItem(FinancialItemModel item) {
    if (item.kind == 'initial' || item.kind == 'controls') return;
    final current = _currentFinancialItems(const <FinancialItemModel>[]);
    setState(() {
      _draftFinancialItems = current
          .where((candidate) => candidate.id != item.id)
          .toList();
      _financialNameCtrls.remove(item.id)?.dispose();
      _financialAmountCtrls.remove(item.id)?.dispose();
      _financialQtyCtrls.remove(item.id)?.dispose();
      _syncFinancialControllers(_draftFinancialItems!);
    });
  }

  List<FinancialItemModel> _sanitizeFinancialItems(
    List<FinancialItemModel> items,
    PatientTreatment treatment, {
    bool allowInvalidDrafts = false,
  }) {
    final now = DateTime.now();
    final result = <FinancialItemModel>[];
    final normalizedNames = <String>{};

    for (var index = 0; index < _orderedFinancialItems(items).length; index++) {
      final item = _orderedFinancialItems(items)[index];
      final controllerText = (_financialNameCtrls[item.id]?.text ?? item.name).trim();
      final fallbackName = item.name.trim().isEmpty ? 'Concepto ${index + 1}' : item.name.trim();
      String rawName = controllerText;
      if (rawName.isEmpty) {
        if (!allowInvalidDrafts) throw Exception('FINANCIAL_ITEM_NAME_REQUIRED');
        rawName = fallbackName;
      }

      var normalizedName = FinancialItemModel.normalizeName(rawName);
      if (normalizedName.isEmpty) {
        if (!allowInvalidDrafts) {
          throw Exception('FINANCIAL_ITEM_NAME_REQUIRED');
        }
        rawName = fallbackName;
        normalizedName = FinancialItemModel.normalizeName(rawName);
      }
      if (normalizedNames.contains(normalizedName)) {
        if (!allowInvalidDrafts) {
          throw Exception('FINANCIAL_ITEM_DUPLICATE_NAME');
        }
        rawName = '$rawName ${index + 1}'.trim();
        normalizedName = FinancialItemModel.normalizeName(rawName);
      }
      normalizedNames.add(normalizedName);

      final isControls = item.kind == 'controls';
      final amount =
          CurrencyInputFormatter.parseToDouble(
            _financialAmountCtrls[item.id]?.text ?? '',
          ) ??
          0;
      final quantity = isControls
          ? (int.tryParse(_financialQtyCtrls[item.id]?.text.trim() ?? '') ?? 1)
          : 1;
      if ((amount < 0 || quantity < 1) && !allowInvalidDrafts) {
        throw Exception('FINANCIAL_ITEM_INVALID_AMOUNT');
      }

      final safeQuantity = quantity < 1 ? 1 : quantity;
      final safeAmount = amount < 0 ? 0.0 : amount.toDouble();
      final computedAmount = isControls
          ? (safeAmount * safeQuantity).toDouble()
          : safeAmount;
      final required = item.kind == 'initial' || item.kind == 'controls';
      result.add(
        item.copyWith(
          patientId: widget.patientId,
          treatmentId: treatment.id,
          name: rawName,
          normalizedName: normalizedName,
          amount: computedAmount,
          unitAmount: isControls ? safeAmount : null,
          quantity: isControls ? safeQuantity : null,
          active: required ? true : item.active,
          deletable: required ? false : item.deletable,
          order: index + 1,
          updatedBy: _currentAdminId(),
          updatedAt: now,
        ),
      );
    }

    final hasInitial = result.any((item) => item.kind == 'initial' && item.active);
    final hasControls = result.any((item) => item.kind == 'controls' && item.active);
    if (!hasInitial || !hasControls) {
      throw Exception('REQUIRED_FINANCIAL_ITEMS_MISSING');
    }

    return result;
  }

  FinancialItemModel? _findThirdConcept(List<FinancialItemModel> items) {
    for (final item in items) {
      if (_isThirdConcept(item)) return item;
    }
    return null;
  }

  bool _isThirdConcept(FinancialItemModel item) {
    final normalized = item.normalizedName.toLowerCase();
    final name = item.name.toLowerCase();
    return item.kind == 'retainers' ||
        item.kind == 'appliance' ||
        item.id == 'retainers' ||
        item.id == 'appliance_1' ||
        normalized.contains('reten') ||
        normalized.contains('aparato') ||
        name.contains('reten') ||
        name.contains('aparato');
  }

  void _syncFinancialControllers(List<FinancialItemModel> items) {
    _updatingControllers = true;
    try {
      for (final item in items) {
        final amountText = _formatInputMoney(
          item.kind == 'controls' ? item.effectiveUnitAmount : item.amount,
        );
        _financialNameCtrls[item.id]?.text = item.name;
        _financialAmountCtrls[item.id]?.text = amountText;
        _financialQtyCtrls[item.id]?.text = item.effectiveQuantity.toString();

        if (item.kind == 'initial') {
          _initialAmountCtrl.text = amountText;
        } else if (item.kind == 'controls') {
          _controlsUnitCtrl.text = amountText;
          _controlsQtyCtrl.text = item.effectiveQuantity.toString();
        } else if (_isThirdConcept(item)) {
          _thirdConceptCtrl.text = amountText;
        }
      }
    } finally {
      _updatingControllers = false;
    }
  }

  TreatmentFinancialSummaryModel _buildFinancialSummary(
    List<FinancialItemModel> items,
  ) {
    final activeItems = items.where((item) => item.active).toList();
    final total = activeItems.fold<double>(
      0,
      (sum, item) => sum + item.computedAmount,
    );
    final previous = widget.initialTreatment;
    final paid = previous == null
        ? 0.0
        : ((previous.totalTratamiento ?? 0) - (previous.saldoPendiente ?? 0))
              .clamp(0, double.infinity)
              .toDouble();
    final pending = (total - paid).clamp(0, double.infinity).toDouble();

    return TreatmentFinancialSummaryModel(
      currency: 'COP',
      subtotalAmount: total,
      discountAmount: 0,
      totalAmount: total,
      paidAmount: paid,
      pendingAmount: pending,
      itemsCount: activeItems.length,
      lastPricingUpdateAt: DateTime.now(),
    );
  }

  PatientTreatment _previewTreatment() {
    final now = DateTime.now();
    final visibleName = _resolvedVisibleName();
    return PatientTreatment(
      id: widget.initialTreatment?.id ?? 'draft-treatment-${widget.patientId}',
      patientId: widget.patientId,
      nombre: visibleName,
      visibleName: visibleName,
      clinicalTreatmentName: _clinicalTreatmentName ?? visibleName,
      catalogTreatmentId: _selectedCatalogId,
      categoria: 'ortodoncia',
      tipoBase: _baseType,
      subtipo: _requiresSubtype ? (_subtype ?? 'metalico') : null,
      estado: _status,
      etapaActual: _stage,
      fechaInicio: _startDate,
      fechaFin: (_status == 'finalizado' || _status == 'cancelado')
          ? now
          : null,
      createdAt: widget.initialTreatment?.createdAt ?? now,
      updatedAt: now,
      isPrimary: _isPrimary,
      createdBy: widget.initialTreatment?.createdBy ?? _currentAdminId(),
      updatedBy: _currentAdminId(),
      suggestedCleaningEveryMonths:
          int.tryParse(_cleaningMonthsCtrl.text.trim()) ?? 3,
      suggestedControlEveryMonths:
          int.tryParse(_controlMonthsCtrl.text.trim()) ?? 6,
      nextCleaningDate: _nextCleaningDate,
      nextControlDate: _nextControlDate,
      notas: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
  }

  Future<void> _submit(
    List<FinancialItemModel> effectiveItems,
    TreatmentFinancialSummaryModel summary,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final initial = effectiveItems.firstWhere((item) => item.kind == 'initial');
    final controls = effectiveItems.firstWhere(
      (item) => item.kind == 'controls',
    );
    if (initial.amount <= 0 || controls.effectiveUnitAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicial y Controles son obligatorios.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final previous = widget.initialTreatment;
      final treatmentId = previous?.id ?? _generateTreatmentId(now);
      final paidBefore = previous == null
          ? 0.0
          : ((previous.totalTratamiento ?? 0) - (previous.saldoPendiente ?? 0))
                .clamp(0, double.infinity)
                .toDouble();
      final pending = (summary.totalAmount - paidBefore)
          .clamp(0, double.infinity)
          .toDouble();

      final treatment = _previewTreatment().copyWith(
        id: treatmentId,
        totalTratamiento: summary.totalAmount,
        saldoPendiente: pending,
        updatedAt: now,
        updatedBy: _currentAdminId(),
      );

      String? previousPrimaryId;
      if (previous != null && previous.isPrimary != treatment.isPrimary) {
        previousPrimaryId = previous.id;
      }

      await ref
          .read(patientTreatmentsRepositoryProvider)
          .saveTreatment(
            patientId: widget.patientId,
            treatment: treatment,
            previousPrimaryId: previousPrimaryId,
          );

      await ref
          .read(treatmentFinancialRepositoryProvider)
          .replaceFinancialItems(
            patientId: widget.patientId,
            treatment: treatment,
            items: _rebindFinancialItems(effectiveItems, treatment.id),
            updatedBy: _currentAdminId(),
          );

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_mapTreatmentError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _generateTreatmentId(DateTime now) {
    final prefix = widget.patientId.length >= 6
        ? widget.patientId.substring(0, 6)
        : widget.patientId;
    return 'treatment-${now.millisecondsSinceEpoch}-$prefix';
  }

  String _resolvedVisibleName() {
    final typed = _visibleNameCtrl.text.trim();
    if (typed.isNotEmpty) return typed;
    if (_clinicalTreatmentName != null &&
        _clinicalTreatmentName!.trim().isNotEmpty) {
      return _clinicalTreatmentName!.trim();
    }
    return PatientTreatment.labelForBaseTreatment(_baseType);
  }

  String _currentAdminId() {
    return ref.read(authStateProvider).asData?.value?.uid ?? 'system';
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

  Future<void> _pickRecurringDate({required bool isCleaning}) async {
    final initialDate = isCleaning ? _nextCleaningDate : _nextControlDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isCleaning) {
          _nextCleaningDate = picked;
        } else {
          _nextControlDate = picked;
        }
      });
    }
  }

  DateTime _addMonths(DateTime date, int months) {
    return DateTime(date.year, date.month + months, date.day, 9, 0);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatInputMoney(double value) {
    final integer = value.round();
    if (integer <= 0) return '';
    return CurrencyInputFormatter.formatDigits(integer.toString());
  }

  String? _requiredMoneyValidator(String? value) {
    final parsed = CurrencyInputFormatter.parseToDouble(value ?? '');
    if (parsed == null || parsed <= 0) return 'Obligatorio';
    return null;
  }

  String? _positiveIntValidator(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) return 'Inválido';
    return null;
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'ortodoncia':
        return 'Ortodoncia';
      case 'estetica':
        return 'Estética';
      case 'rehabilitacion':
        return 'Rehabilitación';
      case 'general':
        return 'General';
      default:
        return PatientTreatment.labelForBaseTreatment(value);
    }
  }

  String _normalizeCatalogName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  Future<TreatmentCatalogItem?> _showCatalogPickerSheet(
    List<TreatmentCatalogItem> catalog,
  ) async {
    return showModalBottomSheet<TreatmentCatalogItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final searchCtrl = TextEditingController();
        var filtered = catalog.toList();

        void applySearch(StateSetter setSheetState, String query) {
          final normalized = query.trim().toLowerCase();
          setSheetState(() {
            filtered = catalog.where((item) {
              if (normalized.isEmpty) return true;
              return item.name.toLowerCase().contains(normalized) ||
                  item.category.toLowerCase().contains(normalized) ||
                  item.baseType.toLowerCase().contains(normalized);
            }).toList();
          });
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.82,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFCF8),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Seleccionar tratamiento clínico',
                              style: TextStyle(
                                color: OcgColors.espresso,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Busca en el catálogo y elige el tratamiento correcto para este paciente.',
                        style: TextStyle(color: Color(0xFF8A6F59), height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: searchCtrl,
                        onChanged: (value) => applySearch(setSheetState, value),
                        decoration: _inputDecoration(
                          'Buscar tratamiento',
                          hint: 'Ej. ortodoncia, retenedores, alineadores',
                        ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final created = await _openCreateCatalogTreatmentDialog(catalog);
                            if (created != null && context.mounted) {
                              Navigator.of(context).pop(created);
                            }
                          },
                          icon: const Icon(Icons.add_business_outlined),
                          label: const Text('Nuevo tratamiento'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay resultados. Usa “Nuevo tratamiento” para crear uno.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF8A6F59)),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final selected = item.id == _selectedCatalogId;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => Navigator.of(context).pop(item),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFFF6EBDD)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: selected
                                              ? OcgColors.espresso
                                              : const Color(0xFFE7DBCF),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: const TextStyle(
                                                    color: OcgColors.espresso,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    _catalogPill(_categoryLabel(item.category)),
                                                    _catalogPill(
                                                      PatientTreatment.labelForBaseTreatment(item.baseType),
                                                    ),
                                                    if (item.requiresSubtype)
                                                      _catalogPill('Requiere subtipo'),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            selected
                                                ? Icons.check_circle_rounded
                                                : Icons.chevron_right_rounded,
                                            color: selected
                                                ? OcgColors.espresso
                                                : OcgColors.bronze,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _catalogPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EFE7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: OcgColors.bronze,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<TreatmentCatalogItem?> _openCreateCatalogTreatmentDialog(
    List<TreatmentCatalogItem> existingCatalog,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    String category = 'ortodoncia';
    String baseType = 'convencional';
    bool requiresSubtype = true;
    final selectedSubtypes = <String>{'metalico', 'estetico'};

    final created = await showDialog<TreatmentCatalogItem>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFFFCF8),
              title: const Text('Nuevo tratamiento clínico'),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Crea un tipo de tratamiento reutilizable para el catálogo clínico.',
                          style: TextStyle(color: Color(0xFF8A6F59), height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: _inputDecoration('Nombre del tratamiento'),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Obligatorio';
                            final normalized = _normalizeCatalogName(text);
                            final exists = existingCatalog.any(
                              (item) => item.normalizedName == normalized,
                            );
                            if (exists) return 'Ya existe en el catálogo';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: _inputDecoration('Categoría'),
                          items: const [
                            DropdownMenuItem(value: 'ortodoncia', child: Text('Ortodoncia')),
                            DropdownMenuItem(value: 'estetica', child: Text('Estética')),
                            DropdownMenuItem(value: 'rehabilitacion', child: Text('Rehabilitación')),
                            DropdownMenuItem(value: 'general', child: Text('General')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => category = value);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: baseType,
                          decoration: _inputDecoration('Tipo base operativo'),
                          items: kBaseTreatmentOptions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(PatientTreatment.labelForBaseTreatment(item)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              baseType = value;
                              requiresSubtype =
                                  value == 'convencional' || value == 'autoligado';
                              if (requiresSubtype && selectedSubtypes.isEmpty) {
                                selectedSubtypes.addAll({'metalico', 'estetico'});
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Requiere subtipo'),
                          subtitle: const Text('Úsalo para tratamientos como convencional o autoligado.'),
                          value: requiresSubtype,
                          onChanged: (value) {
                            setDialogState(() {
                              requiresSubtype = value;
                              if (requiresSubtype && selectedSubtypes.isEmpty) {
                                selectedSubtypes.addAll({'metalico', 'estetico'});
                              }
                            });
                          },
                        ),
                        if (requiresSubtype) ...[
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selectedSubtypes.contains('metalico'),
                            title: const Text('Metálico'),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedSubtypes.add('metalico');
                                } else {
                                  selectedSubtypes.remove('metalico');
                                }
                              });
                            },
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selectedSubtypes.contains('estetico'),
                            title: const Text('Estético'),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedSubtypes.add('estetico');
                                } else {
                                  selectedSubtypes.remove('estetico');
                                }
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _creatingCatalogItem ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: _creatingCatalogItem
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          if (requiresSubtype && selectedSubtypes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Selecciona al menos un subtipo.'),
                              ),
                            );
                            return;
                          }

                          setState(() => _creatingCatalogItem = true);
                          try {
                            final item = await ref.read(createTreatmentCatalogItemProvider)(
                              name: nameCtrl.text.trim(),
                              category: category,
                              baseType: baseType,
                              requiresSubtype: requiresSubtype,
                              allowedSubtypes: selectedSubtypes.toList(),
                              createdBy: _currentAdminId(),
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(item);
                            }
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('No se pudo crear el tratamiento: $error'),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _creatingCatalogItem = false);
                          }
                        },
                  child: Text(_creatingCatalogItem ? 'Creando...' : 'Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();

    if (created != null) {
      setState(() {
        _selectedCatalogId = created.id;
        _clinicalTreatmentName = created.name;
        _baseType = created.baseType;
        _subtype = created.requiresSubtype
            ? (created.allowedSubtypes.isNotEmpty
                  ? created.allowedSubtypes.first
                  : 'metalico')
            : null;
        if (_visibleNameCtrl.text.trim().isEmpty) {
          _visibleNameCtrl.text = created.name;
        }
        _adaptThirdConceptForBaseType();
      });
    }

    return created;
  }

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
    if (raw.contains('REQUIRED_FINANCIAL_ITEMS_MISSING')) {
      return 'Inicial y Controles son obligatorios.';
    }
    if (raw.contains('FINANCIAL_ITEM_DUPLICATE_NAME')) {
      return 'No repitas nombres de conceptos financieros.';
    }
    if (raw.contains('FINANCIAL_ITEM_NEGATIVE_AMOUNT')) {
      return 'No se permiten montos negativos.';
    }
    return 'No se pudo guardar el tratamiento. Intenta de nuevo.';
  }
}
