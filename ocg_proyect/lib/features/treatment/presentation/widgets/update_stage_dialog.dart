import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../patients/data/models/patient_model.dart';
import '../../providers/treatment_provider.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_button.dart';

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
  late final TextEditingController _motivoController;
  late final TextEditingController _diagnosticoController;
  late final TextEditingController _planController;
  late final TextEditingController _adjuntosController;

  TreatmentStage? _nuevaEtapa;
  DateTime? _fechaEfectiva;

  @override
  void initState() {
    super.initState();
    _notasController = TextEditingController();
    _motivoController = TextEditingController();
    _diagnosticoController = TextEditingController();
    _planController = TextEditingController();
    _adjuntosController = TextEditingController();
  }

  @override
  void dispose() {
    _notasController.dispose();
    _motivoController.dispose();
    _diagnosticoController.dispose();
    _planController.dispose();
    _adjuntosController.dispose();
    super.dispose();
  }

  bool get _hasNotesError {
    final value = _notasController.text.trim();
    return value.isNotEmpty && value.length < 10;
  }

  bool get _isRetroceso {
    if (_nuevaEtapa == null) return false;
    return TreatmentStage.values.indexOf(_nuevaEtapa!) < TreatmentStage.values.indexOf(widget.etapaActual);
  }

  bool get _canSave => _nuevaEtapa != null && !_hasNotesError;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateStageProvider);
    final isLoading = state.isLoading;

    return AlertDialog(
      title: const Text('Cambiar etapa del tratamiento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Etapa actual: ${stageNames[widget.etapaActual] ?? widget.etapaActual.name}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<TreatmentStage>(
                value: _nuevaEtapa,
                decoration: const InputDecoration(labelText: 'Nueva etapa'),
                items: TreatmentStage.values
                    .where((e) => e != widget.etapaActual)
                    .map(
                      (e) => DropdownMenuItem<TreatmentStage>(
                        value: e,
                        child: Text(stageNames[e] ?? e.name),
                      ),
                    )
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (value) {
                        setState(() => _nuevaEtapa = value);
                      },
              ),
              if (_isRetroceso) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OcgColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: OcgColors.warning.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.undo, color: OcgColors.warning, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estás registrando un retroceso de etapa. Quedará registrado en el historial clínico.',
                          style: TextStyle(color: OcgColors.warning, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text('Campos opcionales', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notasController,
                minLines: 3,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nota clínica',
                  errorText: _hasNotesError ? 'Si escribes nota, debe tener mínimo 10 caracteres.' : null,
                  helperText: '${_notasController.text.trim().length} / mín. 10 caracteres',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _motivoController,
                maxLines: 1,
                decoration: const InputDecoration(labelText: 'Motivo del cambio'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _diagnosticoController,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Diagnóstico breve'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _planController,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Plan siguiente etapa'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _adjuntosController,
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Adjuntos',
                  hintText: 'Describe los adjuntos asociados',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fechaEfectiva == null
                          ? 'Fecha efectiva (opcional): no definida'
                          : 'Fecha efectiva: ${_formatDate(_fechaEfectiva!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: isLoading ? null : _pickFechaEfectiva,
                    child: const Text('Seleccionar fecha'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OcgColors.error.withOpacity(0.25)),
                ),
                child: const Text(
                  'El historial de cambios quedará registrado y no puede eliminarse.',
                  style: TextStyle(color: OcgColors.error, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OcgButton(
          label: 'Cancelar',
          variant: OcgButtonVariant.outline,
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
        ),
        OcgButton(
          label: 'Guardar cambio',
          isLoading: isLoading,
          onPressed: (!_canSave || isLoading) ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _pickFechaEfectiva() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaEfectiva ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        _fechaEfectiva = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _submit() async {
    if (_nuevaEtapa == null) return;

    try {
      await ref.read(updateStageProvider.notifier).updateStage(
            patientId: widget.patientId,
            etapaActual: widget.etapaActual,
            nuevaEtapa: _nuevaEtapa!,
            notas: _notasController.text,
            adminId: widget.adminId,
            motivoCambio: _motivoController.text,
            diagnosticoBreve: _diagnosticoController.text,
            planSiguienteEtapa: _planController.text,
            adjuntosDescripcion: _adjuntosController.text,
            fechaEfectiva: _fechaEfectiva,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}
