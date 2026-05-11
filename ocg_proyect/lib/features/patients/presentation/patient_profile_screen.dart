import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/route_names.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile_photo/providers/profile_photo_provider.dart';
import '../../profile_photo/services/profile_photo_service.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_logout_dialog.dart';
import '../../../shared/widgets/ocg_confirm_dialog.dart';
import '../../../shared/widgets/profile_photo_avatar.dart';
import '../../../shared/widgets/ocg_loading_state.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../data/models/patient_model.dart';
import '../providers/patients_provider.dart';
import 'patient_viewer_mode.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({
    super.key,
    this.embedded = false,
    this.patientIdOverride,
    this.viewerMode = PatientViewerMode.patient,
  });

  final bool embedded;
  final String? patientIdOverride;
  final PatientViewerMode viewerMode;

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _savingPhone = false;
  bool _uploadingPhoto = false;
  bool _sendingReset = false;
  bool _signingOut = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeSlide = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    if (_signingOut) return;

    final confirm = await OcgLogoutDialog.show(
      context,
      roleLabel: 'Paciente',
    );

    if (confirm != true) return;

    setState(() => _signingOut = true);
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar sesión. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;
    final isAdminViewer = widget.viewerMode == PatientViewerMode.adminViewer;
    final effectivePatientId = (widget.patientIdOverride?.isNotEmpty == true)
        ? widget.patientIdOverride!
        : (user?.uid ?? '');

    if (effectivePatientId.isEmpty) {
      return Center(
        child: Text(
          isAdminViewer
              ? 'No se pudo cargar el perfil del paciente.'
              : 'Debes iniciar sesión para ver tu perfil.',
        ),
      );
    }

    final patientAsync = ref.watch(patientByIdProvider(effectivePatientId));

    final content = patientAsync.when(
      loading: () => OcgLoadingState(),
      error: (error, _) => Center(
        child: Text(
          isAdminViewer
              ? 'No se pudo cargar el perfil del paciente: $error'
              : 'No se pudo cargar tu perfil: $error',
          textAlign: TextAlign.center,
        ),
      ),
      data: (patient) {
        if (patient == null) {
          return const Center(
            child: Text(
              'No encontramos tu registro clínico aún.\nSolicita activación en recepción/admin.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return FadeTransition(
          opacity: _fadeSlide,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(_fadeSlide),
            child: _ProfileBody(
              patient: patient,
              isAdminViewer: isAdminViewer,
              uploadingPhoto: _uploadingPhoto,
              savingPhone: _savingPhone,
              sendingReset: _sendingReset,
              signingOut: _signingOut,
              showSignOut: widget.patientIdOverride == null,
              onSignOut: _handleSignOut,
              onEditPhone: () => _editPhone(patient),
              onChangePhoto: () => _pickAndUploadPhoto(patient.id),
              onDeletePhoto: () => _deletePhoto(patient.id),
              onSendPasswordReset: () => _sendPasswordReset(patient.email),
            ),
          ),
        );
      },
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: const Color(0xFFEDE8DC),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // ── Side decoration ──
            const _ProfileBlob(
              top: -60,
              right: -40,
              size: 220,
              color: Color(0x3DC8AF8C),
            ),
            const _ProfileBlob(
              bottom: -40,
              left: -30,
              size: 180,
              color: Color(0x28B49B78),
            ),
            content,
          ],
        ),
      ),
    );
  }

  Future<void> _editPhone(PatientModel patient) async {
    final ctrl = TextEditingController(text: patient.telefono);

    final newPhone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar teléfono'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newPhone == null || newPhone.isEmpty || newPhone == patient.telefono) {
      return;
    }

    setState(() => _savingPhone = true);
    try {
      await ref
          .read(patientsRepositoryProvider)
          .updatePatientContactData(patient.id, telefono: newPhone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teléfono actualizado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar teléfono: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPhone = false);
    }
  }

  Future<void> _pickAndUploadPhoto(String patientId) async {
    final source = await _selectPhotoSource();
    if (source == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final result = await ref
          .read(profilePhotoServiceProvider)
          .pickAndUpload(
            ownerType: ProfilePhotoOwnerType.patient,
            uid: patientId,
            source: source,
          );
      if (result == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapProfilePhotoError(error))));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto(String patientId) async {
    final confirm = await OcgConfirmDialog.show(
      context,
      type: OcgConfirmDialogType.warning,
      title: 'Eliminar foto',
      message: '¿Deseas volver a mostrar tus iniciales?',
      confirmLabel: 'Eliminar',
      onConfirm: () {},
    );

    if (confirm != true) return;

    setState(() => _uploadingPhoto = true);
    try {
      await ref
          .read(profilePhotoServiceProvider)
          .deletePhoto(
            ownerType: ProfilePhotoOwnerType.patient,
            uid: patientId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil eliminada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapProfilePhotoError(error))));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<ImageSource?> _selectPhotoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Seleccionar de galería'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPasswordReset(String email) async {
    setState(() => _sendingReset = true);
    try {
      await ref.read(authNotifierProvider.notifier).resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enlace de cambio de contraseña enviado a $email'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el enlace: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE BODY
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.patient,
    required this.isAdminViewer,
    required this.uploadingPhoto,
    required this.savingPhone,
    required this.sendingReset,
    required this.signingOut,
    required this.showSignOut,
    required this.onSignOut,
    required this.onEditPhone,
    required this.onChangePhoto,
    required this.onDeletePhoto,
    required this.onSendPasswordReset,
  });

  final PatientModel patient;
  final bool isAdminViewer;
  final bool uploadingPhoto;
  final bool savingPhone;
  final bool sendingReset;
  final bool signingOut;
  final bool showSignOut;
  final VoidCallback onSignOut;
  final VoidCallback onEditPhone;
  final VoidCallback onChangePhoto;
  final VoidCallback onDeletePhoto;
  final VoidCallback onSendPasswordReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Hero header ──
        _ProfileHero(
          patient: patient,
          isAdminViewer: isAdminViewer,
          uploadingPhoto: uploadingPhoto,
          onChangePhoto: onChangePhoto,
          onDeletePhoto: onDeletePhoto,
        ),

        const SizedBox(height: 20),

        // ── Content ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Edit patient button (admin viewer only)
              if (isAdminViewer) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go(
                      RouteNames.adminPatientEdit.replaceFirst(
                        ':patientId',
                        patient.id,
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar paciente'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6E5442),
                      side: const BorderSide(
                        color: Color(0xFFD9CCBE),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Personal data card ──
              _GlassSectionCard(
                title: 'Datos personales',
                icon: Icons.person_outline_rounded,
                children: [
                  _InfoRow(label: 'Nombre', value: patient.nombre),
                  const _CardDivider(),
                  _InfoRow(label: 'Correo', value: patient.email),
                  const _CardDivider(),
                  _EditableInfoRow(
                    label: 'Teléfono',
                    value: patient.telefono,
                    loading: savingPhone,
                    onEdit: onEditPhone,
                  ),
                  const _CardDivider(),
                  _InfoRow(
                    label: 'Fecha nacimiento',
                    value: _fmt(patient.fechaNacimiento),
                  ),
                  const _CardDivider(),
                  _ActionInfoRow(
                    label: 'Contraseña',
                    value: '••••••••',
                    actionLabel: 'Cambiar',
                    loading: sendingReset,
                    onAction: onSendPasswordReset,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Clinical summary card ──
              _GlassSectionCard(
                title: 'Resumen clínico',
                icon: Icons.medical_services_outlined,
                children: [
                  _LockedInfoRow(
                    label: 'Tipo tratamiento',
                    value: patient.tipoTratamiento?.name ?? 'Pendiente',
                  ),
                  const _CardDivider(),
                  _LockedInfoRow(
                    label: 'Etapa actual',
                    value: formatTreatmentStage(patient.etapaActual),
                  ),
                  const _CardDivider(),
                  _LockedInfoRow(
                    label: 'Fecha inicio',
                    value: _fmt(patient.fechaInicio),
                  ),
                  const _CardDivider(),
                  _LockedInfoRow(
                    label: 'Fecha est. fin',
                    value: patient.fechaEstimadaFin == null
                        ? 'No definida'
                        : _fmt(patient.fechaEstimadaFin!),
                  ),
                  if (patient.notasClinicas.isNotEmpty) ...[
                    const _CardDivider(),
                    _LockedInfoRow(
                      label: 'Notas clínicas',
                      value: patient.notasClinicas,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // ── Financial card ──
              _GlassSectionCard(
                title: 'Estado financiero',
                icon: Icons.payments_outlined,
                children: [
                  _LockedInfoRow(
                    label: 'Total tratamiento',
                    value: '${formatCop(patient.totalTratamiento)} COP',
                  ),
                  const _CardDivider(),
                  _LockedInfoRow(
                    label: 'Saldo pendiente',
                    value: '${formatCop(patient.saldoPendiente)} COP',
                  ),
                  const _CardDivider(),
                  _LockedInfoRow(
                    label: 'Próximo pago',
                    value: patient.fechaProximoPago == null
                        ? 'No definido'
                        : _fmt(patient.fechaProximoPago!),
                  ),
                ],
              ),

              // ── Sign out ──
              if (showSignOut) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: signingOut ? null : onSignOut,
                    icon: signingOut
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF991B1B),
                            ),
                          )
                        : const Icon(Icons.logout, size: 18),
                    label: Text(
                      signingOut ? 'Cerrando sesión...' : 'Cerrar sesión',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE2E2),
                      foregroundColor: const Color(0xFF991B1B),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0x33B91C1C)),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE HERO
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHero extends StatefulWidget {
  const _ProfileHero({
    required this.patient,
    required this.isAdminViewer,
    required this.uploadingPhoto,
    required this.onChangePhoto,
    required this.onDeletePhoto,
  });

  final PatientModel patient;
  final bool isAdminViewer;
  final bool uploadingPhoto;
  final VoidCallback onChangePhoto;
  final VoidCallback onDeletePhoto;

  @override
  State<_ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends State<_ProfileHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 28, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C2016), Color(0xFF4A3628), Color(0xFF2C2016)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // ── Photo with pulse ring ──
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse ring
                      Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFC8AF8C)
                                  .withOpacity(0.35 * (1.06 - _pulse.value + 1)),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      // Photo
                      ProfilePhotoAvatar(
                        label: widget.patient.nombre,
                        photoUrl: widget.patient.fotoUrl,
                        radius: 44,
                        loading: widget.uploadingPhoto,
                        showActions: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.uploadingPhoto ? null : widget.onChangePhoto,
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: const Text('Cambiar foto'),
                      ),
                      if ((widget.patient.fotoUrl ?? '').isNotEmpty)
                        TextButton.icon(
                          onPressed: widget.uploadingPhoto ? null : widget.onDeletePhoto,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Eliminar'),
                          style: TextButton.styleFrom(foregroundColor: OcgColors.error),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // ── Name ──
          Text(
            widget.patient.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OcgColors.ivory,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // ── Email ──
          Text(
            widget.patient.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OcgColors.ivory.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),

          // ── Role badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: OcgColors.ivory.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: OcgColors.ivory.withOpacity(0.18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isAdminViewer
                      ? Icons.admin_panel_settings_rounded
                      : Icons.person_rounded,
                  color: OcgColors.ivory.withOpacity(0.8),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isAdminViewer ? 'Perfil del paciente' : 'Paciente OCG',
                  style: TextStyle(
                    color: OcgColors.ivory.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE CARD COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _GlassSectionCard extends StatelessWidget {
  const _GlassSectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFCF8), Color(0xFFF7F2E8)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE7DDD2).withOpacity(0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C2016).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFC8AF8C).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF8A6F59), size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF2C2016),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        height: 1,
        color: const Color(0xFFE7DDD2).withOpacity(0.6),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A6F59),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF2C2016),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedInfoRow extends StatelessWidget {
  const _LockedInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A6F59),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF2C2016),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.lock_outline, size: 14, color: Color(0xFFA89078)),
        ],
      ),
    );
  }
}

class _EditableInfoRow extends StatelessWidget {
  const _EditableInfoRow({
    required this.label,
    required this.value,
    required this.loading,
    required this.onEdit,
  });

  final String label;
  final String value;
  final bool loading;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A6F59),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF2C2016),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8A6F59),
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onEdit,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Color(0xFF6E5442),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _ActionInfoRow extends StatelessWidget {
  const _ActionInfoRow({
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.loading,
    required this.onAction,
  });

  final String label;
  final String value;
  final String actionLabel;
  final bool loading;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A6F59),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF2C2016),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8A6F59),
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onAction,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          color: Color(0xFF6E5442),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECORATIVE BLOB
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBlob extends StatelessWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double size;
  final Color color;

  const _ProfileBlob({
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withOpacity(0)],
              stops: const [0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}
