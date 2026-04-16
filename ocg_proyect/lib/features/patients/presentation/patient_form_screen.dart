import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_button.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../treatment/data/models/patient_treatment.dart';
import '../../treatment/providers/patient_treatments_provider.dart';

class PatientFormScreen extends ConsumerStatefulWidget {
  const PatientFormScreen({super.key, this.patientId});

  final String? patientId;

  bool get isEdit => patientId != null && patientId!.isNotEmpty;

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();

  DateTime _fechaNacimiento = DateTime(2000, 1, 1);
  DateTime _fechaInicio = DateTime.now();
  DateTime? _fechaEstimadaFin;

  TreatmentType _tipo = TreatmentType.convencional;
  TreatmentStage _etapa = TreatmentStage.valoracionInicial;

  bool _loading = false;
  bool _loadedInitialData = false;

  String _initialName = '';
  String _initialEmail = '';
  String _initialPhone = '';
  String _initialNotas = '';
  String _initialTotal = '';
  String _initialSaldo = '';
  DateTime _initialFechaNacimiento = DateTime(2000, 1, 1);
  DateTime _initialFechaInicio = DateTime.now();
  DateTime? _initialFechaEstimadaFin;
  TreatmentType _initialTipo = TreatmentType.convencional;
  TreatmentStage _initialEtapa = TreatmentStage.valoracionInicial;

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notasCtrl.dispose();
    _totalCtrl.dispose();
    _saldoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEdit;

    final patientTreatmentsAsync = isEdit
        ? ref.watch(patientTreatmentsProvider(widget.patientId!))
        : const AsyncData<List<PatientTreatment>>(<PatientTreatment>[]);
    final remoteTreatments = patientTreatmentsAsync.asData?.value ?? const <PatientTreatment>[];
    final primaryTreatment = _resolvePrimaryTreatment(remoteTreatments);
    final hasStructuredTreatments = remoteTreatments.isNotEmpty;

    if (isEdit) {
      final patientAsync = ref.watch(patientByIdProvider(widget.patientId!));
      patientAsync.whenData((patient) {
        if (patient != null && !_loadedInitialData) {
          _idCtrl.text = patient.id;
          _nameCtrl.text = patient.nombre;
          _emailCtrl.text = patient.email;
          _phoneCtrl.text = patient.telefono;
          _notasCtrl.text = patient.notasClinicas;
          _totalCtrl.text = _formatCopInput(patient.totalTratamiento);
          _saldoCtrl.text = _formatCopInput(patient.saldoPendiente);
          _fechaNacimiento = patient.fechaNacimiento;
          _fechaInicio = patient.fechaInicio;
          _fechaEstimadaFin = patient.fechaEstimadaFin;
          _tipo = patient.tipoTratamiento ?? TreatmentType.convencional;
          _etapa = patient.etapaActual;

          _initialName = patient.nombre;
          _initialEmail = patient.email;
          _initialPhone = patient.telefono;
          _initialNotas = patient.notasClinicas;
          _initialTotal = _formatCopInput(patient.totalTratamiento);
          _initialSaldo = _formatCopInput(patient.saldoPendiente);
          _initialFechaNacimiento = patient.fechaNacimiento;
          _initialFechaInicio = patient.fechaInicio;
          _initialFechaEstimadaFin = patient.fechaEstimadaFin;
          _initialTipo = patient.tipoTratamiento ?? TreatmentType.convencional;
          _initialEtapa = patient.etapaActual;
          _loadedInitialData = true;
        }
      });
    }

