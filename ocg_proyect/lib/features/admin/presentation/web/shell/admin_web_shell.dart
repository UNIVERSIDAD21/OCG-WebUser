import 'package:flutter/material.dart';

import '../../../../../presentation/web/common/web_breakpoints.dart';
import '../../../../../presentation/web/common/web_layout_context.dart';
import '../../../../../presentation/web/common/web_page_container.dart';
import '../components/admin_sidebar.dart';

class AdminWebShell extends StatelessWidget {
  const AdminWebShell({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!WebLayoutContext.useDesktopShell(context)) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactDesktop = constraints.maxWidth < 1320;
        final sidebarWidth = compactDesktop ? 220.0 : 250.0;

        return Scaffold(
          body: Row(
            children: [
              SizedBox(width: sidebarWidth, child: const AdminSidebar()),
              Expanded(
                child: SingleChildScrollView(
                  child: WebPageContainer(
                    maxWidth: WebBreakpoints.shellMaxWidth(context),
                    padding: EdgeInsets.all(
                      WebBreakpoints.shellHorizontalPadding(context),
                    ),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
