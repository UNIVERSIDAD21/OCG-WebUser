import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/constants/storage_paths.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/widgets/ocg_signature_pad.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../clinical_files/data/models/clinical_file_model.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../treatment/data/models/patient_treatment.dart';
import '../../treatment/providers/patient_treatments_provider.dart';
import '../data/models/consultation_model.dart';
import '../domain/consultation_treatment_resolver.dart';
import '../providers/consultation_provider.dart';

// ─── Pantalla de Consultación Clínica ────────────────────────────────────────
//
// Reemplaza el simple "Completar" de las citas con un flujo profesional:
// 1. Info del paciente y tratamiento actual
// 2. Control de fase (ver y avanzar)
// 3. Notas clínicas de la consulta
// 4. Firma del paciente (obligatoria para validez legal)
// 5. Guardado con auditoría completa

class _ConsultationAttachment {
  const _ConsultationAttachment({
    required this.bytes,
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
  });

  final Uint8List bytes;
  final String fileName;
  final String extension;
  final String mimeType;
  final int sizeBytes;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';
}

class ConsultationScreen extends ConsumerStatefulWidget {
  const ConsultationScreen({super.key, required this.appointment});

  final AppointmentModel appointment;

  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  final TextEditingController _notesCtrl = TextEditingController();
  Uint8List? _signatureBytes;
  bool _hasSignature = false;
  bool _showingPad = true;
  bool _signatureRequired = true;
  final List<_ConsultationAttachment> _attachments = [];
  final GlobalKey<OcgSignaturePadState> _signaturePadKey =
      GlobalKey<OcgSignaturePadState>();

  bool _saving = false;
  String? _errorMsg;
  bool _wantsAdvancePhase = false;
  TreatmentStage? _selectedNextStage;

  PatientModel? _patient;
  PatientTreatment? _selectedTreatment;
  ConsultationTreatmentResolution? _treatmentResolution;
  bool _loadingPatient = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    final patientId = widget.appointment.patientId;
    debugPrint('[_loadPatientData] Cargando datos para patientId=$patientId');

