import 'package:flutter/material.dart';
import '../theme/ocg_colors.dart';

/// Esta es la función solicitada.
/// Retorna el Widget de carga con el estilo visual de OCG.
Widget ocgLoading({String label = 'Cargando...'}) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            // Si quieres que el color del spinner también sea del tema:
            // valueColor: AlwaysStoppedAnimation<Color>(OcgColors.primary),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: OcgColors.ink.withOpacity(0.65),
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}
