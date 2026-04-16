import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/ocg_colors.dart';
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
  ConsumerState<ManageFinancialItemsDialog> createState() => _ManageFinancialItemsDialogState();
}

class _ManageFinancialItemsDialogState extends ConsumerState<ManageFinancialItemsDialog> {
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
    final total = _items.where((item) => item.active).fold<double>(0, (sum, item) => sum + item.amount);

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
                  onRemove: _items[i].isRequired ? null : () => setState(() => _items.removeAt(i)),
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
          onPressed: saveState.isLoading ? null : () => Navigator.of(context).pop(),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: OcgColors.ivory),
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
        order: index,
        active: true,
        deletable: true,
        editableName: true,
      ),
    );
    setState(() {});
  }

  Future<void> _save() async {
    try {
      final models = <FinancialItemModel>[];
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        final cleanName = item.name.trim();
        if (cleanName.isEmpty) throw Exception('FINANCIAL_ITEM_NAME_REQUIRED');
        if (item.amount < 0) throw Exception('FINANCIAL_ITEM_NEGATIVE_AMOUNT');
        models.add(
          FinancialItemModel(
            id: item.id,
            patientId: widget.patientId,
            treatmentId: widget.treatment.id,
            name: cleanName,
            normalizedName: FinancialItemModel.normalizeName(cleanName),
            kind: item.kind,
            amount: item.amount,
            deletable: item.deletable,
            editableName: item.editableName,
            order: i + 1,
            active: item.active,
            createdByAdmin: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      await ref.read(saveTreatmentFinancialItemsProvider.notifier).replaceItems(
            patientId: widget.patientId,
            treatment: widget.treatment,
            items: models,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_mapError(e))));
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
    final amountController = TextEditingController(text: item.amount == 0 ? '' : item.amount.toStringAsFixed(0));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: TextFormField(
            controller: nameController,
            enabled: item.editableName,
            decoration: InputDecoration(
              labelText: item.isRequired ? '${item.kind == 'initial' ? 'Inicial' : 'Controles'} (obligatorio)' : 'Concepto',
            ),
            onChanged: (value) => onChanged(item.copyWith(name: value)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monto COP'),
            onChanged: (value) => onChanged(item.copyWith(amount: double.tryParse(value.replaceAll('.', '').trim()) ?? 0)),
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: item.active,
          onChanged: item.isRequired ? null : (value) => onChanged(item.copyWith(active: value)),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _EditableFinancialItem {
  const _EditableFinancialItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    required this.order,
    required this.active,
    required this.deletable,
    required this.editableName,
  });

  final String id;
  final String name;
  final String kind;
  final double amount;
  final int order;
  final bool active;
  final bool deletable;
  final bool editableName;

  bool get isRequired => kind == 'initial' || kind == 'controls';

  factory _EditableFinancialItem.fromModel(FinancialItemModel item) {
    return _EditableFinancialItem(
      id: item.id,
      name: item.name,
      kind: item.kind,
      amount: item.amount,
      order: item.order,
      active: item.active,
      deletable: item.deletable,
      editableName: item.editableName,
    );
  }

  _EditableFinancialItem copyWith({
    String? id,
    String? name,
    String? kind,
    double? amount,
    int? order,
    bool? active,
    bool? deletable,
    bool? editableName,
  }) {
    return _EditableFinancialItem(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      order: order ?? this.order,
      active: active ?? this.active,
      deletable: deletable ?? this.deletable,
      editableName: editableName ?? this.editableName,
    );
  }
}
