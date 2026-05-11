import 'package:flutter/material.dart';

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
      barrierDismissible: false,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
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
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // No se usa directamente; _OcgConfirmDialogContent maneja la UI.
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
    final text = '${title.toLowerCase()} ${message.toLowerCase()} '
        '${(confirmLabel ?? '').toLowerCase()}';
    return text.contains('cerrar sesión') || text.contains('cerrar sesion');
  }

  IconData get _icon => switch (type) {
    _ when _isSignOutAction => Icons.logout_rounded,
    OcgConfirmDialogType.danger => Icons.warning_rounded,
    OcgConfirmDialogType.warning => Icons.error_outline_rounded,
    OcgConfirmDialogType.info => Icons.info_outline_rounded,
  };

  Color get _iconBgColor => switch (type) {
    _ when _isSignOutAction => const Color(0xFF6E5442),
    OcgConfirmDialogType.danger => const Color(0xFFD32F2F),
    OcgConfirmDialogType.warning => const Color(0xFFED8E00),
    OcgConfirmDialogType.info => const Color(0xFF6E5442),
  };

  Color get _confirmBgColor => switch (type) {
    _ when _isSignOutAction => const Color(0xFF6E5442),
    OcgConfirmDialogType.danger => const Color(0xFFD32F2F),
    OcgConfirmDialogType.warning => const Color(0xFFED8E00),
    OcgConfirmDialogType.info => const Color(0xFF2C2016),
  };

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFCF8), Color(0xFFF7F2E8)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFE7DDD2).withOpacity(0.7),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2C2016).withOpacity(0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Icon header
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _iconBgColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _iconBgColor.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(_icon, color: _iconBgColor, size: 28),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF2C2016),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Message
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8A6F59),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                if (_isSignOutAction) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4ECE2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE4D6C6),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Color(0xFF8A6F59),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Podrás iniciar sesión nuevamente cuando quieras.',
                            style: TextStyle(
                              color: Color(0xFF8A6F59),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
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
                          child: Text(
                            cancelLabel ?? 'Cancelar',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(true);
                            onConfirm();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _confirmBgColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            confirmLabel ?? 'Confirmar',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
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
          ),
        ),
      ),
    );
  }
}
