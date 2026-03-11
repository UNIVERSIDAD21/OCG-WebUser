import 'package:flutter/material.dart';

/// Cierra un diálogo de forma segura en Flutter Web.
///
/// En Flutter Web, llamar [Navigator.pop] síncronamente dentro de [onPressed]
/// provoca un crash de focus traversal:
/// `"Cannot get renderObject of inactive element"`
///
/// Esto ocurre porque el sistema de foco intenta calcular la posición de los
/// widgets del diálogo en el mismo frame en que se están desmontando.
///
/// Este helper difiere el pop al siguiente frame con [addPostFrameCallback],
/// dando tiempo a Flutter para finalizar el frame actual antes de desmontar.
///
/// Usar **siempre** este método en lugar de [Navigator.pop] dentro de
/// `onPressed` de botones en [AlertDialog] y [Dialog].
///
/// ```dart
/// // ❌ Causa crash en Flutter Web
/// onPressed: () => Navigator.of(ctx).pop(),
///
/// // ✅ Seguro en todas las plataformas
/// onPressed: () => popDialog(ctx),
/// onPressed: () => popDialog(ctx, true),
/// onPressed: () => popDialog(ctx, {'name': name}),
/// ```
void popDialog<T>(BuildContext context, [T? result]) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      Navigator.of(context).pop(result);
    }
  });
}
