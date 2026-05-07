import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_mobile_bottom_nav.dart';
import 'admin_appointments_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_mobile_shell_controller.dart';
import 'admin_modules_screens.dart';
import 'admin_patients_screen.dart';
import 'admin_profile_screen.dart';

class AdminMobileShell extends ConsumerStatefulWidget {
  const AdminMobileShell({super.key, this.initialIndex = 0, this.detailChild});

  final int initialIndex;
  final Widget? detailChild;

  @override
  ConsumerState<AdminMobileShell> createState() => _AdminMobileShellState();
}

class _AdminMobileShellState extends ConsumerState<AdminMobileShell> {
  late int _selectedIndex;
  late bool _showDetailChild;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 4);
    _showDetailChild = widget.detailChild != null;
  }

  @override
  void didUpdateWidget(covariant AdminMobileShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _selectedIndex = widget.initialIndex.clamp(0, 4);
    }
    if (oldWidget.detailChild != widget.detailChild) {
      _showDetailChild = widget.detailChild != null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = const [
      AdminDashboardScreen(embeddedInMobileShell: true),
      AdminPatientsScreen(embeddedInMobileShell: true),
      AdminAppointmentsScreen(embeddedInMobileShell: true),
      AdminSimulatorScreen(embeddedInMobileShell: true),
      AdminProfileScreen(embeddedInMobileShell: true),
    ];

    final visibleDetailChild = _showDetailChild ? widget.detailChild : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemOverlayStyleForTab(_selectedIndex),
      child: AdminMobileShellController(
        selectTab: _selectTab,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F5F0),
          body:
              visibleDetailChild ??
              IndexedStack(index: _selectedIndex, children: sections),
          floatingActionButton: visibleDetailChild == null
              ? _buildFloatingActionButton(context)
              : null,
          bottomNavigationBar: OcgMobileBottomNav(
            selectedIndex: _selectedIndex,
            onSelected: _selectTab,
            items: const [
              OcgMobileBottomNavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Inicio',
              ),
              OcgMobileBottomNavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Pacientes',
              ),
              OcgMobileBottomNavItem(
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month,
                label: 'Agenda',
              ),
              OcgMobileBottomNavItem(
                icon: Icons.auto_awesome_outlined,
                activeIcon: Icons.auto_awesome,
                label: 'Simulador',
              ),
              OcgMobileBottomNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  SystemUiOverlayStyle _systemOverlayStyleForTab(int index) {
    final hasDarkHeader = index == 0 || index == 1;
    return (hasDarkHeader
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFFF8F5F0),
          systemNavigationBarIconBrightness: Brightness.dark,
        );
  }

  void _selectTab(int index) {
    final nextIndex = index.clamp(0, 4);
    if (_showDetailChild) {
      context.go(_routeForIndex(nextIndex));
      return;
    }
    if (nextIndex == _selectedIndex) return;
    setState(() => _selectedIndex = nextIndex);
  }

  String _routeForIndex(int index) {
    return switch (index) {
      0 => RouteNames.adminDashboard,
      1 => RouteNames.adminPatients,
      2 => RouteNames.adminAppointments,
      3 => RouteNames.adminSimulator,
      4 => RouteNames.adminProfile,
      _ => RouteNames.adminDashboard,
    };
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    switch (_selectedIndex) {
      case 1:
        return FloatingActionButton(
          heroTag: 'admin-mobile-shell-add-patient',
          onPressed: () =>
              AdminPatientsScreen.showAddPatientDialog(context, ref),
          backgroundColor: OcgColors.bronze,
          child: const Icon(Icons.person_add),
        );
      case 2:
        return FloatingActionButton(
          heroTag: 'admin-mobile-shell-add-appointment',
          mini: true,
          tooltip: 'Nueva cita',
          backgroundColor: OcgColors.espresso,
          foregroundColor: OcgColors.ivory,
          onPressed: () =>
              AdminAppointmentsScreen.showCreateDialog(context, ref),
          child: const Icon(Icons.add, size: 18),
        );
      default:
        return null;
    }
  }
}
