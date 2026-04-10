import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_names.dart';
import '../../../../../shared/theme/ocg_colors.dart';
import '../../../../auth/providers/auth_providers.dart';

class AdminSidebar extends ConsumerStatefulWidget {
  const AdminSidebar({super.key});

  @override
  ConsumerState<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends ConsumerState<AdminSidebar> {
  final _searchCtrl = TextEditingController();
  String _menuQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final filteredItems = items.where((item) {
      final q = _menuQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return item.label.toLowerCase().contains(q);
    }).toList();

    return Container(
      color: OcgColors.espresso,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 10),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _menuQuery = v),
                style: const TextStyle(color: OcgColors.ivory, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar sección...',
                  hintStyle: const TextStyle(color: Color(0xCCFFFFFF)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: OcgColors.ivory),
                  filled: true,
                  fillColor: OcgColors.ivory.withOpacity(0.12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Divider(color: Color(0x33FFFFFF), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                children: filteredItems.map((item) {
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
