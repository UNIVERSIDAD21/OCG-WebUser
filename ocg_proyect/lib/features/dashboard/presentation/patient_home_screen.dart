import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/providers/patients_provider.dart';
import '../../patients/presentation/patient_profile_screen.dart';
import '../../payments/presentation/patient_payments_screen.dart';
import '../../simulator/presentation/patient_simulations_screen.dart';
import 'patient_appointments_screen.dart';
import '../../treatment/presentation/widgets/stage_history_list.dart';
import '../../treatment/presentation/widgets/treatment_progress_bar.dart';
import '../../treatment/presentation/widgets/treatment_timeline.dart';
import '../../treatment/providers/treatment_provider.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authNotifierProvider).isLoading;
    final user = ref.watch(authStateProvider).asData?.value;

    final sections = [
      _InicioSection(userId: user?.uid ?? ''),
      const PatientAppointmentsScreen(embedded: true),
      _TratamientoSection(userId: user?.uid ?? ''),
      const PatientPaymentsScreen(embedded: true),
      const PatientSimulationsScreen(embedded: true),
      const PatientProfileScreen(embedded: true),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCG Clínica'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: loading ? null : () => _handleSignOut(context),
            icon: const Icon(Icons.logout, color: OcgColors.error),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: sections,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: OcgColors.ivory,
        indicatorColor: OcgColors.sand,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Citas',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Tratamiento',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Pagos',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Simulaciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar tu sesión?'),
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
  }
}

class _InicioSection extends ConsumerWidget {
  const _InicioSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) return const SizedBox.shrink();

    final patientAsync = ref.watch(patientByIdProvider(userId));
    final user = ref.watch(authStateProvider).asData?.value;
    final nombre = user?.displayName ?? 'Paciente';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, $nombre 👋',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Bienvenido a tu panel de seguimiento',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OcgColors.ink.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
          patientAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const OcgEmptyState(
              icon: Icons.error_outline,
              title: 'No se pudo cargar tu información',
            ),
            data: (patient) {
              if (patient == null) {
                return const OcgEmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Perfil no encontrado',
                  subtitle: 'Contacta a la clínica para activar tu perfil.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu tratamiento',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TreatmentProgressBar(etapaActual: patient.etapaActual),
                  const SizedBox(height: 16),
                  if (patient.proximaCita != null) ...[
                    Text(
                      'Próxima cita',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.event, color: OcgColors.bronze),
                        title: Text(_formatDate(patient.proximaCita!)),
                        subtitle: const Text('Toca "Citas" para ver el detalle'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (patient.saldoPendiente > 0) ...[
                    Text(
                      'Estado de cuenta',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.account_balance_wallet_outlined, color: OcgColors.bronze),
                        title: Text(
                          'Saldo pendiente: \$${_formatCop(patient.saldoPendiente)} COP',
                        ),
                        subtitle: const Text('Toca "Pagos" para ver y pagar tu saldo'),
                        trailing: TextButton(
                          onPressed: () => context.go(RouteNames.patientPayments),
                          child: const Text('Ir a pagos'),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatCop(num value) {
    final digits = value.round().toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }
}

class _TratamientoSection extends ConsumerWidget {
  const _TratamientoSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) return const SizedBox.shrink();

    final patientAsync = ref.watch(patientByIdProvider(userId));
    final historyAsync = ref.watch(stageHistoryProvider(userId));

    return patientAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const OcgEmptyState(
        icon: Icons.error_outline,
        title: 'No se pudo cargar tu tratamiento',
      ),
      data: (patient) {
        if (patient == null) {
          return const OcgEmptyState(
            icon: Icons.medical_services_outlined,
            title: 'Sin tratamiento activo',
            subtitle: 'Contacta a la clínica para información.',
          );
        }
        return historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const OcgEmptyState(
            icon: Icons.error_outline,
            title: 'No se pudo cargar el historial',
          ),
          data: (historial) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mi tratamiento', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                TreatmentProgressBar(etapaActual: patient.etapaActual),
                const SizedBox(height: 24),
                TreatmentTimeline(
                  etapaActual: patient.etapaActual,
                  historial: historial,
                  isAdmin: false,
                  onAdvanceStage: null,
                ),
                const SizedBox(height: 20),
                Text('Historial', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                StageHistoryList(historial: historial, isAdmin: false),
              ],
            ),
          ),
        );
      },
    );
  }
}
