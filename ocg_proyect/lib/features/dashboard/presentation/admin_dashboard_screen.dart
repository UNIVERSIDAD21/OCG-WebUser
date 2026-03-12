import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../auth/providers/auth_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar tu sesión de administrador?'),
        actions: [
          TextButton(
            onPressed: () => popDialog(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OcgColors.error,
              foregroundColor: OcgColors.ivory,
            ),
            onPressed: () => popDialog(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar sesión. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(authNotifierProvider).isLoading;

    return OcgAdaptiveScaffold(
      selectedIndex: 0, // Dashboard = índice 0
      title: 'Dashboard',
      appBarActions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: loading ? null : () => _handleSignOut(context, ref),
          icon: const Icon(Icons.logout, color: OcgColors.error),
        ),
      ],
      railTrailing: OutlinedButton.icon(
        onPressed: loading ? null : () => _handleSignOut(context, ref),
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Cerrar sesión'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFD9D9),
          backgroundColor: OcgColors.error.withOpacity(0.14),
          side: BorderSide(color: const Color(0xFFFFD9D9).withOpacity(0.55)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      body: _DashboardBody(
        onSignOut: () => _handleSignOut(context, ref),
        loading: loading,
      ),
    );
  }
}

// ─── Cuerpo del dashboard ─────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.onSignOut, required this.loading});

  final VoidCallback onSignOut;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Saludo ─────────────────────────────────────────────────────────
          const Text(
            'Bienvenida, Dra.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Panel de administración OCG Clínica',
            style: TextStyle(
              fontSize: 14,
              color: OcgColors.ink.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 32),

          // ── Accesos rápidos ────────────────────────────────────────────────
          const Text(
            'Acceso rápido',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _QuickCard(
                    icon: Icons.people_outline,
                    label: 'Pacientes',
                    onTap: () => context.go(RouteNames.adminPatients),
                  ),
                  _QuickCard(
                    icon: Icons.calendar_month_outlined,
                    label: 'Agenda',
                    onTap: () => context.go(RouteNames.adminAppointments),
                  ),
                  _QuickCard(
                    icon: Icons.person_add_outlined,
                    label: 'Nuevo paciente',
                    onTap: () => context.go(RouteNames.adminPatients),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // ── Cerrar sesión (solo visible en móvil — en web está en el rail) ──
          const _SignOutButton(),
        ],
      ),
    );
  }
}

// ─── Tarjeta de acceso rápido ─────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OcgColors.ivory,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: OcgColors.bronze, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OcgColors.espresso,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Botón cerrar sesión (solo en móvil — el rail no tiene este botón) ────────

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo visible en pantallas pequeñas (el NavigationRail no lo muestra)
    if (MediaQuery.of(context).size.width > 800) return const SizedBox.shrink();

    final loading = ref.watch(authNotifierProvider).isLoading;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: loading
            ? null
            : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text('¿Deseas cerrar tu sesión de administrador?'),
                    actions: [
                      TextButton(
                        onPressed: () => popDialog(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: OcgColors.error,
                          foregroundColor: OcgColors.ivory,
                        ),
                        onPressed: () => popDialog(ctx, true),
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                try {
                  await ref.read(authNotifierProvider.notifier).signOut();
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No se pudo cerrar sesión.')),
                  );
                }
              },
        icon: const Icon(Icons.logout, color: OcgColors.error),
        label: const Text(
          'Cerrar sesión',
          style: TextStyle(color: OcgColors.error),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: OcgColors.error.withOpacity(0.08),
          side: BorderSide(color: OcgColors.error.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
