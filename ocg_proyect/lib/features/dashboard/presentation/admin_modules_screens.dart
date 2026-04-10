import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../admin/presentation/web/components/page_header.dart';
import '../../auth/providers/auth_providers.dart';
import '../../admin/presentation/web/components/section_panel.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
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
      error: (e, _) => Center(child: Text('No se pudieron cargar tratamientos: $e')),
      data: (patients) {
        final byStage = <TreatmentStage, int>{
          for (final stage in TreatmentStage.values)
            stage: patients.where((p) => p.etapaActual == stage).length,
        };

        final activePatients = patients.where((p) => p.etapaActual != TreatmentStage.alta).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

        return _UnifiedTreatmentsView(
          patients: patients,
          activePatients: activePatients,
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
    final patientsAsync = ref.watch(patientsStreamProvider);
    final isDesktop = WebLayoutContext.useDesktopShell(context);

    Widget body = patientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('No se pudieron cargar pagos: $e')),
      data: (patients) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final withDebt = patients.where((p) => p.saldoPendiente > 0).toList();
        final overdue = withDebt
            .where((p) => p.fechaProximoPago != null && p.fechaProximoPago!.isBefore(today))
            .toList();

        withDebt.sort((a, b) => b.saldoPendiente.compareTo(a.saldoPendiente));

        final totalDebt = withDebt.fold<double>(0, (acc, p) => acc + p.saldoPendiente);

        if (!isDesktop) {
          return _MobilePaymentsAdminView(
            withDebt: withDebt,
            overdue: overdue,
            totalDebt: totalDebt,
          );
        }

        return _WebPaymentsView(
          withDebt: withDebt,
          overdue: overdue,
          totalDebt: totalDebt,
          today: today,
        );
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
  const _WebPaymentsView({
    required this.withDebt,
    required this.overdue,
    required this.totalDebt,
    required this.today,
  });

  final List<PatientModel> withDebt;
  final List<PatientModel> overdue;
  final double totalDebt;
  final DateTime today;

  @override
  State<_WebPaymentsView> createState() => _WebPaymentsViewState();
}

class _WebPaymentsViewState extends State<_WebPaymentsView> {
  bool showOnlyOverdue = false;

