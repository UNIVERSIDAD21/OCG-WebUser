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
    'Activos',
    'Alta',
    'Convencional',
    'Estetico',
    'Autoligado',
    'Alineadores',
    'Ortopedia',
    'Retenedores',
  ];

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
        onPressed: () => context.go(RouteNames.adminPatientNew),
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
    final initial = patient.nombre.isNotEmpty ? patient.nombre[0].toUpperCase() : '?';
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
                      initial,
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
                      OcgChip(label: patient.tipoTratamiento.name),
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

  String _fmtDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
