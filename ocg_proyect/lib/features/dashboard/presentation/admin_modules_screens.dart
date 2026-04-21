import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../admin/presentation/web/layout/admin_desktop_layout.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../payments/data/models/admin_payment_overview.dart';
import '../../payments/providers/payments_provider.dart';
import '../../treatment/data/models/patient_treatment.dart';
import '../../treatment/providers/patient_treatments_provider.dart';

Future<void> _signOutAdminModules(BuildContext context, WidgetRef ref) async {
  await ref.read(authServiceProvider).signOut();
  if (context.mounted) context.go(RouteNames.login);
}

OutlinedButton _buildRailSignOutButton(BuildContext context, WidgetRef ref) {
  return OutlinedButton.icon(
    onPressed: () => _signOutAdminModules(context, ref),
    icon: const Icon(Icons.logout, size: 18),
    label: const Text('Cerrar sesión'),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFFFD9D9),
      backgroundColor: OcgColors.error.withOpacity(0.14),
      side: BorderSide(color: const Color(0xFFFFD9D9).withOpacity(0.55)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class AdminTreatmentsScreen extends ConsumerWidget {
  const AdminTreatmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsStreamProvider);
    final isDesktop = WebLayoutContext.useDesktopShell(context);

    Widget body = patientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('No se pudieron cargar tratamientos: $e')),
      data: (patients) {
        final treatmentEntries = <_TreatmentAdminEntry>[];
        for (final patient in patients) {
          final treatments = ref.watch(
            effectivePatientTreatmentsProvider((
              patientId: patient.id,
              patient: patient,
            )),
          );
          if (treatments.isEmpty) {
            treatmentEntries.add(_TreatmentAdminEntry.fromLegacy(patient));
            continue;
          }
          for (final treatment in treatments) {
            treatmentEntries.add(
              _TreatmentAdminEntry(patient: patient, treatment: treatment),
            );
          }
        }

        final byStage = <TreatmentStage, int>{
          for (final stage in TreatmentStage.values)
            stage: treatmentEntries
                .where((entry) => entry.treatment.etapaActual == stage)
                .length,
        };

        final activeEntries =
            treatmentEntries
                .where((entry) => !entry.treatment.isFinished)
                .toList()
              ..sort(
                (a, b) => a.patient.nombre.toLowerCase().compareTo(
                  b.patient.nombre.toLowerCase(),
                ),
              );

        return _UnifiedTreatmentsView(
          patients: patients,
          entries: treatmentEntries,
          activeEntries: activeEntries,
          byStage: byStage,
        );
      },
    );

    if (isDesktop) {
      return AdminWebShell(title: 'Tratamientos', child: body);
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 3,
      title: 'Tratamientos',
      showMobileAppBar: false,
      onSignOut: () => _signOutAdminModules(context, ref),
      appBarActions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: () => _signOutAdminModules(context, ref),
          icon: const Icon(Icons.logout, color: OcgColors.error),
        ),
      ],
      railTrailing: _buildRailSignOutButton(context, ref),
      body: body,
    );
  }
}

class AdminPaymentsScreen extends ConsumerWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(adminPaymentsOverviewProvider);
    final isDesktop = WebLayoutContext.useDesktopShell(context);

    Widget body = overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('No se pudieron cargar pagos: $e')),
      data: (overview) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        if (!isDesktop) {
          final withDebt = overview.entries
              .where((entry) => entry.saldoPendiente > 0)
              .map((entry) => entry.patient)
              .toList();
          final overdue = overview.overdueEntries
              .map((entry) => entry.patient)
              .toList();
          return _MobilePaymentsAdminView(
            withDebt: withDebt,
            overdue: overdue,
            totalDebt: overview.totalDebt,
          );
        }

        return _WebPaymentsView(overview: overview, today: today);
      },
    );

    if (isDesktop) {
      return AdminWebShell(title: 'Pagos', child: body);
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 4,
      title: 'Pagos',
      showMobileAppBar: false,
      onSignOut: () => _signOutAdminModules(context, ref),
      appBarActions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: () => _signOutAdminModules(context, ref),
          icon: const Icon(Icons.logout, color: OcgColors.error),
        ),
      ],
      railTrailing: _buildRailSignOutButton(context, ref),
      body: body,
    );
  }
}

class _WebPaymentsView extends StatefulWidget {
  const _WebPaymentsView({required this.overview, required this.today});

  final AdminPaymentsOverview overview;
  final DateTime today;

  @override
  State<_WebPaymentsView> createState() => _WebPaymentsViewState();
}

class _WebPaymentsViewState extends State<_WebPaymentsView> {
  AdminPaymentsFilter selectedFilter = AdminPaymentsFilter.todos;

