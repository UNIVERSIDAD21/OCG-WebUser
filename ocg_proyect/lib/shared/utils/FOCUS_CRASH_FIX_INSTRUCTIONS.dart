// ══════════════════════════════════════════════════════════════════════════════
// FIX: Flutter Web — "Cannot get renderObject of inactive element"
//
// CAUSA RAÍZ: En Flutter Web, el sistema de traversal de foco intenta calcular
// la posición de los widgets del diálogo en el mismo frame en que el diálogo
// se está desmontando. Esto ocurre porque Navigator.pop() se llama
// síncronamente dentro de onPressed, antes de que Flutter finalice el frame.
//
// SOLUCIÓN GLOBAL: Envolver TODOS los Navigator.pop() que están dentro de
// onPressed de botones en AlertDialog con addPostFrameCallback.
//
// PATRÓN A APLICAR:
//
//   ANTES:
//     onPressed: () => Navigator.of(ctx).pop(),
//     onPressed: () => Navigator.of(ctx).pop(data),
//     onPressed: () { Navigator.pop(ctx); },
//
//   DESPUÉS:
//     onPressed: () {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (ctx.mounted) Navigator.of(ctx).pop();
//       });
//     },
//
// ══════════════════════════════════════════════════════════════════════════════
//
// ARCHIVOS QUE NECESITAN ESTE FIX ADEMÁS DE LOS YA ENTREGADOS:
//
// 1. lib/features/dashboard/presentation/admin_appointments_screen.dart
//    Buscar y reemplazar todos los Navigator.pop() en:
//    - showCreateDialog (botón "Cancelar" y botón "Crear cita")
//    - showCreatePatientAccountDialog (botón "Cancelar" y éxito)
//    - _showRescheduleDialog (botones "Cancelar" y "Confirmar")
//    - _showCancelDialog (botones "No" y "Sí, cancelar")
//
// 2. lib/features/dashboard/presentation/admin_patients_screen.dart
//    Buscar y reemplazar en _showAddPatientDialog:
//    - botón "Entendido"
//    - botón "Ver pendientes de completar"
//
// 3. lib/features/patients/presentation/patient_form_screen.dart
//    Si tiene diálogos con Navigator.pop() en onPressed, aplicar el mismo fix.
//
// 4. lib/features/patients/presentation/patient_detail_screen.dart
//    El diálogo de confirmación de eliminación usa Navigator.pop(bool).
//    Aplicar el fix preservando el valor de retorno:
//
//    ANTES:
//      onPressed: () => Navigator.of(dialogContext).pop(false),
//      onPressed: () => Navigator.of(dialogContext).pop(true),
//
//    DESPUÉS:
//      onPressed: () {
//        WidgetsBinding.instance.addPostFrameCallback((_) {
//          if (dialogContext.mounted) Navigator.of(dialogContext).pop(false);
//        });
//      },
//      onPressed: () {
//        WidgetsBinding.instance.addPostFrameCallback((_) {
//          if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
//        });
//      },
//
// ══════════════════════════════════════════════════════════════════════════════
//
// ALTERNATIVA: Crear un helper global para no repetir el patrón:
//
// // lib/shared/utils/dialog_utils.dart
// import 'package:flutter/material.dart';
//
// /// Cierra el diálogo de forma segura en Flutter Web evitando el crash de
// /// focus traversal. Siempre usar este método en lugar de Navigator.pop()
// /// dentro de onPressed de botones en AlertDialog.
// void popDialog<T>(BuildContext context, [T? result]) {
//   WidgetsBinding.instance.addPostFrameCallback((_) {
//     if (context.mounted) Navigator.of(context).pop(result);
//   });
// }
//
// USO:
//   onPressed: () => popDialog(ctx),
//   onPressed: () => popDialog(ctx, true),
//   onPressed: () => popDialog(ctx, {'name': name, 'email': email}),
//
// ══════════════════════════════════════════════════════════════════════════════
