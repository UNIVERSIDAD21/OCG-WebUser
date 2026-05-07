import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Coordina la navegación interna del shell móvil del administrador.
///
/// Si una pantalla está embebida dentro de [AdminMobileShell], las acciones
/// entre tabs cambian el índice del shell en vez de reconstruir una ruta
/// completa con otro Scaffold. Fuera del shell, conserva la navegación por ruta
/// para desktop/web y enlaces profundos.
class AdminMobileShellController extends InheritedWidget {
  const AdminMobileShellController({
    super.key,
    required this.selectTab,
    required super.child,
  });

  final ValueChanged<int> selectTab;

  static AdminMobileShellController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdminMobileShellController>();
  }

  @override
  bool updateShouldNotify(AdminMobileShellController oldWidget) {
    return selectTab != oldWidget.selectTab;
  }
}

extension AdminMobileShellNavigation on BuildContext {
  void goAdminTab(int index, String route) {
    final controller = AdminMobileShellController.maybeOf(this);
    if (controller != null) {
      controller.selectTab(index);
      return;
    }
    go(route);
  }
}