  void _goToRegisterPayment(BuildContext context) {
    context.go(RouteNames.adminPatients);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.maybeOf(context);
    final tier = layout?.tier ?? AdminDesktopTier.standard;
    final sectionGap = layout?.sectionSpacing ?? 16;
    final panelGap = layout?.panelGap ?? 12;
    final titleSize = switch (tier) {
      AdminDesktopTier.wide => 46.0,
      AdminDesktopTier.standard => 42.0,
      AdminDesktopTier.compact => 36.0,
      AdminDesktopTier.tight => 32.0,
    };
    final shouldSplit =
        layout?.shouldKeepSplit(primaryMinWidth: 360, secondaryMinWidth: 320) ??
        true;
    final history = widget.overview.historyForFilter(selectedFilter);

    final recoveredTotal = widget.overview.entries.fold<double>(
      0,
      (sum, entry) => sum + entry.totalPaid,
    );
    final paidThisMonth = widget.overview.transactionsThisMonth;

    final recentIncome = widget.overview.recentIncomeEntries;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagos',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C2016),
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Control financiero y facturación',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9A735C)),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _goToRegisterPayment(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C2016),
                  foregroundColor: OcgColors.ivory,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.add, size: 16, color: Color(0xFFC9A882)),
                label: const Text('Registrar pago'),
              ),
            ],
          ),
          SizedBox(height: sectionGap),
          _PaymentsKpiGrid(
            totalDebt: widget.overview.totalDebt,
            recoveredTotal: recoveredTotal,
            paidThisMonth: paidThisMonth,
            overdueCount: widget.overview.overdueEntries.length,
          ),
          SizedBox(height: sectionGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final ingresosCard = Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8DDD2)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MobileSectionHeader(title: 'Ingresos recientes'),
                    const SizedBox(height: 10),
                    ...recentIncome.take(3).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PaymentsCompactRow(
                          entry: entry,
                          onTap: () => context.go(
                            RouteNames.adminPatientDetail.replaceFirst(
                              ':patientId',
                              entry.patient.id,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );

              final alertsCard = Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8DDD2)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MobileSectionHeader(title: 'Alertas de cobro'),
                    const SizedBox(height: 10),
                    ...widget.overview.overdueEntries
                        .take(3)
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _PaymentsCompactRow(
                              entry: entry,
                              emphasizeDebt: true,
                              onTap: () => context.go(
                                RouteNames.adminPatientDetail.replaceFirst(
                                  ':patientId',
                                  entry.patient.id,
                                ),
                              ),
                            ),
                          ),
                        ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Total pendiente',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7E6A5B),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '\$${formatCop(widget.overview.totalDebt)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB06A5A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              if (!shouldSplit) {
                return Column(
                  children: [
                    ingresosCard,
                    SizedBox(height: panelGap),
                    alertsCard,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: ingresosCard),
                  SizedBox(width: panelGap),
                  Expanded(child: alertsCard),
                ],
              );
            },
          ),
          SizedBox(height: sectionGap),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
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
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Buscar pagos, pacientes o facturas...',
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
            children: [
              _TreatmentChip(
                label: 'Todos',
                selected: selectedFilter == AdminPaymentsFilter.todos,
                onTap: () =>
                    setState(() => selectedFilter = AdminPaymentsFilter.todos),
              ),
              _TreatmentChip(
                label: 'Vencido',
                selected: selectedFilter == AdminPaymentsFilter.vencido,
                onTap: () => setState(
                  () => selectedFilter = AdminPaymentsFilter.vencido,
                ),
              ),
              _TreatmentChip(
                label: 'Pagado',
                selected: selectedFilter == AdminPaymentsFilter.pagado,
                onTap: () =>
                    setState(() => selectedFilter = AdminPaymentsFilter.pagado),
              ),
              _TreatmentChip(
                label: 'Pendiente',
                selected: selectedFilter == AdminPaymentsFilter.pendiente,
                onTap: () => setState(
                  () => selectedFilter = AdminPaymentsFilter.pendiente,
                ),
              ),
            ],
          ),
          SizedBox(height: sectionGap),
          Row(
            children: [
              const Text(
                'Historial de pagos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2016),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EFE7),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFE2D0BC)),
                ),
                child: Text(
                  '${history.length} transacciones',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9A735C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8DDD2)),
            ),
            padding: const EdgeInsets.all(14),
            child: history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No hay pagos para los filtros actuales.'),
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Paciente / Concepto',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9A735C),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Fecha',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9A735C),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Monto',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9A735C),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  'Estado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9A735C),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  'Método',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9A735C),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < history.length && i < 8; i++) ...[
                        _PaymentsHistoryRow(
                          item: history[i],
                          onOpen: () => context.go(
                            RouteNames.adminPatientDetail.replaceFirst(
                              ':patientId',
                              history[i].patient.id,
                            ),
                          ),
                        ),
                        if (i < history.length - 1 && i < 7)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminSimulatorScreen extends ConsumerWidget {
  const AdminSimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsStreamProvider);
    final isDesktop = WebLayoutContext.useDesktopShell(context);

    Widget body = patientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('No se pudo cargar simulador: $e')),
      data: (patients) {
        final ordered = [...patients]
          ..sort(
            (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
          );

        return _WebSimulatorView(ordered: ordered);
      },
    );

    if (isDesktop) {
      return AdminWebShell(title: 'Simulador', child: body);
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 5,
      title: 'Simulador',
      onSignOut: () => _signOutAdminModules(context, ref),
      appBarActions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: () => _signOutAdminModules(context, ref),
          icon: const Icon(Icons.logout, color: OcgColors.error),
        ),
      ],
      railTrailing: _buildRailSignOutButton(context, ref),
      body: body,
    );
  }
}

class _UnifiedTreatmentsView extends StatefulWidget {
  const _UnifiedTreatmentsView({
    required this.patients,
    required this.byStage,
    required this.entries,
    required this.activeEntries,
  });

  final List<PatientModel> patients;

