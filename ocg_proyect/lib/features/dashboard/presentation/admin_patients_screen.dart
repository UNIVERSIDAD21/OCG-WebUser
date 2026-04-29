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
import '../../admin/presentation/web/layout/admin_desktop_layout.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../../shared/widgets/ocg_chip.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notifications/providers/notifications_provider.dart';

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
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'El tratamiento se configurará después desde el perfil del paciente.',
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
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
                            );
                        ref.invalidate(patientsStreamProvider);
                        ref.invalidate(filteredPatientsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Paciente creado correctamente.'),
                            ),
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
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
                      } on FirebaseException catch (e) {
                        setDs(() {
                          submitting = false;
                          final code = e.code.toLowerCase();
                          formError =
                              code.contains('already') ||
                                  code.contains('in-use')
                              ? 'Este correo ya está en uso.'
                              : (e.message ??
                                    'No se pudo crear la cuenta. Intenta de nuevo.');
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

    final mobileBody = Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 12,
            16,
            14,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF21170F), OcgColors.espresso],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Pacientes',
                  style: TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _AdminMobileNotificationsAction(ref: ref),
              const SizedBox(width: 8),
              _AdminMobileProfileAction(ref: ref),
            ],
          ),
        ),
        Expanded(
          child: asyncPatients.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No se pudo cargar pacientes: $error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (_) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7D6C6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: Color(0xFF8A6F59),
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (value) => ref
                              .read(patientsSearchQueryProvider.notifier)
                              .setQuery(value),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Buscar por nombre o correo...',
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2EDE8),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.tune,
                          size: 16,
                          color: OcgColors.bronze,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 7),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final selected = filter == selectedFilter;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => ref
                            .read(patientsFilterProvider.notifier)
                            .setFilter(filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? OcgColors.espresso : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? OcgColors.espresso
                                  : const Color(0xFFE5D4C4),
                            ),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: selected
                                  ? OcgColors.ivory
                                  : const Color(0xFF8A6F59),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${filteredPatients.length} pacientes',
                  style: const TextStyle(
                    color: Color(0xFF8A6F59),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (filteredPatients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No hay pacientes para los filtros actuales.',
                      ),
                    ),
                  )
                else
                  ...filteredPatients.map(
                    (patient) => Padding(
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
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      final now = DateTime.now();
      final totalPacientes = filteredPatients.length;
      final pacientesActivos = filteredPatients
          .where((p) => p.etapaActual != TreatmentStage.alta)
          .length;
      final citasHoy = filteredPatients.where((p) {
        final cita = p.proximaCita;
        if (cita == null) return false;
        return cita.year == now.year &&
            cita.month == now.month &&
            cita.day == now.day;
      }).length;
      final saldoPendienteTotal = filteredPatients.fold<double>(
        0,
        (acc, p) => acc + p.saldoPendiente,
      );
      final nuevosMes = filteredPatients.where((p) {
        final created = p.createdAt;
        if (created == null) return false;
        return created.year == now.year && created.month == now.month;
      }).length;

      final layout = AdminDesktopLayoutScope.maybeOf(context);
      final tier = layout?.tier ?? AdminDesktopTier.standard;
      final sectionGap = layout?.sectionSpacing ?? 16;
      final panelGap = layout?.panelGap ?? 16;
      final headerTitleSize = switch (tier) {
        AdminDesktopTier.wide => 32.0,
        AdminDesktopTier.standard => 30.0,
        AdminDesktopTier.compact => 28.0,
        AdminDesktopTier.tight => 26.0,
      };

      final desktopContent = Padding(
        padding: EdgeInsets.only(bottom: sectionGap + 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pacientes',
                        style: TextStyle(
                          fontSize: headerTitleSize,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C2016),
                          letterSpacing: -0.3,
                          height: 1.05,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Gestión clínica y financiera',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9A735C),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2016),
                    foregroundColor: OcgColors.ivory,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => _showAddPatientDialog(context, ref),
                  icon: const Icon(
                    Icons.person_add_outlined,
                    size: 16,
                    color: Color(0xFFC9A882),
                  ),
                  label: const Text('Nuevo paciente'),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            _KpiRow(
              totalPacientes: totalPacientes,
              pacientesActivos: pacientesActivos,
              citasHoy: citasHoy,
              saldoPendienteTotal: saldoPendienteTotal,
              nuevosMes: nuevosMes,
              onTapTotal: () {
                ref.read(patientsFilterProvider.notifier).setFilter('Todos');
                context.go(RouteNames.adminPatients);
              },
              onTapActivos: () {
                ref.read(patientsFilterProvider.notifier).setFilter('Activos');
                context.go(RouteNames.adminPatients);
              },
              onTapCitasHoy: () => context.go(RouteNames.adminAppointments),
              onTapSaldoPendiente: () => context.go(RouteNames.adminPayments),
            ),
            SizedBox(height: panelGap),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: tier == AdminDesktopTier.tight ? 12 : 14,
                vertical: tier == AdminDesktopTier.tight ? 7 : 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Color(0xFFC9A882)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (value) => ref
                          .read(patientsSearchQueryProvider.notifier)
                          .setQuery(value),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Buscar en pacientes ...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8DDD2)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.tune, size: 14, color: Color(0xFF9A735C)),
                        SizedBox(width: 6),
                        Text(
                          'Filtros',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A735C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: panelGap * 0.75),
            Wrap(
              spacing: tier == AdminDesktopTier.tight ? 6 : 8,
              runSpacing: tier == AdminDesktopTier.tight ? 6 : 8,
              children: _filters.map((filter) {
                final selected = filter == selectedFilter;
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => ref
                      .read(patientsFilterProvider.notifier)
                      .setFilter(filter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2C2016)
                          : const Color(0xFFF8F5F0),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF2C2016)
                            : const Color(0xFFE8DDD2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(
                            Icons.check_circle,
                            size: 12,
                            color: OcgColors.ivory,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          filter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? OcgColors.ivory
                                : const Color(0xFF7E6A5B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: panelGap),
            Row(
              children: [
                const Text(
                  'Listado de pacientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C2016),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EFE7),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFFE2D0BC)),
                  ),
                  child: Text(
                    '${filteredPatients.length} registros',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9A735C),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: panelGap * 0.75),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              padding: EdgeInsets.all(tier == AdminDesktopTier.tight ? 12 : 14),
              child: filteredPatients.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No hay pacientes para los filtros actuales.',
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < filteredPatients.length; i++) ...[
                          _DesktopPatientRow(
                            patient: filteredPatients[i],
                            selected: false,
                            onTap: () => context.go(
                              RouteNames.adminPatientDetail.replaceFirst(
                                ':patientId',
                                filteredPatients[i].id,
                              ),
                            ),
                          ),
                          if (i != filteredPatients.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      );

      return AdminWebShell(title: 'Pacientes', child: desktopContent);
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 1, // Pacientes = índice 1
      title: 'Pacientes',
      showMobileAppBar: false,
      appBarActions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: loading ? null : () => _handleSignOut(context, ref),
          icon: const Icon(Icons.logout, color: OcgColors.error),
        ),
      ],
      onSignOut: () => _handleSignOut(context, ref),
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
      body: mobileBody,
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

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.totalPacientes,
    required this.pacientesActivos,
    required this.citasHoy,
    required this.saldoPendienteTotal,
    required this.nuevosMes,
    required this.onTapTotal,
    required this.onTapActivos,
    required this.onTapCitasHoy,
    required this.onTapSaldoPendiente,
  });

  final int totalPacientes;
  final int pacientesActivos;
  final int citasHoy;
  final double saldoPendienteTotal;
  final int nuevosMes;
  final VoidCallback onTapTotal;
  final VoidCallback onTapActivos;
  final VoidCallback onTapCitasHoy;
  final VoidCallback onTapSaldoPendiente;

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.maybeOf(context);
    final tier = layout?.tier ?? AdminDesktopTier.standard;
    final spacing = layout?.panelGap ?? 10;
    final cardWidth = switch (tier) {
      AdminDesktopTier.wide => 260.0,
      AdminDesktopTier.standard => 245.0,
      AdminDesktopTier.compact => 228.0,
      AdminDesktopTier.tight => 210.0,
    };

    final cards = [
      _KpiCard(
        icon: Icons.people_outline,
        value: '$totalPacientes',
        label: 'Total pacientes',
        footer: '+$nuevosMes este mes',
        footerColor: const Color(0xFF2E7D32),
        footerBg: const Color(0xFFE8F5E9),
        bgColor: const Color(0xFFF6EFE7),
        onTap: onTapTotal,
      ),
      _KpiCard(
        icon: Icons.timelapse_outlined,
        value: '$pacientesActivos',
        label: 'Activos',
        footer: 'en tratamiento',
        bgColor: const Color(0xFFEFF8F0),
        onTap: onTapActivos,
      ),
      _KpiCard(
        icon: Icons.calendar_month_outlined,
        value: '$citasHoy',
        label: 'Citas hoy',
        footer: 'programadas',
        bgColor: const Color(0xFFFFF4D8),
        onTap: onTapCitasHoy,
      ),
      _KpiCard(
        icon: Icons.attach_money,
        value: '\$${formatCop(saldoPendienteTotal)}',
        label: 'Saldo pendiente',
        footer: 'por cobrar',
        bgColor: const Color(0xFFFFECEC),
        onTap: onTapSaldoPendiente,
      ),
    ];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: (context, index) =>
            SizedBox(width: cardWidth, child: cards[index]),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    this.footer,
    this.footerColor,
    this.footerBg,
    this.bgColor,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? footer;
  final Color? footerColor;
  final Color? footerBg;
  final Color? bgColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AdminDesktopLayoutScope.maybeOf(context);
        final tier = layout?.tier ?? AdminDesktopTier.standard;
        final compact =
            tier == AdminDesktopTier.compact || tier == AdminDesktopTier.tight;
        final base = bgColor ?? OcgColors.ivory;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base, Color.lerp(base, Colors.white, 0.35)!],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6D8CB), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x142C2016),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 12,
              compact ? 8 : 10,
              compact ? 10 : 12,
              compact ? 8 : 10,
            ),
            child: Stack(
              children: [
                if (tier != AdminDesktopTier.tight)
                  Positioned(
                    top: -16,
                    right: -16,
                    child: Container(
                      width: compact ? 40 : 48,
                      height: compact ? 40 : 48,
                      decoration: BoxDecoration(
                        color: OcgColors.ivory.withOpacity(0.28),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compact ? 22 : 26,
                          height: compact ? 22 : 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x1A2C2016)),
                          ),
                          child: Icon(
                            icon,
                            size: compact ? 12 : 14,
                            color: const Color(0xFF9A735C),
                          ),
                        ),
                        const Spacer(),
                        if (tier != AdminDesktopTier.tight)
                          Container(
                            width: 18,
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0x409A735C),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 5 : 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: compact ? 16 : 21,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2C2016),
                                    letterSpacing: -0.4,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 2 : 4),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 10 : 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2C2016),
                            ),
                          ),
                          if (footer != null &&
                              footer!.trim().isNotEmpty &&
                              tier != AdminDesktopTier.tight)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                footer!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: compact ? 9 : 9.5,
                                  color: const Color(0xFF9A735C),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopPatientRow extends StatelessWidget {
  const _DesktopPatientRow({
    required this.patient,
    required this.onTap,
    this.selected = false,
  });

  final PatientModel patient;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final stage = formatTreatmentStage(patient.etapaActual);
    final stageLower = stage.toLowerCase();
    final stageBg = stageLower.contains('valor')
        ? const Color(0xFFFFF3E0)
        : stageLower.contains('alta') || stageLower.contains('reten')
        ? const Color(0xFFE8F5E9)
        : OcgColors.mist;
    final stageFg = stageLower.contains('valor')
        ? const Color(0xFFE65100)
        : stageLower.contains('alta') || stageLower.contains('reten')
        ? const Color(0xFF2E7D32)
        : OcgColors.ink;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: OcgColors.ivory,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? OcgColors.bronze : OcgColors.sand,
            width: selected ? 1.3 : .7,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: OcgColors.bronze.withOpacity(.15),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: OcgColors.bronze.withOpacity(0.16),
              child: Text(
                _initialsFromName(patient.nombre),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: OcgColors.espresso,
                    ),
                  ),
                  Text(
                    patient.email,
                    style: TextStyle(
                      fontSize: 11,
                      color: OcgColors.ink.withOpacity(.55),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      OcgChip(
                        label: patient.tipoTratamiento?.name ?? 'Pendiente',
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: stageBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stage,
                          style: TextStyle(
                            fontSize: 10,
                            color: stageFg,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${formatCop(patient.saldoPendiente)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: OcgColors.espresso,
                  ),
                ),
                Text(
                  patient.proximaCita == null
                      ? 'Sin cita'
                      : _fmtDate(patient.proximaCita!),
                  style: TextStyle(
                    fontSize: 11,
                    color: OcgColors.ink.withOpacity(.5),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5F0),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              child: const Icon(
                Icons.chevron_right,
                color: OcgColors.bronze,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPatientsDesktopTestHarness extends StatelessWidget {
  const AdminPatientsDesktopTestHarness({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.maybeOf(context);
    final tier = layout?.tier ?? AdminDesktopTier.standard;
    final sectionGap = layout?.sectionSpacing ?? 16;
    final panelGap = layout?.panelGap ?? 16;
    final headerTitleSize = switch (tier) {
      AdminDesktopTier.wide => 32.0,
      AdminDesktopTier.standard => 30.0,
      AdminDesktopTier.compact => 28.0,
      AdminDesktopTier.tight => 26.0,
    };

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(bottom: sectionGap + 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pacientes',
                        style: TextStyle(
                          fontSize: headerTitleSize,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2C2016),
                          letterSpacing: -0.3,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gestión clínica y financiera',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9A735C),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Nuevo paciente'),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            _KpiRow(
              totalPacientes: 18,
              pacientesActivos: 12,
              citasHoy: 5,
              saldoPendienteTotal: 12500000,
              nuevosMes: 3,
              onTapTotal: () {},
              onTapActivos: () {},
              onTapCitasHoy: () {},
              onTapSaldoPendiente: () {},
            ),
            SizedBox(height: panelGap),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: tier == AdminDesktopTier.tight ? 12 : 14,
                vertical: tier == AdminDesktopTier.tight ? 7 : 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, size: 16, color: Color(0xFFC9A882)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Buscar en pacientes ...')),
                ],
              ),
            ),
            SizedBox(height: panelGap),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              padding: EdgeInsets.all(tier == AdminDesktopTier.tight ? 12 : 14),
              child: const Column(
                children: [
                  ListTile(title: Text('Paciente demo 1')),
                  SizedBox(height: 8),
                  ListTile(title: Text('Paciente demo 2')),
                ],
              ),
            ),
          ],
        ),
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
    final avatarTones = const [
      Color(0xFFF3E7DA),
      Color(0xFFEFE7F7),
      Color(0xFFE5F3EA),
      Color(0xFFF6EBD7),
      Color(0xFFE4EDF9),
    ];
    final avatarBg =
        avatarTones[patient.id.hashCode.abs() % avatarTones.length];

    final treatmentLabel = patient.tipoTratamiento == null
        ? 'Pendiente'
        : _tipoTratamientoLabel(patient.tipoTratamiento!);
    final stageLabel = formatTreatmentStage(patient.etapaActual);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7D6C6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x122C2016),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: avatarBg,
              backgroundImage: hasPhoto ? NetworkImage(patient.fotoUrl!) : null,
              onBackgroundImageError: hasPhoto ? (_, _) {} : null,
              child: hasPhoto
                  ? null
                  : Text(
                      initials,
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: OcgColors.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    patient.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.2,
                      color: Color(0xFF8A6F59),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2EDE8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          treatmentLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: OcgColors.espresso,
                          ),
                        ),
                      ),
                      const Text(
                        '·',
                        style: TextStyle(color: Color(0xFF8A6F59)),
                      ),
                      Text(
                        stageLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF8A6F59),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFB59D87), size: 20),
          ],
        ),
      ),
    );
  }
}