  @override
  Widget build(BuildContext context) {
    final list = showOnlyOverdue ? widget.overdue : widget.withDebt;

    final recoveredTotal = widget.withDebt.fold<double>(0, (sum, p) => sum + (p.totalTratamiento - p.saldoPendiente));
    final paidThisMonth = widget.withDebt.where((p) {
      final d = p.fechaProximoPago;
      return d != null && d.month == widget.today.month && d.year == widget.today.year;
    }).length;

    final recentIncome = [...widget.withDebt]
      ..sort((a, b) => (b.totalTratamiento - b.saldoPendiente).compareTo(a.totalTratamiento - a.saldoPendiente));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pagos', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, color: Color(0xFF2C2016), height: 1)),
                    SizedBox(height: 4),
                    Text('Control financiero y facturación', style: TextStyle(fontSize: 13, color: Color(0xFF9A735C))),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7E6A5B),
                  side: const BorderSide(color: Color(0xFFE8DDD2)),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.download_outlined, size: 14),
                label: const Text('Exportar'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => context.go(RouteNames.adminPatients),
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
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.45,
            children: [
              _TreatmentKpiPremium(value: '\$${formatCop(widget.totalDebt)}', title: 'Saldo pendiente', subtitle: 'por cobrar', bg: const Color(0xFFFBEAED), accent: const Color(0xFFB06A5A), icon: Icons.payments_outlined),
              _TreatmentKpiPremium(value: '\$${formatCop(recoveredTotal)}', title: 'Recaudado', subtitle: 'total acumulado', bg: const Color(0xFFEAF5EE), accent: const Color(0xFF2E7D4C), icon: Icons.check_circle_outline),
              _TreatmentKpiPremium(value: '$paidThisMonth', title: 'Pagos este mes', subtitle: 'transacciones', bg: const Color(0xFFF8F3EC), accent: const Color(0xFF9A735C), icon: Icons.receipt_long_outlined),
              _TreatmentKpiPremium(value: '${widget.overdue.length}', title: 'Pagos vencidos', subtitle: 'requieren seguimiento', bg: const Color(0xFFFFF4D8), accent: const Color(0xFFC99730), icon: Icons.warning_amber_rounded),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final split = constraints.maxWidth > 1100;
              final ingresosCard = Container(
                decoration: BoxDecoration(color: const Color(0xFFFFFDFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8DDD2))),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MobileSectionHeader(title: 'Ingresos recientes'),
                    const SizedBox(height: 10),
                    ...recentIncome.take(3).map((p) {
                      final amount = (p.totalTratamiento - p.saldoPendiente).clamp(0, 999999999).toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PaymentsCompactRow(
                          patient: p,
                          amountLabel: '+\$${formatCop(amount)}',
                          trailingTag: p.tipoTratamiento == null ? 'Sin tipo' : _tipoLabel(p.tipoTratamiento!),
                          positive: true,
                          onTap: () => context.go(RouteNames.adminPatientDetail.replaceFirst(':patientId', p.id)),
                        ),
                      );
                    }),
                  ],
                ),
              );

              final alertsCard = Container(
                decoration: BoxDecoration(color: const Color(0xFFFFFDFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8DDD2))),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MobileSectionHeader(title: 'Alertas de cobro'),
                    const SizedBox(height: 10),
                    ...widget.overdue.take(3).map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PaymentsCompactRow(
                            patient: p,
                            amountLabel: '\$${formatCop(p.saldoPendiente)}',
                            trailingTag: 'Vencido',
                            positive: false,
                            onTap: () => context.go(RouteNames.adminPatientDetail.replaceFirst(':patientId', p.id)),
                          ),
                        )),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF8F5F0), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Text('Total pendiente', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF7E6A5B))),
                          const Spacer(),
                          Text('\$${formatCop(widget.totalDebt)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB06A5A))),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              if (!split) return Column(children: [ingresosCard, const SizedBox(height: 12), alertsCard]);
              return Row(children: [Expanded(child: ingresosCard), const SizedBox(width: 12), Expanded(child: alertsCard)]);
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8DDD2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 16, color: Color(0xFFC9A882)),
                const SizedBox(width: 8),
                const Expanded(child: TextField(decoration: InputDecoration(isDense: true, hintText: 'Buscar pagos, pacientes o facturas...', border: InputBorder.none))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF8F5F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8DDD2))),
                  child: Row(
                    children: const [Icon(Icons.tune, size: 14, color: Color(0xFF9A735C)), SizedBox(width: 6), Text('Filtros', style: TextStyle(fontSize: 12, color: Color(0xFF9A735C), fontWeight: FontWeight.w600))],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TreatmentChip(label: 'Todos', selected: !showOnlyOverdue, onTap: () => setState(() => showOnlyOverdue = false)),
              _TreatmentChip(label: 'Vencido', selected: showOnlyOverdue, onTap: () => setState(() => showOnlyOverdue = true)),
              _TreatmentChip(label: 'Pagado', selected: false, onTap: () {}),
              _TreatmentChip(label: 'Pendiente', selected: false, onTap: () {}),
              _TreatmentChip(label: 'Transferencia', selected: false, onTap: () {}),
              _TreatmentChip(label: 'Tarjeta', selected: false, onTap: () {}),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Historial de pagos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF2C2016))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF6EFE7), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFFE2D0BC))),
                child: Text('${list.length} transacciones', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9A735C))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: const Color(0xFFFFFDFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8DDD2))),
            padding: const EdgeInsets.all(14),
            child: list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No hay pagos para los filtros actuales.'),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < list.length && i < 8; i++) ...[
                        _PaymentsHistoryRow(patient: list[i], onOpen: () => context.go(RouteNames.adminPatientDetail.replaceFirst(':patientId', list[i].id))),
                        if (i < list.length - 1 && i < 7) const SizedBox(height: 8),
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
        final ordered = [...patients]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

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
    required this.activePatients,
  });

  final List<PatientModel> patients;

  final Map<TreatmentStage, int> byStage;
  final List<PatientModel> activePatients;

  @override
  State<_UnifiedTreatmentsView> createState() => _UnifiedTreatmentsViewState();
}