  final Map<TreatmentStage, int> byStage;
  final List<_TreatmentAdminEntry> entries;
  final List<_TreatmentAdminEntry> activeEntries;

  @override
  State<_UnifiedTreatmentsView> createState() => _UnifiedTreatmentsViewState();
}

class _UnifiedTreatmentsViewState extends State<_UnifiedTreatmentsView> {
  TreatmentType? selectedType;
  String selectedStatus = 'Todos';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.maybeOf(context);
    final tier = layout?.tier ?? AdminDesktopTier.standard;
    final sectionGap = layout?.sectionSpacing ?? 16;
    final panelGap = layout?.panelGap ?? 12;
    final titleSize = switch (tier) {
      AdminDesktopTier.wide => 46.0,
      AdminDesktopTier.standard => 42.0,
      AdminDesktopTier.compact => 36.0,
      AdminDesktopTier.tight => 32.0,
    };
    List<_TreatmentAdminEntry> filteredEntries = widget.activeEntries;

    if (selectedType != null) {
      filteredEntries = filteredEntries
          .where((entry) => entry.legacyType == selectedType)
          .toList();
    }

    if (selectedStatus == 'Finalizados') {
      filteredEntries = widget.entries
          .where((entry) => entry.legacyStatus == TreatmentStatus.finalizado)
          .toList();
    } else if (selectedStatus == 'En espera') {
      filteredEntries = filteredEntries
          .where((entry) => entry.legacyStatus == TreatmentStatus.enEspera)
          .toList();
    } else if (selectedStatus == 'Activos') {
      filteredEntries = filteredEntries
          .where((entry) => entry.legacyStatus == TreatmentStatus.activo)
          .toList();
    }

    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      filteredEntries = filteredEntries
          .where(
            (entry) =>
                entry.patient.nombre.toLowerCase().contains(q) ||
                entry.patient.email.toLowerCase().contains(q) ||
                entry.treatment.displayName.toLowerCase().contains(q),
          )
          .toList();
    }

    final activeCount = widget.entries
        .where((entry) => entry.legacyStatus == TreatmentStatus.activo)
        .length;
    final completedCount = widget.entries
        .where((entry) => entry.legacyStatus == TreatmentStatus.finalizado)
        .length;
    final waitingCount = widget.entries
        .where((entry) => entry.legacyStatus == TreatmentStatus.enEspera)
        .length;
    final ingresos = widget.activeEntries.fold<double>(
      0,
      (sum, entry) => sum + (entry.treatment.totalTratamiento ?? 0),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 0, 0, sectionGap + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tratamientos',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C2016),
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Seguimiento clínico y progreso',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9A735C)),
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
                onPressed: () => context.go(RouteNames.adminPatients),
                icon: const Icon(Icons.add, size: 16, color: Color(0xFFC9A882)),
                label: const Text('Nuevo tratamiento'),
              ),
            ],
          ),
          SizedBox(height: sectionGap),
          _TreatmentsKpiGrid(
            activeCount: activeCount,
            completedCount: completedCount,
            waitingCount: waitingCount,
            ingresos: ingresos,
          ),
          SizedBox(height: sectionGap),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
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
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Buscar tratamientos...',
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
            children: [
              ...['Todos', 'Activos', 'Finalizados', 'En espera'].map((f) {
                final selected = selectedStatus == f;
                return _TreatmentChip(
                  label: f,
                  selected: selected,
                  onTap: () => setState(() => selectedStatus = f),
                );
              }),
              ...TreatmentType.values.map((t) {
                final label = _tipoLabel(t);
                final selected = selectedType == t;
                return _TreatmentChip(
                  label: label,
                  selected: selected,
                  onTap: () =>
                      setState(() => selectedType = selected ? null : t),
                );
              }),
            ],
          ),
          SizedBox(height: sectionGap),
          Row(
            children: [
              const Text(
                'Listado de tratamientos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2016),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EFE7),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFE2D0BC)),
                ),
                child: Text(
                  '${filteredEntries.length} registros',
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
            padding: const EdgeInsets.all(14),
            child: filteredEntries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No hay tratamientos para los filtros actuales.',
                    ),
                  )
                : Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 2, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'PACIENTE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9A735C),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'TIPO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9A735C),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'ESTADO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9A735C),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'PROGRESO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9A735C),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'FINANCIERO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9A735C),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < filteredEntries.length; i++) ...[
                        _TreatmentPatientCard(
                          entry: filteredEntries[i],
                          onOpen: () => context.go(
                            RouteNames.adminPatientDetail.replaceFirst(
                              ':patientId',
                              filteredEntries[i].patient.id,
                            ),
                          ),
                        ),
                        if (i != filteredEntries.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _WebSimulatorView extends StatelessWidget {
  const _WebSimulatorView({required this.ordered});

  final List<PatientModel> ordered;

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.maybeOf(context);
    final tier = layout?.tier ?? AdminDesktopTier.standard;
    final sectionGap = layout?.sectionSpacing ?? 16;
    final panelGap = layout?.panelGap ?? 12;
    final titleSize = switch (tier) {
      AdminDesktopTier.wide => 46.0,
      AdminDesktopTier.standard => 42.0,
      AdminDesktopTier.compact => 36.0,
      AdminDesktopTier.tight => 32.0,
    };
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 0, 0, sectionGap + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              tier == AdminDesktopTier.tight ? 18 : 24,
              tier == AdminDesktopTier.tight ? 16 : 20,
              tier == AdminDesktopTier.tight ? 18 : 24,
              tier == AdminDesktopTier.tight ? 18 : 22,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF21170F), OcgColors.espresso],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simulador',
                  style: TextStyle(
                    color: OcgColors.ivory,
                    fontSize: titleSize > 32 ? 32 : titleSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gestión clínica de simulaciones por paciente',
                  style: TextStyle(color: Color(0xD9F6EDE5), fontSize: 13),
                ),
              ],
            ),
          ),
          SizedBox(height: sectionGap),
          GridView.count(
            crossAxisCount: switch (tier) {
              AdminDesktopTier.wide => 3,
              AdminDesktopTier.standard => 3,
              AdminDesktopTier.compact => 2,
              AdminDesktopTier.tight => 1,
            },
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: panelGap,
            mainAxisSpacing: panelGap,
            childAspectRatio: switch (tier) {
              AdminDesktopTier.wide => 2.1,
              AdminDesktopTier.standard => 2.0,
              AdminDesktopTier.compact => 2.6,
              AdminDesktopTier.tight => 3.0,
            },
            children: [
              _PayMiniKpi(
                value: '${ordered.length}',
                title: 'Pacientes',
                subtitle: 'con acceso a simulación',
                bg: const Color(0xFFF6EFE7),
                onTap: () => context.go(RouteNames.adminPatients),
              ),
              _PayMiniKpi(
                value: '3D',
                title: 'Módulo visual',
                subtitle: 'simulación guiada',
                bg: const Color(0xFFEFF2FA),
                onTap: () => context.go(RouteNames.adminSimulator),
              ),
              _PayMiniKpi(
                value: 'IA',
                title: 'Asistencia',
                subtitle: 'apoyo clínico',
                bg: const Color(0xFFFFF4D8),
                onTap: () => context.go(RouteNames.adminSimulator),
              ),
            ],
          ),
          SizedBox(height: sectionGap),
          const _MobileSectionHeader(
            title: 'Pacientes con acceso a simulación',
          ),
          const SizedBox(height: 10),
          if (ordered.isEmpty)
            const Text('No hay pacientes registrados.')
          else
            ...ordered.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AdminSimulatorPatientCard(
                  patient: p,
                  onOpen: () => context.go(
                    '${RouteNames.adminPatientDetail.replaceFirst(':patientId', p.id)}?section=simulador',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileSectionHeader extends StatelessWidget {
  const _MobileSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: OcgColors.bronze,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: OcgColors.espresso,
          ),
        ),
      ],
    );
  }
}

