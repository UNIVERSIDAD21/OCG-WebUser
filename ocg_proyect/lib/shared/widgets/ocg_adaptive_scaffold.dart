import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../theme/ocg_colors.dart';

/// Scaffold adaptivo para pantallas del admin.
///
/// - Pantallas > 800px: [NavigationRail] (240px) a la izquierda + [Expanded(child: body)]
/// - Pantallas ≤ 800px: [Scaffold] móvil con navegación inferior compacta
class OcgAdaptiveScaffold extends StatelessWidget {
  const OcgAdaptiveScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    this.title,
    this.appBarActions,
    this.floatingActionButton,
    this.railTrailing,
    this.onSignOut,
    this.showMobileAppBar = true,
  });

  final Widget body;
  final int selectedIndex;
  final String? title;
  final List<Widget>? appBarActions;
  final Widget? floatingActionButton;
  final Widget? railTrailing;
  final VoidCallback? onSignOut;
  final bool showMobileAppBar;

  static const _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: Text('Pacientes'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: Text('Agenda'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.monitor_heart_outlined),
      selectedIcon: Icon(Icons.monitor_heart),
      label: Text('Tratamientos'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.payments_outlined),
      selectedIcon: Icon(Icons.payments),
      label: Text('Pagos'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome),
      label: Text('Simulador'),
    ),
  ];

  static const _routes = [
    RouteNames.adminDashboard,
    RouteNames.adminPatients,
    RouteNames.adminAppointments,
    RouteNames.adminTreatments,
    RouteNames.adminPayments,
    RouteNames.adminSimulator,
  ];

  static const _mobileRoutes = [
    RouteNames.adminDashboard,
    RouteNames.adminPatients,
    RouteNames.adminAppointments,
    RouteNames.adminSimulator,
    RouteNames.adminProfile,
  ];

  void _onDestinationSelected(BuildContext context, int index) {
    if (index < _routes.length) {
      context.go(_routes[index]);
    }
  }

  int _mobileSelectedIndex() {
    if (selectedIndex == 5) return 3; // Simulador
    if (selectedIndex >= 6) return 4; // Perfil / extras móviles
    if (selectedIndex == 3 || selectedIndex == 4) return 1; // Mantener fuera de móvil
    return selectedIndex.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    if (isWide) {
      return Scaffold(
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            SizedBox(
              width: 240,
              child: NavigationRail(
                extended: true,
                backgroundColor: OcgColors.espresso,
                selectedIndex: selectedIndex,
                onDestinationSelected: (i) => _onDestinationSelected(context, i),
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OCG',
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: OcgColors.bronze,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Clínica',
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 16,
                          color: OcgColors.ivory.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                selectedIconTheme: const IconThemeData(color: OcgColors.bronze),
                unselectedIconTheme: IconThemeData(
                  color: OcgColors.ivory.withOpacity(0.6),
                ),
                selectedLabelTextStyle: const TextStyle(
                  color: OcgColors.bronze,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: OcgColors.ivory.withOpacity(0.6),
                ),
                indicatorColor: OcgColors.bronze.withOpacity(0.15),
                destinations: _destinations,
                trailing: railTrailing == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        child: railTrailing,
                      ),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: showMobileAppBar
          ? AppBar(
              title: title != null ? Text(title!) : null,
              actions: appBarActions,
            )
          : null,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: !showMobileAppBar,
        bottom: false,
        child: body,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mobileSelectedIndex(),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (index < _mobileRoutes.length) {
            context.go(_mobileRoutes[index]);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Pacientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Simulador',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