class _UnifiedTreatmentsViewState extends State<_UnifiedTreatmentsView> {
  TreatmentType? selectedType;
  String selectedStatus = 'Todos';
  String query = '';

  @override
  Widget build(BuildContext context) {
    List<PatientModel> filteredActivePatients = widget.activePatients;

    if (selectedType != null) {
      filteredActivePatients = filteredActivePatients
          .where((p) => p.tipoTratamiento == selectedType)
          .toList();
    }

    if (selectedStatus == 'Completados') {
      filteredActivePatients = filteredActivePatients
          .where((p) => p.etapaActual == TreatmentStage.alta || p.etapaActual == TreatmentStage.retencion)
          .toList();
    } else if (selectedStatus == 'En espera') {
      filteredActivePatients = filteredActivePatients
          .where((p) => p.etapaActual == TreatmentStage.valoracionInicial || p.etapaActual == TreatmentStage.estudioPlaneacion)
          .toList();
    } else if (selectedStatus == 'Activos') {
      filteredActivePatients = filteredActivePatients
          .where((p) => p.etapaActual != TreatmentStage.alta)
          .toList();
    }

    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      filteredActivePatients = filteredActivePatients
          .where((p) => p.nombre.toLowerCase().contains(q) || p.email.toLowerCase().contains(q))
          .toList();
    }

    final activeCount = widget.activePatients.where((p) => p.etapaActual != TreatmentStage.alta).length;
    final completedCount = widget.activePatients.where((p) => p.etapaActual == TreatmentStage.alta || p.etapaActual == TreatmentStage.retencion).length;
    final waitingCount = widget.activePatients.where((p) => p.etapaActual == TreatmentStage.valoracionInicial || p.etapaActual == TreatmentStage.estudioPlaneacion).length;
    final ingresos = widget.activePatients.fold<double>(0, (sum, p) => sum + p.totalTratamiento);