    try {
      // Usar el repositorio directamente para evitar problemas con StreamProvider
      final repo = ref.read(patientsRepositoryProvider);
      final patient = await repo.getPatient(patientId);
      debugPrint('[_loadPatientData] Paciente: ${patient?.nombre ?? 'null'}');

      final treatRepo = ref.read(patientTreatmentsRepositoryProvider);
      final treatments = await treatRepo.getPatientTreatments(patientId);
      debugPrint('[_loadPatientData] Tratamientos: ${treatments.length}');
      final treatmentResolution = const ConsultationTreatmentResolver().resolve(
        appointment: widget.appointment,
        treatments: treatments,
      );

      if (!mounted) return;

      setState(() {
        _patient = patient;
        _selectedTreatment = treatmentResolution.treatment;
        _treatmentResolution = treatmentResolution;
        _loadingPatient = false;
      });
    } catch (e, st) {
      debugPrint('[_loadPatientData] ERROR: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loadingPatient = false;
        _errorMsg = 'No se pudo cargar información del paciente: $e';
      });
    }
  }

  bool get _hasUnsavedChanges =>
      _notesCtrl.text.trim().isNotEmpty ||
      _signatureBytes != null ||
      _attachments.isNotEmpty;

  Future<void> _onBackPressed() async {
    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar dictamen?'),
        content: const Text(
          'Tienes información sin guardar. Si sales ahora, perderás las notas, '
          'firma y documentos que hayas agregado.',
        ),
        actions: [
          TextButton(
            onPressed: () => popDialog(ctx, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OcgColors.error,
              foregroundColor: OcgColors.ivory,
            ),
            onPressed: () => popDialog(ctx, true),
            child: const Text('Descartar y salir'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) Navigator.of(context).pop(false);
  }

  TreatmentStage get _currentStage =>
      _selectedTreatment?.etapaActual ??
      _patient?.etapaActual ??
      TreatmentStage.valoracionInicial;

  List<TreatmentStage> get _nextStages {
    final current = _currentStage;
    final idx = TreatmentStage.values.indexOf(current);
    if (idx < 0 || idx >= TreatmentStage.values.length - 1) return [];
    return TreatmentStage.values.sublist(idx + 1);
  }

  bool get _treatmentLockedByAppointment =>
      _treatmentResolution?.cameFromAppointment ?? false;

  String? get _treatmentResolutionMessage {
    final resolution = _treatmentResolution;
    if (resolution == null || _selectedTreatment == null) return null;
    if (resolution.cameFromAppointment) {
      return 'Ligado a la cita';
    }
    if (resolution.appointmentTreatmentWasMissing) {
      return 'La cita apunta a un tratamiento que no existe; se usara el tratamiento disponible como fallback.';
    }
    if (resolution.source == ConsultationTreatmentResolutionSource.primary) {
      return 'Fallback al tratamiento principal';
    }
    if (resolution.source ==
        ConsultationTreatmentResolutionSource.firstAvailable) {
      return 'Fallback al primer tratamiento disponible';
    }
    return null;
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
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${d.day.toString().padLeft(2, '0')} de ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _saveConsultation() async {
    final notes = _notesCtrl.text.trim();
    if (notes.isEmpty) {
      setState(() => _errorMsg = 'Debes escribir las notas de la consulta.');
      return;
    }

    final sigBytes = _signatureBytes;
    if (_signatureRequired && (sigBytes == null || sigBytes.isEmpty)) {
      setState(() => _errorMsg = 'La firma del paciente es obligatoria.');
      return;
    }

    if (_wantsAdvancePhase && _selectedNextStage == null) {
      setState(
        () => _errorMsg = 'Selecciona la fase a la que avanza el paciente.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    final uploadedStoragePaths = <String>[];
    try {
      final now = DateTime.now();
      final patientId = widget.appointment.patientId;
      final actorId = ref.read(authStateProvider).asData?.value?.uid ?? 'admin';

      // ── Auto-crear tratamiento si el paciente no tiene ninguno ──────
      // La primera valoración *es* donde nace el tratamiento. Si no existe,
      // se crea uno provisional que el admin puede editar después.
      var treatment = _selectedTreatment;
      if (treatment == null) {
        debugPrint(
          '[Consultation] Paciente sin tratamiento — auto-creando uno',
        );
        final treatRepo = ref.read(patientTreatmentsRepositoryProvider);
        final newTreatmentId = '$patientId-auto-${now.millisecondsSinceEpoch}';
        treatment = PatientTreatment(
          id: newTreatmentId,
          patientId: patientId,
          nombre: 'Tratamiento principal',
          categoria: 'ortodoncia',
          tipoBase: 'convencional',
          subtipo: 'metalico',
          estado: 'activo',
          etapaActual: _currentStage,
          fechaInicio: now,
          createdAt: now,
          updatedAt: now,
          isPrimary: true,
          createdBy: actorId,
          updatedBy: actorId,
          notas:
              'Creado automáticamente durante la consulta '
              'del ${_fmtDate(widget.appointment.fechaHora)}.',
        );
        await treatRepo.saveTreatment(
          patientId: patientId,
          treatment: treatment,
        );
        // Actualizar estado local para que la consulta use este tratamiento
        setState(() {
          _selectedTreatment = treatment;
          _treatmentResolution = ConsultationTreatmentResolution(
            treatment: treatment,
            source: ConsultationTreatmentResolutionSource.none,
            appointmentTreatmentId: widget.appointment.treatmentId?.trim(),
          );
        });
        debugPrint('[Consultation] Tratamiento auto-creado: ${treatment.id}');
      }

      final repo = ref.read(consultationRepositoryProvider);
      final consultationId = repo.newConsultationId(patientId);
      final treatmentId = treatment.id.startsWith('legacy-primary-')
          ? null
          : treatment.id;
      final currentStage = _currentStage;
      final resultingStage = _wantsAdvancePhase
          ? (_selectedNextStage ?? currentStage)
          : currentStage;

      // 1. Subir firma a Storage (solo si fue capturada)
      String? signatureUrl;
      if (sigBytes != null && sigBytes.isNotEmpty) {
        final signatureFileId = '${consultationId}_signature';
        final signaturePath =
            'patients/$patientId/consultations/signatures/$signatureFileId.png';
        final storageRef = FirebaseStorage.instance.ref().child(signaturePath);
        await storageRef.putData(
          sigBytes,
          SettableMetadata(contentType: 'image/png'),
        );
        signatureUrl = await storageRef.getDownloadURL();
        uploadedStoragePaths.add(signaturePath);
      }

      final clinicalFiles = <ClinicalFileModel>[];
      final attachmentUrls = <String>[];
      for (var i = 0; i < _attachments.length; i++) {
        final attachment = _attachments[i];
        final fileId = '${consultationId}_doc_${i + 1}';
        final storagePath = StoragePaths.patientClinicalFile(
          patientId,
          fileId,
          attachment.fileName,
          treatmentId: treatmentId,
        );
        final fileRef = FirebaseStorage.instance.ref(storagePath);
        await fileRef.putData(
          attachment.bytes,
          SettableMetadata(contentType: attachment.mimeType),
        );
        final url = await fileRef.getDownloadURL();
        uploadedStoragePaths.add(storagePath);
        attachmentUrls.add(url);

        clinicalFiles.add(
          ClinicalFileModel(
            id: fileId,
            patientId: patientId,
            treatmentId: treatmentId,
            consultationId: consultationId,
            sourceType: 'consultation_attachment',
            sourceId: consultationId,
            treatmentNameSnapshot: treatment.displayName,
            stageId: currentStage.name,
            stageNameSnapshot: stageNames[currentStage] ?? currentStage.name,
            originalName: attachment.fileName,
            displayName: attachment.fileName,
            storagePath: storagePath,
            downloadUrl: url,
            mimeType: attachment.mimeType,
            extension: attachment.extension,
            sizeBytes: attachment.sizeBytes,
            category: _categoryForAttachment(attachment),
            notes: 'Adjunto cargado desde consulta clinica.',
            uploadedBy: actorId,
            uploadedAt: now,
            updatedAt: now,
            active: true,
            visibleToPatient: false,
          ),
        );
      }

      // 2. Crear documento de consulta
      final auditEntry = AuditEntry(
        action: 'created',
        actorId: actorId,
        actorName: 'Doctora',
        timestamp: now,
      );

      PhaseSnapshot? phaseSnapshot;
      if (_wantsAdvancePhase && _selectedNextStage != null) {
        phaseSnapshot = PhaseSnapshot(
          previousStage: currentStage,
          currentStage: _selectedNextStage!,
          phaseAdvanced: true,
        );
      }

      final consultation = ConsultationModel(
        id: consultationId,
        patientId: patientId,
        patientName: widget.appointment.patientName,
        appointmentId: widget.appointment.id,
        treatmentId: treatmentId,
        treatmentNameSnapshot: treatment.displayName,
        stageId: currentStage,
        stageNameSnapshot: stageNames[currentStage] ?? currentStage.name,
        doctorId: actorId,
        doctorName: 'Doctora',
        date: now,
        clinicalNotes: notes,
        photos: attachmentUrls,
        phaseSnapshot: phaseSnapshot,
        signatureUrl: signatureUrl,
        signatureCapturedAt: now,
        status: ConsultationStatus.completed,
        auditTrail: [auditEntry],
        createdAt: now,
        updatedAt: now,
      );

      // 3. Si avanzó de fase, actualizar paciente
      final attachmentsSummary = _buildAttachmentsSummary();
      await repo.saveCompletedConsultation(
        consultation: consultation,
        clinicalFiles: clinicalFiles,
        appointmentId: widget.appointment.id,
        currentStage: currentStage,
        resultingStage: resultingStage,
        stageSummary: _buildHistorySummary(
          notes: notes,
          currentStage: currentStage,
          resultingStage: resultingStage,
        ),
        actorId: actorId,
        advancePhase: _wantsAdvancePhase,
        treatmentId: treatmentId,
        treatmentIsPrimary: treatment.isPrimary,
        stageReason: null,
        nextStagePlan: _wantsAdvancePhase
            ? 'Paciente avanza a ${stageNames[resultingStage] ?? resultingStage.name}.'
            : null,
        attachmentsSummary: attachmentsSummary,
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
      for (final path in uploadedStoragePaths.reversed) {
        try {
          await FirebaseStorage.instance.ref(path).delete();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMsg = 'Error al guardar: $e';
      });
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  String _buildHistorySummary({
    required String notes,
    required TreatmentStage currentStage,
    required TreatmentStage resultingStage,
  }) {
    final lines = <String>[
      'Consulta clinica: $_tipoLabel',
      'Notas: $notes',
      'Firma: capturada',
    ];
    if (_attachments.isNotEmpty) {
      lines.add(
        'Documentos: ${_attachments.map((f) => f.fileName).join(', ')}',
      );
    }
    if (_wantsAdvancePhase && resultingStage != currentStage) {
      lines.add(
        'Cambio de etapa: ${stageNames[currentStage] ?? currentStage.name} -> '
        '${stageNames[resultingStage] ?? resultingStage.name}',
      );
    }
    return lines.join('\n');
  }

  String _buildAttachmentsSummary() {
    final items = <String>['Firma capturada'];
    if (_attachments.isNotEmpty) {
      items.add(
        'Documentos: ${_attachments.map((f) => f.fileName).join(', ')}',
      );
    }
    return items.join(' | ');
  }

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

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onBackPressed();
      },
      child: Scaffold(
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
                      const SizedBox(height: 16),
                      _buildDocumentsCard(),
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
      ),
    );
  }

  Widget _buildHeader() {
    final patientName = widget.appointment.patientName;
    final tipoLabel = _tipoLabel;
    final fechaFormatted = _fmtDate(widget.appointment.fechaHora);
    final stageLabel = widget.appointment.stageName;

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
          colors: [OcgColors.espresso, Color(0xFF4A3628), OcgColors.espresso],
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
                onPressed: () => _onBackPressed(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dictamen · $patientName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OcgColors.ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cormorant Garamond',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$tipoLabel · $fechaFormatted',
                          style: TextStyle(
                            color: OcgColors.ivory.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                        if (stageLabel != null) ...[
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: OcgColors.bronze.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              stageLabel,
                              style: TextStyle(
                                color: OcgColors.ivory.withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
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
                      style: TextStyle(color: OcgColors.bronze, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_selectedTreatment != null) ...[
            const Divider(height: 24, color: Color(0xFFECD9C6)),
            _infoRow(
              Icons.medical_services_outlined,
              'Tratamiento',
              _selectedTreatment!.displayName,
            ),
            const SizedBox(height: 10),
            _infoRow(
              Icons.flag_outlined,
              'Fase actual',
              stageNames[_selectedTreatment!.etapaActual] ??
                  _selectedTreatment!.etapaActual.name,
              valueColor: OcgColors.bronze,
            ),
            if (_treatmentResolutionMessage != null) ...[
              const SizedBox(height: 10),
              _treatmentTraceabilityBadge(_treatmentResolutionMessage!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _treatmentTraceabilityBadge(String message) {
    final isLocked = _treatmentLockedByAppointment;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isLocked
            ? const Color(0xFF166534).withOpacity(0.08)
            : OcgColors.sand.withOpacity(0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocked
              ? const Color(0xFF166534).withOpacity(0.18)
              : OcgColors.bronze.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLocked ? Icons.lock_outline : Icons.info_outline,
            size: 16,
            color: isLocked ? const Color(0xFF166534) : OcgColors.bronze,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isLocked ? const Color(0xFF166534) : OcgColors.espresso,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
                  border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
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
    final currentStage = _currentStage;
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              hintText:
                  'Ej: Se realizó ajuste de brackets en arcada superior. '
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

  // ─── Signature Card (Premium con Toggle) ───────────────────────────────────

  Widget _buildSignatureCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _signatureRequired
              ? [Colors.white, const Color(0xFFFFFDF8)]
              : [const Color(0xFFF5F3F0), const Color(0xFFEDEAE5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _signatureRequired
              ? OcgColors.bronze.withOpacity(0.2)
              : OcgColors.bronze.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(
              _signatureRequired ? 0.06 : 0.02,
            ),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          if (_signatureRequired)
            BoxShadow(
              color: OcgColors.bronze.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header con toggle ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _signatureRequired
                        ? (_hasSignature
                              ? [
                                  const Color(0xFF166534),
                                  const Color(0xFF22C55E),
                                ]
                              : [
                                  OcgColors.bronze.withOpacity(0.15),
                                  OcgColors.espresso.withOpacity(0.15),
                                ])
                        : [
                            Colors.grey.withOpacity(0.1),
                            Colors.grey.withOpacity(0.05),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _signatureRequired
                        ? (_hasSignature
                              ? const Color(0xFF166534)
                              : OcgColors.bronze.withOpacity(0.3))
                        : Colors.grey.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _signatureRequired
                      ? (_hasSignature
                            ? Icons.shield_outlined
                            : Icons.edit_note_rounded)
                      : Icons.edit_note_rounded,
                  color: _signatureRequired
                      ? (_hasSignature ? Colors.white : OcgColors.bronze)
                      : Colors.grey.withOpacity(0.4),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Firma del Paciente',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _signatureRequired
                                  ? OcgColors.espresso
                                  : Colors.grey.withOpacity(0.5),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cormorant Garamond',
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (_signatureRequired) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: OcgColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: OcgColors.error.withOpacity(0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 9,
                                  color: OcgColors.error.withOpacity(0.7),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Req.',
                                  style: TextStyle(
                                    color: OcgColors.error.withOpacity(0.7),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Opcional',
                              style: TextStyle(
                                color: Colors.grey.withOpacity(0.5),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _signatureRequired
                          ? (_hasSignature
                                ? 'Documento firmado — listo para guardar'
                                : 'Validación legal de la historia clínica')
                          : 'Firma deshabilitada — no se solicitará al paciente',
                      style: TextStyle(
                        color: _signatureRequired
                            ? OcgColors.bronze.withOpacity(0.55)
                            : Colors.grey.withOpacity(0.35),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Toggle Switch ──
              _buildSignatureToggle(),
            ],
          ),
          const SizedBox(height: 16),

          // ── Pad de firma o firma confirmada (solo si requerida) ──
          if (_signatureRequired) ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _showingPad
                  ? Column(
                      key: const ValueKey('pad'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OcgSignaturePad(
                          key: _signaturePadKey,
                          height: 200,
                          onSignatureReady: (bytes) {
                            setState(() {
                              _signatureBytes = bytes;
                              _hasSignature = true;
                              _showingPad = false;
                              _errorMsg = null;
                            });
                          },
                          onSignatureCleared: () {},
                        ),
                        const SizedBox(height: 12),
                        // Botones del pad
                        Row(
                          children: [
                            InkWell(
                              onTap: () =>
                                  _signaturePadKey.currentState?.clear(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: OcgColors.bronze.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: OcgColors.bronze.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.restart_alt_rounded,
                                      size: 16,
                                      color: OcgColors.bronze.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Limpiar',
                                      style: TextStyle(
                                        color: OcgColors.bronze.withOpacity(
                                          0.7,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: () {
                                _signaturePadKey.currentState
                                    ?.confirmSignature();
                              },
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                              ),
                              label: const Text('Confirmar firma'),
                              style: FilledButton.styleFrom(
                                backgroundColor: OcgColors.espresso,
                                foregroundColor: OcgColors.ivory,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Container(
                      key: const ValueKey('confirmed'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF166534).withOpacity(0.08),
                            const Color(0xFF22C55E).withOpacity(0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF166534).withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF166534),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Firma capturada exitosamente',
                                  style: TextStyle(
                                    color: Color(0xFF166534),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Documento válido con firma digital del paciente',
                                  style: TextStyle(
                                    color: Color(0xFF166534),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _signatureBytes = null;
                                _hasSignature = false;
                                _showingPad = true;
                              });
                              _signaturePadKey.currentState?.clear();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: const Color(0xFF166534).withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ] else ...[
            // Estado deshabilitado — mensaje sutil
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.draw_outlined,
                    size: 40,
                    color: Colors.grey.withOpacity(0.25),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Firma deshabilitada',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Actívala para capturar la firma del paciente',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.3),
                      fontSize: 11,
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

  Widget _buildSignatureToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _signatureRequired = !_signatureRequired;
          if (!_signatureRequired) {
            // Al desactivar, limpiar firma y resetear pad
            _signatureBytes = null;
            _hasSignature = false;
            _showingPad = true;
            _signaturePadKey.currentState?.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          gradient: _signatureRequired
              ? const LinearGradient(
                  colors: [OcgColors.espresso, Color(0xFF4A3728)],
                )
              : null,
          color: _signatureRequired ? null : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _signatureRequired
                ? OcgColors.espresso
                : Colors.grey.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: _signatureRequired
              ? [
                  BoxShadow(
                    color: OcgColors.espresso.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              alignment: _signatureRequired
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _signatureRequired
                        ? OcgColors.ivory
                        : Colors.grey.shade300,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    _signatureRequired
                        ? Icons.check_rounded
                        : Icons.close_rounded,
                    size: 14,
                    color: _signatureRequired
                        ? OcgColors.espresso
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Documentos Adjuntos ───────────────────────────────────────────────────

  Widget _buildDocumentsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFFFFDF8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _attachments.isNotEmpty
                        ? [const Color(0xFF166534), const Color(0xFF22C55E)]
                        : [
                            OcgColors.bronze.withOpacity(0.15),
                            OcgColors.espresso.withOpacity(0.15),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _attachments.isNotEmpty
                        ? const Color(0xFF166534)
                        : OcgColors.bronze.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _attachments.isNotEmpty
                      ? Icons.folder_open_outlined
                      : Icons.attach_file_rounded,
                  color: _attachments.isNotEmpty
                      ? Colors.white
                      : OcgColors.bronze,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Documentos Adjuntos',
                          style: TextStyle(
                            color: OcgColors.espresso,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cormorant Garamond',
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (_attachments.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF166534).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${_attachments.length}',
                              style: const TextStyle(
                                color: Color(0xFF166534),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Radiografías, fotos clínicas, documentos del paciente',
                      style: TextStyle(
                        color: OcgColors.bronze.withOpacity(0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lista de archivos subidos
          if (_attachments.isNotEmpty) ...[
            ..._attachments.asMap().entries.map((entry) {
              final idx = entry.key;
              final attachment = entry.value;
              final name = attachment.fileName;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: OcgColors.mist,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: OcgColors.bronze.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: OcgColors.bronze.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _iconForAttachment(attachment),
                          size: 18,
                          color: OcgColors.bronze,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: OcgColors.espresso,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _attachments.removeAt(idx);
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: OcgColors.error.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Botones para subir
          Row(
            children: [
              Expanded(
                child: _uploadButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Cámara',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _uploadButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Galería',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _uploadButton(
                  icon: Icons.description_outlined,
                  label: 'Archivo',
                  onTap: () => _pickFile(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _uploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: OcgColors.bronze.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: OcgColors.bronze.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: OcgColors.bronze),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: OcgColors.bronze,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final extension = _extensionFromName(picked.name, fallback: 'jpg');
        setState(() {
          _attachments.add(
            _ConsultationAttachment(
              bytes: bytes,
              fileName: picked.name,
              extension: extension,
              mimeType: _mimeFromExtension(extension),
              sizeBytes: bytes.length,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'dicom',
          'dcm',
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null) return;
        final extension = _extensionFromName(
          file.name,
          fallback: file.extension ?? '',
        );
        setState(() {
          _attachments.add(
            _ConsultationAttachment(
              bytes: bytes,
              fileName: file.name,
              extension: extension,
              mimeType: _mimeFromExtension(extension),
              sizeBytes: file.size,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  String _extensionFromName(String name, {String fallback = ''}) {
    final cleanFallback = fallback.toLowerCase().replaceAll('.', '');
    final idx = name.lastIndexOf('.');
    if (idx < 0 || idx == name.length - 1) return cleanFallback;
    return name.substring(idx + 1).toLowerCase();
  }

  String _mimeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'dicom':
      case 'dcm':
        return 'application/dicom';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _categoryForAttachment(_ConsultationAttachment attachment) {
    if (attachment.isImage) return 'foto_clinica';
    if (attachment.isPdf) return 'pdf_clinico';
    return 'otro';
  }

  IconData _iconForAttachment(_ConsultationAttachment attachment) {
    if (attachment.isPdf) return Icons.picture_as_pdf_rounded;
    if (attachment.isImage) return Icons.image_outlined;
    return Icons.description_outlined;
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }
}
