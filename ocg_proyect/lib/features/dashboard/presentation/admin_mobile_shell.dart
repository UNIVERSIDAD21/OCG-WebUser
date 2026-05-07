import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import 'admin_appointments_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_mobile_shell_controller.dart';
import 'admin_modules_screens.dart';
import 'admin_patients_screen.dart';
import 'admin_profile_screen.dart';

class AdminMobileShell extends ConsumerStatefulWidget {
  const AdminMobileShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<AdminMobileShell> createState() => _AdminMobileShellState();
}

class _AdminMobileShellState extends ConsumerState<AdminMobileShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 4);
  }

  @override
  void didUpdateWidget(covariant AdminMobileShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _selectedIndex = widget.initialIndex.clamp(0, 4);
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemOverlayStyleForTab(_selectedIndex),
      child: AdminMobileShellController(
        selectTab: _selectTab,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F5F0),
          body: IndexedStack(index: _selectedIndex, children: sections),
          floatingActionButton: _buildFloatingActionButton(context),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            height: 72,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: _selectTab,
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
    if (nextIndex == _selectedIndex) return;
    setState(() => _selectedIndex = nextIndex);
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