class _AdminMobileNotificationsAction extends ConsumerWidget {
  const _AdminMobileNotificationsAction({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final user = ref.watch(authStateProvider).asData?.value;
    final unread = user == null
        ? 0
        : ref.watch(unreadNotificationsCountProvider(user.uid));

    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () => context.push(RouteNames.adminNotifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: OcgColors.ivory),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: OcgColors.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminMobileProfileAction extends ConsumerWidget {
  const _AdminMobileProfileAction({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final user = ref.watch(authStateProvider).asData?.value;
    final initials = _adminProfileInitials(user?.displayName, user?.email);

    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: () => context.go(RouteNames.adminProfile),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: OcgColors.bronze,
          shape: BoxShape.circle,
        ),
        child: Text(
          initials,
          style: const TextStyle(
            color: OcgColors.ivory,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}

String _adminProfileInitials(String? displayName, String? email) {
  final source = (displayName?.trim().isNotEmpty == true)
      ? displayName!.trim()
      : (email?.trim().isNotEmpty == true ? email!.trim() : 'Administrador');
  final parts = source.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'AD';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String _tipoTratamientoLabel(TreatmentType value) => switch (value) {
  TreatmentType.convencional => 'Convencional',
  TreatmentType.estetico => 'Brackets Estéticos',
  TreatmentType.autoligado => 'Autoligado',
  TreatmentType.alineadores => 'Alineadores',
  TreatmentType.ortopedia => 'Ortopedia',
  TreatmentType.retenedores => 'Retenedores',
  TreatmentType.interceptivo => 'Interceptivo',
};
