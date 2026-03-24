import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import 'web/shell/admin_web_shell.dart';

class AdminModulePlaceholderScreen extends StatelessWidget {
  const AdminModulePlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OcgColors.ivory,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OcgColors.bronze.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: OcgColors.bronze),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: OcgColors.espresso,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: OcgColors.ink.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go(RouteNames.adminPatients),
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Ir a Pacientes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(RouteNames.adminAppointments),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Ir a Agenda'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      return AdminWebShell(title: title, child: content);
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 0,
      title: title,
      body: content,
    );
  }
}
