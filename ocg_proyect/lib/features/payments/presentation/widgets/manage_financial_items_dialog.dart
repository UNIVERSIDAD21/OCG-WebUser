import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/utils/currency_input_formatter.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../treatment/data/models/patient_treatment.dart';
import '../../data/models/financial_item_model.dart';
import '../../providers/treatment_financial_provider.dart';

class ManageFinancialItemsDialog extends ConsumerStatefulWidget {
  const ManageFinancialItemsDialog({
    super.key,
    required this.patientId,
    required this.treatment,
    required this.initialItems,
  });

  final String patientId;
  final PatientTreatment treatment;
  final List<FinancialItemModel> initialItems;

  @override
  ConsumerState<ManageFinancialItemsDialog> createState() =>
      _ManageFinancialItemsDialogState();
}

class _ManageFinancialItemsDialogState
    extends ConsumerState<ManageFinancialItemsDialog> {
  late List<_EditableFinancialItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems
        .map((item) => _EditableFinancialItem.fromModel(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(saveTreatmentFinancialItemsProvider);
    final total = _items
        .where((item) => item.active)
        .fold<double>(0, (sum, item) => sum + item.effectiveAmount);

    return AlertDialog(
      title: Text('Conceptos financieros · ${widget.treatment.displayName}'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _items.length; i++) ...[
                _FinancialItemEditorRow(
                  item: _items[i],
                  onChanged: (next) => setState(() => _items[i] = next),
                  onRemove: _items[i].isRequired
                      ? null
                      : () => setState(() => _items.removeAt(i)),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: saveState.isLoading ? null : _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Agregar nuevo concepto'),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.mist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total calculado automáticamente: ${_formatCop(total)}',
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: saveState.isLoading
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: OcgColors.espresso,
            foregroundColor: OcgColors.ivory,
          ),
          onPressed: saveState.isLoading ? null : _save,
          child: saveState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: OcgColors.ivory,
                  ),
                )
              : const Text('Guardar conceptos'),
        ),
      ],
    );
  }

  void _addItem() {
    final index = _items.length + 1;
    _items.add(
      _EditableFinancialItem(
        id: 'extra_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Concepto $index',
        kind: 'extra',
        amount: 0,
        unitAmount: 0,
        quantity: 1,
        order: index,
        active: true,
        deletable: true,
        editableName: true,
        createdAt: DateTime.now(),
      ),
    );
    setState(() {});
  }

  Future<void> _save() async {
    try {
      final adminId = ref.read(authStateProvider).asData?.value?.uid ?? 'admin';
      final models = <FinancialItemModel>[];
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        final cleanName = item.name.trim();
        if (cleanName.isEmpty) throw Exception('FINANCIAL_ITEM_NAME_REQUIRED');
        if (item.amount < 0 || item.unitAmount < 0) {
          throw Exception('FINANCIAL_ITEM_NEGATIVE_AMOUNT');
        }
        if (item.kind == 'controls' && item.quantity < 1) {
          throw Exception('FINANCIAL_ITEM_INVALID_QUANTITY');
        }
        models.add(
          FinancialItemModel(
            id: item.id,
            patientId: widget.patientId,
            treatmentId: widget.treatment.id,
            name: cleanName,
            normalizedName: FinancialItemModel.normalizeName(cleanName),
            kind: item.kind,
            amount: item.effectiveAmount,
            unitAmount: item.kind == 'controls' ? item.unitAmount : null,
            quantity: item.kind == 'controls' ? item.quantity : null,
            deletable: item.deletable,
            editableName: item.editableName,
            order: i + 1,
            active: item.active,
            createdByAdmin: true,
            createdBy: item.createdBy ?? adminId,
            updatedBy: adminId,
            createdAt: item.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }

      await ref
          .read(saveTreatmentFinancialItemsProvider.notifier)
          .replaceItems(
            patientId: widget.patientId,
            treatment: widget.treatment,
            items: models,
            updatedBy: adminId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapError(e))));
    }
  }

  String _mapError(Object error) {
    final raw = error.toString();
    if (raw.contains('REQUIRED_FINANCIAL_ITEMS_MISSING')) {
      return 'Inicial y Controles son obligatorios.';
    }
    if (raw.contains('FINANCIAL_ITEM_NAME_REQUIRED')) {
      return 'Todos los conceptos deben tener nombre.';
    }
    if (raw.contains('FINANCIAL_ITEM_NEGATIVE_AMOUNT')) {
      return 'No se permiten montos negativos.';
    }
    if (raw.contains('FINANCIAL_ITEM_DUPLICATE_NAME')) {
      return 'No repitas nombres de conceptos.';
    }
    if (raw.contains('FINANCIAL_ITEM_INVALID_QUANTITY')) {
      return 'Controles debe tener una cantidad válida mayor o igual a 1.';
    }
    return raw;
  }

  String _formatCop(double amount) {
    final value = amount.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      final posFromEnd = value.length - i;
      buffer.write(value[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    return '\$${buffer.toString()} COP';
  }
}

class _FinancialItemEditorRow extends StatelessWidget {
  const _FinancialItemEditorRow({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final _EditableFinancialItem item;
  final ValueChanged<_EditableFinancialItem> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: item.name);
    final amountController = TextEditingController(
      text: item.unitAmount == 0
          ? ''
          : CurrencyInputFormatter.formatDigits(
              item.unitAmount.toStringAsFixed(0),
            ),
    );
    final quantityController = TextEditingController(
      text: item.kind == 'controls' ? item.quantity.toString() : '',
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: nameController,
                  enabled: item.editableName,
                  decoration: InputDecoration(
                    labelText: item.isRequired
                        ? '${item.kind == 'initial' ? 'Inicial' : 'Controles'} (obligatorio)'
                        : 'Concepto',
                  ),
                  onChanged: (value) => onChanged(item.copyWith(name: value)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: item.kind == 'controls' ? 2 : 3,
                child: TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: item.kind == 'controls'
                        ? 'Valor unitario COP'
                        : 'Monto COP',
                  ),
                  onChanged: (value) => onChanged(
                    item.copyWith(
                      unitAmount:
                          CurrencyInputFormatter.parseToDouble(value) ?? 0,
                    ),
                  ),
                ),
              ),
              if (item.kind == 'controls') ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    onChanged: (value) => onChanged(
                      item.copyWith(quantity: int.tryParse(value.trim()) ?? 1),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Switch(
                value: item.active,
                onChanged: item.isRequired
                    ? null
                    : (value) => onChanged(item.copyWith(active: value)),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (item.kind == 'controls') ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Fórmula: ${_formatCop(item.unitAmount)} × ${item.quantity} = ${_formatCop(item.effectiveAmount)}',
                style: const TextStyle(
                  color: OcgColors.espresso,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCop(double amount) {
    final value = amount.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      final posFromEnd = value.length - i;
      buffer.write(value[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    return '\$${buffer.toString()}';
  }
}

class _EditableFinancialItem {
  const _EditableFinancialItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    required this.unitAmount,
    required this.quantity,
    required this.order,
    required this.active,
    required this.deletable,
    required this.editableName,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String kind;
  final double amount;
  final double unitAmount;
  final int quantity;
  final int order;
  final bool active;
  final bool deletable;
  final bool editableName;
  final String? createdBy;
  final DateTime createdAt;

  bool get isRequired => kind == 'initial' || kind == 'controls';
  double get effectiveAmount =>
      kind == 'controls' ? unitAmount * quantity : amount;

  factory _EditableFinancialItem.fromModel(FinancialItemModel item) {
    return _EditableFinancialItem(
      id: item.id,
      name: item.name,
      kind: item.kind,
      amount: item.kind == 'controls' ? item.effectiveUnitAmount : item.amount,
      unitAmount: item.kind == 'controls'
          ? item.effectiveUnitAmount
          : item.amount,
      quantity: item.kind == 'controls' ? item.effectiveQuantity : 1,
      order: item.order,
      active: item.active,
      deletable: item.deletable,
      editableName: item.editableName,
      createdBy: item.createdBy,
      createdAt: item.createdAt,
    );
  }

  _EditableFinancialItem copyWith({
    String? id,
    String? name,
    String? kind,
    double? amount,
    double? unitAmount,
    int? quantity,
    int? order,
    bool? active,
    bool? deletable,
    bool? editableName,
    String? createdBy,
    DateTime? createdAt,
  }) {
    final nextKind = kind ?? this.kind;
    final nextUnit = nextKind == 'controls'
        ? (unitAmount ?? this.unitAmount)
        : (amount ?? this.amount);
    final nextQty = nextKind == 'controls'
        ? ((quantity ?? this.quantity) < 1 ? 1 : (quantity ?? this.quantity))
        : 1;
    final nextAmount = nextKind == 'controls'
        ? nextUnit * nextQty
        : (amount ?? this.amount);

    return _EditableFinancialItem(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: nextKind,
      amount: nextAmount,
      unitAmount: nextUnit,
      quantity: nextQty,
      order: order ?? this.order,
      active: active ?? this.active,
      deletable: deletable ?? this.deletable,
      editableName: editableName ?? this.editableName,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
