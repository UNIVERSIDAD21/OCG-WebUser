import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_names.dart';
import '../../../../../shared/constants/firestore_paths.dart';
import '../../../../../shared/theme/ocg_colors.dart';
import '../../../../../shared/widgets/ocg_confirm_dialog.dart';
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

  Future<void> _showSearchDialog(
    BuildContext context,
    List<({String label, IconData icon, String route})> sections,
  ) async {
    final dialogCtrl = TextEditingController();

    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buscar'),
        content: TextField(
          controller: dialogCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Pacientes, secciones...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
          textInputAction: TextInputAction.search,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(dialogCtrl.text.trim()),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );

    dialogCtrl.dispose();

    if (query == null || query.isEmpty || !mounted) return;

    _searchCtrl.text = query;
    await _runSystemSearch(context, sections);
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

  Widget _sectionLabel(bool collapsed, bool compactRail, String label) {
    if (collapsed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 1,
            color: OcgColors.bronze.withOpacity(0.25),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: OcgColors.bronze.withOpacity(0.45),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    OcgColors.bronze.withOpacity(0.25),
                    OcgColors.bronze.withOpacity(0.0),
                  ],
                ),
              ),
            ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1C1208),
            const Color(0xFF21170F),
            const Color(0xFF1A100A),
            const Color(0xFF130E08),
          ],
          stops: const [0, 0.4, 0.75, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header: Logo ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                collapsed ? (compactRail ? 8 : 12) : 20,
                28,
                collapsed ? (compactRail ? 8 : 12) : 20,
                compactRail ? 14 : 18,
              ),
              child: Column(
                crossAxisAlignment: collapsed
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 3,
                        height: collapsed ? 18 : 26,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              OcgColors.bronze.withOpacity(0.8),
                              OcgColors.bronze.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                    ],
                  ),
                  if (!collapsed) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 13),
                        Container(
                          width: 18,
                          height: 1,
                          color: OcgColors.bronze.withOpacity(0.3),
                        ),
                        const SizedBox(width: 6),
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
                    ),
                  ],
                ],
              ),
            ),
            // Línea divisoria header
            Container(
              margin: EdgeInsets.fromLTRB(
                collapsed ? (compactRail ? 12 : 16) : 20,
                0,
                collapsed ? (compactRail ? 12 : 16) : 20,
                compactRail ? 8 : 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x00FFFFFF),
                            Color(0x0DFFFFFF),
                            Color(0x0DFFFFFF),
                            Color(0x00FFFFFF),
                          ],
                          stops: [0, 0.3, 0.7, 1],
                        ),
                      ),
                    ),
                  ),
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: OcgColors.bronze.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
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
                      onTap: () => _showSearchDialog(context, items),
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
            // ── Navegación principal ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _sectionLabel(collapsed, compactRail, 'MENÚ'),
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

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Tooltip(
                      message: item.label,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.go(item.route),
                          child: Container(
                            decoration: active
                                ? BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        const Color(0xFFF5EDE0)
                                            .withOpacity(0.95),
                                        const Color(0xFFF5EDE0)
                                            .withOpacity(0.65),
                                        const Color(0xFFF5EDE0)
                                            .withOpacity(0.15),
                                      ],
                                      stops: const [0, 0.4, 1],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFF5EDE0)
                                          .withOpacity(0.2),
                                    ),
                                  )
                                : BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.transparent,
                                    ),
                                  ),
                            padding: const EdgeInsets.only(left: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                if (active && !collapsed)
                                  Container(
                                    width: 3,
                                    height: 24,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          OcgColors.bronze.withOpacity(0.9),
                                          OcgColors.bronze.withOpacity(0.3),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  )
                                else if (collapsed)
                                  const SizedBox(width: 4),
                                Icon(
                                  item.icon,
                                  color: active
                                      ? const Color(0xFF2C2016)
                                      : const Color(0xFF7E6A5B),
                                  size: collapsed
                                      ? (compactRail ? 16 : 18)
                                      : 15,
                                ),
                                if (!collapsed) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: active
                                          ? const Color(0xFF2C2016)
                                          : const Color(0xFF7E6A5B),
                                      fontSize: 13,
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      letterSpacing: 0.12,
                                    ),
                                  ),
                                  if (active)
                                    const Spacer(),
                                  if (active && !collapsed)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: OcgColors.bronze
                                              .withOpacity(0.6),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                                if (collapsed)
                                  const SizedBox(width: 4),
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
            // Línea divisoria inferior
            Container(
              margin: EdgeInsets.fromLTRB(
                collapsed ? (compactRail ? 12 : 16) : 20,
                8,
                collapsed ? (compactRail ? 12 : 16) : 20,
                compactRail ? 6 : 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x00FFFFFF),
                            Color(0x0DFFFFFF),
                            Color(0x0DFFFFFF),
                            Color(0x00FFFFFF),
                          ],
                          stops: [0, 0.3, 0.7, 1],
                        ),
                      ),
                    ),
                  ),
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: OcgColors.bronze.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Footer: Cerrar sesión ────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                compactRail ? 8 : 12,
                8,
                compactRail ? 8 : 12,
                collapsed ? 16 : 20,
              ),
              child: Tooltip(
                message: 'Cerrar sesión',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final confirm = await OcgConfirmDialog.show(
                        context,
                        type: OcgConfirmDialogType.danger,
                        title: 'Cerrar sesión',
                        message: '¿Deseas cerrar tu sesión?',
                        confirmLabel: 'Cerrar sesión',
                        onConfirm: () {},
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