class _PaymentsKpiGrid extends StatelessWidget {
  const _PaymentsKpiGrid({
    required this.totalDebt,
    required this.recoveredTotal,
    required this.paidThisMonth,
    required this.overdueCount,
  });

  final double totalDebt;
  final double recoveredTotal;
  final int paidThisMonth;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    return _AdminResponsiveKpiGrid(
      cards: [
        _TreatmentKpiPremium(
          value: '\$${formatCop(totalDebt)}',
          title: 'Saldo pendiente',
          subtitle: 'por cobrar',
          bg: const Color(0xFFFBEAED),
          accent: const Color(0xFFB06A5A),
          icon: Icons.payments_outlined,
        ),
        _TreatmentKpiPremium(
          value: '\$${formatCop(recoveredTotal)}',
          title: 'Recaudado',
          subtitle: 'total acumulado',
          bg: const Color(0xFFEAF5EE),
          accent: const Color(0xFF2E7D4C),
          icon: Icons.check_circle_outline,
        ),
        _TreatmentKpiPremium(
          value: '$paidThisMonth',
          title: 'Pagos este mes',
          subtitle: 'transacciones',
          bg: const Color(0xFFF8F3EC),
          accent: const Color(0xFF9A735C),
          icon: Icons.receipt_long_outlined,
        ),
        _TreatmentKpiPremium(
          value: '$overdueCount',
          title: 'Pagos vencidos',
          subtitle: 'requieren seguimiento',
          bg: const Color(0xFFFFF4D8),
          accent: const Color(0xFFC99730),
          icon: Icons.warning_amber_rounded,
        ),
      ],
    );
  }
}

class _TreatmentsKpiGrid extends StatelessWidget {
  const _TreatmentsKpiGrid({
    required this.activeCount,
    required this.completedCount,
    required this.waitingCount,
    required this.ingresos,
  });

  final int activeCount;
  final int completedCount;
  final int waitingCount;
  final double ingresos;

  @override
  Widget build(BuildContext context) {
    return _AdminResponsiveKpiGrid(
      cards: [
        _TreatmentKpiPremium(
          value: '$activeCount',
          title: 'Tratamientos activos',
          subtitle: '+2 este mes',
          bg: const Color(0xFFF6EFE7),
          accent: const Color(0xFF9A735C),
          icon: Icons.monitor_heart_outlined,
        ),
        _TreatmentKpiPremium(
          value: '$completedCount',
          title: 'Completados',
          subtitle: 'últimos 30 días',
          bg: const Color(0xFFEFF8F0),
          accent: const Color(0xFF2E7D4C),
          icon: Icons.check_circle_outline,
        ),
        _TreatmentKpiPremium(
          value: '$waitingCount',
          title: 'En espera',
          subtitle: 'pendientes inicio',
          bg: const Color(0xFFFFF4D8),
          accent: const Color(0xFFC99730),
          icon: Icons.schedule_outlined,
        ),
        _TreatmentKpiPremium(
          value: '\$${(ingresos / 1000000).toStringAsFixed(1)}M',
          title: 'Ingresos totales',
          subtitle: 'tratamientos vigentes',
          bg: const Color(0xFFFFECEC),
          accent: const Color(0xFFB06A5A),
          icon: Icons.payments_outlined,
        ),
      ],
    );
  }
}

