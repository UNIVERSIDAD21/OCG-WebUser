import 'package:flutter/material.dart';

import '../../../../../presentation/web/common/web_layout_context.dart';
import '../../../../../presentation/web/common/web_page_container.dart';
import '../components/admin_sidebar.dart';
import '../components/admin_topbar.dart';

class AdminWebShell extends StatelessWidget {
  const AdminWebShell({
    super.key,
    required this.title, // ✅ Se elimina currentRoute
    required this.child,
  });

  // ✅ Ya no existe currentRoute aquí
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
              SizedBox(
                width: sidebarWidth,
                child: const AdminSidebar(), // ✅ Sin parámetros
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: WebPageContainer(
                    maxWidth: compactDesktop ? 1180 : 1400,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminTopbar(title: title),
                          const SizedBox(height: 12),
                          child,
                        ],
                      ),
                    ),
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
