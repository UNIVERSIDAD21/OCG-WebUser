import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_card.dart';
import '../../../shared/widgets/ocg_chip.dart';

class AdminPatientsScreen extends ConsumerWidget {
  const AdminPatientsScreen({super.key});

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

  static Future<void> _showAddPatientDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar paciente'),
        content: const Text(
          'Para agregar un paciente, el paciente debe crear su cuenta desde la pantalla de login. '
          'Una vez registrado, aparecerá aquí para completar sus datos clínicos.',
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
    final filteredPatients = ref.watch(filteredPatientsProvider);
    final selectedFilter = ref.watch(patientsFilterProvider);


    return Scaffold(
      appBar: AppBar(
        title: const Text('Pacientes'),
      ),
      body: Column(
        children: [
          if (kDebugMode)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OcgColors.bronze.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OcgColors.bronze.withValues(alpha: 0.28)),
              ),
              child: Text(
                'DEBUG build=01d88ee total=${asyncPatients.asData?.value.length ?? 0} '
                'filtrados=${filteredPatients.length} filtro=$selectedFilter',
                style: const TextStyle(fontSize: 12, color: OcgColors.espresso),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (value) => ref.read(patientsSearchQueryProvider.notifier).setQuery(value),
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
                  onSelected: (_) => ref.read(patientsFilterProvider.notifier).setFilter(filter),
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
                  return const Center(child: Text('No hay pacientes para los filtros actuales.'));
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
                        onTap: () => context.go(RouteNames.adminPatientDetail.replaceFirst(':patientId', patient.id)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPatientDialog(context, ref),
        backgroundColor: OcgColors.bronze,
        child: const Icon(Icons.person_add),
      ),
    );
  }
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
              backgroundColor: OcgColors.bronze.withValues(alpha: 0.18),
              backgroundImage: hasPhoto ? NetworkImage(patient.fotoUrl!) : null,
              onBackgroundImageError: hasPhoto ? (_, error) {} : null,
              child: hasPhoto
                  ? null
                  : Text(
                      initials,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        color: OcgColors.espresso,
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
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: OcgColors.espresso,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patient.email,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: OcgColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OcgChip(label: patient.tipoTratamiento?.name ?? 'Pendiente'),
                      OcgChip(label: patient.etapaActual.name),
                    ],
                  ),
                  if (patient.proximaCita != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 13, color: OcgColors.bronze),
                        const SizedBox(width: 4),
                        Text(
                          _fmtDate(patient.proximaCita!),
                          style: const TextStyle(fontSize: 12, color: OcgColors.bronze),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Sin cita programada',
                      style: TextStyle(fontSize: 12, color: OcgColors.ink),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }


  String _initialsFromName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  String _fmtDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