    final pageBody = isEdit
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                      ),
                      validator: Validators.fullName,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Correo'),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                      ),
                      validator: (v) => Validators.requiredField(
                        v,
                        message: 'Ingresa teléfono',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (hasStructuredTreatments)
                      _StructuredTreatmentBanner(
                        treatment: primaryTreatment,
                        onOpenTreatmentWorkspace: () => context.go(
                          '${RouteNames.adminPatientDetail.replaceFirst(':patientId', widget.patientId!)}?section=tratamiento',
                        ),
                      )
                    else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: OcgColors.bronze.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: OcgColors.bronze.withValues(alpha: 0.18)),
                        ),
                        child: const Text(
                          'Este paciente aún usa el esquema legacy. Al guardar se creará automáticamente su tratamiento principal en la subcolección de tratamientos.',
                          style: TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 560;

                          Widget typeField = DropdownButtonFormField<TreatmentType>(
                            value: _tipo,
                            isExpanded: true,
                            items: TreatmentType.values
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(_treatmentTypeLabel(e)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _tipo = value);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Tipo tratamiento principal',
                            ),
                          );

                          Widget stageField = DropdownButtonFormField<TreatmentStage>(
                            value: _etapa,
                            isExpanded: true,
                            items: TreatmentStage.values
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(formatTreatmentStage(e)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _etapa = value);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Etapa actual',
                            ),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                typeField,
                                const SizedBox(height: 10),
                                stageField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: typeField),
                              const SizedBox(width: 10),
                              Expanded(child: stageField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _totalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total tratamiento (COP)',
                        ),
                        onChanged: (value) => _applyCopMask(_totalCtrl, value),
                        validator: (v) => Validators.requiredField(
                          v,
                          message: 'Ingresa total tratamiento',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _saldoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Saldo pendiente (COP)',
                        ),
                        onChanged: (value) => _applyCopMask(_saldoCtrl, value),
                        validator: (v) => Validators.requiredField(
                          v,
                          message: 'Ingresa saldo pendiente',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _notasCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notas clínicas del tratamiento principal',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _DatePickerRow(
                      label: 'Fecha nacimiento',
                      value: _fechaNacimiento,
                      onPick: (date) =>
                          setState(() => _fechaNacimiento = date),
                    ),
                    _DatePickerRow(
                      label: 'Fecha inicio',
                      value: _fechaInicio,
                      onPick: (date) => setState(() => _fechaInicio = date),
                    ),
                    _DatePickerRow(
                      label: 'Fecha estimada fin',
                      value: _fechaEstimadaFin,
                      onPick: (date) =>
                          setState(() => _fechaEstimadaFin = date),
                      nullable: true,
                      onClear: () => setState(() => _fechaEstimadaFin = null),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () async {
                                    final canLeave =
                                        await _confirmDiscardChangesIfNeeded();
                                    if (!canLeave || !context.mounted) return;
                                    _exitWithoutSaving();
                                  },
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OcgButton(
                            label: 'Guardar cambios',
                            isLoading: _loading,
                            onPressed: _loading ? null : _save,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: OcgColors.bronze.withValues(alpha: 0.22),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Flujo de creación actualizado',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: OcgColors.espresso,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'El paciente debe registrarse primero desde login. '
                        'Cuando aparezca en la lista de pacientes, completa sus datos clínicos desde edición.',
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () =>
                              context.go(RouteNames.adminPatients),
                          child: const Text('Entendido'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

    if (WebLayoutContext.useDesktopShell(context)) {
      return AdminWebShell(
        title: isEdit ? 'Editar paciente' : 'Nuevo paciente',
        child: pageBody,
      );
    }

    return WillPopScope(
      onWillPop: _confirmDiscardChangesIfNeeded,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canLeave = await _confirmDiscardChangesIfNeeded();
              if (!canLeave || !context.mounted) return;
              _exitWithoutSaving();
            },
          ),
          title: Text(isEdit ? 'Editar paciente' : 'Nuevo paciente'),
        ),
        body: pageBody,
      ),
    );
  }

  String _treatmentTypeLabel(TreatmentType type) => switch (type) {
    TreatmentType.convencional => 'Convencional',
    TreatmentType.estetico => 'Estético',
    TreatmentType.autoligado => 'Autoligado',
    TreatmentType.alineadores => 'Alineadores',
    TreatmentType.ortopedia => 'Ortopedia',
    TreatmentType.interceptivo => 'Interceptivo',
    TreatmentType.retenedores => 'Retenedores',
  };

  PatientTreatment? _resolvePrimaryTreatment(List<PatientTreatment> items) {
    if (items.isEmpty) return null;
    for (final item in items) {
      if (item.isPrimary) return item;
    }
    return items.first;
  }

  String _formatCopInput(num value) {
    return formatCop(value);
  }

  double _parseCopInput(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return double.tryParse(digits) ?? 0;
  }

  void _applyCopMask(TextEditingController controller, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      controller.value = const TextEditingValue(text: '');
      return;
    }

    final formatted = formatCop(double.parse(digits));

    if (formatted == controller.text) return;

    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  bool _hasUnsavedChanges() {
    if (!widget.isEdit || !_loadedInitialData) return false;

    return _nameCtrl.text.trim() != _initialName.trim() ||
        _emailCtrl.text.trim() != _initialEmail.trim() ||
        _phoneCtrl.text.trim() != _initialPhone.trim() ||
        _notasCtrl.text.trim() != _initialNotas.trim() ||
        _totalCtrl.text.trim() != _initialTotal.trim() ||
        _saldoCtrl.text.trim() != _initialSaldo.trim() ||
        _fechaNacimiento != _initialFechaNacimiento ||
        _fechaInicio != _initialFechaInicio ||
        _fechaEstimadaFin != _initialFechaEstimadaFin ||
        _tipo != _initialTipo ||
        _etapa != _initialEtapa;
  }

  Future<bool> _confirmDiscardChangesIfNeeded() async {
    if (!_hasUnsavedChanges()) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text(
          'Tienes cambios sin guardar. ¿Deseas salir y descartarlos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    return shouldDiscard == true;
  }

  void _exitWithoutSaving() {
    if (!mounted) return;

    if (context.canPop()) {
      context.pop();
      return;
    }

    if (widget.isEdit && widget.patientId != null) {
      context.go(
        RouteNames.adminPatientDetail.replaceFirst(':patientId', widget.patientId!),
      );
      return;
    }

    context.go(RouteNames.adminPatients);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.isEdit) return;

    setState(() => _loading = true);
    final repo = ref.read(patientsRepositoryProvider);
    final treatmentsAsync = ref.read(patientTreatmentsProvider(widget.patientId!));
    final remoteTreatments = treatmentsAsync.asData?.value ?? const <PatientTreatment>[];
    final hasStructuredTreatments = remoteTreatments.isNotEmpty;

    try {
      final patient = PatientModel(
        id: widget.patientId!.trim(),
        nombre: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        telefono: _phoneCtrl.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        tipoTratamiento: _tipo,
        etapaActual: _etapa,
        fechaInicio: _fechaInicio,
        fechaEstimadaFin: _fechaEstimadaFin,
        notasClinicas: _notasCtrl.text.trim(),
        totalTratamiento: _parseCopInput(_totalCtrl.text),
        saldoPendiente: _parseCopInput(_saldoCtrl.text),
      );

      final updatePayload = <String, dynamic>{
        'id': patient.id,
        'uid': patient.id,
        'nombre': patient.nombre,
        'email': patient.email,
        'telefono': patient.telefono,
        'fechaNacimiento': Timestamp.fromDate(patient.fechaNacimiento),
        'fechaEstimadaFin': patient.fechaEstimadaFin == null
            ? null
            : Timestamp.fromDate(patient.fechaEstimadaFin!),
      };

      if (!hasStructuredTreatments) {
        updatePayload.addAll(<String, dynamic>{
          'tipoTratamiento': patient.tipoTratamiento?.name,
          'etapaActual': patient.etapaActual.name,
          'fechaInicio': Timestamp.fromDate(patient.fechaInicio),
          'notasClinicas': patient.notasClinicas,
          'totalTratamiento': patient.totalTratamiento,
          'saldoPendiente': patient.saldoPendiente,
        });
      }

      await repo.updatePatientBasicData(patient.id, updatePayload);

      if (!hasStructuredTreatments) {
        final treatmentRepo = ref.read(patientTreatmentsRepositoryProvider);
        final initialTreatment = PatientTreatment.fromLegacyPatient(patient).copyWith(
          id: 'treatment-${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isPrimary: true,
        );

        await treatmentRepo.saveTreatment(
          patientId: patient.id,
          treatment: initialTreatment,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasStructuredTreatments
                ? 'Paciente actualizado'
                : 'Paciente actualizado y tratamiento principal creado',
          ),
        ),
      );
      context.go(
        RouteNames.adminPatientDetail.replaceFirst(':patientId', patient.id),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _StructuredTreatmentBanner extends StatelessWidget {
  const _StructuredTreatmentBanner({
    required this.treatment,
    required this.onOpenTreatmentWorkspace,
  });

  final PatientTreatment? treatment;
  final VoidCallback onOpenTreatmentWorkspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tratamientos múltiples activos en este paciente',
            style: theme.titleSmall?.copyWith(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            treatment == null
                ? 'El tratamiento se gestiona desde la pestaña Tratamiento del expediente.'
                : 'Tratamiento principal: ${treatment!.displayName}. Etapa actual: ${stageNames[treatment!.etapaActual] ?? treatment!.etapaActual.name}.',
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onOpenTreatmentWorkspace,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Gestionar tratamientos'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.onPick,
    this.nullable = false,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final bool nullable;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'No definida'
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text('$label: $text')),
          TextButton(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(1950),
                lastDate: DateTime(now.year + 15),
              );
              if (picked != null) onPick(picked);
            },
            child: const Text('Seleccionar'),
          ),
          if (nullable)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.clear),
              tooltip: 'Limpiar',
            ),
        ],
      ),
    );
  }
}
