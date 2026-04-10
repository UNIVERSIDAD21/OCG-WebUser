import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_names.dart';
import '../../../../../shared/constants/firestore_paths.dart';
import '../../../../../shared/theme/ocg_colors.dart';
import '../../../../auth/providers/auth_providers.dart';

class AdminSidebar extends ConsumerStatefulWidget {
  const AdminSidebar({super.key});

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

        final match = name.toLowerCase().contains(query) ||
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
                onSubmitted: (_) => _runSystemSearch(context, items),
                style: const TextStyle(color: OcgColors.ivory, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar pacientes o secciones...',
                  hintStyle: const TextStyle(color: Color(0xCCFFFFFF)),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: OcgColors.ivory,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => _runSystemSearch(context, items),
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: OcgColors.ivory,
                    ),
                  ),
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
