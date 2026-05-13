import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_signature_pad.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../treatment/data/models/patient_treatment.dart';
import '../../treatment/providers/patient_treatments_provider.dart';
import '../data/models/consultation_model.dart';
import '../data/repositories/consultation_repository.dart';
import '../providers/consultation_provider.dart';

// ─── Pantalla de Consultación Clínica ────────────────────────────────────────
//
// Reemplaza el simple "Completar" de las citas con un flujo profesional:
// 1. Info del paciente y tratamiento actual
// 2. Control de fase (ver y avanzar)
// 3. Notas clínicas de la consulta
// 4. Firma del paciente (obligatoria para validez legal)
// 5. Guardado con auditoría completa

class ConsultationScreen extends ConsumerStatefulWidget {
  const ConsultationScreen({super.key, required this.appointment});

  final AppointmentModel appointment;

  @override
  ConsumerState<ConsultationScreen> createState() =>
      _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  final TextEditingController _notesCtrl = TextEditingController();
  final ValueNotifier<Uint8List?> _signatureBytes = ValueNotifier<Uint8List?>(null);
  final ValueNotifier<bool> _hasSignature = ValueNotifier<bool>(false);
  final GlobalKey<OcgSignaturePadState> _signaturePadKey = GlobalKey<OcgSignaturePadState>();

  bool _saving = false;
  String? _errorMsg;
  bool _wantsAdvancePhase = false;
  TreatmentStage? _selectedNextStage;

