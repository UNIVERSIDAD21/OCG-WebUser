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

        if (!isDesktop) {
          return _MobileTreatmentsView(
            ref: ref,
            patients: patients,
            activePatients: activePatients,
            byStage: byStage,
          );
        }

        final content = [
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
                    children: activePatients
                        .map(
                          (p) => _PatientActionTile(
                            patient: p,
                            subtitle:
                                '${p.tipoTratamiento?.name ?? 'Tipo pendiente'} · ${stageNames[p.etapaActual] ?? p.etapaActual.name}',
                            onOpen: () => context.go(
                              RouteNames.adminPatientDetail.replaceFirst(
                                ':patientId',
                                p.id,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ];

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),
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

        final content = [
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
        ];

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),
        );
      },
    );

    if (isDesktop) {
      return AdminWebShell(title: 'Pagos', child: body);
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 4,
      title: 'Pagos',
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

        final content = [
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
                    children: ordered
                        .map(
                          (p) => _PatientActionTile(
                            patient: p,
                            subtitle:
                                'Abrir detalle para gestionar simulación clínica',
                            onOpen: () => context.go(
                              RouteNames.adminPatientDetail.replaceFirst(
                                ':patientId',
                                p.id,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ];

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),
        );
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

class _MiniStageCard extends StatelessWidget {
  const _MiniStageCard({required this.value, required this.label, required this.bg});
  final String value;
  final String label;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: OcgColors.ink, height: 1)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: OcgColors.espresso)),
        ],
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

class _TreatmentPatientCard extends StatelessWidget {
  const _TreatmentPatientCard({required this.patient, required this.onOpen});
  final PatientModel patient;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(patient.nombre);
    final stageLabel = stageNames[patient.etapaActual] ?? patient.etapaActual.name;
    final treatmentLabel = _tipoLabel(patient.tipoTratamiento ?? TreatmentType.convencional);

    final stageIdx = TreatmentStage.values.indexOf(patient.etapaActual).clamp(0, TreatmentStage.values.length - 1);
    final progress = (((stageIdx) / (TreatmentStage.values.length - 1)) * 100).round().clamp(0, 100);

    final months = DateTime.now().difference(patient.fechaInicio).inDays ~/ 30;

    final statusBg = stageIdx >= 4
        ? const Color(0xFFEFF8F0)
        : (stageIdx <= 1 ? const Color(0xFFFFF4D8) : const Color(0xFFEFF2FA));
    final statusColor = stageIdx >= 4
        ? OcgColors.success
        : (stageIdx <= 1 ? OcgColors.warning : const Color(0xFF3B5B8C));

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7D6C6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: const Color(0xFFF2EDE8),
                  child: Text(initials, style: const TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: OcgColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('$treatmentLabel · ${months <= 0 ? 1 : months} meses', style: const TextStyle(fontSize: 12, color: Color(0xFF8A6F59))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                  child: Text(stageLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Progreso del tratamiento', style: TextStyle(fontSize: 11.5, color: Color(0xFF8A6F59))),
                const Spacer(),
                Text('$progress%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: OcgColors.espresso)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFFF2EDE8),
                valueColor: const AlwaysStoppedAnimation<Color>(OcgColors.bronze),
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
    };

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
