import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../admin/presentation/web/components/page_header.dart';
import '../../admin/presentation/web/components/section_panel.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';

class AdminTreatmentsScreen extends ConsumerWidget {
  const AdminTreatmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsStreamProvider);

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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PageHeader(
              title: 'Tratamientos',
              subtitle: 'Seguimiento clínico por etapa y acceso rápido por paciente',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: TreatmentStage.values.map((stage) {
                return _KpiPill(
                  title: stageNames[stage] ?? stage.name,
                  value: '${byStage[stage] ?? 0}',
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SectionPanel(
              title: 'Pacientes en tratamiento activo',
              child: activePatients.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay pacientes activos en este momento.'),
                    )
                  : Column(
                      children: activePatients.map((p) => _PatientActionTile(
                        patient: p,
                        subtitle: '${p.tipoTratamiento?.name ?? 'Tipo pendiente'} · ${stageNames[p.etapaActual] ?? p.etapaActual.name}',
                        onOpen: () => context.go(
                          RouteNames.adminPatientDetail.replaceFirst(':patientId', p.id),
                        ),
                      )).toList(),
                    ),
            ),
          ],
        );
      },
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      return AdminWebShell(title: 'Tratamientos', child: body);
    }

    return OcgAdaptiveScaffold(selectedIndex: 0, title: 'Tratamientos', body: body);
  }
}

class AdminPaymentsScreen extends ConsumerWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsStreamProvider);

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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PageHeader(
              title: 'Pagos',
              subtitle: 'Control financiero de saldos y vencimientos',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _KpiPill(title: 'Pacientes con saldo', value: '${withDebt.length}'),
                _KpiPill(title: 'Pagos vencidos', value: '${overdue.length}'),
                _KpiPill(title: 'Saldo pendiente total', value: '\$${formatCop(totalDebt)}'),
              ],
            ),
            const SizedBox(height: 16),
            SectionPanel(
              title: 'Cartera activa',
              child: withDebt.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay saldos pendientes.'),
                    )
                  : Column(
                      children: withDebt.map((p) {
                        final due = p.fechaProximoPago;
                        final dueText = due == null
                            ? 'Sin fecha de próximo pago'
                            : 'Próximo pago: ${due.day.toString().padLeft(2, '0')}/${due.month.toString().padLeft(2, '0')}/${due.year}';
                        return _PatientActionTile(
                          patient: p,
                          subtitle: 'Saldo: \$${formatCop(p.saldoPendiente)} · $dueText',
                          critical: due != null && due.isBefore(today),
                          onOpen: () => context.go(
                            RouteNames.adminPatientDetail.replaceFirst(':patientId', p.id),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      return AdminWebShell(title: 'Pagos', child: body);
    }

    return OcgAdaptiveScaffold(selectedIndex: 0, title: 'Pagos', body: body);
  }
}

class AdminSimulatorScreen extends ConsumerWidget {
  const AdminSimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsStreamProvider);

    Widget body = patientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('No se pudo cargar simulador: $e')),
      data: (patients) {
        final ordered = [...patients]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PageHeader(
              title: 'Simulador',
              subtitle: 'Acceso clínico al flujo de simulaciones por paciente',
            ),
            const SizedBox(height: 12),
            const SectionPanel(
              title: 'Flujo activo',
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Selecciona un paciente para entrar a su ficha clínica y gestionar la simulación antes/después desde el flujo principal.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SectionPanel(
              title: 'Pacientes',
              child: ordered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay pacientes registrados.'),
                    )
                  : Column(
                      children: ordered.map((p) => _PatientActionTile(
                        patient: p,
                        subtitle: 'Abrir detalle para gestionar simulación clínica',
                        onOpen: () => context.go(
                          RouteNames.adminPatientDetail.replaceFirst(':patientId', p.id),
                        ),
                      )).toList(),
                    ),
            ),
          ],
        );
      },
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      return AdminWebShell(title: 'Simulador', child: body);
    }

    return OcgAdaptiveScaffold(selectedIndex: 0, title: 'Simulador', body: body);
  }
}

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