class _AdminResponsiveKpiGrid extends StatelessWidget {
  const _AdminResponsiveKpiGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.maybeOf(context);
    final tier = layout?.tier ?? AdminDesktopTier.standard;
    final spacing = layout?.panelGap ?? 12;
    final columns = switch (tier) {
      AdminDesktopTier.wide => 4,
      AdminDesktopTier.standard => 4,
      AdminDesktopTier.compact => 2,
      AdminDesktopTier.tight => 1,
    };
    final extent = switch (tier) {
      AdminDesktopTier.wide => 110.0,
      AdminDesktopTier.standard => 114.0,
      AdminDesktopTier.compact => 124.0,
      AdminDesktopTier.tight => 118.0,
    };

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      mainAxisExtent: extent,
      children: cards,
    );
  }
}

class _TreatmentKpiPremium extends StatelessWidget {
  const _TreatmentKpiPremium({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.accent,
    required this.icon,
  });

  final String value;
  final String title;
  final String subtitle;
  final Color bg;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final compactWidth = outerConstraints.maxWidth < 220;
        final horizontalPadding = compactWidth ? 10.0 : 14.0;
        final verticalPadding = compactWidth ? 8.0 : 12.0;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bg, Color.lerp(bg, Colors.white, 0.35)!],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6D8CB), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x122C2016),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, innerConstraints) {
              final density = _TreatmentKpiDensity.resolve(
                width: innerConstraints.maxWidth,
                height: innerConstraints.maxHeight,
              );

              return Stack(
                children: [
                  if (density.showDecoration)
                    Positioned(
                      top: -18,
                      right: -12,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.28),
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
                            width: density.iconBoxSize,
                            height: density.iconBoxSize,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x1A2C2016),
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: density.iconSize,
                              color: accent,
                            ),
                          ),
                          const Spacer(),
                          if (density.showAccentBar)
                            Container(
                              width: density.accentBarWidth,
                              height: 2,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: density.headerGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    value,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: density.valueFontSize,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF2C2016),
                                      letterSpacing: -0.4,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: density.valueGap),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: density.titleFontSize,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2C2016),
                                height: 1.1,
                              ),
                            ),
                            if (density.showSubtitle) ...[
                              SizedBox(height: density.subtitleGap),
                              Flexible(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: density.subtitleFontSize,
                                    color: accent.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TreatmentKpiDensity {
  const _TreatmentKpiDensity({
    required this.iconBoxSize,
    required this.iconSize,
    required this.accentBarWidth,
    required this.valueFontSize,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.headerGap,
    required this.valueGap,
    required this.subtitleGap,
    required this.showSubtitle,
    required this.showDecoration,
    required this.showAccentBar,
  });

  final double iconBoxSize;
  final double iconSize;
  final double accentBarWidth;
  final double valueFontSize;
  final double titleFontSize;
  final double subtitleFontSize;
  final double headerGap;
  final double valueGap;
  final double subtitleGap;
  final bool showSubtitle;
  final bool showDecoration;
  final bool showAccentBar;

  static _TreatmentKpiDensity resolve({
    required double width,
    required double height,
  }) {
    final compactWidth = width < 196;
    final veryTightHeight = height < 68;
    final compactHeight = height < 86;

    if (veryTightHeight) {
      return _TreatmentKpiDensity(
        iconBoxSize: 16,
        iconSize: 9,
        accentBarWidth: 0,
        valueFontSize: compactWidth ? 17 : 18,
        titleFontSize: 10,
        subtitleFontSize: 0,
        headerGap: 2,
        valueGap: 1,
        subtitleGap: 0,
        showSubtitle: false,
        showDecoration: false,
        showAccentBar: false,
      );
    }

    if (compactHeight || compactWidth) {
      return _TreatmentKpiDensity(
        iconBoxSize: 18,
        iconSize: 10,
        accentBarWidth: 14,
        valueFontSize: compactWidth ? 18 : 19,
        titleFontSize: 10.5,
        subtitleFontSize: 9.5,
        headerGap: 4,
        valueGap: 2,
        subtitleGap: 1,
        showSubtitle: height >= 78,
        showDecoration: height >= 78,
        showAccentBar: height >= 78,
      );
    }

    return const _TreatmentKpiDensity(
      iconBoxSize: 22,
      iconSize: 12,
      accentBarWidth: 18,
      valueFontSize: 24,
      titleFontSize: 12,
      subtitleFontSize: 10.5,
      headerGap: 10,
      valueGap: 4,
      subtitleGap: 2,
      showSubtitle: true,
      showDecoration: true,
      showAccentBar: true,
    );
  }
}

class TreatmentKpiPremiumTestHarness extends StatelessWidget {
  const TreatmentKpiPremiumTestHarness({
    super.key,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.width,
    required this.height,
    this.bg = const Color(0xFFF6EFE7),
    this.accent = const Color(0xFF9A735C),
    this.icon = Icons.payments_outlined,
  });

  final String value;
  final String title;
  final String subtitle;
  final double width;
  final double height;
  final Color bg;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: _TreatmentKpiPremium(
        value: value,
        title: title,
        subtitle: subtitle,
        bg: bg,
        accent: accent,
        icon: icon,
      ),
    );
  }
}

