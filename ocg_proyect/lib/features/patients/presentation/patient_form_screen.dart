import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_button.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';

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
  TreatmentStage _etapa = TreatmentStage.diagnostico;

  bool _loading = false;
  bool _loadedInitialData = false;

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

    if (isEdit) {
      final patientAsync = ref.watch(patientByIdProvider(widget.patientId!));
      patientAsync.whenData((patient) {
        if (patient != null && !_loadedInitialData) {
          _idCtrl.text = patient.id;
          _nameCtrl.text = patient.nombre;
          _emailCtrl.text = patient.email;
          _phoneCtrl.text = patient.telefono;
          _notasCtrl.text = patient.notasClinicas;
          _totalCtrl.text = patient.totalTratamiento.toStringAsFixed(0);
          _saldoCtrl.text = patient.saldoPendiente.toStringAsFixed(0);
          _fechaNacimiento = patient.fechaNacimiento;
          _fechaInicio = patient.fechaInicio;
          _fechaEstimadaFin = patient.fechaEstimadaFin;
          _tipo = patient.tipoTratamiento;
          _etapa = patient.etapaActual;
          _loadedInitialData = true;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar paciente' : 'Nuevo paciente'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _idCtrl,
              enabled: !isEdit,
              decoration: const InputDecoration(
                labelText: 'UID paciente',
                hintText: 'UID de Firebase Auth',
              ),
              validator: (v) => Validators.requiredField(v, message: 'Ingresa UID del paciente'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
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
              decoration: const InputDecoration(labelText: 'Teléfono'),
              validator: (v) => Validators.requiredField(v, message: 'Ingresa teléfono'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TreatmentType>(
                    initialValue: _tipo,
                    items: TreatmentType.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _tipo = value);
                    },
                    decoration: const InputDecoration(labelText: 'Tipo tratamiento'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<TreatmentStage>(
                    initialValue: _etapa,
                    items: TreatmentStage.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _etapa = value);
                    },
                    decoration: const InputDecoration(labelText: 'Etapa actual'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _totalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total tratamiento (COP)'),
              validator: (v) => Validators.requiredField(v, message: 'Ingresa total tratamiento'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _saldoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Saldo pendiente (COP)'),
              validator: (v) => Validators.requiredField(v, message: 'Ingresa saldo pendiente'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notasCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notas clínicas'),
            ),
            const SizedBox(height: 10),
            _DatePickerRow(
              label: 'Fecha nacimiento',
              value: _fechaNacimiento,
              onPick: (date) => setState(() => _fechaNacimiento = date),
            ),
            _DatePickerRow(
              label: 'Fecha inicio',
              value: _fechaInicio,
              onPick: (date) => setState(() => _fechaInicio = date),
            ),
            _DatePickerRow(
              label: 'Fecha estimada fin',
              value: _fechaEstimadaFin,
              onPick: (date) => setState(() => _fechaEstimadaFin = date),
              nullable: true,
              onClear: () => setState(() => _fechaEstimadaFin = null),
            ),
            const SizedBox(height: 16),
            OcgButton(
              label: isEdit ? 'Guardar cambios' : 'Crear paciente',
              isLoading: _loading,
              onPressed: _loading ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final repo = ref.read(patientsRepositoryProvider);

    try {
      final patient = PatientModel(
        id: _idCtrl.text.trim(),
        nombre: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        telefono: _phoneCtrl.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        tipoTratamiento: _tipo,
        etapaActual: _etapa,
        fechaInicio: _fechaInicio,
        fechaEstimadaFin: _fechaEstimadaFin,
        notasClinicas: _notasCtrl.text.trim(),
        totalTratamiento: double.tryParse(_totalCtrl.text.trim()) ?? 0,
        saldoPendiente: double.tryParse(_saldoCtrl.text.trim()) ?? 0,
      );

      if (widget.isEdit) {
        await repo.updatePatientBasicData(patient.id, patient.toJson());
      } else {
        await repo.createPatient(patient);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEdit ? 'Paciente actualizado' : 'Paciente creado')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
