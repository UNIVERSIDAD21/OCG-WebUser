import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/utils/currency_input_formatter.dart';
import '../../data/models/financial_item_model.dart';
import '../../providers/treatment_financial_provider.dart';
import '../../../treatment/data/models/patient_treatment.dart';

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
  final Map<String, TextEditingController> _amountCtrls = {};
  final Map<String, TextEditingController> _qtyCtrls = {};
  late List<FinancialItemModel> _items;
  bool _saving = false;

  bool get _isOrtopedia => widget.treatment.tipoBase == 'ortopedia';

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems.map((e) => e).toList();
    for (final item in _items) {
      _amountCtrls[item.id] = TextEditingController(
        text: _toCurrencyInput(
          item.kind == 'controls' ? item.effectiveUnitAmount : item.amount,
        ),
      );
      _qtyCtrls[item.id] = TextEditingController(
        text: '${item.effectiveQuantity}',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _visibleItems();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFCF8F3),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE7DDD2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Editar conceptos financieros',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: OcgColors.espresso,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.treatment.displayName,
              style: const TextStyle(
                color: Color(0xFF8A6F59),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildItemCard(filtered[index]),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: OcgColors.espresso,
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
    final amountCtrl = _amountCtrls[item.id]!;
    final qtyCtrl = _qtyCtrls[item.id]!;
    final isControls = item.kind == 'controls';
    final locked = item.kind == 'initial' || item.kind == 'controls';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Switch.adaptive(
                value: item.active,
                onChanged: locked
                    ? null
                    : (value) => setState(() {
                        _replaceItem(item.copyWith(active: value));
                      }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: isControls ? 'Valor unitario' : 'Monto',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (value) {
                    final parsed = _parseMoney(value);
                    setState(() {
                      if (isControls) {
                        _replaceItem(item.copyWith(unitAmount: parsed));
                      } else {
                        _replaceItem(item.copyWith(amount: parsed));
                      }
                    });
                  },
                ),
              ),
              if (isControls) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (value) {
                      final qty = int.tryParse(value.trim()) ?? 0;
                      setState(() {
                        _replaceItem(
                          item.copyWith(quantity: qty <= 0 ? 1 : qty),
                        );
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isControls
                ? 'Total: ${_money(item.effectiveUnitAmount * item.effectiveQuantity)}'
                : 'Total: ${_money(item.amount)}',
            style: const TextStyle(
              color: Color(0xFF8A6F59),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<FinancialItemModel> _visibleItems() {
    final base = _items.where((item) {
      if (_isOrtopedia) {
        return item.kind == 'initial' ||
            item.kind == 'controls' ||
            item.normalizedName.contains('aparato') ||
            (item.active && item.kind == 'extra');
      }
      return item.kind == 'initial' ||
          item.kind == 'controls' ||
          item.normalizedName.contains('reten') ||
          (item.active && item.kind == 'extra');
    }).toList();

    int orderFor(FinancialItemModel item) {
      if (item.kind == 'initial') return 0;
      if (item.kind == 'controls') return 1;
      if (item.normalizedName.contains('aparato')) return 2;
      if (item.normalizedName.contains('reten') ||
          item.name.toLowerCase().contains('reten'))
        return 2;
      return 10;
    }

    base.sort((a, b) => orderFor(a).compareTo(orderFor(b)));
    return base;
  }

  void _replaceItem(FinancialItemModel updated) {
    final index = _items.indexWhere((i) => i.id == updated.id);
    if (index >= 0) _items[index] = updated;
  }

  Future<void> _save() async {
    final initial = _items.where((i) => i.kind == 'initial').first;
    final controls = _items.where((i) => i.kind == 'controls').first;
    if (initial.amount <= 0 || controls.effectiveUnitAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicial y Controles son obligatorios.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(treatmentFinancialRepositoryProvider);
      // FIX: reemplazado el loop de upsertItem (no existe) por una sola
      // llamada a replaceFinancialItems con la firma real del repositorio.
      await repo.replaceFinancialItems(
        patientId: widget.patientId,
        treatment: widget.treatment,
        items: _visibleItems(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _parseMoney(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(digits) ?? 0;
  }

  String _toCurrencyInput(double value) {
    final integer = value.round();
    if (integer <= 0) return '';
    final text = integer.toString();
    final chars = text.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }
    return buffer.toString().split('').reversed.join();
  }

  String _money(double value) => _toCurrencyInput(value);
}
