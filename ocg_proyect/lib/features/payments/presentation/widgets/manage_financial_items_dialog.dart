import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/utils/currency_input_formatter.dart';
import '../../../treatment/data/models/patient_treatment.dart';
import '../../data/models/financial_item_model.dart';
import '../../providers/treatment_financial_provider.dart';

class ManageFinancialItemsDialog extends ConsumerStatefulWidget {
  const ManageFinancialItemsDialog({
    super.key,
    required this.patientId,
    required this.treatment,
    required this.initialItems,
    this.persistOnSave = true,
    this.onDraftSaved,
  });

  final String patientId;
  final PatientTreatment treatment;
  final List<FinancialItemModel> initialItems;

  /// When false, the dialog edits a local draft and does not write to Firestore.
  /// Use this while a treatment is being created and still has not been saved.
  final bool persistOnSave;

  /// Called with the sanitized concepts when [persistOnSave] is false.
  final ValueChanged<List<FinancialItemModel>>? onDraftSaved;

  @override
  ConsumerState<ManageFinancialItemsDialog> createState() =>
      _ManageFinancialItemsDialogState();
}

class _ManageFinancialItemsDialogState
    extends ConsumerState<ManageFinancialItemsDialog> {
  final Map<String, TextEditingController> _nameCtrls = {};
  final Map<String, TextEditingController> _amountCtrls = {};
  final Map<String, TextEditingController> _qtyCtrls = {};

  late List<FinancialItemModel> _items;
  bool _saving = false;

  bool get _isOrtopedia => widget.treatment.tipoBase == 'ortopedia';

  @override
  void initState() {
    super.initState();
    _items = _normalizeInitialItems(widget.initialItems);
    _syncControllersForAllItems();
  }

  @override
  void dispose() {
    for (final controller in _nameCtrls.values) {
      controller.dispose();
    }
    for (final controller in _amountCtrls.values) {
      controller.dispose();
    }
    for (final controller in _qtyCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _orderedItems();
    final total = ordered
        .where((item) => item.active)
        .fold<double>(0, (sum, item) => sum + item.computedAmount);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 860,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 48,
        ),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFCF8F3),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE7DDD2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x242C2016),
              blurRadius: 30,
              offset: Offset(0, 14),
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: OcgColors.espresso,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: OcgColors.ivory,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editar conceptos financieros',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: OcgColors.espresso,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.treatment.displayName,
                        style: const TextStyle(
                          color: Color(0xFF8A6F59),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Inicial y Controles son obligatorios. Retenedores, Aparato 1 y conceptos extras pueden activarse o desactivarse.',
                        style: TextStyle(
                          color: Color(0xFF8A6F59),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: ordered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildItemCard(ordered[index]),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : _addExtraItem,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar concepto'),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1E5D8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE0C7AF)),
                  ),
                  child: Text(
                    'Total activo: ${_money(total)}',
                    style: const TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFD9CCBE)),
                      foregroundColor: OcgColors.espresso,
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: OcgColors.espresso,
                      foregroundColor: OcgColors.ivory,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_saving ? 'Guardando...' : 'Guardar conceptos'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(FinancialItemModel item) {
    final isControls = item.kind == 'controls';
    final lockedRequired = item.kind == 'initial' || item.kind == 'controls';
    final nameController = _nameCtrls[item.id]!;
    final amountController = _amountCtrls[item.id]!;
    final qtyController = _qtyCtrls[item.id]!;

    return AnimatedOpacity(
      opacity: item.active ? 1 : 0.62,
      duration: const Duration(milliseconds: 160),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
                  onChanged: lockedRequired
                      ? null
                      : (value) => setState(
                          () => _replaceItem(item.copyWith(active: value)),
                        ),
                ),
                if (!lockedRequired && item.deletable)
                  IconButton(
                    tooltip: 'Eliminar concepto',
                    onPressed: _saving ? null : () => _removeItem(item),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final nameField = TextField(
                  controller: nameController,
                  enabled: item.editableName && !lockedRequired,
                  decoration: _fieldDecoration('Nombre del concepto'),
                  onChanged: (value) => _updateItemName(item, value),
                );
                final amountField = TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  decoration: _fieldDecoration(
                    isControls ? 'Valor unitario COP' : 'Monto COP',
                  ),
                  onChanged: (value) => _updateItemAmount(item, value),
                );
                final qtyField = TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDecoration('Cantidad'),
                  onChanged: (value) => _updateItemQuantity(item, value),
                );

                if (compact) {
                  return Column(
                    children: [
                      nameField,
                      const SizedBox(height: 10),
                      amountField,
                      if (isControls) ...[const SizedBox(height: 10), qtyField],
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
                  ? 'Fórmula: ${_money(item.effectiveUnitAmount)} × ${item.effectiveQuantity} = ${_money(item.computedAmount)}'
                  : 'Total: ${_money(item.computedAmount)}',
              style: const TextStyle(
                color: Color(0xFF8A6F59),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFFCF8F3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE4D8CB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: OcgColors.bronze, width: 1.3),
      ),
    );
  }

  List<FinancialItemModel> _normalizeInitialItems(
    List<FinancialItemModel> source,
  ) {
    final now = DateTime.now();
    final result = source.map((item) {
      if (item.kind == 'initial' || item.kind == 'controls') {
        return item.copyWith(active: true, deletable: false);
      }
      return item;
    }).toList();

    bool hasId(String id) => result.any((item) => item.id == id);
    bool hasKind(String kind) => result.any((item) => item.kind == kind);

    if (!hasKind('initial')) {
      result.add(
        FinancialItemModel(
          id: 'initial',
          patientId: widget.patientId,
          treatmentId: widget.treatment.id,
          name: 'Inicial',
          normalizedName: 'inicial',
          kind: 'initial',
          amount: 0,
          deletable: false,
          editableName: false,
          order: 1,
          active: true,
          createdByAdmin: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (!hasKind('controls')) {
      result.add(
        FinancialItemModel(
          id: 'controls',
          patientId: widget.patientId,
          treatmentId: widget.treatment.id,
          name: 'Controles',
          normalizedName: 'controles',
          kind: 'controls',
          amount: 0,
          unitAmount: 0,
          quantity: 1,
          deletable: false,
          editableName: false,
          order: 2,
          active: true,
          createdByAdmin: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final thirdId = _isOrtopedia ? 'appliance_1' : 'retainers';
    if (!hasId(thirdId)) {
      result.add(
        FinancialItemModel(
          id: thirdId,
          patientId: widget.patientId,
          treatmentId: widget.treatment.id,
          name: _isOrtopedia ? 'Aparato 1' : 'Retenedores',
          normalizedName: _isOrtopedia ? 'aparato_1' : 'retenedores',
          kind: _isOrtopedia ? 'appliance' : 'retainers',
          amount: 0,
          deletable: true,
          editableName: true,
          order: 3,
          active: true,
          createdByAdmin: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    result.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    return result;
  }

  void _syncControllersForAllItems() {
    for (final item in _items) {
      _ensureControllers(item);
    }
  }

  void _ensureControllers(FinancialItemModel item) {
    _nameCtrls.putIfAbsent(
      item.id,
      () => TextEditingController(text: item.name),
    );
    _amountCtrls.putIfAbsent(
      item.id,
      () => TextEditingController(
        text: _toCurrencyInput(
          item.kind == 'controls' ? item.effectiveUnitAmount : item.amount,
        ),
      ),
    );
    _qtyCtrls.putIfAbsent(
      item.id,
      () => TextEditingController(text: '${item.effectiveQuantity}'),
    );
  }

  List<FinancialItemModel> _orderedItems() {
    final copy = _items.map((item) {
      if (item.kind == 'initial' || item.kind == 'controls') {
        return item.copyWith(active: true, deletable: false);
      }
      return item;
    }).toList();
    copy.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    return copy;
  }

  int _sortKey(FinancialItemModel item) {
    if (item.kind == 'initial') return 10;
    if (item.kind == 'controls') return 20;
    if (item.id == 'appliance_1' || item.kind == 'appliance') return 30;
    if (item.id == 'retainers' || item.kind == 'retainers') return 40;
    return 100 + item.order;
  }

  void _replaceItem(FinancialItemModel updated) {
    final normalized = updated.kind == 'initial' || updated.kind == 'controls'
        ? updated.copyWith(active: true, deletable: false)
        : updated;
    final index = _items.indexWhere((item) => item.id == normalized.id);
    if (index >= 0) {
      _items[index] = normalized.copyWith(updatedAt: DateTime.now());
    } else {
      _items.add(normalized.copyWith(updatedAt: DateTime.now()));
    }
    _ensureControllers(normalized);
  }

  void _updateItemName(FinancialItemModel item, String value) {
    final nextName = value.trimLeft();
    _replaceItem(
      item.copyWith(
        name: nextName,
        normalizedName: FinancialItemModel.normalizeName(nextName),
      ),
    );
  }

  void _updateItemAmount(FinancialItemModel item, String value) {
    final parsed = _parseMoney(value);
    if (item.kind == 'controls') {
      _replaceItem(item.copyWith(unitAmount: parsed));
    } else {
      _replaceItem(item.copyWith(amount: parsed));
    }
  }

  void _updateItemQuantity(FinancialItemModel item, String value) {
    final parsed = int.tryParse(value.trim()) ?? 1;
    _replaceItem(item.copyWith(quantity: parsed <= 0 ? 1 : parsed));
  }

  void _addExtraItem() {
    final now = DateTime.now();
    final index = _items.where((item) => item.kind == 'extra').length + 1;
    final id = 'extra_${now.microsecondsSinceEpoch}';
    final item = FinancialItemModel(
      id: id,
      patientId: widget.patientId,
      treatmentId: widget.treatment.id,
      name: 'Concepto $index',
      normalizedName: FinancialItemModel.normalizeName('Concepto $index'),
      kind: 'extra',
      amount: 0,
      deletable: true,
      editableName: true,
      order: _items.length + 1,
      active: true,
      createdByAdmin: true,
      createdAt: now,
      updatedAt: now,
    );
    setState(() {
      _items.add(item);
      _ensureControllers(item);
    });
  }

  void _removeItem(FinancialItemModel item) {
    if (item.kind == 'initial' || item.kind == 'controls') return;
    setState(() {
      _items.removeWhere((candidate) => candidate.id == item.id);
      _nameCtrls.remove(item.id)?.dispose();
      _amountCtrls.remove(item.id)?.dispose();
      _qtyCtrls.remove(item.id)?.dispose();
    });
  }

  Future<void> _save() async {
    late final List<FinancialItemModel> sanitized;
    try {
      sanitized = _sanitizedItemsForSave();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapError(error))));
      return;
    }

    if (!widget.persistOnSave) {
      widget.onDraftSaved?.call(sanitized);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(saveTreatmentFinancialItemsProvider.notifier)
          .replaceItems(
            patientId: widget.patientId,
            treatment: widget.treatment,
            items: sanitized,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_mapError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<FinancialItemModel> _sanitizedItemsForSave() {
    final now = DateTime.now();
    final result = <FinancialItemModel>[];
    final normalizedNames = <String>{};

    for (var index = 0; index < _orderedItems().length; index++) {
      final item = _orderedItems()[index];
      final rawName = _nameCtrls[item.id]?.text.trim() ?? item.name.trim();
      if (rawName.isEmpty) throw Exception('FINANCIAL_ITEM_NAME_REQUIRED');
      final normalizedName = FinancialItemModel.normalizeName(rawName);
      if (normalizedName.isEmpty) {
        throw Exception('FINANCIAL_ITEM_NAME_REQUIRED');
      }
      if (normalizedNames.contains(normalizedName)) {
        throw Exception('FINANCIAL_ITEM_DUPLICATE_NAME');
      }
      normalizedNames.add(normalizedName);

      final isControls = item.kind == 'controls';
      final amount = _parseMoney(_amountCtrls[item.id]?.text ?? '');
      final quantity = isControls
          ? int.tryParse(_qtyCtrls[item.id]?.text.trim() ?? '') ?? 1
          : 1;

      if (amount < 0 || quantity < 1) {
        throw Exception('FINANCIAL_ITEM_INVALID_AMOUNT');
      }

      final required = item.kind == 'initial' || item.kind == 'controls';
      result.add(
        item.copyWith(
          patientId: widget.patientId,
          treatmentId: widget.treatment.id,
          name: rawName,
          normalizedName: normalizedName,
          amount: isControls ? amount * quantity : amount,
          unitAmount: isControls ? amount : null,
          quantity: isControls ? quantity : null,
          active: required ? true : item.active,
          deletable: required ? false : item.deletable,
          order: index + 1,
          updatedAt: now,
        ),
      );
    }

    final hasInitial = result.any(
      (item) => item.kind == 'initial' && item.active,
    );
    final hasControls = result.any(
      (item) => item.kind == 'controls' && item.active,
    );
    if (!hasInitial || !hasControls) {
      throw Exception('REQUIRED_FINANCIAL_ITEMS_MISSING');
    }

    return result;
  }

  double _parseMoney(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(digits) ?? 0;
  }

  String _toCurrencyInput(double value) {
    final integer = value.round();
    if (integer <= 0) return '';
    return CurrencyInputFormatter.formatDigits(integer.toString());
  }

  String _money(double value) =>
      '\$ ${_toCurrencyInput(value).isEmpty ? '0' : _toCurrencyInput(value)} COP';

  String _mapError(Object error) {
    final raw = error.toString();
    if (raw.contains('FINANCIAL_ITEM_NAME_REQUIRED')) {
      return 'Todos los conceptos deben tener nombre.';
    }
    if (raw.contains('FINANCIAL_ITEM_DUPLICATE_NAME')) {
      return 'No repitas nombres de conceptos.';
    }
    if (raw.contains('REQUIRED_FINANCIAL_ITEMS_MISSING')) {
      return 'Inicial y Controles son obligatorios y no se pueden desactivar.';
    }
    if (raw.contains('FINANCIAL_ITEM_INVALID_AMOUNT')) {
      return 'Revisa los montos y cantidades de los conceptos.';
    }
    if (raw.contains('FINANCIAL_ITEM_NEGATIVE_AMOUNT')) {
      return 'No se permiten montos negativos.';
    }
    return 'No se pudieron guardar los conceptos financieros.';
  }
}
