import 'package:flutter/material.dart';

import '../../../../../presentation/web/common/web_layout_context.dart';
import '../../../../../presentation/web/common/web_page_container.dart';
import '../components/admin_sidebar.dart';
import '../components/admin_topbar.dart';

class AdminWebShell extends StatelessWidget {
  const AdminWebShell({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.child,
  });

  final String currentRoute;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!WebLayoutContext.useDesktopShell(context)) return child;

    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(currentRoute: currentRoute),
          Expanded(
            child: Column(
              children: [
                AdminTopbar(title: title),
                Expanded(
                  child: SingleChildScrollView(
                    child: WebPageContainer(child: child),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
