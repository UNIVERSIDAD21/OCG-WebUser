import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'web_breakpoints.dart';

class WebLayoutContext {
  const WebLayoutContext._();

  static bool useDesktopShell(BuildContext context) =>
      kIsWeb && WebBreakpoints.isDesktop(context);

  static bool useWebPatientNavRail(BuildContext context) =>
      kIsWeb && WebBreakpoints.isDesktop(context);
}