  PatientModel? _patient;
  PatientTreatment? _primaryTreatment;
  bool _loadingPatient = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _signatureBytes.dispose();
    _hasSignature.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    try {
      final patientAsync = await ref
          .read(patientByIdProvider(widget.appointment.patientId).future);
      final treatmentsAsync = await ref
          .read(patientTreatmentsProvider(widget.appointment.patientId).future);

      if (!mounted) return;

      setState(() {
        _patient = patientAsync;
        _primaryTreatment = treatmentsAsync
                ?.where((t) => t.isPrimary)
                .firstOrNull ??
            treatmentsAsync?.firstOrNull;
        _loadingPatient = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPatient = false;
        _errorMsg = 'No se pudo cargar información del paciente.';
      });
    }
  }

  List<TreatmentStage> get _nextStages {
    if (_patient == null) return TreatmentStage.values.toList();
    final current = _patient!.etapaActual;
    final idx = TreatmentStage.values.indexOf(current);
    if (idx < 0 || idx >= TreatmentStage.values.length - 1) return [];
    return TreatmentStage.values.sublist(idx + 1);
  }

  String get _tipoLabel => switch (widget.appointment.tipo) {
        AppointmentType.valoracion => 'Valoración',
        AppointmentType.control => 'Control',
        AppointmentType.instalacion => 'Instalación',
        AppointmentType.urgencia => 'Urgencia',
        AppointmentType.alta => 'Alta',
      };

  String _fmtDate(DateTime d) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${d.day.toString().padLeft(2, '0')} de ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _saveConsultation() async {
    if (_notesCtrl.text.trim().isEmpty) {
      setState(() =>
          _errorMsg = 'Debes escribir las notas de la consulta.');
      return;
    }

    final sigBytes = _signatureBytes.value;
    if (sigBytes == null || sigBytes.isEmpty) {
      setState(() =>
          _errorMsg = 'La firma del paciente es obligatoria.');
      return;
    }

    if (_wantsAdvancePhase && _selectedNextStage == null) {
      setState(() =>
          _errorMsg = 'Selecciona la fase a la que avanza el paciente.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      // 1. Subir firma a Storage
      final signaturePath =
          'patients/${widget.appointment.patientId}/consultations/'
          'signatures/${DateTime.now().millisecondsSinceEpoch}.png';
      final storageRef = FirebaseStorage.instance.ref().child(signaturePath);
      await storageRef.putData(
        sigBytes,
        SettableMetadata(contentType: 'image/png'),
      );
      final signatureUrl = await storageRef.getDownloadURL();

      // 2. Crear documento de consulta
      final now = DateTime.now();
      final auditEntry = AuditEntry(
        action: 'created',
        actorId: 'admin',
        actorName: 'Doctora',
        timestamp: now,
      );

      PhaseSnapshot? phaseSnapshot;
      if (_wantsAdvancePhase && _selectedNextStage != null && _patient != null) {
        phaseSnapshot = PhaseSnapshot(
          previousStage: _patient!.etapaActual,
          currentStage: _selectedNextStage!,
          phaseAdvanced: true,
        );
      }

      final consultation = ConsultationModel(
        id: '',
        patientId: widget.appointment.patientId,
        patientName: widget.appointment.patientName,
        appointmentId: widget.appointment.id,
        doctorId: 'admin',
        doctorName: 'Doctora',
        date: now,
        clinicalNotes: _notesCtrl.text.trim(),
        photos: [],
        phaseSnapshot: phaseSnapshot,
        signatureUrl: signatureUrl,
        signatureCapturedAt: now,
        status: ConsultationStatus.completed,
        auditTrail: [auditEntry],
        createdAt: now,
        updatedAt: now,
      );

      await ref
          .read(consultationRepositoryProvider)
          .createConsultation(consultation);

      // 3. Si avanzó de fase, actualizar paciente
      if (_wantsAdvancePhase && _selectedNextStage != null && _patient != null) {
        await ref.read(patientsRepositoryProvider).updateTreatmentStage(
          patientId: _patient!.id,
          newStage: _selectedNextStage!,
          notas: 'Avance de fase desde consulta: ${widget.appointment.tipo.name}',
          adminId: 'admin',
        );
      }

      // 4. Marcar cita como completada
      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(
            widget.appointment.id,
            AppointmentStatus.completada,
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Consulta guardada exitosamente.'),
          backgroundColor: Color(0xFF166534),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMsg = 'Error al guardar: $e';
      });
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingPatient) {
      return Scaffold(
        backgroundColor: OcgColors.ivory,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [OcgColors.espresso, OcgColors.bronze],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: OcgColors.ivory,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cargando datos del paciente...',
                style: TextStyle(
                  color: OcgColors.bronze,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: OcgColors.ivory,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMsg != null) _buildErrorBanner(),
                    _buildPatientInfoCard(),
                    const SizedBox(height: 16),
                    _buildPhaseControlCard(),
                    const SizedBox(height: 16),
                    _buildClinicalNotesCard(),
                    const SizedBox(height: 16),
                    _buildSignatureCard(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OcgColors.espresso,
            Color(0xFF4A3628),
            OcgColors.espresso,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: OcgColors.ivory,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Consultación Clínica',
                      style: TextStyle(
                        color: OcgColors.ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cormorant Garamond',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_tipoLabel · ${_fmtDate(widget.appointment.fechaHora)}',
                      style: TextStyle(
                        color: OcgColors.ivory.withOpacity(0.65),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OcgColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.error.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: OcgColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMsg!,
              style: const TextStyle(
                color: OcgColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [OcgColors.sand, OcgColors.bronze],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.appointment.patientName,
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cormorant Garamond',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _patient?.telefono ?? '',
                      style: TextStyle(
                        color: OcgColors.bronze,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_primaryTreatment != null) ...[
            const Divider(height: 24, color: Color(0xFFECD9C6)),
            _infoRow(
              Icons.medical_services_outlined,
              'Tratamiento',
              _primaryTreatment!.displayName,
            ),
            const SizedBox(height: 10),
            _infoRow(
              Icons.flag_outlined,
              'Fase actual',
              stageNames[_primaryTreatment!.etapaActual] ??
                  _primaryTreatment!.etapaActual.name,
              valueColor: OcgColors.bronze,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: OcgColors.bronze.withOpacity(0.7)),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
            color: OcgColors.ink.withOpacity(0.55),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? OcgColors.espresso,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseControlCard() {
    final nextStages = _nextStages;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OcgColors.sand.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: OcgColors.espresso,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Control de Fase',
                  style: TextStyle(
                    color: OcgColors.espresso,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cormorant Garamond',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPhaseTimeline(),
          if (nextStages.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFECD9C6)),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _wantsAdvancePhase,
                    onChanged: (v) {
                      setState(() {
                        _wantsAdvancePhase = v ?? false;
                        if (!_wantsAdvancePhase) {
                          _selectedNextStage = null;
                        }
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: BorderSide(
                      color: OcgColors.bronze.withOpacity(0.4),
                      width: 1.5,
                    ),
                    activeColor: OcgColors.espresso,
                    checkColor: OcgColors.ivory,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Avanzar al paciente de fase en esta consulta',
                    style: TextStyle(
                      color: OcgColors.ink.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (_wantsAdvancePhase) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.sand.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: OcgColors.bronze.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seleccionar nueva fase:',
                      style: TextStyle(
                        color: OcgColors.espresso,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...nextStages.map((stage) {
                      final isSelected = _selectedNextStage == stage;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () => setState(() {
                            _selectedNextStage = stage;
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? OcgColors.espresso
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? OcgColors.espresso
                                    : OcgColors.bronze.withOpacity(0.25),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: isSelected
                                      ? OcgColors.ivory
                                      : OcgColors.bronze,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    stageNames[stage] ?? stage.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? OcgColors.ivory
                                          : OcgColors.espresso,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
          if (nextStages.isEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF166534).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 18,
                    color: Color(0xFF166534),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El paciente ya está en la última fase (Alta).',
                      style: const TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhaseTimeline() {
    final currentStage =
        _patient?.etapaActual ?? TreatmentStage.valoracionInicial;
    final allStages = TreatmentStage.values;

    return Row(
      children: allStages.asMap().entries.map((entry) {
        final idx = entry.key;
        final stage = entry.value;
        final isCurrent = stage == currentStage;
        final isPast =
            allStages.indexOf(stage) < allStages.indexOf(currentStage);

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? OcgColors.espresso
                          : isPast
                              ? OcgColors.bronze
                              : OcgColors.mist,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: isCurrent || isPast
                            ? OcgColors.espresso
                            : OcgColors.bronze.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: isCurrent || isPast
                        ? const Icon(
                            Icons.check,
                            size: 12,
                            color: OcgColors.ivory,
                          )
                        : null,
                  ),
                  if (idx < allStages.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isPast
                            ? OcgColors.bronze
                            : OcgColors.bronze.withOpacity(0.2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (isCurrent)
                Text(
                  (stageNames[stage] ?? stage.name).split(' ').first,
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClinicalNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OcgColors.sand.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notes_outlined,
                  color: OcgColors.espresso,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notas Clínicas',
                      style: TextStyle(
                        color: OcgColors.espresso,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cormorant Garamond',
                      ),
                    ),
                    Text(
                      'Describe lo realizado en esta consulta',
                      style: TextStyle(
                        color: OcgColors.bronze.withOpacity(0.6),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: OcgColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: OcgColors.error.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Obligatorio',
                      style: TextStyle(
                        color: OcgColors.error.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesCtrl,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Ej: Se realizó ajuste de brackets en arcada superior. '
                  'Paciente reporta mejoría en alineación. '
                  'Se indica uso de elásticos intermaxilares...',
              filled: true,
              fillColor: OcgColors.mist,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: OcgColors.bronze.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: OcgColors.bronze,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: OcgColors.ink,
            ),
            onChanged: (_) => setState(() => _errorMsg = null),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: OcgColors.bronze.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Las notas clínicas forman parte de la historia clínica '
                  'y no pueden editarse después.',
                  style: TextStyle(
                    color: OcgColors.bronze.withOpacity(0.5),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [OcgColors.bronze, OcgColors.espresso],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Firma del Paciente',
                      style: TextStyle(
                        color: OcgColors.espresso,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cormorant Garamond',
                      ),
                    ),
                    Text(
                      'Requerida para validez de la historia clínica',
                      style: TextStyle(
                        color: OcgColors.bronze.withOpacity(0.6),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: OcgColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: OcgColors.error.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Obligatorio',
                      style: TextStyle(
                        color: OcgColors.error.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OcgSignaturePad(
            key: _signaturePadKey,
            height: 180,
            onSignatureChanged: (bytes) {
              setState(() {
                _signatureBytes.value = bytes;
                _hasSignature.value = true;
                _errorMsg = null;
              });
            },
            onSignatureCleared: () {
              setState(() {
                _signatureBytes.value = null;
                _hasSignature.value = false;
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  _signaturePadKey.currentState?.clear();
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Limpiar firma'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OcgColors.bronze,
                  side: BorderSide(
                    color: OcgColors.bronze.withOpacity(0.3),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              const Spacer(),
              ValueListenableBuilder<bool>(
                valueListenable: _hasSignature,
                builder: (_, has, __) {
                  if (!has) return const SizedBox.shrink();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF166534),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Firma capturada',
                        style: const TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: _saving ? null : _saveConsultation,
        style: FilledButton.styleFrom(
          backgroundColor: OcgColors.espresso,
          foregroundColor: OcgColors.ivory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: OcgColors.espresso.withOpacity(0.3),
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: OcgColors.ivory,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Guardar Consulta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
