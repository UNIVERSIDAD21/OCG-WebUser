import 'package:flutter/widgets.dart';

import '../../../features/admin/presentation/web/layout/admin_desktop_layout.dart';
import 'web_breakpoints.dart';

class WebLayoutContext {
  const WebLayoutContext._();

  static bool useDesktopShell(BuildContext context) =>
      WebBreakpoints.isDesktop(context);

  static bool useWebPatientNavRail(BuildContext context) =>
      WebBreakpoints.isDesktop(context);

  static bool useCompactDesktop(BuildContext context) =>
      WebBreakpoints.isCompactDesktop(context);

  static AdminDesktopLayoutData? maybeAdminDesktopLayout(
    BuildContext context,
  ) => AdminDesktopLayoutScope.maybeOf(context);
}