class PaymentsKpiSectionTestHarness extends StatelessWidget {
  const PaymentsKpiSectionTestHarness({
    super.key,
    required this.width,
    this.totalDebt = 1200000,
    this.recoveredTotal = 3600000,
    this.paidThisMonth = 3,
    this.overdueCount = 1,
  });

  final double width;
  final double totalDebt;
  final double recoveredTotal;
  final int paidThisMonth;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _PaymentsKpiGrid(
        totalDebt: totalDebt,
        recoveredTotal: recoveredTotal,
        paidThisMonth: paidThisMonth,
        overdueCount: overdueCount,
      ),
    );
  }
}

class TreatmentsKpiSectionTestHarness extends StatelessWidget {
  const TreatmentsKpiSectionTestHarness({
    super.key,
    required this.width,
    this.activeCount = 4,
    this.completedCount = 2,
    this.waitingCount = 1,
    this.ingresos = 4800000,
  });

  final double width;
  final int activeCount;
  final int completedCount;
  final int waitingCount;
  final double ingresos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _TreatmentsKpiGrid(
        activeCount: activeCount,
        completedCount: completedCount,
        waitingCount: waitingCount,
        ingresos: ingresos,
      ),
    );
  }
}

class _TreatmentChip extends StatelessWidget {
  const _TreatmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2C2016) : const Color(0xFFF8F5F0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2C2016) : const Color(0xFFE8DDD2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_circle, size: 12, color: OcgColors.ivory),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? OcgColors.ivory : const Color(0xFF7E6A5B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtShortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _TreatmentAdminEntry {
  const _TreatmentAdminEntry({required this.patient, required this.treatment});

  final PatientModel patient;
  final PatientTreatment treatment;

  factory _TreatmentAdminEntry.fromLegacy(PatientModel patient) {
    return _TreatmentAdminEntry(
      patient: patient,
      treatment: PatientTreatment.fromLegacyPatient(patient),
    );
  }

  TreatmentType get legacyType {
    if (treatment.tipoBase == 'convencional' &&
        treatment.subtipo == 'estetico') {
      return TreatmentType.estetico;
    }
    return switch (treatment.tipoBase) {
      'convencional' => TreatmentType.convencional,
      'autoligado' => TreatmentType.autoligado,
      'alineadores' => TreatmentType.alineadores,
      'ortopedia' => TreatmentType.ortopedia,
      'interceptivo' => TreatmentType.interceptivo,
      'retenedores' => TreatmentType.retenedores,
      _ => TreatmentType.convencional,
    };
  }

  TreatmentStatus get legacyStatus {
    return switch (treatment.estado) {
      'finalizado' || 'cancelado' => TreatmentStatus.finalizado,
      'pausado' => TreatmentStatus.enEspera,
      _ => TreatmentStatus.activo,
    };
  }

  String get legacyStatusLabel {
    return switch (legacyStatus) {
      TreatmentStatus.activo => 'Activo',
      TreatmentStatus.finalizado => 'Finalizado',
      TreatmentStatus.enEspera => 'En espera',
    };
  }
}

class _TreatmentPatientCard extends StatelessWidget {
  const _TreatmentPatientCard({required this.entry, required this.onOpen});
  final _TreatmentAdminEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final patient = entry.patient;
    final treatment = entry.treatment;
    final initials = _initials(patient.nombre);
    final treatmentLabel = _tipoLabel(entry.legacyType).toLowerCase();

    final stageIdx = TreatmentStage.values
        .indexOf(treatment.etapaActual)
        .clamp(0, TreatmentStage.values.length - 1);
    final progress = (((stageIdx) / (TreatmentStage.values.length - 1)) * 100)
        .round()
        .clamp(0, 100);

    final statusLabel = entry.legacyStatusLabel;
    final statusBg = switch (entry.legacyStatus) {
      TreatmentStatus.activo => const Color(0xFFEFF8F0),
      TreatmentStatus.finalizado => const Color(0xFFE8F5E9),
      TreatmentStatus.enEspera => const Color(0xFFFFF4D8),
    };
    final statusColor = switch (entry.legacyStatus) {
      TreatmentStatus.activo => const Color(0xFF406B4D),
      TreatmentStatus.finalizado => const Color(0xFF2E7D4C),
      TreatmentStatus.enEspera => const Color(0xFF9A6B00),
    };
    final nextSessionColor = switch (patient.nextSessionStatus) {
      NextSessionStatus.programada => const Color(0xFF9A735C),
      NextSessionStatus.vencida => OcgColors.error,
      NextSessionStatus.sinAgendar => const Color(0xFF8A6F59),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEFE2D6)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF2E7D4C),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: OcgColors.ivory,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OcgColors.ink,
                          ),
                        ),
                        Text(
                          'Tratamiento: ${treatment.displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A6F59),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Inicio: ${_fmtShortDate(treatment.fechaInicio)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A6F59),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EFE7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE6D8CB)),
                ),
                child: Text(
                  treatmentLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7E6A5B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE6D8CB)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${(progress / 5).round()} sesiones',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A6F59),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$progress%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: OcgColors.espresso,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFF2EDE8),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        OcgColors.bronze,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patient.nextSessionLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: nextSessionColor,
                      fontWeight:
                          patient.nextSessionStatus == NextSessionStatus.vencida
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Valor total: \$${formatCop(treatment.totalTratamiento ?? 0)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OcgColors.espresso,
                    ),
                  ),
                  Text(
                    'Pagado: \$${formatCop(((treatment.totalTratamiento ?? 0) - (treatment.saldoPendiente ?? 0)).clamp(0, double.infinity).toDouble())}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A6F59),
                    ),
                  ),
                  Text(
                    'Saldo pendiente: \$${formatCop(treatment.saldoPendiente ?? 0)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFFB06A5A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
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

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

String _tipoLabel(TreatmentType type) => switch (type) {
  TreatmentType.convencional => 'Convencional',
  TreatmentType.estetico => 'Brackets Estéticos',
  TreatmentType.autoligado => 'Autoligado',
  TreatmentType.alineadores => 'Alineadores',
  TreatmentType.ortopedia => 'Ortopedia',
  TreatmentType.retenedores => 'Retenedores',
  TreatmentType.interceptivo => 'Interceptivo',
};

class _PaymentsCompactRow extends StatelessWidget {
  const _PaymentsCompactRow({
    required this.entry,
    required this.onTap,
    this.emphasizeDebt = false,
  });

  final AdminPaymentEntry entry;
  final VoidCallback onTap;
  final bool emphasizeDebt;

  @override
  Widget build(BuildContext context) {
    final patient = entry.patient;
    final initials = patient.nombre.trim().isEmpty
        ? '?'
        : patient.nombre
              .trim()
              .split(' ')
              .where((e) => e.isNotEmpty)
              .take(2)
              .map((e) => e[0].toUpperCase())
              .join();
    final latestDate = entry.latestPaymentDate;
    final primaryColor = emphasizeDebt
        ? const Color(0xFFB06A5A)
        : const Color(0xFF2E7D4C);
    final chipBg = emphasizeDebt
        ? const Color(0xFFFFF4D8)
        : const Color(0xFFEFF8F0);
    final chipTextColor = emphasizeDebt
        ? const Color(0xFF9A735C)
        : const Color(0xFF2E7D4C);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF9F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEDE2D7)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2E7D4C),
              child: Text(
                initials,
                style: const TextStyle(
                  color: OcgColors.ivory,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
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
                      color: OcgColors.ink,
                    ),
                  ),
                  Text(
                    latestDate == null
                        ? 'Último pago: sin registros'
                        : 'Último pago: ${_fmtShortDate(latestDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9A735C),
                    ),
                  ),
                  Text(
                    'Total pagado: \$${formatCop(entry.totalPaid)}${entry.saldoPendiente > 0 ? ' · Saldo: \$${formatCop(entry.saldoPendiente)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7E6A5B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  emphasizeDebt
                      ? '\$${formatCop(entry.saldoPendiente)}'
                      : '+\$${formatCop(entry.latestPaymentAmount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    emphasizeDebt
                        ? entry.financialStatusLabel
                        : (latestDate == null
                              ? 'Sin pagos'
                              : entry.latestPaymentMethodLabel),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: chipTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentsHistoryRow extends StatelessWidget {
  const _PaymentsHistoryRow({required this.item, required this.onOpen});

  final AdminPaymentHistoryItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final patient = item.patient;
    final transaction = item.transaction;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0E5D9)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: OcgColors.ink,
                    ),
                  ),
                  Text(
                    'Pago registrado · Total pagado: \$${formatCop(item.payment.montoPagado)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9A735C),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _fmtShortDate(transaction.fecha),
                style: const TextStyle(fontSize: 12, color: OcgColors.ink),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '\$${formatCop(transaction.monto)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: OcgColors.espresso,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.statusLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D4C),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2FA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.paymentMethodLabel,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF45669A),
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

class _MobilePaymentsAdminView extends StatefulWidget {
  const _MobilePaymentsAdminView({
    required this.withDebt,
    required this.overdue,
    required this.totalDebt,
  });

  final List<PatientModel> withDebt;
  final List<PatientModel> overdue;
  final double totalDebt;

  @override
  State<_MobilePaymentsAdminView> createState() =>
      _MobilePaymentsAdminViewState();
}

class _MobilePaymentsAdminViewState extends State<_MobilePaymentsAdminView> {
  bool showOnlyOverdue = false;

  @override
  Widget build(BuildContext context) {
    final list = showOnlyOverdue ? widget.overdue : widget.withDebt;
    final now = DateTime.now();
    final subtitleDate = '${now.day} de ${_monthName(now.month)} ${now.year}';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 12,
              16,
              16,
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
                Builder(
                  builder: (ctx) => InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: OcgColors.ivory.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.menu,
                        color: OcgColors.ivory,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Pagos',
                    style: TextStyle(
                      color: OcgColors.ivory,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: OcgColors.ivory.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_none,
                    color: OcgColors.ivory,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: OcgColors.bronze,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'AD',
                    style: TextStyle(
                      color: OcgColors.ivory,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Control financiero de la cartera',
                  style: TextStyle(
                    color: OcgColors.ink.withOpacity(0.92),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Actualizado hoy · $subtitleDate',
                  style: const TextStyle(
                    color: Color(0xFF8A6F59),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _PayMiniKpi(
                        value: '${widget.withDebt.length}',
                        title: 'Con saldo',
                        subtitle: 'pacientes activos',
                        bg: const Color(0xFFF6EFE7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PayMiniKpi(
                        value: '${widget.overdue.length}',
                        title: 'Vencidos',
                        subtitle: 'requieren atención',
                        bg: const Color(0xFFFFECEC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: OcgColors.espresso,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332C2016),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SALDO TOTAL EN CARTERA',
                              style: TextStyle(
                                color: OcgColors.ivory.withOpacity(0.72),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${formatCop(widget.totalDebt)}',
                              style: const TextStyle(
                                color: OcgColors.ivory,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.withDebt.length} pacientes activos',
                              style: TextStyle(
                                color: OcgColors.ivory.withOpacity(0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: OcgColors.ivory.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.payments_outlined,
                          color: OcgColors.ivory,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: _MobileSectionHeader(title: 'Cartera activa'),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2EDE8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          _MiniToggle(
                            label: 'Todos',
                            active: !showOnlyOverdue,
                            onTap: () =>
                                setState(() => showOnlyOverdue = false),
                          ),
                          _MiniToggle(
                            label: 'Vencidos',
                            active: showOnlyOverdue,
                            onTap: () => setState(() => showOnlyOverdue = true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  const Text('No hay pacientes en esta vista.')
                else
                  ...list.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DebtPatientCard(patient: p),
                    ),
                  ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1DFB9)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: OcgColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.overdue.length} pacientes con pagos vencidos',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: OcgColors.ink,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Se recomienda contactar antes del 10 de abril',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF7B6654),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayMiniKpi extends StatelessWidget {
  const _PayMiniKpi({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.bg,
    this.onTap,
  });
  final String value;
  final String title;
  final String subtitle;
  final Color bg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 88;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: EdgeInsets.all(compactHeight ? 8 : 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compactHeight ? 18 : 22,
                    fontWeight: FontWeight.w800,
                    color: OcgColors.ink,
                    height: 1,
                  ),
                ),
                SizedBox(height: compactHeight ? 2 : 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compactHeight ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: OcgColors.espresso,
                  ),
                ),
                if (!compactHeight)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.8,
                      color: Color(0xFF7E6754),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? OcgColors.espresso : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? OcgColors.ivory : const Color(0xFF8A6F59),
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}

class _DebtPatientCard extends StatelessWidget {
  const _DebtPatientCard({required this.patient});
  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    final overdue =
        patient.fechaProximoPago != null &&
        patient.fechaProximoPago!.isBefore(DateTime.now());
    final overdueDays = overdue
        ? DateTime.now().difference(patient.fechaProximoPago!).inDays
        : 0;
    final dueText = patient.fechaProximoPago == null
        ? 'Sin fecha de próximo pago'
        : overdue
        ? 'Vencido hace $overdueDays días'
        : 'Próximo pago: ${patient.fechaProximoPago!.day.toString().padLeft(2, '0')} ${_monthShort(patient.fechaProximoPago!.month)}';

    final initials = patient.nombre.trim().isEmpty
        ? 'P'
        : patient.nombre
              .trim()
              .split(' ')
              .where((e) => e.isNotEmpty)
              .take(2)
              .map((e) => e[0].toUpperCase())
              .join();

    return InkWell(
      onTap: () => context.go(
        RouteNames.adminPatientDetail.replaceFirst(':patientId', patient.id),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: overdue ? const Color(0xFFF3C6C6) : const Color(0xFFE7D6C6),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF2EDE8),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (overdue)
                  const Positioned(
                    right: -1,
                    top: -1,
                    child: Icon(Icons.error, size: 14, color: OcgColors.error),
                  ),
              ],
            ),
            const SizedBox(width: 10),
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
                      color: OcgColors.ink,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tipoLabel(
                      patient.tipoTratamiento ?? TreatmentType.convencional,
                    ),
                    style: const TextStyle(
                      fontSize: 11.8,
                      color: Color(0xFF8A6F59),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: overdue
                          ? const Color(0xFFFFECEC)
                          : const Color(0xFFEFF8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      dueText,
                      style: TextStyle(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                        color: overdue ? OcgColors.error : OcgColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${formatCop(patient.saldoPendiente)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: overdue ? OcgColors.error : OcgColors.espresso,
                  ),
                ),
                const Text(
                  'pendiente',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF8A6F59)),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFFB59D87), size: 20),
          ],
        ),
      ),
    );
  }
}

String _monthName(int m) => const [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
][m - 1];
String _monthShort(int m) => const [
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
][m - 1];

class _AdminSimulatorPatientCard extends StatelessWidget {
  const _AdminSimulatorPatientCard({
    required this.patient,
    required this.onOpen,
  });

  final PatientModel patient;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8D8C8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: OcgColors.espresso.withOpacity(0.14),
              child: Text(
                _initials(patient.nombre),
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
                      fontWeight: FontWeight.w700,
                      color: OcgColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Abrir simulaciones del paciente',
                    style: TextStyle(color: OcgColors.ink.withOpacity(0.64)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.auto_awesome, color: OcgColors.bronze),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
