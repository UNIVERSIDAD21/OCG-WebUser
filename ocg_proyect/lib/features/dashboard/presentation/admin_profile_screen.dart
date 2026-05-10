import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/route_names.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_confirm_dialog.dart';
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
    final confirm = await OcgConfirmDialog.show(
      context,
      type: OcgConfirmDialogType.danger,
      title: 'Cerrar sesión',
      message: '¿Deseas cerrar tu sesión de administrador?',
      confirmLabel: 'Cerrar sesión',
      onConfirm: () {},
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

    // Mobile standalone — scaffold con fondo decorativo
    return Scaffold(
      backgroundColor: const Color(0xFFEDE8DC),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            const _AdminProfileBlob(
              top: -70,
              right: -50,
              size: 200,
              color: Color(0x3DC8AF8C),
            ),
            const _AdminProfileBlob(
              bottom: -50,
              left: -40,
              size: 160,
              color: Color(0x28B49B78),
            ),
            body,
          ],
        ),
      ),
    );
  }
}

class _AdminProfileBody extends ConsumerStatefulWidget {
  const _AdminProfileBody({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  ConsumerState<_AdminProfileBody> createState() => _AdminProfileBodyState();
}

class _AdminProfileBodyState extends ConsumerState<_AdminProfileBody>
    with SingleTickerProviderStateMixin {
  bool _uploadingPhoto = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = WebLayoutContext.useDesktopShell(context);
    final user = ref.watch(authStateProvider).asData?.value;
    final roleAsync = ref.watch(userRoleProvider);
    final unreadCount = user == null
        ? 0
        : ref.watch(unreadNotificationsCountProvider(user.uid));

    return FadeTransition(
      opacity: _fadeSlide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(_fadeSlide),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 16 : 0,
            isDesktop ? 16 : 0,
            isDesktop ? 16 : 0,
            110,
          ),
          children: [
            _AdminHero(
              user: user,
              roleAsync: roleAsync,
              isDesktop: isDesktop,
              uploadingPhoto: _uploadingPhoto,
              onChangePhoto:
                  user == null ? null : () => _pickAndUploadPhoto(user.uid),
              onDeletePhoto:
                  user == null ? null : () => _deletePhoto(user.uid),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16),
              child: Column(
                children: [
                  // ── Basic info card ──
                  _AdminGlassCard(
                    title: 'Datos básicos',
                    icon: Icons.person_outline_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AdminInfoRow(
                          label: 'Correo',
                          value: _safeValue(user?.email),
                        ),
                        const _AdminCardDivider(),
                        _AdminInfoRow(
                          label: 'Rol',
                          value: roleAsync.asData?.value == 'admin'
                              ? 'Administrador'
                              : 'Sin rol',
                        ),
                        const _AdminCardDivider(),
                        _AdminInfoRow(
                          label: 'Estado',
                          value: user == null ? 'Sin sesión' : 'Sesión activa',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Notifications card ──
                  _AdminGlassCard(
                    title: 'Accesos',
                    icon: Icons.grid_view_rounded,
                    child: InkWell(
                      onTap: () => context.push(RouteNames.adminNotifications),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC8AF8C).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(
                                    Icons.notifications_outlined,
                                    color: Color(0xFF8A6F59),
                                    size: 20,
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      right: -4,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD32F2F),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          unreadCount > 99
                                              ? '99+'
                                              : '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Notificaciones',
                                    style: TextStyle(
                                      color: Color(0xFF2C2016),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    unreadCount > 0
                                        ? 'Tienes $unreadCount pendientes'
                                        : 'No tienes notificaciones pendientes',
                                    style: const TextStyle(
                                      color: Color(0xFF8A6F59),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFA89078),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Sign out ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: widget.onSignOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE2E2),
                        foregroundColor: const Color(0xFF991B1B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0x33B91C1C)),
                        ),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text(
                        'Cerrar sesión',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _safeValue(String? value) {
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

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN HERO
// ─────────────────────────────────────────────────────────────────────────────

class _AdminHero extends ConsumerStatefulWidget {
  const _AdminHero({
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
  ConsumerState<_AdminHero> createState() => _AdminHeroState();
}

class _AdminHeroState extends ConsumerState<_AdminHero>
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
    final label = (widget.user?.displayName?.trim().isNotEmpty ?? false)
        ? widget.user!.displayName!.trim()
        : 'Administrador';
    final adminDoc = widget.user == null
        ? null
        : ref
            .watch(adminProfileDocProvider(widget.user!.uid))
            .asData
            ?.value;
    final photoUrl = resolveProfilePhotoUrl(adminDoc);
    final topPadding =
        widget.isDesktop ? 0.0 : MediaQuery.paddingOf(context).top + 6;
    final roleLabel = widget.roleAsync.asData?.value == 'admin'
        ? 'Administrador'
        : 'Perfil disponible';
    final mail = widget.user?.email?.trim() ?? '';
    final mailLabel = mail.isEmpty ? 'Sin correo registrado' : mail;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 18 + topPadding, 18, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C2016), Color(0xFF4A3628), Color(0xFF2C2016)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: widget.isDesktop ? const Radius.circular(22) : Radius.zero,
          topRight: widget.isDesktop ? const Radius.circular(22) : Radius.zero,
          bottomLeft: Radius.circular(widget.isDesktop ? 22 : 32),
          bottomRight: Radius.circular(widget.isDesktop ? 22 : 32),
        ),
      ),
      child: Column(
        children: [
          // Photo with pulse ring + action buttons
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 95,
                          height: 95,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFC8AF8C)
                                  .withOpacity(0.3 * (1.06 - _pulse.value + 1)),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      ProfilePhotoAvatar(
                        label: label,
                        photoUrl: photoUrl,
                        radius: 38,
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
                      if (photoUrl != null && photoUrl.isNotEmpty)
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
          const SizedBox(height: 16),

          // Name
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Role
          Text(
            roleLabel,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),

          // Email badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.alternate_email,
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mailLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
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

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE CARD COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _AdminGlassCard extends StatelessWidget {
  const _AdminGlassCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
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
          child,
        ],
      ),
    );
  }
}

class _AdminCardDivider extends StatelessWidget {
  const _AdminCardDivider();

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

class _AdminInfoRow extends StatelessWidget {
  const _AdminInfoRow({required this.label, required this.value});

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
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFA89078),
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminProfileBlob extends StatelessWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double size;
  final Color color;

  const _AdminProfileBlob({
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