    final byType = <TreatmentType, int>{
      for (final t in TreatmentType.values)
        t: filteredActivePatients.where((p) => p.tipoTratamiento == t).length,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tratamientos', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, color: Color(0xFF2C2016), height: 1)),
                    SizedBox(height: 4),
                    Text('Seguimiento clínico y progreso', style: TextStyle(fontSize: 13, color: Color(0xFF9A735C))),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C2016),
                  foregroundColor: OcgColors.ivory,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: () => context.go(RouteNames.adminPatients),
                icon: const Icon(Icons.add, size: 16, color: Color(0xFFC9A882)),
                label: const Text('Nuevo tratamiento'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.45,
            children: [
              _TreatmentKpiPremium(value: '$activeCount', title: 'Tratamientos activos', subtitle: '+2 este mes', bg: const Color(0xFFF6EFE7), accent: const Color(0xFF9A735C), icon: Icons.monitor_heart_outlined),
              _TreatmentKpiPremium(value: '$completedCount', title: 'Completados', subtitle: 'últimos 30 días', bg: const Color(0xFFEFF8F0), accent: const Color(0xFF2E7D4C), icon: Icons.check_circle_outline),
              _TreatmentKpiPremium(value: '$waitingCount', title: 'En espera', subtitle: 'pendientes inicio', bg: const Color(0xFFFFF4D8), accent: const Color(0xFFC99730), icon: Icons.schedule_outlined),
              _TreatmentKpiPremium(value: '\$${(ingresos / 1000000).toStringAsFixed(1)}M', title: 'Ingresos totales', subtitle: 'tratamientos vigentes', bg: const Color(0xFFFFECEC), accent: const Color(0xFFB06A5A), icon: Icons.payments_outlined),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    decoration: const InputDecoration(isDense: true, hintText: 'Buscar tratamientos...', border: InputBorder.none),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8DDD2)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.tune, size: 14, color: Color(0xFF9A735C)),
                      SizedBox(width: 6),
                      Text('Filtros', style: TextStyle(fontSize: 12, color: Color(0xFF9A735C), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...['Todos', 'Activos', 'Completados', 'En espera'].map((f) {
                final selected = selectedStatus == f;
                return _TreatmentChip(label: f, selected: selected, onTap: () => setState(() => selectedStatus = f));
              }),
              ...TreatmentType.values.map((t) {
                final label = _tipoLabel(t);
                final selected = selectedType == t;
                return _TreatmentChip(label: label, selected: selected, onTap: () => setState(() => selectedType = selected ? null : t));
              }),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Listado de tratamientos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF2C2016))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EFE7),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFE2D0BC)),
                ),
                child: Text('${filteredActivePatients.length} registros', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9A735C))),
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
            child: filteredActivePatients.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No hay tratamientos para los filtros actuales.'),
                  )
                : Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 2, 8, 8),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text('PACIENTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9A735C)))),
                            Expanded(flex: 2, child: Text('TIPO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9A735C)))),
                            Expanded(flex: 2, child: Text('ESTADO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9A735C)))),
                            Expanded(flex: 3, child: Text('PROGRESO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9A735C)))),
                            Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('FINANCIERO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9A735C))))),
                          ],
                        ),
                      ),
                      for (var i = 0; i < filteredActivePatients.length; i++) ...[
                        _TreatmentPatientCard(
                          patient: filteredActivePatients[i],
                          onOpen: () => context.go(RouteNames.adminPatientDetail.replaceFirst(':patientId', filteredActivePatients[i].id)),
                        ),
                        if (i != filteredActivePatients.length - 1) const SizedBox(height: 8),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF21170F), OcgColors.espresso],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simulador',
                  style: TextStyle(color: OcgColors.ivory, fontSize: 32, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Gestión clínica de simulaciones por paciente',
                  style: TextStyle(color: Color(0xD9F6EDE5), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 980 ? 3 : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: cols == 3 ? 2.1 : 3.0,
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
              );
            },
          ),
          const SizedBox(height: 16),
          const _MobileSectionHeader(title: 'Pacientes con acceso a simulación'),
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

class _MobileTreatmentsView extends StatelessWidget {
  const _MobileTreatmentsView({
    required this.ref,
    required this.patients,
    required this.activePatients,
    required this.byStage,
  });

  final WidgetRef ref;
  final List<PatientModel> patients;
  final List<PatientModel> activePatients;
  final Map<TreatmentStage, int> byStage;

  @override
  Widget build(BuildContext context) {
    int phaseCount(String phase) {
      return patients.where((p) {
        final s = p.etapaActual;
        switch (phase) {
          case 'registrado':
            return s == TreatmentStage.valoracionInicial;
          case 'evaluacion':
            return s == TreatmentStage.estudioPlaneacion;
          case 'tratamiento':
            return s == TreatmentStage.instalacion || s == TreatmentStage.controles;
          case 'retencion':
            return s == TreatmentStage.retencion || s == TreatmentStage.alta;
        }
        return false;
      }).length;
    }

    final byType = <TreatmentType, int>{
      for (final t in TreatmentType.values)
        t: patients.where((p) => p.tipoTratamiento == t).length,
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 16),
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
                      child: const Icon(Icons.menu, color: OcgColors.ivory, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tratamientos',
                    style: TextStyle(color: OcgColors.ivory, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: OcgColors.ivory.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_none, color: OcgColors.ivory, size: 18),
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
                  child: const Text('AD', style: TextStyle(color: OcgColors.ivory, fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seguimiento clínico activo', style: TextStyle(color: OcgColors.ink.withOpacity(0.92), fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${activePatients.length} pacientes en programa · actualizado hoy', style: const TextStyle(color: Color(0xFF8A6F59), fontSize: 12.5)),
                const SizedBox(height: 14),
                const _MobileSectionHeader(title: 'Distribución por etapa'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _MiniStageCard(value: '${phaseCount('registrado')}', label: 'Registrado', bg: const Color(0xFFF6EFE7))),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniStageCard(value: '${phaseCount('evaluacion')}', label: 'Evaluación', bg: const Color(0xFFEFE7F7))),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniStageCard(value: '${phaseCount('tratamiento')}', label: 'Tratamiento', bg: const Color(0xFFE5F3EA))),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniStageCard(value: '${phaseCount('retencion')}', label: 'Retención', bg: const Color(0xFFFFF4D8))),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: const Color(0xFFF2EDE8), borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    children: [
                      const Icon(Icons.chevron_left, size: 14, color: Color(0xFF9D856F)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(color: const Color(0xFFD6C3B1), borderRadius: BorderRadius.circular(999)),
                          child: FractionallySizedBox(
                            widthFactor: 0.36,
                            alignment: Alignment.center,
                            child: Container(
                              decoration: BoxDecoration(color: OcgColors.bronze, borderRadius: BorderRadius.circular(999)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 14, color: Color(0xFF9D856F)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _MobileSectionHeader(title: 'Por tipo de tratamiento'),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7D6C6)),
                  ),
                  child: Column(
                    children: [
                      _TypeRow(type: TreatmentType.convencional, count: byType[TreatmentType.convencional] ?? 0, max: patients.length),
                      _TypeRow(type: TreatmentType.estetico, count: byType[TreatmentType.estetico] ?? 0, max: patients.length),
                      _TypeRow(type: TreatmentType.autoligado, count: byType[TreatmentType.autoligado] ?? 0, max: patients.length),
                      _TypeRow(type: TreatmentType.alineadores, count: byType[TreatmentType.alineadores] ?? 0, max: patients.length),
                      _TypeRow(type: TreatmentType.ortopedia, count: byType[TreatmentType.ortopedia] ?? 0, max: patients.length),
                      _TypeRow(type: TreatmentType.retenedores, count: byType[TreatmentType.retenedores] ?? 0, max: patients.length, isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _MobileSectionHeader(title: 'Pacientes en tratamiento'),
                const SizedBox(height: 10),
                if (activePatients.isEmpty)
                  const Text('No hay pacientes activos en este momento.')
                else
                  ...activePatients.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TreatmentPatientCard(patient: p, onOpen: () => context.go(RouteNames.adminPatientDetail.replaceFirst(':patientId', p.id))),
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

class _MobileSectionHeader extends StatelessWidget {
  const _MobileSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: OcgColors.bronze, borderRadius: BorderRadius.circular(99))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: OcgColors.espresso)),
      ],
    );
  }
}

class _ModuleQuickCard extends StatelessWidget {
  const _ModuleQuickCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final bg = emphasized ? OcgColors.espresso : Colors.white;
    final fg = emphasized ? OcgColors.ivory : OcgColors.espresso;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: emphasized ? OcgColors.espresso : const Color(0xFFE7D6C6)),
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: emphasized ? OcgColors.ivory.withOpacity(0.14) : const Color(0xFFF2EDE8),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: fg),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStageCard extends StatelessWidget {
  const _MiniStageCard({
    required this.value,
    required this.label,
    required this.bg,
    this.onTap,
  });
  final String value;
  final String label;
  final Color bg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tooShort = constraints.maxHeight < 56;
          if (tooShort) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$value · $label',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OcgColors.espresso,
                  ),
                ),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: OcgColors.ink, height: 1)),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: OcgColors.espresso),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.count, required this.max, this.isLast = false});
  final TreatmentType type;
  final int count;
  final int max;
  final bool isLast;

  Color _dot(TreatmentType t) => switch (t) {
        TreatmentType.convencional => const Color(0xFF8A6F59),
        TreatmentType.estetico => const Color(0xFFA78361),
        TreatmentType.autoligado => const Color(0xFF6E8BA7),
        TreatmentType.alineadores => const Color(0xFF4A8F72),
        TreatmentType.ortopedia => const Color(0xFF8B6FB0),
        TreatmentType.retenedores => const Color(0xFFB07F6F),
        TreatmentType.interceptivo => const Color(0xFF6F8F9D),
      };

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (count / max).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF0E3D8))),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _dot(type), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(_tipoLabel(type), style: const TextStyle(fontSize: 12.5, color: OcgColors.ink, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: const Color(0xFFF2EDE8),
                valueColor: AlwaysStoppedAnimation<Color>(_dot(type)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text('$count', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: OcgColors.espresso)),
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg, Color.lerp(bg, Colors.white, 0.35)!],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6D8CB), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x122C2016), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
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
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x1A2C2016)),
                    ),
                    child: Icon(icon, size: 12, color: accent),
                  ),
                  const Spacer(),
                  Container(
                    width: 18,
                    height: 2,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C2016),
                  letterSpacing: -0.4,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2C2016))),
              Text(subtitle, style: TextStyle(fontSize: 10.5, color: accent.withOpacity(0.9), fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TreatmentChip extends StatelessWidget {
  const _TreatmentChip({required this.label, required this.selected, required this.onTap});

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
          border: Border.all(color: selected ? const Color(0xFF2C2016) : const Color(0xFFE8DDD2)),
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

String _fmtShortDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _TreatmentPatientCard extends StatelessWidget {
  const _TreatmentPatientCard({required this.patient, required this.onOpen});
  final PatientModel patient;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(patient.nombre);
    final treatmentLabel = _tipoLabel(patient.tipoTratamiento ?? TreatmentType.convencional).toLowerCase();

    final stageIdx = TreatmentStage.values.indexOf(patient.etapaActual).clamp(0, TreatmentStage.values.length - 1);
    final progress = (((stageIdx) / (TreatmentStage.values.length - 1)) * 100).round().clamp(0, 100);

    final statusLabel = (patient.etapaActual == TreatmentStage.alta || patient.etapaActual == TreatmentStage.retencion)
        ? 'Completado'
        : (patient.etapaActual == TreatmentStage.valoracionInicial || patient.etapaActual == TreatmentStage.estudioPlaneacion)
            ? 'En espera'
            : 'Activo';

    final statusBg = statusLabel == 'Activo'
        ? const Color(0xFFEFF8F0)
        : statusLabel == 'Completado'
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF4D8);

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
                    child: Text(initials, style: const TextStyle(color: OcgColors.ivory, fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: OcgColors.ink)),
                        Text('Inicio: ${_fmtShortDate(patient.fechaInicio)}', style: const TextStyle(fontSize: 11, color: Color(0xFF8A6F59))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF6EFE7), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFE6D8CB))),
                child: Text(treatmentLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF7E6A5B), fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFE6D8CB))),
                child: Text(statusLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF406B4D), fontWeight: FontWeight.w700)),
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
                      Text('${(progress / 5).round()} sesiones', style: const TextStyle(fontSize: 11, color: Color(0xFF8A6F59))),
                      const Spacer(),
                      Text('$progress%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: OcgColors.espresso)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFF2EDE8),
                      valueColor: const AlwaysStoppedAnimation<Color>(OcgColors.bronze),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Próx: ${patient.proximaCita == null ? '--/--/----' : _fmtShortDate(patient.proximaCita!)}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF9A735C))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${formatCop(patient.totalTratamiento)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: OcgColors.espresso)),
                  Text('de \$${formatCop(patient.totalTratamiento - patient.saldoPendiente)}', style: const TextStyle(fontSize: 11, color: Color(0xFF8A6F59))),
                  Text('Pendiente: \$${formatCop(patient.saldoPendiente)}', style: const TextStyle(fontSize: 10.5, color: Color(0xFFB06A5A))),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: const Color(0xFFF8F5F0), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFE8DDD2))),
              child: const Icon(Icons.chevron_right, color: OcgColors.bronze, size: 14),
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
    required this.patient,
    required this.amountLabel,
    required this.trailingTag,
    required this.positive,
    required this.onTap,
  });

  final PatientModel patient;
  final String amountLabel;
  final String trailingTag;
  final bool positive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = patient.nombre.trim().isEmpty
        ? '?'
        : patient.nombre
            .trim()
            .split(' ')
            .where((e) => e.isNotEmpty)
            .take(2)
            .map((e) => e[0].toUpperCase())
            .join();

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
              child: Text(initials, style: const TextStyle(color: OcgColors.ivory, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: OcgColors.ink)),
                  Text('Cuota mensual — ${patient.tipoTratamiento == null ? 'Sin tipo' : _tipoLabel(patient.tipoTratamiento!)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9A735C))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amountLabel, style: TextStyle(fontWeight: FontWeight.w800, color: positive ? const Color(0xFF2E7D4C) : const Color(0xFFB06A5A))),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: positive ? const Color(0xFFEFF8F0) : const Color(0xFFFFF4D8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(trailingTag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: positive ? const Color(0xFF2E7D4C) : const Color(0xFF9A735C))),
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
  const _PaymentsHistoryRow({required this.patient, required this.onOpen});

  final PatientModel patient;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final recovered = (patient.totalTratamiento - patient.saldoPendiente).clamp(0, 999999999).toDouble();
    final date = patient.fechaProximoPago ?? patient.fechaInicio;

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
                  Text(patient.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: OcgColors.ink)),
                  Text('Cuota mensual — ${patient.tipoTratamiento == null ? 'Sin tipo' : _tipoLabel(patient.tipoTratamiento!)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9A735C))),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(_fmtShortDate(date), style: const TextStyle(fontSize: 12, color: OcgColors.ink)),
            ),
            Expanded(
              flex: 2,
              child: Text('\$${formatCop(recovered)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, color: OcgColors.espresso)),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: patient.saldoPendiente <= 0 ? const Color(0xFFEFF8F0) : const Color(0xFFFFF4D8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  patient.saldoPendiente <= 0 ? 'Pagado' : 'Pendiente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: patient.saldoPendiente <= 0 ? const Color(0xFF2E7D4C) : const Color(0xFF9A735C),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2FA),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Transferencia', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF45669A))),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF9A735C)),
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
  State<_MobilePaymentsAdminView> createState() => _MobilePaymentsAdminViewState();
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
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 16),
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
                      child: const Icon(Icons.menu, color: OcgColors.ivory, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Pagos', style: TextStyle(color: OcgColors.ivory, fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: OcgColors.ivory.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_none, color: OcgColors.ivory, size: 18),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: OcgColors.bronze, shape: BoxShape.circle),
                  child: const Text('AD', style: TextStyle(color: OcgColors.ivory, fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Control financiero de la cartera', style: TextStyle(color: OcgColors.ink.withOpacity(0.92), fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Actualizado hoy · $subtitleDate', style: const TextStyle(color: Color(0xFF8A6F59), fontSize: 12.5)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _PayMiniKpi(value: '${widget.withDebt.length}', title: 'Con saldo', subtitle: 'pacientes activos', bg: const Color(0xFFF6EFE7))),
                    const SizedBox(width: 8),
                    Expanded(child: _PayMiniKpi(value: '${widget.overdue.length}', title: 'Vencidos', subtitle: 'requieren atención', bg: const Color(0xFFFFECEC))),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: OcgColors.espresso,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x332C2016), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SALDO TOTAL EN CARTERA', style: TextStyle(color: OcgColors.ivory.withOpacity(0.72), fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            Text('\$${formatCop(widget.totalDebt)}', style: const TextStyle(color: OcgColors.ivory, fontSize: 30, fontWeight: FontWeight.w800, height: 1)),
                            const SizedBox(height: 4),
                            Text('${widget.withDebt.length} pacientes activos', style: TextStyle(color: OcgColors.ivory.withOpacity(0.75), fontSize: 12)),
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
                        child: const Icon(Icons.payments_outlined, color: OcgColors.ivory),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: _MobileSectionHeader(title: 'Cartera activa')),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2EDE8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          _MiniToggle(label: 'Todos', active: !showOnlyOverdue, onTap: () => setState(() => showOnlyOverdue = false)),
                          _MiniToggle(label: 'Vencidos', active: showOnlyOverdue, onTap: () => setState(() => showOnlyOverdue = true)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  const Text('No hay pacientes en esta vista.')
                else
                  ...list.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DebtPatientCard(patient: p),
                      )),
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
                      const Icon(Icons.warning_amber_rounded, color: OcgColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${widget.overdue.length} pacientes con pagos vencidos', style: const TextStyle(fontWeight: FontWeight.w700, color: OcgColors.ink, fontSize: 13)),
                            const SizedBox(height: 2),
                            const Text('Se recomienda contactar antes del 10 de abril', style: TextStyle(fontSize: 11.5, color: Color(0xFF7B6654))),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: OcgColors.ink, height: 1)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: OcgColors.espresso)),
            Text(subtitle, style: const TextStyle(fontSize: 10.8, color: Color(0xFF7E6754))),
          ],
        ),
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({required this.label, required this.active, required this.onTap});
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
    final overdue = patient.fechaProximoPago != null && patient.fechaProximoPago!.isBefore(DateTime.now());
    final overdueDays = overdue ? DateTime.now().difference(patient.fechaProximoPago!).inDays : 0;
    final dueText = patient.fechaProximoPago == null
        ? 'Sin fecha de próximo pago'
        : overdue
            ? 'Vencido hace $overdueDays días'
            : 'Próximo pago: ${patient.fechaProximoPago!.day.toString().padLeft(2, '0')} ${_monthShort(patient.fechaProximoPago!.month)}';

    final initials = patient.nombre.trim().isEmpty
        ? 'P'
        : patient.nombre.trim().split(' ').where((e) => e.isNotEmpty).take(2).map((e) => e[0].toUpperCase()).join();

    return InkWell(
      onTap: () => context.go(RouteNames.adminPatientDetail.replaceFirst(':patientId', patient.id)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: overdue ? const Color(0xFFF3C6C6) : const Color(0xFFE7D6C6)),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF2EDE8),
                  child: Text(initials, style: const TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w700)),
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
                  Text(patient.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: OcgColors.ink, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(_tipoLabel(patient.tipoTratamiento ?? TreatmentType.convencional), style: const TextStyle(fontSize: 11.8, color: Color(0xFF8A6F59))),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: overdue ? const Color(0xFFFFECEC) : const Color(0xFFEFF8F0),
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
                Text('\$${formatCop(patient.saldoPendiente)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: overdue ? OcgColors.error : OcgColors.espresso)),
                const Text('pendiente', style: TextStyle(fontSize: 10.5, color: Color(0xFF8A6F59))),
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

String _monthName(int m) => const ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'][m - 1];
String _monthShort(int m) => const ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'][m - 1];

class _KpiPill extends StatelessWidget {
  const _KpiPill({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, color: OcgColors.ink.withOpacity(0.72)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _PatientActionTile extends StatelessWidget {
  const _PatientActionTile({
    required this.patient,
    required this.subtitle,
    required this.onOpen,
    this.critical = false,
  });

  final PatientModel patient;
  final String subtitle;
  final VoidCallback onOpen;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: critical ? const Color(0xFFFFEFEF) : OcgColors.mist,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: critical ? OcgColors.error.withOpacity(0.4) : OcgColors.bronze.withOpacity(0.15),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: OcgColors.bronze.withOpacity(0.18),
          child: Text(
            _initials(patient.nombre),
            style: const TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(patient.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: OcgColors.bronze),
        onTap: onOpen,
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
