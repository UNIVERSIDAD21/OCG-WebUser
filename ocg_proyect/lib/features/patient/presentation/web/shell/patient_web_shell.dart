import 'package:flutter/material.dart';

import '../../../../../presentation/web/common/web_layout_context.dart';
import '../../../../../presentation/web/common/web_page_container.dart';
import '../components/patient_header.dart';
import '../components/patient_navigation.dart';

class PatientWebShell extends StatelessWidget {
  const PatientWebShell({
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
      body: Column(
        children: [
          PatientHeader(title: title),
          Expanded(
            child: Row(
              children: [
                PatientNavigation(currentRoute: currentRoute),
                Expanded(
                  child: SingleChildScrollView(
                    child: WebPageContainer(
                      maxWidth: 1100,
                      child: child,
                    ),
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
