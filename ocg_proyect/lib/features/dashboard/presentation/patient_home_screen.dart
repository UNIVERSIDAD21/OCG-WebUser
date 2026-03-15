import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/providers/patients_provider.dart';
import '../../treatment/presentation/widgets/treatment_progress_bar.dart';
import '../../treatment/presentation/widgets/treatment_timeline.dart';
import '../../treatment/providers/treatment_provider.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
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
        const SnackBar(content: Text('No se pudo cerrar sesión. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(authNotifierProvider).isLoading;
    final user = ref.watch(authStateProvider).asData?.value;

    final patientAsync = user == null
        ? const AsyncValue<Never>.loading()
        : ref.watch(patientByIdProvider(user.uid));

    final historyAsync = user == null
        ? const AsyncValue<Never>.loading()
        : ref.watch(stageHistoryProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Home'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: loading ? null : () => _handleSignOut(context, ref),
            icon: const Icon(Icons.logout, color: OcgColors.error),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aqui es el dashboard principal para que el paciente vea información relevante, como próximas citas, estado de tratamientos, etc.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.go(RouteNames.patientProfile),
                icon: const Icon(Icons.person),
                label: const Text('Ver mi perfil'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go(RouteNames.patientAppointments),
                icon: const Icon(Icons.event_note),
                label: const Text('Ver mis citas'),
              ),
              const SizedBox(height: 24),
              patientAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => OcgEmptyState(
                  icon: Icons.error_outline,
                  title: 'No se pudo cargar tu tratamiento',
                  subtitle: '$error',
                ),
                data: (patient) {
                  if (patient == null) {
                    return const OcgEmptyState(
                      icon: Icons.person_off,
                      title: 'No encontramos tu perfil de paciente.',
                    );
                  }

                  return historyAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => OcgEmptyState(
                      icon: Icons.error_outline,
                      title: 'No se pudo cargar tu historial',
                      subtitle: '$error',
                    ),
                    data: (historial) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TreatmentProgressBar(etapaActual: patient.etapaActual),
                        const SizedBox(height: 16),
                        TreatmentTimeline(
                          etapaActual: patient.etapaActual,
                          historial: historial,
                          isAdmin: false,
                          onAdvanceStage: null,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
