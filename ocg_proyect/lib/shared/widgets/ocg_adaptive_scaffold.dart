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
    this.onSignOut,
  });

  final Widget body;

  /// Índice del destino activo en el NavigationRail.
  /// 0 = Dashboard, 1 = Pacientes, 2 = Agenda,
  /// 3 = Tratamientos, 4 = Pagos, 5 = Simulador
  final int selectedIndex;

  /// Título que aparece en el AppBar (pantallas pequeñas).
  final String? title;

  /// Acciones del AppBar en pantallas pequeñas.
  final List<Widget>? appBarActions;

  /// FAB opcional.
  final Widget? floatingActionButton;

  /// Widget opcional al final del NavigationRail (pantallas anchas).
  final Widget? railTrailing;

  /// Acción de cerrar sesión usada por el Drawer móvil admin.
  final VoidCallback? onSignOut;

  // ─── Destinos admin (fuente única de verdad para rail + drawer) ─────────

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

  void _onDestinationSelected(BuildContext context, int index) {
    if (index < _routes.length) {
      context.go(_routes[index]);
    }
  }

  Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: OcgColors.espresso,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OCG',
                      style: TextStyle(
                        color: OcgColors.bronze,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Panel Clínico',
                      style: TextStyle(color: OcgColors.ivory),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0x33FFFFFF), height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _destinations.length,
                  itemBuilder: (context, index) {
                    final item = _destinations[index];
                    final active = selectedIndex == index;
                    return ListTile(
                      selected: active,
                      selectedTileColor: OcgColors.bronze.withOpacity(0.18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Icon(
                        active
                            ? (item.selectedIcon as Icon).icon
                            : (item.icon as Icon).icon,
                        color: active ? OcgColors.bronze : OcgColors.ivory,
                      ),
                      title: DefaultTextStyle(
                        style: TextStyle(
                          color: active ? OcgColors.bronze : OcgColors.ivory,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        ),
                        child: item.label,
                      ),
                      onTap: () {
                        Navigator.of(context).maybePop();
                        _onDestinationSelected(context, index);
                      },
                    );
                  },
                ),
              ),
              const Divider(color: Color(0x33FFFFFF), height: 1),
              ListTile(
                enabled: onSignOut != null,
                leading: const Icon(Icons.logout, color: Color(0xFFFFD9D9)),
                title: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Color(0xFFFFD9D9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: onSignOut == null
                    ? null
                    : () {
                        Navigator.of(context).maybePop();
                        onSignOut!();
                      },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
      drawer: _buildAdminDrawer(context),
      appBar: AppBar(
        title: title != null ? Text(title!) : null,
        actions: appBarActions,
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
