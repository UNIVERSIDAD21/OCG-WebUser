import 'package:flutter/material.dart';

import '../../../../../presentation/web/common/web_layout_context.dart';
import '../../../../../presentation/web/common/web_page_container.dart';
import '../components/admin_sidebar.dart';
import '../layout/admin_desktop_layout.dart';

class AdminWebShell extends StatelessWidget {
  const AdminWebShell({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!WebLayoutContext.useDesktopShell(context)) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AdminDesktopLayoutData.fromViewport(
          Size(constraints.maxWidth, constraints.maxHeight),
        );

        return AdminDesktopLayoutScope(
          layout: layout,
          child: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: layout.sidebarWidth,
                  child: AdminSidebar(mode: layout.sidebarMode),
                ),
                SizedBox(width: layout.shellGap),
                Expanded(
                  child: SingleChildScrollView(
                    child: WebPageContainer(
                      maxWidth: layout.contentMaxWidth,
                      padding: EdgeInsets.symmetric(
                        horizontal: layout.pageHorizontalPadding,
                        vertical: layout.sectionSpacing,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
