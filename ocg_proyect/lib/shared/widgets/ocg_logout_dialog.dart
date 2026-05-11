import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

/// Diálogo dedicado para cerrar sesión (Admin y Paciente).
/// Diseño premium con colores de marca OCG.
class OcgLogoutDialog extends StatelessWidget {
  const OcgLogoutDialog._();

  /// Muestra el diálogo y retorna `true` si el usuario confirmó.
  ///
  /// [roleLabel] — etiqueta del rol: 'Administrador' | 'Paciente'.
  /// [userName] — nombre del usuario (opcional, se muestra si está presente).
  static Future<bool?> show(
    BuildContext context, {
    String roleLabel = 'Usuario',
    String? userName,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar diálogo',
      barrierColor: OcgColors.espresso.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) {
        return _LogoutDialogBody(
          roleLabel: roleLabel,
          userName: userName,
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curve = Curves.easeOutCubic;
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: anim, curve: curve),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: curve)),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: curve),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError('Usa OcgLogoutDialog.show()');
  }
}

class _LogoutDialogBody extends StatelessWidget {
  const _LogoutDialogBody({
    required this.roleLabel,
    this.userName,
  });

  final String roleLabel;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _Card(roleLabel: roleLabel, userName: userName),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.roleLabel, this.userName});

  final String roleLabel;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFCF8),
              Color(0xFFF9F3EB),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: OcgColors.sand.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: OcgColors.espresso.withOpacity(0.14),
              blurRadius: 48,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: OcgColors.espresso.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // ── Header with gradient ──
            _Header(roleLabel: roleLabel, userName: userName),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Warning info box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: OcgColors.bronze.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: OcgColors.bronze.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: OcgColors.bronze.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: OcgColors.bronze,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sesión segura',
                                style: TextStyle(
                                  color: OcgColors.espresso,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Podrás volver a ingresar cuando lo necesites. '
                                'Tus datos permanecerán protegidos.',
                                style: TextStyle(
                                  color: OcgColors.bronze,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Buttons ──
                  Row(
                    children: [
                      Expanded(
                        child: _CancelButton(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ConfirmButton(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.roleLabel, this.userName});

  final String roleLabel;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OcgColors.espresso,
            Color(0xFF3D2B1F),
            OcgColors.espresso,
          ],
        ),
      ),
      child: Column(
        children: [
          // Logout icon with glow
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow ring
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      OcgColors.bronze.withOpacity(0.25),
                      OcgColors.bronze.withOpacity(0),
                    ],
                    stops: const [0.5, 1],
                  ),
                ),
              ),
              // Icon container
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4A3628),
                      Color(0xFF3D2B1F),
                    ],
                  ),
                  border: Border.all(
                    color: OcgColors.bronze.withOpacity(0.35),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: OcgColors.sand,
                  size: 32,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Title
          const Text(
            'Cerrar sesión',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OcgColors.ivory,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 8),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: OcgColors.ivory.withOpacity(0.1),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: OcgColors.ivory.withOpacity(0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  roleLabel == 'Administrador'
                      ? Icons.admin_panel_settings_rounded
                      : Icons.person_rounded,
                  color: OcgColors.sand,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  roleLabel,
                  style: TextStyle(
                    color: OcgColors.sand,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          if (userName?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(
              'Hola, $userName',
              style: TextStyle(
                color: OcgColors.ivory.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(false),
        style: OutlinedButton.styleFrom(
          foregroundColor: OcgColors.espresso,
          side: BorderSide(
            color: OcgColors.sand,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Quedarme',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(true),
        style: ElevatedButton.styleFrom(
          backgroundColor: OcgColors.error,
          foregroundColor: OcgColors.ivory,
          elevation: 0,
          shadowColor: OcgColors.error.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: 18),
            SizedBox(width: 8),
            Text(
              'Salir',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
