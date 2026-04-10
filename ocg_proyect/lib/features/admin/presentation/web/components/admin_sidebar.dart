import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_names.dart';
import '../../../../../shared/theme/ocg_colors.dart';
import '../../../../auth/providers/auth_providers.dart';

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    final items = <({String label, IconData icon, String route})>[
      (
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        route: RouteNames.adminDashboard,
      ),
      (
        label: 'Pacientes',
        icon: Icons.people_outline,
        route: RouteNames.adminPatients,
      ),
      (
        label: 'Agenda',
        icon: Icons.calendar_month_outlined,
        route: RouteNames.adminAppointments,
      ),
      (
        label: 'Tratamientos',
        icon: Icons.monitor_heart_outlined,
        route: RouteNames.adminTreatments,
      ), // ✅ ruta propia
      (
        label: 'Pagos',
        icon: Icons.payments_outlined,
        route: RouteNames.adminPayments,
      ), // ✅ ruta propia
      (
        label: 'Simulador',
        icon: Icons.auto_awesome_outlined,
        route: RouteNames.adminSimulator,
      ), // ✅ ruta propia

    ];

    return Container(
      color: OcgColors.espresso,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OCG',
                    style: TextStyle(
                      color: OcgColors.bronze,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Panel Clínico',
                    style: TextStyle(color: OcgColors.ivory),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0x33FFFFFF), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                children: items.map((item) {
                  final active = currentRoute == item.route ||
                      currentRoute.startsWith('${item.route}/');

                  final bgColor = active ? OcgColors.ivory : Colors.transparent;
                  final fgColor = active ? OcgColors.espresso : OcgColors.ivory;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Material(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.go(item.route),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Icon(item.icon, color: fgColor, size: 22),
                              const SizedBox(width: 14),
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: fgColor,
                                  fontSize: 14,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(color: Color(0x33FFFFFF), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) {
                      context.go(RouteNames.login);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: OcgColors.ivory, size: 22),
                        SizedBox(width: 14),
                        Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            color: OcgColors.ivory,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
