import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/providers/auth_providers.dart';
import '../../../shared/constants/storage_paths.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/widgets/ocg_card.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../data/models/patient_model.dart';
import '../providers/patients_provider.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  bool _savingPhone = false;
  bool _uploadingPhoto = false;
  bool _sendingReset = false;
  bool _signingOut = false;

  Future<void> _handleSignOut() async {
    if (_signingOut) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => popDialog(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OcgColors.error,
              foregroundColor: OcgColors.ivory,
            ),
            onPressed: () => popDialog(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
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

    if (user == null) {
      return const Center(child: Text('Debes iniciar sesión para ver tu perfil.'));
    }

    final patientAsync = ref.watch(patientByIdProvider(user.uid));

    final content = patientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'No se pudo cargar tu perfil: $error',
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OcgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Datos personales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Center(child: _ProfileAvatar(patient: patient, uploading: _uploadingPhoto, onTap: () => _pickAndUploadPhoto(patient.id))),
                    const SizedBox(height: 12),
                    _Field(label: 'Nombre', value: patient.nombre),
                    _Field(label: 'Correo', value: patient.email),
                    _EditableField(
                      label: 'Teléfono',
                      value: patient.telefono,
                      loading: _savingPhone,
                      onEdit: () => _editPhone(patient),
                    ),
                    _Field(label: 'Fecha nacimiento', value: _fmt(patient.fechaNacimiento)),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Contraseña'),
                      subtitle: const Text('••••••••'),
                      trailing: TextButton(
                        onPressed: _sendingReset ? null : () => _sendPasswordReset(patient.email),
                        child: _sendingReset
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Cambiar'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OcgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen clínico (solo lectura)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _LockedField(label: 'Tipo tratamiento', value: patient.tipoTratamiento?.name ?? 'Pendiente'),
                    _LockedField(label: 'Etapa actual', value: stageNames[patient.etapaActual] ?? patient.etapaActual.name),
                    _LockedField(label: 'Fecha inicio', value: _fmt(patient.fechaInicio)),
                    _LockedField(
                      label: 'Fecha estimada fin',
                      value: patient.fechaEstimadaFin == null ? 'No definida' : _fmt(patient.fechaEstimadaFin!),
                    ),
                    _LockedField(
                      label: 'Notas clínicas',
                      value: patient.notasClinicas.isEmpty ? 'Sin notas' : patient.notasClinicas,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OcgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estado financiero', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _Field(label: 'Total tratamiento', value: '${_fmtCop(patient.totalTratamiento)} COP'),
                    _Field(label: 'Saldo pendiente', value: '${_fmtCop(patient.saldoPendiente)} COP'),
                    _Field(
                      label: 'Próximo pago',
                      value: patient.fechaProximoPago == null ? 'No definido' : _fmt(patient.fechaProximoPago!),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _signingOut ? null : _handleSignOut,
            icon: const Icon(Icons.logout, color: OcgColors.error),
          ),
        ],
      ),
      body: content,
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newPhone == null || newPhone.isEmpty || newPhone == patient.telefono) return;

    setState(() => _savingPhone = true);
    try {
      await ref.read(patientsRepositoryProvider).updatePatientContactData(patient.id, telefono: newPhone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teléfono actualizado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo actualizar teléfono: $e')));
    } finally {
      if (mounted) setState(() => _savingPhone = false);
    }
  }

  Future<void> _pickAndUploadPhoto(String patientId) async {
    setState(() => _uploadingPhoto = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final storageRef = FirebaseStorage.instance.ref(StoragePaths.patientProfile(patientId));
      await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await storageRef.getDownloadURL();

      await ref.read(patientsRepositoryProvider).updatePatientContactData(patientId, fotoUrl: url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto de perfil actualizada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo subir la foto: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _sendPasswordReset(String email) async {
    setState(() => _sendingReset = true);
    try {
      await ref.read(authNotifierProvider.notifier).resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enlace de cambio de contraseña enviado a $email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo enviar el enlace: $e')));
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  static String _fmt(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }

}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.patient, required this.uploading, required this.onTap});

  final PatientModel patient;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = patient.fotoUrl != null && patient.fotoUrl!.isNotEmpty;
    final initial = patient.nombre.isNotEmpty ? patient.nombre[0].toUpperCase() : '?';

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: OcgColors.bronze.withValues(alpha: 0.18),
          backgroundImage: hasPhoto ? NetworkImage(patient.fotoUrl!) : null,
          child: hasPhoto
              ? null
              : Text(
                  initial,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: OcgColors.espresso),
                ),
        ),
        CircleAvatar(
          radius: 16,
          backgroundColor: OcgColors.bronze,
          child: IconButton(
            onPressed: uploading ? null : onTap,
            icon: uploading
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: OcgColors.ivory),
                  )
                : const Icon(Icons.camera_alt, size: 14, color: OcgColors.ivory),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            tooltip: 'Cambiar foto',
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({required this.label, required this.value, required this.loading, required this.onEdit});

  final String label;
  final String value;
  final bool loading;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value),
      trailing: IconButton(
        onPressed: loading ? null : onEdit,
        icon: loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.edit_outlined, size: 18),
      ),
    );
  }
}

class _LockedField extends StatelessWidget {
  const _LockedField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
          const SizedBox(width: 4),
          const Icon(Icons.lock_outline, size: 14, color: OcgColors.ink),
        ],
      ),
    );
  }
}
