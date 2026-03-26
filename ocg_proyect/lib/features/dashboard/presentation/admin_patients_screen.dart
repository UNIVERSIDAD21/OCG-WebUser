import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../admin/presentation/web/components/filter_bar.dart';
import '../../admin/presentation/web/components/data_table_card.dart';
import '../../admin/presentation/web/components/page_header.dart';
import '../../admin/presentation/web/components/status_badge.dart';
import '../../admin/presentation/web/components/action_toolbar.dart';
import '../../admin/presentation/web/components/section_panel.dart';
import '../../../shared/widgets/ocg_card.dart';
import '../../../shared/widgets/ocg_chip.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../auth/providers/auth_providers.dart';

class AdminPatientsScreen extends ConsumerWidget {
  const AdminPatientsScreen({super.key});

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
    final formKey = GlobalKey<FormState>();
    String fullName = '';
    String email = '';
    String password = '';
    String confirmPassword = '';
    TreatmentType treatmentType = TreatmentType.convencional;
    final totalTreatmentCtrl = TextEditingController();
    bool submitting = false;
    String? formError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDs) => AlertDialog(
          title: const Text('Agregar paciente'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: Validators.fullName,
                    onSaved: (v) => fullName = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: Validators.email,
                    onSaved: (v) => email = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña temporal',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: Validators.passwordForRegister,
                    onChanged: (v) => password = v,
                    onSaved: (v) => password = v ?? '',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => Validators.confirmPassword(v, password),
                    onChanged: (v) => confirmPassword = v,
                    onSaved: (v) => confirmPassword = v ?? '',
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<TreatmentType>(
                    initialValue: treatmentType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de tratamiento',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                    items: TreatmentType.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDs(() => treatmentType = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: totalTreatmentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto total del tratamiento (COP)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (v) {
                      final raw = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                      if (raw.isEmpty)
                        return 'Ingresa el monto del tratamiento';
                      final amount = double.tryParse(raw) ?? 0;
                      if (amount <= 0) return 'El monto debe ser mayor que 0';
                      return null;
                    },
                    onChanged: (value) {
                      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.isEmpty) return;
                      final formatted = formatCop(double.parse(digits));
                      if (formatted == totalTreatmentCtrl.text) return;
                      totalTreatmentCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    },
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      formError!,
                      style: const TextStyle(
                        color: OcgColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      formKey.currentState!.save();

                      if (confirmPassword != password) {
                        setDs(() => formError = 'Las contraseñas no coinciden');
                        return;
                      }

                      final amountRaw = totalTreatmentCtrl.text.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      final totalTreatment = double.tryParse(amountRaw) ?? 0;

                      setDs(() {
                        submitting = true;
                        formError = null;
                      });

                      try {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .createPatientByAdmin(
                              email: email,
                              password: password,
                              displayName: fullName,
                              treatmentType: treatmentType.name,
                              totalTreatment: totalTreatment,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Paciente creado correctamente.'),
                            ),
                          );
                        }
                        if (dialogContext.mounted)
                          Navigator.of(dialogContext).pop();
                      } on FirebaseAuthException catch (e) {
                        setDs(() {
                          submitting = false;
                          formError = e.code == 'email-already-in-use'
                              ? 'Este correo ya está en uso.'
                              : 'No se pudo crear la cuenta [${e.code}].';
                        });
                      } on FirebaseFunctionsException catch (e) {
                        setDs(() {
                          submitting = false;
                          formError = e.code == 'already-exists'
                              ? 'Este correo ya está en uso.'
                              : (e.message ?? 'No se pudo crear la cuenta.');
                        });
                      } catch (_) {
                        setDs(() {
                          submitting = false;
                          formError =
                              'No se pudo crear la cuenta. Intenta de nuevo.';
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear cuenta'),
            ),
          ],
        ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: FilterBar(
            hintText: 'Buscar por nombre o correo…',
            onSearch: (value) =>
                ref.read(patientsSearchQueryProvider.notifier).setQuery(value),
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

    if (WebLayoutContext.useDesktopShell(context)) {
      final desktopRows = filteredPatients.map((patient) {
        final stage = formatTreatmentStage(patient.etapaActual);
        final stageLower = stage.toLowerCase();
        final stageBg =
            stageLower.contains('final') || stageLower.contains('reten')
            ? const Color(0xFFE7F6EC)
            : stageLower.contains('valor')
            ? const Color(0xFFFFF3E5)
            : OcgColors.sand;
        final stageFg =
            stageLower.contains('final') || stageLower.contains('reten')
            ? const Color(0xFF1B5E20)
            : stageLower.contains('valor')
            ? const Color(0xFF8A4B00)
            : OcgColors.espresso;

        return DataRow(
          cells: [
            DataCell(
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.go(
                  RouteNames.adminPatientDetail.replaceFirst(
                    ':patientId',
                    patient.id,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: OcgColors.bronze.withOpacity(0.16),
                        child: Text(
                          _initialsFromName(patient.nombre),
                          style: const TextStyle(
                            fontSize: 11,
                            color: OcgColors.espresso,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          patient.nombre,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                            color: OcgColors.espresso,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            DataCell(Text(patient.tipoTratamiento?.name ?? 'Pendiente')),
            DataCell(
              StatusBadge(
                label: stage,
                background: stageBg,
                foreground: stageFg,
              ),
            ),
            DataCell(
              Text(
                patient.proximaCita == null
                    ? 'Sin cita'
                    : _fmtDate(patient.proximaCita!),
              ),
            ),
            DataCell(Text('\$${formatCop(patient.saldoPendiente)}')),
          ],
        );
      }).toList();

      final desktopContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Pacientes',
            subtitle: 'Gestión clínica y financiera de pacientes',
            trailing: ActionToolbar(
              actions: [
                FilledButton.icon(
                  onPressed: () => _showAddPatientDialog(context, ref),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Nuevo paciente'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilterBar(
            hintText: 'Buscar por nombre o correo…',
            onSearch: (value) =>
                ref.read(patientsSearchQueryProvider.notifier).setQuery(value),
          ),
          const SizedBox(height: 12),
          SectionPanel(
            title: 'Listado de pacientes',
            child: DataTableCard(
              columns: const [
                DataColumn(label: Text('Paciente')),
                DataColumn(label: Text('Tratamiento')),
                DataColumn(label: Text('Etapa')),
                DataColumn(label: Text('Próxima cita')),
                DataColumn(label: Text('Saldo')),
              ],
              rows: desktopRows,
            ),
          ),
        ],
      );

      return AdminWebShell(title: 'Pacientes', child: desktopContent);
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 1, // Pacientes = índice 1
      title: 'Pacientes',
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
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

String _fmtDate(DateTime value) {
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  return '$d/$m/${value.year}';
}

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
              onBackgroundImageError: hasPhoto ? (_, _) {} : null,
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
                      OcgChip(label: formatTreatmentStage(patient.etapaActual)),
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
