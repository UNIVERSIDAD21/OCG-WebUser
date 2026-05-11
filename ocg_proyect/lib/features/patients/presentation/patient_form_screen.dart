import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_confirm_dialog.dart';
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

class _PatientFormScreenState extends ConsumerState<PatientFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();

  DateTime? _fechaNacimiento;
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
  DateTime? _initialFechaNacimiento;
  DateTime _initialFechaInicio = DateTime.now();
  DateTime? _initialFechaEstimadaFin;
  TreatmentType _initialTipo = TreatmentType.convencional;
  TreatmentStage _initialEtapa = TreatmentStage.valoracionInicial;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeSlide = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notasCtrl.dispose();
    _totalCtrl.dispose();
    _saldoCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEdit;
    final isDesktop = WebLayoutContext.useDesktopShell(context);

    final patientTreatmentsAsync = isEdit
        ? ref.watch(patientTreatmentsProvider(widget.patientId!))
        : const AsyncData<List<PatientTreatment>>(<PatientTreatment>[]);
    final remoteTreatments =
        patientTreatmentsAsync.asData?.value ?? const <PatientTreatment>[];
    final primary = _resolvePrimaryTreatment(remoteTreatments);
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
        ? _EditFormView(
            formKey: _formKey,
            nameCtrl: _nameCtrl,
            emailCtrl: _emailCtrl,
            phoneCtrl: _phoneCtrl,
            notasCtrl: _notasCtrl,
            totalCtrl: _totalCtrl,
            saldoCtrl: _saldoCtrl,
            tipo: _tipo,
            etapa: _etapa,
            fechaNacimiento: _fechaNacimiento,
            fechaInicio: _fechaInicio,
            fechaEstimadaFin: _fechaEstimadaFin,
            hasStructuredTreatments: hasStructuredTreatments,
            primaryTreatment: primary,
            patientId: widget.patientId!,
            loading: _loading,
            onTipoChanged: (v) {
              if (v != null) setState(() => _tipo = v);
            },
            onEtapaChanged: (v) {
              if (v != null) setState(() => _etapa = v);
            },
            onFechaNacimiento: (d) => setState(() => _fechaNacimiento = d),
            onFechaNacimientoClear: () =>
                setState(() => _fechaNacimiento = null),
            onFechaInicio: (d) => setState(() => _fechaInicio = d),
            onFechaEstimadaFin: (d) =>
                setState(() => _fechaEstimadaFin = d),
            onFechaEstimadaFinClear: () =>
                setState(() => _fechaEstimadaFin = null),
            onCancel: _loading
                ? null
                : () async {
                    final canLeave = await _confirmDiscardChangesIfNeeded();
                    if (!canLeave || !context.mounted) return;
                    _exitWithoutSaving();
                  },
            onSave: _loading ? null : _save,
            applyCopMask: _applyCopMask,
          )
        : const _CreateInfoView();

    final body = FadeTransition(
      opacity: _fadeSlide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(_fadeSlide),
        child: pageBody,
      ),
    );

    if (isDesktop) {
      return AdminWebShell(
        title: isEdit ? 'Editar paciente' : 'Nuevo paciente',
        child: body,
      );
    }

    return WillPopScope(
      onWillPop: _confirmDiscardChangesIfNeeded,
      child: Scaffold(
        backgroundColor: const Color(0xFFEDE8DC),
        body: SafeArea(
          child: Stack(
            children: [
              const _FormBlob(
                top: -50, right: -30, size: 160, color: Color(0x30C8AF8C),
              ),
              const _FormBlob(
                bottom: -30, left: -20, size: 120, color: Color(0x20B49B78),
              ),
              Column(
                children: [
                  _FormHeader(
                    title: isEdit ? 'Editar paciente' : 'Nuevo paciente',
                    onBack: () async {
                      final canLeave =
                          await _confirmDiscardChangesIfNeeded();
                      if (!canLeave || !context.mounted) return;
                      _exitWithoutSaving();
                    },
                  ),
                  Expanded(child: body),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────

  PatientTreatment? _resolvePrimaryTreatment(
      List<PatientTreatment> items) {
    if (items.isEmpty) return null;
    for (final item in items) {
      if (item.isPrimary) return item;
    }
    return items.first;
  }

  String _formatCopInput(num value) => formatCop(value);

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
    return await OcgConfirmDialog.show(
      context,
      type: OcgConfirmDialogType.warning,
      title: 'Descartar cambios',
      message: 'Tienes cambios sin guardar. ¿Deseas salir y descartarlos?',
      confirmLabel: 'Descartar',
      cancelLabel: 'Seguir editando',
      onConfirm: () {},
    ) ?? false;
  }

  void _exitWithoutSaving() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (widget.isEdit && widget.patientId != null) {
      context.go(RouteNames.adminPatientDetail
          .replaceFirst(':patientId', widget.patientId!));
      return;
    }
    context.go(RouteNames.adminPatients);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.isEdit) return;

    setState(() => _loading = true);
    final repo = ref.read(patientsRepositoryProvider);
    final treatmentsAsync =
        ref.read(patientTreatmentsProvider(widget.patientId!));
    final remote =
        treatmentsAsync.asData?.value ?? const <PatientTreatment>[];
    final hasStructuredTreatments = remote.isNotEmpty;

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

      final payload = <String, dynamic>{
        'id': patient.id, 'uid': patient.id,
        'nombre': patient.nombre, 'email': patient.email,
        'telefono': patient.telefono,
        'fechaNacimiento': patient.fechaNacimiento == null
            ? null
            : Timestamp.fromDate(patient.fechaNacimiento!),
        'fechaEstimadaFin': patient.fechaEstimadaFin == null
            ? null : Timestamp.fromDate(patient.fechaEstimadaFin!),
      };

      if (!hasStructuredTreatments) {
        payload.addAll(<String, dynamic>{
          'tipoTratamiento': patient.tipoTratamiento?.name,
          'etapaActual': patient.etapaActual.name,
          'fechaInicio': Timestamp.fromDate(patient.fechaInicio),
          'notasClinicas': patient.notasClinicas,
          'totalTratamiento': patient.totalTratamiento,
          'saldoPendiente': patient.saldoPendiente,
        });
      }

      await repo.updatePatientBasicData(patient.id, payload);

      if (!hasStructuredTreatments) {
        final tr = ref.read(patientTreatmentsRepositoryProvider);
        final initial = PatientTreatment.fromLegacyPatient(patient).copyWith(
          id: 'treatment-${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isPrimary: true,
        );
        await tr.saveTreatment(patientId: patient.id, treatment: initial);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(hasStructuredTreatments
            ? 'Paciente actualizado'
            : 'Paciente actualizado y tratamiento principal creado'),
      ));
      context.go(RouteNames.adminPatientDetail
          .replaceFirst(':patientId', patient.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM HEADER (mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.fromLTRB(4, MediaQuery.paddingOf(context).top + 4, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C2016), Color(0xFF4A3628)],
        ),
        borderRadius:
            BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: OcgColors.ivory, size: 18),
          ),
          const SizedBox(width: 4),
          Text(title,
              style: const TextStyle(color: OcgColors.ivory, fontSize: 18,
                  fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT FORM CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _EditFormView extends StatelessWidget {
  const _EditFormView({
    required this.formKey, required this.nameCtrl, required this.emailCtrl,
    required this.phoneCtrl, required this.notasCtrl, required this.totalCtrl,
    required this.saldoCtrl, required this.tipo, required this.etapa,
    required this.fechaNacimiento, required this.fechaInicio,
    required this.fechaEstimadaFin, required this.hasStructuredTreatments,
    required this.primaryTreatment, required this.patientId,
    required this.loading, required this.onTipoChanged,
    required this.onEtapaChanged, required this.onFechaNacimiento,
    required this.onFechaNacimientoClear,
    required this.onFechaInicio, required this.onFechaEstimadaFin,
    required this.onFechaEstimadaFinClear, required this.onCancel,
    required this.onSave, required this.applyCopMask,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl, emailCtrl, phoneCtrl, notasCtrl,
      totalCtrl, saldoCtrl;
  final TreatmentType tipo;
  final TreatmentStage etapa;
  final DateTime? fechaNacimiento;
  final DateTime fechaInicio;
  final DateTime? fechaEstimadaFin;
  final bool hasStructuredTreatments;
  final PatientTreatment? primaryTreatment;
  final String patientId;
  final bool loading;
  final ValueChanged<TreatmentType?> onTipoChanged;
  final ValueChanged<TreatmentStage?> onEtapaChanged;
  final ValueChanged<DateTime> onFechaNacimiento, onFechaInicio,
      onFechaEstimadaFin;
  final VoidCallback onFechaNacimientoClear;
  final VoidCallback onFechaEstimadaFinClear;
  final VoidCallback? onCancel, onSave;
  final void Function(TextEditingController, String) applyCopMask;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            _section('Datos personales', Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _field(nameCtrl, 'Nombre completo', 'Nombre y apellidos', Icons.person_outline_rounded,
                validator: Validators.fullName),
            const SizedBox(height: 14),
            _field(emailCtrl, 'Correo electrónico', 'correo@ejemplo.com', Icons.email_outlined,
                keyboardType: TextInputType.emailAddress, validator: Validators.email),
            const SizedBox(height: 14),
            _field(phoneCtrl, 'Teléfono', 'Número de contacto', Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => Validators.requiredField(v, message: 'Ingresa teléfono')),
            const SizedBox(height: 14),
            _dateField(
              context,
              'Fecha de nacimiento',
              fechaNacimiento,
              onFechaNacimiento,
              nullable: true,
              onClear: onFechaNacimientoClear,
            ),
            const SizedBox(height: 24),

            _section('Tratamiento', Icons.medical_services_outlined),
            const SizedBox(height: 12),

            if (hasStructuredTreatments)
              _StructuredTreatmentBanner(treatment: primaryTreatment, patientId: patientId)
            else ...[
              _legacyBanner(),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                final narrow = constraints.maxWidth < 520;
                final tipoField = _dropdown<TreatmentType>(
                  'Tipo de tratamiento', tipo, TreatmentType.values,
                  (e) => switch (e) {
                    TreatmentType.convencional => 'Convencional',
                    TreatmentType.estetico => 'Estético',
                    TreatmentType.autoligado => 'Autoligado',
                    TreatmentType.alineadores => 'Alineadores',
                    TreatmentType.ortopedia => 'Ortopedia',
                    TreatmentType.interceptivo => 'Interceptivo',
                    TreatmentType.retenedores => 'Retenedores',
                  }, onTipoChanged);
                final etapaField = _dropdown<TreatmentStage>(
                  'Etapa actual', etapa, TreatmentStage.values,
                  formatTreatmentStage, onEtapaChanged);
                if (narrow) {
                  return Column(
                      children: [tipoField, const SizedBox(height: 14), etapaField]);
                }
                return Row(children: [
                  Expanded(child: tipoField),
                  const SizedBox(width: 12),
                  Expanded(child: etapaField),
                ]);
              }),
              const SizedBox(height: 14),
              _field(totalCtrl, 'Total tratamiento (COP)', '0', Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => applyCopMask(totalCtrl, v),
                  validator: (v) => Validators.requiredField(v, message: 'Ingresa total')),
              const SizedBox(height: 14),
              _field(saldoCtrl, 'Saldo pendiente (COP)', '0', Icons.account_balance_wallet_outlined,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => applyCopMask(saldoCtrl, v),
                  validator: (v) => Validators.requiredField(v, message: 'Ingresa saldo')),
              const SizedBox(height: 14),
              _field(notasCtrl, 'Notas clínicas', 'Observaciones', Icons.description_outlined,
                  maxLines: 3),
            ],
            const SizedBox(height: 24),

            _section('Fechas del tratamiento', Icons.calendar_today_rounded),
            const SizedBox(height: 12),
            _dateField(context, 'Fecha de inicio', fechaInicio, onFechaInicio),
            const SizedBox(height: 14),
            _dateField(context, 'Fecha estimada de fin', fechaEstimadaFin, onFechaEstimadaFin,
                nullable: true, onClear: onFechaEstimadaFinClear),
            const SizedBox(height: 28),

            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6E5442),
                      side: const BorderSide(color: Color(0xFFD9CCBE), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2016),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('Guardar cambios',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Helper builders ──

  Widget _section(String title, IconData icon) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFC8AF8C), Color(0xFFA88F6E)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(color: Color(0xFF2C2016), fontSize: 16,
                  fontWeight: FontWeight.w700, letterSpacing: -0.2)),
          Container(
            height: 2, margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFC8AF8C), Color(0x00C8AF8C)]),
              borderRadius: BorderRadius.all(Radius.circular(1)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _field(TextEditingController ctrl, String label, String placeholder, IconData icon,
      {TextInputType? keyboardType, int maxLines = 1, FormFieldValidator<String>? validator,
      ValueChanged<String>? onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 14, color: const Color(0xFFA89078)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFFA89078), fontSize: 12,
              fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ]),
      ),
      TextFormField(
        controller: ctrl, keyboardType: keyboardType, maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(color: Color(0xFF2C2016), fontSize: 14.5, letterSpacing: 0.15),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(color: Color(0xFFC4B3A2), fontSize: 13.5),
          filled: true, fillColor: const Color(0xFFF9F5EF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE0C7AF), width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFC8AF8C), width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2)),
        ),
        validator: validator,
      ),
    ]);
  }

  Widget _dropdown<T>(String label, T value, List<T> items,
      String Function(T) labelFn, ValueChanged<T?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          const Icon(Icons.arrow_drop_down_circle_outlined, size: 14, color: Color(0xFFA89078)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFFA89078), fontSize: 12,
              fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ]),
      ),
      DropdownButtonFormField<T>(
        value: value, isExpanded: true,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(labelFn(e)))).toList(),
        onChanged: onChanged,
        style: const TextStyle(color: Color(0xFF2C2016), fontSize: 14.5),
        decoration: InputDecoration(
          filled: true, fillColor: const Color(0xFFF9F5EF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE0C7AF), width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFC8AF8C), width: 2)),
        ),
      ),
    ]);
  }

  Widget _dateField(BuildContext context, String label, DateTime? value, ValueChanged<DateTime> onPick,
      {bool nullable = false, VoidCallback? onClear}) {
    final text = value == null ? 'No definida'
        : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFFA89078)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFFA89078), fontSize: 12,
              fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ]),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F5EF), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0C7AF)),
        ),
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(
              color: value == null ? const Color(0xFFC4B3A2) : const Color(0xFF2C2016),
              fontSize: 14.5))),
          TextButton(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                  context: context, initialDate: value ?? now,
                  firstDate: DateTime(1950), lastDate: DateTime(now.year + 15));
              if (picked != null) onPick(picked);
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF6E5442)),
            child: const Text('Seleccionar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (nullable && value != null)
            SizedBox(
              width: 32,
              child: IconButton(onPressed: onClear, icon: const Icon(Icons.clear, size: 16),
                  color: const Color(0xFFA89078), padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(), tooltip: 'Limpiar'),
            ),
        ]),
      ),
    ]);
  }

  Widget _legacyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF9F3), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0C7AF).withOpacity(0.6)),
      ),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: Color(0xFF8A6F59), size: 18),
        SizedBox(width: 10),
        Expanded(child: Text(
          'Al ser un paciente con esquema legacy, se creará automáticamente su tratamiento principal al guardar.',
          style: TextStyle(color: Color(0xFF6E5442), fontSize: 12.5, height: 1.4),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE INFO VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _CreateInfoView extends StatelessWidget {
  const _CreateInfoView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFFCF8), Color(0xFFF7F2E8)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE7DDD2).withOpacity(0.7), width: 1.2),
            boxShadow: [BoxShadow(color: const Color(0xFF2C2016).withOpacity(0.08),
                blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: const Color(0xFFC8AF8C).withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.person_add_rounded, color: Color(0xFF8A6F59), size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Flujo de creación actualizado', textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF2C2016), fontSize: 17,
                    fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            const Text(
              'El paciente debe registrarse primero desde la pantalla de login. '
              'Cuando aparezca en la lista, completa sus datos clínicos desde aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A6F59), fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () => context.go(RouteNames.adminPatients),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C2016), foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Ir a lista de pacientes',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER & DECO
// ─────────────────────────────────────────────────────────────────────────────

class _StructuredTreatmentBanner extends StatelessWidget {
  const _StructuredTreatmentBanner({required this.treatment, required this.patientId});
  final PatientTreatment? treatment;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFDF9F3), Color(0xFFF5EDE0)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9CCBE).withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: const Color(0xFF8A6F59).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_tree_outlined, color: Color(0xFF6E5442), size: 18)),
          const SizedBox(width: 10),
          const Text('Tratamientos múltiples activos',
              style: TextStyle(color: Color(0xFF2C2016), fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Text(
          treatment == null
              ? 'Gestiona los tratamientos desde la pestaña Tratamiento del expediente.'
              : 'Principal: ${treatment!.displayName} — ${stageNames[treatment!.etapaActual] ?? treatment!.etapaActual.name}.',
          style: const TextStyle(color: Color(0xFF6E5442), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: () => context.go(
                '${RouteNames.adminPatientDetail.replaceFirst(':patientId', patientId)}?section=tratamiento'),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Gestionar tratamientos'),
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6E5442),
                side: const BorderSide(color: Color(0xFFD9CCBE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ]),
    );
  }
}

class _FormBlob extends StatelessWidget {
  final double? top, right, bottom, left;
  final double size;
  final Color color;
  const _FormBlob({this.top, this.right, this.bottom, this.left,
      required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, right: right, bottom: bottom, left: left,
      child: IgnorePointer(
        child: Container(width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [color, color.withOpacity(0)], stops: const [0, 0.7])),
        ),
      ),
    );
  }
}
