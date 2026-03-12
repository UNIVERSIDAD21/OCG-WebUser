import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../shared/widgets/ocg_card.dart';
import '../../../shared/widgets/ocg_chip.dart';
import '../../auth/providers/auth_providers.dart';

class AdminPatientsScreen extends ConsumerWidget {
  const AdminPatientsScreen({super.key});

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
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

  static const _filters = <String>[
    'Todos',
    'Pendientes',
    'Activos',
    'Alta',
    'Convencional',
    'Estetico',
    'Autoligado',
    'Alineadores',
    'Ortopedia',
    'Retenedores',
  ];

  static Future<void> _showAddPatientDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar paciente'),
        content: const Text(
          'Para agregar un paciente, el paciente debe crear su cuenta desde '
          'la pantalla de login. Una vez registrado, aparecerá aquí para '
          'completar sus datos clínicos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(patientsFilterProvider.notifier).setFilter('Pendientes');
              Navigator.of(context).pop();
            },
            child: const Text('Ver pendientes de completar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPatients = ref.watch(patientsStreamProvider);
    final loading = ref.watch(authNotifierProvider).isLoading;
    final filteredPatients = ref.watch(filteredPatientsProvider);
    final selectedFilter = ref.watch(patientsFilterProvider);

    final body = Column(
      children: [
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (value) => ref
                  .read(patientsSearchQueryProvider.notifier)
                  .setQuery(value),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o correo…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final selected = filter == selectedFilter;
              return ChoiceChip(
                label: Text(filter),
                selected: selected,
                onSelected: (_) =>
                    ref.read(patientsFilterProvider.notifier).setFilter(filter),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemCount: _filters.length,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: asyncPatients.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'No se pudo cargar pacientes: $error',
                textAlign: TextAlign.center,
              ),
            ),
            data: (_) {
              if (filteredPatients.isEmpty) {
                return const Center(
                  child: Text('No hay pacientes para los filtros actuales.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filteredPatients.length,
                itemBuilder: (context, index) {
                  final patient = filteredPatients[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PatientCard(
                      patient: patient,
                      onTap: () => context.go(
                        RouteNames.adminPatientDetail.replaceFirst(
                          ':patientId',
                          patient.id,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    // ✅ OcgAdaptiveScaffold: NavigationRail en web > 800px, AppBar en móvil
    return OcgAdaptiveScaffold(
      selectedIndex: 1, // Pacientes = índice 1
      title: 'Pacientes',
      appBarActions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: loading ? null : () => _handleSignOut(context, ref),
          icon: const Icon(Icons.logout),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPatientDialog(context, ref),
        backgroundColor: OcgColors.bronze,
        child: const Icon(Icons.person_add),
      ),
      body: body,
    );
  }
}

// ─── _PatientCard ─────────────────────────────────────────────────────────────

String _initialsFromName(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient, required this.onTap});

  final PatientModel patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromName(patient.nombre);
    final hasPhoto = patient.fotoUrl != null && patient.fotoUrl!.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: OcgCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: OcgColors.bronze.withOpacity(0.18),
              backgroundImage: hasPhoto ? NetworkImage(patient.fotoUrl!) : null,
              onBackgroundImageError: hasPhoto ? (_, __) {} : null,
              child: hasPhoto
                  ? null
                  : Text(
                      initials,
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    patient.email,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      OcgChip(
                        label: patient.tipoTratamiento?.name ?? 'Pendiente',
                      ),
                      OcgChip(label: patient.etapaActual.name),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: OcgColors.bronze),
          ],
        ),
      ),
    );
  }
}
