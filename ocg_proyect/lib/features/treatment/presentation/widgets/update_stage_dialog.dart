import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../patients/data/models/patient_model.dart';
import '../../providers/treatment_provider.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_button.dart';
import 'treatment_timeline.dart';

class UpdateStageDialog extends ConsumerStatefulWidget {
  const UpdateStageDialog({
    super.key,
    required this.patientId,
    required this.etapaActual,
    required this.adminId,
  });

  final String patientId;
  final TreatmentStage etapaActual;
  final String adminId;

  @override
  ConsumerState<UpdateStageDialog> createState() => _UpdateStageDialogState();
}

class _UpdateStageDialogState extends ConsumerState<UpdateStageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notasController;

  @override
  void initState() {
    super.initState();
    _notasController = TextEditingController();
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateStageProvider);
    final isLoading = state.isLoading;
    final canAdvance = widget.etapaActual != TreatmentStage.alta;

    final int currentIdx = TreatmentStage.values.indexOf(widget.etapaActual);
    final TreatmentStage? nextStage = canAdvance ? TreatmentStage.values[currentIdx + 1] : null;

    return AlertDialog(
      title: const Text('Avanzar etapa del tratamiento'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(stageNames[widget.etapaActual] ?? widget.etapaActual.name)),
                const Icon(Icons.arrow_forward),
                Expanded(
                  child: Text(
                    nextStage != null ? (stageNames[nextStage] ?? nextStage.name) : 'Sin siguiente etapa',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasController,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notas del cambio'),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Las notas son obligatorias';
                if (v.length < 10) return 'Mínimo 10 caracteres';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(
              'Esta acción no se puede deshacer. El historial quedará registrado.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OcgColors.error,
                    fontWeight: FontWeight.w600,
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
          label: 'Confirmar',
          isLoading: isLoading,
          onPressed: (!canAdvance || !_isNotesValid || isLoading)
              ? null
              : () => _submit(nextStage!),
        ),
      ],
    );
  }

  bool get _isNotesValid => _notasController.text.trim().length >= 10;

  Future<void> _submit(TreatmentStage nextStage) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      await ref.read(updateStageProvider.notifier).updateStage(
            patientId: widget.patientId,
            etapaAnterior: widget.etapaActual,
            nuevaEtapa: nextStage,
            notas: _notasController.text.trim(),
            adminId: widget.adminId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}
