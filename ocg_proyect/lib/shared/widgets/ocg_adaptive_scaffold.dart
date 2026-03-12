import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../theme/ocg_colors.dart';

/// Scaffold adaptivo para pantallas del admin.
///
/// - Pantallas > 800px: [NavigationRail] (240px) a la izquierda + [Expanded(child: body)]
/// - Pantallas ≤ 800px: [Scaffold] normal con [AppBar]
class OcgAdaptiveScaffold extends StatelessWidget {
  const OcgAdaptiveScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    this.title,
    this.appBarActions,
    this.floatingActionButton,
    this.railTrailing,
  });

  final Widget body;

  /// Índice del destino activo en el NavigationRail.
  /// 0 = Dashboard, 1 = Pacientes, 2 = Agenda
  final int selectedIndex;

  /// Título que aparece en el AppBar (pantallas pequeñas).
  final String? title;

  /// Acciones del AppBar en pantallas pequeñas.
  final List<Widget>? appBarActions;

  /// FAB opcional.
  final Widget? floatingActionButton;

  /// Widget opcional al final del NavigationRail (pantallas anchas).
  final Widget? railTrailing;

  // ─── Destinos del NavigationRail ──────────────────────────────────────────

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
  ];

  static const _routes = [
    RouteNames.adminDashboard,
    RouteNames.adminPatients,
    RouteNames.adminAppointments,
  ];

  void _onDestinationSelected(BuildContext context, int index) {
    if (index < _routes.length) {
      context.go(_routes[index]);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    if (isWide) {
      return Scaffold(
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            // ── NavigationRail lateral ──────────────────────────────────────
            SizedBox(
              width: 240,
              child: NavigationRail(
                extended: true,
                backgroundColor: OcgColors.espresso,
                selectedIndex: selectedIndex,
                onDestinationSelected: (i) =>
                    _onDestinationSelected(context, i),
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
            // ── Separador ───────────────────────────────────────────────────
            const VerticalDivider(width: 1, thickness: 1),
            // ── Contenido principal ─────────────────────────────────────────
            Expanded(child: body),
          ],
        ),
      );
    }

    // ── Layout compacto (≤ 800px) ──────────────────────────────────────────
    return Scaffold(
      appBar: AppBar(
        title: title != null ? Text(title!) : null,
        actions: appBarActions,
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
