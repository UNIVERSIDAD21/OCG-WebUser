import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_names.dart';
import '../../../../../shared/constants/firestore_paths.dart';
import '../../../../../shared/theme/ocg_colors.dart';
import '../../../../auth/providers/auth_providers.dart';
import '../layout/admin_desktop_layout.dart';

class AdminSidebar extends ConsumerStatefulWidget {
  const AdminSidebar({super.key, this.mode = AdminSidebarMode.expanded});

  final AdminSidebarMode mode;

  @override
  ConsumerState<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends ConsumerState<AdminSidebar> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSystemSearch(
    BuildContext context,
    List<({String label, IconData icon, String route})> sections,
  ) async {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return;

    final results = <_SidebarSearchResult>[];

    for (final section in sections) {
      if (section.label.toLowerCase().contains(query)) {
        results.add(
          _SidebarSearchResult(
            icon: section.icon,
            title: section.label,
            subtitle: 'Sección del sistema',
            onTap: (ctx) => ctx.go(section.route),
          ),
        );
      }
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.patients)
          .limit(300)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['nombre'] ?? '').toString();
        final email = (data['email'] ?? '').toString();

        final match =
            name.toLowerCase().contains(query) ||
            email.toLowerCase().contains(query);
        if (!match) continue;

        results.add(
          _SidebarSearchResult(
            icon: Icons.person_outline,
            title: name.isEmpty ? 'Paciente sin nombre' : name,
            subtitle: email.isEmpty ? 'Paciente' : email,
            onTap: (ctx) => ctx.go(
              RouteNames.adminPatientDetail.replaceFirst(':patientId', doc.id),
            ),
          ),
        );
      }
    } catch (_) {
      // Ignorar fallo de lectura y mostrar solo resultados de secciones.
    }

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resultados para "${_searchCtrl.text.trim()}"'),
        content: SizedBox(
          width: 560,
          child: results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sin resultados en secciones o pacientes.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = results[index];
                    return ListTile(
                      leading: Icon(item.icon, color: OcgColors.espresso),
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        item.onTap(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final mode = widget.mode;
    final collapsed = mode != AdminSidebarMode.expanded;
    final compactRail = mode == AdminSidebarMode.compactRail;

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
      ),
      (
        label: 'Pagos',
        icon: Icons.payments_outlined,
        route: RouteNames.adminPayments,
      ),
      (
        label: 'Simulador',
        icon: Icons.auto_awesome_outlined,
        route: RouteNames.adminSimulator,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1208), Color(0xFF21170F), Color(0xFF1A100A)],
          stops: [0, 0.6, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                collapsed ? (compactRail ? 8 : 12) : 20,
                28,
                collapsed ? (compactRail ? 8 : 12) : 20,
                compactRail ? 18 : 24,
              ),
              child: Column(
                crossAxisAlignment: collapsed
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    'OCG',
                    style: TextStyle(
                      color: OcgColors.ivory,
                      fontSize: collapsed ? (compactRail ? 16 : 18) : 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: collapsed
                          ? (compactRail ? 1.0 : 1.4)
                          : 2.8,
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'PANEL CLÍNICO',
                      style: TextStyle(
                        color: Color(0xFF6E5442),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.fromLTRB(
                collapsed ? (compactRail ? 12 : 16) : 20,
                0,
                collapsed ? (compactRail ? 12 : 16) : 20,
                compactRail ? 14 : 20,
              ),
              height: 1,
              color: const Color(0x0DFFFFFF),
            ),
            if (collapsed)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compactRail ? 10 : 16,
                  0,
                  compactRail ? 10 : 16,
                  compactRail ? 18 : 24,
                ),
                child: Tooltip(
                  message: 'Buscar en el sistema',
                  child: Material(
                    color: const Color(0x0DFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _runSystemSearch(context, items),
                      child: Padding(
                        padding: EdgeInsets.all(compactRail ? 10 : 12),
                        child: Icon(
                          Icons.search,
                          size: compactRail ? 16 : 18,
                          color: const Color(0xFF6E5442),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _runSystemSearch(context, items),
                  style: const TextStyle(
                    color: Color(0xFFB09070),
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar pacientes o secciones...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF6E5442),
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 14,
                      color: Color(0xFF6E5442),
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: IconButton(
                        onPressed: () => _runSystemSearch(context, items),
                        icon: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0x12FFFFFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: Color(0xFF7E6A5B),
                          ),
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0x0DFFFFFF),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Color(0x12FFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Color(0x12FFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Color(0x25FFFFFF)),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? (compactRail ? 8 : 10) : 12,
                  vertical: 0,
                ),
                children: items.map((item) {
                  final active =
                      currentRoute == item.route ||
                      currentRoute.startsWith('${item.route}/');

                  final bgColor = active
                      ? const Color(0xFFF5EDE0)
                      : Colors.transparent;
                  final fgColor = active
                      ? const Color(0xFF2C2016)
                      : const Color(0xFF7E6A5B);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Tooltip(
                      message: item.label,
                      child: Material(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.go(item.route),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: collapsed ? 0 : 12,
                              vertical: collapsed ? (compactRail ? 10 : 12) : 9,
                            ),
                            child: Row(
                              mainAxisAlignment: collapsed
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Icon(
                                  item.icon,
                                  color: fgColor,
                                  size: collapsed
                                      ? (compactRail ? 16 : 18)
                                      : 15,
                                ),
                                if (!collapsed) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: fgColor,
                                      fontSize: 13,
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      letterSpacing: 0.12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compactRail ? 8 : 12,
                16,
                compactRail ? 8 : 12,
                collapsed ? 16 : 24,
              ),
              child: Tooltip(
                message: 'Cerrar sesión',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cerrar sesión'),
                          content: const Text('¿Deseas cerrar tu sesión?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Cerrar sesión'),
                            ),
                          ],
                        ),
                      );

                      if (confirm != true) return;

                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) {
                        context.go(RouteNames.login);
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: collapsed ? 0 : 12,
                        vertical: collapsed ? (compactRail ? 10 : 12) : 9,
                      ),
                      child: Row(
                        mainAxisAlignment: collapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.logout,
                            color: Color(0xFF6E5442),
                            size: 15,
                          ),
                          if (!collapsed) ...[
                            const SizedBox(width: 10),
                            const Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                color: Color(0xFF6E5442),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
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

class _SidebarSearchResult {
  const _SidebarSearchResult({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context) onTap;
}
