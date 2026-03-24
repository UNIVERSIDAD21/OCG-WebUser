import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_names.dart';
import '../../../../../shared/theme/ocg_colors.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.currentRoute,
  });

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, String route})>[
      (label: 'Dashboard', icon: Icons.dashboard_outlined, route: RouteNames.adminDashboard),
      (label: 'Pacientes', icon: Icons.people_outline, route: RouteNames.adminPatients),
      (label: 'Agenda', icon: Icons.calendar_month_outlined, route: RouteNames.adminAppointments),
      (label: 'Tratamientos', icon: Icons.monitor_heart_outlined, route: RouteNames.adminPatients),
      (label: 'Pagos', icon: Icons.payments_outlined, route: RouteNames.adminPatients),
      (label: 'Simulador', icon: Icons.auto_awesome_outlined, route: RouteNames.adminPatients),
      (label: 'Notificaciones', icon: Icons.notifications_outlined, route: RouteNames.adminDashboard),
      (label: 'Configuración', icon: Icons.settings_outlined, route: RouteNames.adminDashboard),
    ];

    return Container(
      width: 250,
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
                  Text('OCG', style: TextStyle(color: OcgColors.bronze, fontSize: 28, fontWeight: FontWeight.bold)),
                  Text('Panel Clínico', style: TextStyle(color: OcgColors.ivory)),
                ],
              ),
            ),
            const Divider(color: Color(0x33FFFFFF), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                children: items.map((item) {
                  final active = currentRoute == item.route;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      selected: active,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      selectedTileColor: OcgColors.bronze.withOpacity(0.2),
                      iconColor: active ? OcgColors.bronze : OcgColors.ivory,
                      textColor: active ? OcgColors.bronze : OcgColors.ivory,
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      onTap: () => context.go(item.route),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
