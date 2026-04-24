import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../payments/data/models/financial_item_model.dart';
import '../../../payments/data/models/treatment_financial_summary_model.dart';
import '../../../payments/providers/treatment_financial_provider.dart';
import '../../../payments/presentation/widgets/manage_financial_items_dialog.dart';
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
  final _currency = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _cleaningCtrl;
  late final TextEditingController _controlCtrl;
  late String _baseType;
  String? _subtype;
  late String _status;
  late TreatmentStage _stage;
  late DateTime _startDate;
  late DateTime _nextCleaningDate;
  late DateTime _nextControlDate;
  late bool _isPrimary;

  bool get _editing => widget.initialTreatment != null;
  bool get _requiresSubtype =>
      kSubtypeRequiredBaseTreatments.contains(_baseType);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTreatment;
    _nameCtrl = TextEditingController(text: initial?.nombre ?? '');
    _notesCtrl = TextEditingController(text: initial?.notas ?? '');
    _cleaningCtrl = TextEditingController(
      text: (initial?.suggestedCleaningEveryMonths ?? 3).toString(),
    );
    _controlCtrl = TextEditingController(
      text: (initial?.suggestedControlEveryMonths ?? 6).toString(),
    );
    _baseType = initial?.tipoBase ?? 'convencional';
    _subtype = initial?.subtipo;
    _status = initial?.estado ?? 'activo';
    _stage = initial?.etapaActual ?? TreatmentStage.valoracionInicial;
    _startDate = initial?.fechaInicio ?? DateTime.now();
    _nextCleaningDate = initial?.nextCleaningDate ?? _addMonths(_startDate, 3);
    _nextControlDate = initial?.nextControlDate ?? _addMonths(_startDate, 6);
    _isPrimary = initial?.isPrimary ?? true;
    if (_requiresSubtype && (_subtype == null || _subtype!.trim().isEmpty)) {
      _subtype = 'metalico';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _cleaningCtrl.dispose();
    _controlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(savePatientTreatmentProvider);
    final existingTreatments =
        ref.watch(patientTreatmentsProvider(widget.patientId)).asData?.value ??
        const <PatientTreatment>[];
    final otherPrimary = existingTreatments
        .where((t) => t.id != widget.initialTreatment?.id && t.isPrimary)
        .cast<PatientTreatment?>()
        .firstWhere((t) => t != null, orElse: () => null);
    final canTogglePrimary = !_editing || !_isPrimary || otherPrimary != null;

    ref.listen<AsyncValue<void>>(savePatientTreatmentProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (prev?.isLoading == true && mounted) {
            Navigator.of(context).pop(true);
          }
        },
        error: (error, _) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_mapTreatmentError(error))));
        },
      );
    });

    final financialItemsAsync = widget.initialTreatment == null
        ? const AsyncValue<List<FinancialItemModel>>.data(
            <FinancialItemModel>[],
          )
        : ref.watch(
            treatmentFinancialItemsProvider((
              patientId: widget.patientId,
              treatmentId: widget.initialTreatment!.id,
            )),
          );

    final financialSummary = _buildFinancialSummary(
      widget.initialTreatment,
      financialItemsAsync.asData?.value ?? const <FinancialItemModel>[],
    );

    final media = MediaQuery.sizeOf(context);
    final wide = media.width >= 980;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
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
                      final split = constraints.maxWidth >= 900;
                      if (split) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildClinicalColumn(
                                  saveState.isLoading,
                                  canTogglePrimary,
                                  otherPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 4,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(left: 8),
                                child: _buildFinancialColumn(
                                  financialItemsAsync,
                                  financialSummary,
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
                              saveState.isLoading,
                              canTogglePrimary,
                              otherPrimary,
                            ),
                            const SizedBox(height: 18),
                            _buildFinancialColumn(
                              financialItemsAsync,
                              financialSummary,
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
                      onPressed: saveState.isLoading
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
                      onPressed: saveState.isLoading ? null : _submit,
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
                        saveState.isLoading
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
                if (_isPrimary || otherPrimary != null)
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
    bool isLoading,
    bool canTogglePrimary,
    PatientTreatment? otherPrimary,
  ) {
    return Column(
      children: [
        _sectionCard(
          title: 'Configuración clínica',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDecoration('Nombre del tratamiento'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Ingresa el nombre del tratamiento'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _baseType,
                decoration: _inputDecoration('Tipo base'),
                items: kBaseTreatmentOptions
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          PatientTreatment.labelForBaseTreatment(item),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _baseType = value;
                          if (!_requiresSubtype) {
                            _subtype = null;
                          }
                        });
                      },
              ),
              if (_requiresSubtype) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: (_subtype?.isNotEmpty ?? false)
                      ? _subtype
                      : 'metalico',
                  decoration: _inputDecoration('Subtipo'),
                  items: kTreatmentSubtypes
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            PatientTreatment.labelForBaseTreatment(item),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() => _subtype = value),
                ),
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<TreatmentStage>(
                initialValue: _stage,
                decoration: _inputDecoration('Etapa actual'),
                items: TreatmentStage.values
                    .map(
                      (stage) => DropdownMenuItem(
                        value: stage,
                        child: Text(stageNames[stage] ?? stage.name),
                      ),
                    )
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (value) {
                        if (value != null) setState(() => _stage = value);
                      },
              ),
              const SizedBox(height: 14),
              _dateRow('Inicio', _startDate, isLoading, _pickStartDate),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cleaningCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Limpieza cada (meses)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _controlCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Control cada (meses)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _dateRow(
                'Próxima limpieza',
                _nextCleaningDate,
                isLoading,
                () => _pickRecurringDate(isCleaning: true),
              ),
              const SizedBox(height: 10),
              _dateRow(
                'Próximo control',
                _nextControlDate,
                isLoading,
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
                onChanged: (!canTogglePrimary || isLoading)
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
    TreatmentFinancialSummaryModel summary,
  ) {
    return Column(
      children: [
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
              const Text(
                'Resultado autocalculado con Inicial + Controles + concepto base + extras activos.',
                style: TextStyle(color: Color(0xFFE4D6CA), height: 1.45),
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
                'Total',
                _currency.format(summary.totalAmount),
                emphasized: true,
              ),
              const SizedBox(height: 14),
              financialItemsAsync.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (_, __) => const Text(
                  'No se pudo cargar el detalle financiero.',
                  style: TextStyle(color: Color(0xFF8A6F59)),
                ),
                data: (items) {
                  final active = items.where((i) => i.active).toList();
                  final initialItem = active
                      .cast<FinancialItemModel?>()
                      .firstWhere(
                        (i) => i?.kind == 'initial',
                        orElse: () => null,
                      );
                  final controlsItem = active
                      .cast<FinancialItemModel?>()
                      .firstWhere(
                        (i) => i?.kind == 'controls',
                        orElse: () => null,
                      );
                  final retainerItems = active
                      .where(
                        (i) =>
                            i.normalizedName.contains('reten') ||
                            i.name.toLowerCase().contains('reten'),
                      )
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F3ED),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _summaryRow(
                              'Inicial',
                              initialItem == null
                                  ? 'No configurado'
                                  : _currency.format(
                                      initialItem.computedAmount,
                                    ),
                            ),
                            _summaryRow(
                              'Controles',
                              controlsItem == null
                                  ? 'No configurado'
                                  : '${controlsItem.effectiveQuantity} x ${_currency.format(controlsItem.effectiveUnitAmount)}',
                            ),
                            if (retainerItems.isNotEmpty)
                              ...retainerItems.map(
                                (item) => _summaryRow(
                                  item.name,
                                  _currency.format(item.computedAmount),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: widget.initialTreatment == null
                              ? null
                              : () => showDialog<void>(
                                  context: context,
                                  builder: (_) => ManageFinancialItemsDialog(
                                    patientId: widget.patientId,
                                    treatment: widget.initialTreatment!,
                                    initialItems: items,
                                  ),
                                ),
                          icon: const Icon(Icons.tune_outlined),
                          label: const Text('Editar conceptos financieros'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
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
              Text(
                title,
                style: const TextStyle(
                  color: OcgColors.espresso,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
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

  TreatmentFinancialSummaryModel _buildFinancialSummary(
    PatientTreatment? treatment,
    List<FinancialItemModel> items,
  ) {
    final activeItems = items.where((item) => item.active).toList();
    if (activeItems.isEmpty) {
      final total = treatment?.totalTratamiento ?? 0;
      final pending = treatment?.saldoPendiente ?? total;
      final paid = (total - pending).clamp(0, double.infinity).toDouble();
      return TreatmentFinancialSummaryModel(
        currency: 'COP',
        subtotalAmount: total,
        discountAmount: 0,
        totalAmount: total,
        paidAmount: paid,
        pendingAmount: pending,
        itemsCount: 0,
        lastPricingUpdateAt: DateTime.now(),
      );
    }

    final total = activeItems.fold<double>(
      0,
      (sum, item) => sum + item.computedAmount,
    );
    final pending = treatment?.saldoPendiente ?? total;
    final paid = (total - pending).clamp(0, double.infinity).toDouble();

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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
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
    return DateTime(date.year, date.month + months, date.day);
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
      suggestedCleaningEveryMonths:
          int.tryParse(_cleaningCtrl.text.trim()) ?? 3,
      suggestedControlEveryMonths: int.tryParse(_controlCtrl.text.trim()) ?? 6,
      nextCleaningDate: _nextCleaningDate,
      nextControlDate: _nextControlDate,
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
