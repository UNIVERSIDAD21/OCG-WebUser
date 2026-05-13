import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

enum OcgConfirmDialogType { danger, warning, info }

class OcgConfirmDialog extends StatelessWidget {
  const OcgConfirmDialog._();

  /// Muestra el diálogo y retorna `true` si el usuario confirmó.
  static Future<bool?> show(
    BuildContext context, {
    required OcgConfirmDialogType type,
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    required VoidCallback onConfirm,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar diálogo',
      barrierColor: OcgColors.espresso.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) {
        return _OcgConfirmDialogContent(
          type: type,
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          onConfirm: onConfirm,
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curve = Curves.easeOutCubic;
        return FadeTransition(
          opacity: Tween<double>(
            begin: 0,
            end: 1,
          ).animate(CurvedAnimation(parent: anim, curve: curve)),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: curve)),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.94,
                end: 1.0,
              ).animate(CurvedAnimation(parent: anim, curve: curve)),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError('Usa OcgConfirmDialog.show() en su lugar');
  }
}

class _OcgConfirmDialogContent extends StatelessWidget {
  const _OcgConfirmDialogContent({
    required this.type,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    required this.onConfirm,
  });

  final OcgConfirmDialogType type;
  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final VoidCallback onConfirm;

  bool get _isSignOutAction {
    final text =
        '${title.toLowerCase()} ${message.toLowerCase()} '
        '${(confirmLabel ?? '').toLowerCase()}';
    return text.contains('cerrar sesión') || text.contains('cerrar sesion');
  }

  IconData get _icon => switch (type) {
    _ when _isSignOutAction => Icons.logout_rounded,
    OcgConfirmDialogType.danger => Icons.warning_rounded,
    OcgConfirmDialogType.warning => Icons.error_outline_rounded,
    OcgConfirmDialogType.info => Icons.info_outline_rounded,
  };

  String get _defaultConfirmLabel => switch (type) {
    _ when _isSignOutAction => 'Salir',
    OcgConfirmDialogType.danger => 'Eliminar',
    OcgConfirmDialogType.warning => 'Confirmar',
    OcgConfirmDialogType.info => 'Aceptar',
  };

  String get _defaultCancelLabel => _isSignOutAction ? 'Quedarme' : 'Cancelar';

  Color get _confirmBgColor => switch (type) {
    OcgConfirmDialogType.danger => OcgColors.error,
    OcgConfirmDialogType.warning => const Color(0xFFED8E00),
    OcgConfirmDialogType.info => OcgColors.espresso,
  };

  Color get _badgeColor => switch (type) {
    OcgConfirmDialogType.danger => OcgColors.error,
    OcgConfirmDialogType.warning => const Color(0xFFED8E00),
    OcgConfirmDialogType.info => OcgColors.sand,
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                decoration: TextDecoration.none,
                decorationColor: Colors.transparent,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFCF8), Color(0xFFF9F3EB)],
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
                      _DialogHeader(
                        title: title,
                        icon: _icon,
                        badgeColor: _badgeColor,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                      Icons.info_outline_rounded,
                                      color: OcgColors.bronze,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: const TextStyle(
                                        color: OcgColors.bronze,
                                        fontSize: 12.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: OcgColors.espresso,
                                        side: BorderSide(
                                          color: OcgColors.sand,
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        cancelLabel ?? _defaultCancelLabel,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop(true);
                                        onConfirm();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _confirmBgColor,
                                        foregroundColor: OcgColors.ivory,
                                        elevation: 0,
                                        shadowColor: _confirmBgColor
                                            .withOpacity(0.3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        confirmLabel ?? _defaultConfirmLabel,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ),
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.icon,
    required this.badgeColor,
  });

  final String title;
  final IconData icon;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OcgColors.espresso, Color(0xFF3D2B1F), OcgColors.espresso],
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      badgeColor.withOpacity(0.25),
                      badgeColor.withOpacity(0),
                    ],
                    stops: const [0.5, 1],
                  ),
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4A3628), Color(0xFF3D2B1F)],
                  ),
                  border: Border.all(
                    color: badgeColor.withOpacity(0.35),
                    width: 2,
                  ),
                ),
                child: Icon(icon, color: OcgColors.sand, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OcgColors.ivory,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
