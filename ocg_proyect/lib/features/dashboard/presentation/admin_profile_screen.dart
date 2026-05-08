import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/route_names.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../shared/widgets/profile_photo_avatar.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../profile_photo/providers/profile_photo_provider.dart';
import '../../profile_photo/services/profile_photo_service.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key, this.embeddedInMobileShell = false});

  final bool embeddedInMobileShell;

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar tu sesión de administrador?'),
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

    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar sesión. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = WebLayoutContext.useDesktopShell(context);
    final body = _AdminProfileBody(
      onSignOut: () => _handleSignOut(context, ref),
    );

    if (isDesktop) {
      return AdminWebShell(title: 'Perfil', child: body);
    }

    if (embeddedInMobileShell) {
      return body;
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 6,
      title: 'Perfil',
      appBarActions: const [],
      body: body,
    );
  }
}

class _AdminProfileBody extends ConsumerStatefulWidget {
  const _AdminProfileBody({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  ConsumerState<_AdminProfileBody> createState() => _AdminProfileBodyState();
}

class _AdminProfileBodyState extends ConsumerState<_AdminProfileBody> {
  bool _uploadingPhoto = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = WebLayoutContext.useDesktopShell(context);
    final user = ref.watch(authStateProvider).asData?.value;
    final roleAsync = ref.watch(userRoleProvider);
    final unreadCount = user == null
        ? 0
        : ref.watch(unreadNotificationsCountProvider(user.uid));

    return ListView(
      padding: EdgeInsets.fromLTRB(isDesktop ? 16 : 0, isDesktop ? 16 : 0, isDesktop ? 16 : 0, 110),
      children: [
        _ProfileHero(
          user: user,
          roleAsync: roleAsync,
          isDesktop: isDesktop,
          uploadingPhoto: _uploadingPhoto,
          onChangePhoto: user == null
              ? null
              : () => _pickAndUploadPhoto(user.uid),
          onDeletePhoto: user == null ? null : () => _deletePhoto(user.uid),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Datos básicos',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Correo', _safeValue(user?.email)),
              _infoRow(
                'Rol',
                roleAsync.asData?.value == 'admin'
                    ? 'Administrador'
                    : 'Sin rol',
              ),
              _infoRow('Estado', user == null ? 'Sin sesion' : 'Sesion activa'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Accesos',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: OcgColors.espresso,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: OcgColors.error,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: const Text('Notificaciones'),
                subtitle: Text(
                  unreadCount > 0
                      ? 'Tienes $unreadCount pendientes'
                      : 'No tienes notificaciones pendientes',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(RouteNames.adminNotifications),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: widget.onSignOut,
          style: FilledButton.styleFrom(
            backgroundColor: OcgColors.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: OcgColors.bronze,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: OcgColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeValue(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return 'No disponible';
    return clean;
  }

  Future<void> _pickAndUploadPhoto(String adminId) async {
    final source = await _selectPhotoSource();
    if (source == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final result = await ref
          .read(profilePhotoServiceProvider)
          .pickAndUpload(
            ownerType: ProfilePhotoOwnerType.admin,
            uid: adminId,
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

  Future<void> _deletePhoto(String adminId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Deseas volver a mostrar tus iniciales?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OcgColors.error,
              foregroundColor: OcgColors.ivory,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _uploadingPhoto = true);
    try {
      await ref
          .read(profilePhotoServiceProvider)
          .deletePhoto(ownerType: ProfilePhotoOwnerType.admin, uid: adminId);
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
}

class _ProfileHero extends ConsumerWidget {
  const _ProfileHero({
    required this.user,
    required this.roleAsync,
    required this.isDesktop,
    required this.uploadingPhoto,
    this.onChangePhoto,
    this.onDeletePhoto,
  });

  final User? user;
  final AsyncValue<String?> roleAsync;
  final bool isDesktop;
  final bool uploadingPhoto;
  final VoidCallback? onChangePhoto;
  final VoidCallback? onDeletePhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : 'Administrador';
    final adminDoc = user == null
        ? null
        : ref.watch(adminProfileDocProvider(user!.uid)).asData?.value;
    final photoUrl = resolveProfilePhotoUrl(adminDoc);
    final topPadding = isDesktop ? 0.0 : MediaQuery.paddingOf(context).top + 6;
    final roleLabel = roleAsync.asData?.value == 'admin'
        ? 'Administrador'
        : 'Perfil disponible';
    final mail = user?.email?.trim() ?? '';
    final mailLabel = mail.isEmpty ? 'Sin correo registrado' : mail;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 18 + topPadding, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25180F), Color(0xFF5B3C26), Color(0xFF9A7654)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isDesktop ? const Radius.circular(22) : Radius.zero,
          topRight: isDesktop ? const Radius.circular(22) : Radius.zero,
          bottomLeft: Radius.circular(isDesktop ? 22 : 28),
          bottomRight: Radius.circular(isDesktop ? 22 : 28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfilePhotoAvatar(
                label: label,
                photoUrl: photoUrl,
                radius: 32,
                loading: uploadingPhoto,
                showActions: true,
                onChange: onChangePhoto,
                onDelete: onDeletePhoto,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      roleLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.alternate_email, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mailLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7D6C6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
