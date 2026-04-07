import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../patients/presentation/patient_profile_screen.dart';
import '../../patients/presentation/patient_viewer_mode.dart';
import '../../payments/presentation/patient_payments_screen.dart';
import '../../simulator/presentation/patient_simulations_screen.dart';
import 'patient_appointments_screen.dart';
import '../../treatment/presentation/widgets/stage_history_list.dart';
import '../../treatment/providers/treatment_provider.dart';
import 'widgets/patient_bottom_nav.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({
    super.key,
    this.patientIdOverride,
    this.isAdminView = false,
    this.initialSection = 0,
  });

  final String? patientIdOverride;
  final bool isAdminView;
  final int initialSection;

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSection.clamp(0, 5);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;
    final effectivePatientId = (widget.patientIdOverride?.isNotEmpty == true)
        ? widget.patientIdOverride!
        : (user?.uid ?? '');

    final overrideForAdmin = widget.isAdminView ? effectivePatientId : null;

    final sections = [
      _InicioSection(userId: effectivePatientId),
      PatientAppointmentsScreen(
        embedded: true,
        patientIdOverride: overrideForAdmin,
        viewerMode: widget.isAdminView
            ? PatientViewerMode.adminViewer
            : PatientViewerMode.patient,
      ),
      _TratamientoSection(userId: effectivePatientId),
      PatientPaymentsScreen(
        embedded: true,
        patientIdOverride: overrideForAdmin,
        viewerMode: widget.isAdminView
            ? PatientViewerMode.adminViewer
            : PatientViewerMode.patient,
      ),
      PatientSimulationsScreen(
        embedded: true,
        patientIdOverride: overrideForAdmin,
        viewerMode: widget.isAdminView
            ? PatientViewerMode.adminViewer
            : PatientViewerMode.patient,
      ),
      PatientProfileScreen(
        embedded: true,
        patientIdOverride: overrideForAdmin,
        viewerMode: widget.isAdminView
            ? PatientViewerMode.adminViewer
            : PatientViewerMode.patient,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: sections),
          if (widget.isAdminView)
            Positioned(
              left: 12,
              top: MediaQuery.paddingOf(context).top + 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: OcgColors.espresso.withOpacity(0.78),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: OcgColors.ivory,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: PatientBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
        items: const [
          PatientNavItem(
            label: 'Inicio',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
          ),
          PatientNavItem(
            label: 'Citas',
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
          ),
          PatientNavItem(
            label: 'Tratamiento',
            icon: Icons.format_align_left_outlined,
            selectedIcon: Icons.format_align_left,
          ),
          PatientNavItem(
            label: 'Pagos',
            icon: Icons.credit_card_outlined,
            selectedIcon: Icons.credit_card,
          ),
          PatientNavItem(
            label: 'Simulación',
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome,
          ),
          PatientNavItem(
            label: 'Perfil',
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
          ),
        ],
      ),
    );
  }
}

int _progressByStage(TreatmentStage stage) {
  final idx = TreatmentStage.values
      .indexOf(stage)
      .clamp(0, TreatmentStage.values.length - 1);
  final totalSteps = TreatmentStage.values.length - 1;
  if (totalSteps <= 0) return 0;
  return ((idx / totalSteps) * 100).round().clamp(0, 100);
}

int _phaseFromProgress(int progress) {
  if (progress <= 0) return 1;
  return ((progress / 20).ceil()).clamp(1, 5);
}

class _InicioSection extends ConsumerWidget {
  const _InicioSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) return const SizedBox.shrink();

    final patientAsync = ref.watch(patientByIdProvider(userId));
    final appointmentsAsync = ref.watch(patientAppointmentsProvider(userId));
    final historyAsync = ref.watch(stageHistoryProvider(userId));
    final user = ref.watch(authStateProvider).asData?.value;

    return patientAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const OcgEmptyState(
        icon: Icons.error_outline,
        title: 'No se pudo cargar tu información',
      ),
      data: (patient) {
        if (patient == null) {
          return const OcgEmptyState(
            icon: Icons.person_off_outlined,
            title: 'Perfil no encontrado',
            subtitle: 'Contacta a la clínica para activar tu perfil.',
          );
        }

        final nombre = (patient.nombre.trim().isNotEmpty)
            ? patient.nombre.trim()
            : (user?.displayName?.trim().isNotEmpty == true
                  ? user!.displayName!.trim()
                  : 'Paciente');

        final stageIndex = TreatmentStage.values
            .indexOf(patient.etapaActual)
            .clamp(0, TreatmentStage.values.length - 1);
        final stageTotal = TreatmentStage.values.length;
        final progress = _progressByStage(patient.etapaActual);

        final total = patient.totalTratamiento;
        final saldo = patient.saldoPendiente;
        final pagado = (total > 0) ? (total - saldo).clamp(0, total) : 0.0;
        final pagoPercent = (total > 0)
            ? ((pagado / total) * 100).round().clamp(0, 100)
            : null;

        final nextAppointment =
            (appointmentsAsync.asData?.value ?? const <AppointmentModel>[])
                .where((a) => a.fechaHora.isAfter(DateTime.now()))
                .toList()
              ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

        final cita = nextAppointment.isNotEmpty ? nextAppointment.first : null;

        final historial = historyAsync.asData?.value ?? const [];
        final historialFechas = <TreatmentStage, DateTime>{};
        for (final h in historial) {
          historialFechas[h.etapaNueva] = h.fechaEfectiva ?? h.fechaCambio;
        }
        historialFechas.putIfAbsent(
          TreatmentStage.values.first,
          () => patient.fechaInicio,
        );

        final mesesTotal = patient.fechaEstimadaFin == null
            ? null
            : _monthsBetween(patient.fechaInicio, patient.fechaEstimadaFin!);
        final mesesRestantes = patient.fechaEstimadaFin == null
            ? null
            : _monthsBetween(DateTime.now(), patient.fechaEstimadaFin!);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 20,
                  20,
                  20,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [OcgColors.espresso, Color(0xFF4A3628)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
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
                                _headerDate(DateTime.now()),
                                style: TextStyle(
                                  color: OcgColors.ivory.withOpacity(0.68),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Hola, ${_firstTwoNames(nombre)} 👋',
                                style: const TextStyle(
                                  color: OcgColors.ivory,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tu sonrisa está progresando muy bien',
                                style: TextStyle(
                                  color: OcgColors.ivory.withOpacity(0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _PatientAvatar(name: nombre, photoUrl: patient.fotoUrl),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _TreatmentHeroCard(
                      progress: progress,
                      stageLabel: 'Fase ${stageIndex + 1} de $stageTotal',
                      stageName:
                          stageNames[patient.etapaActual] ??
                          patient.etapaActual.name,
                      mesesTotal: mesesTotal,
                      mesesRestantes: mesesRestantes,
                      citasRegistradas: appointmentsAsync.asData?.value?.length,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Próxima cita'),
                    const SizedBox(height: 10),
                    _NextAppointmentCard(
                      cita: cita,
                      fallback: patient.proximaCita,
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle('Estado de cuenta'),
                    const SizedBox(height: 10),
                    _BalanceCard(
                      total: total,
                      saldo: saldo,
                      pagoPercent: pagoPercent,
                      onGoToPayments: () =>
                          context.go(RouteNames.patientPayments),
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle('Etapas del tratamiento'),
                    const SizedBox(height: 10),
                    ...TreatmentStage.values.map((stage) {
                      final idx = TreatmentStage.values.indexOf(stage);
                      final isDone = idx < stageIndex;
                      final isCurrent = idx == stageIndex;
                      final fecha = historialFechas[stage];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MilestoneTile(
                          title: stageNames[stage] ?? stage.name,
                          dateLabel: fecha == null
                              ? 'Sin fecha registrada'
                              : _shortDate(fecha),
                          done: isDone,
                          current: isCurrent,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _firstTwoNames(String fullName) {
    final parts = fullName
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return fullName;
    if (parts.length == 1) return parts.first;
    return '${parts[0]} ${parts[1]}';
  }

  int _monthsBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month);
    final b = DateTime(to.year, to.month);
    return (b.year - a.year) * 12 + (b.month - a.month);
  }

  String _headerDate(DateTime d) {
    const wd = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const months = [
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
    ];
    return '${wd[d.weekday - 1]}, ${d.day} de ${months[d.month - 1]}';
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  static final _style = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xFF8A6F59),
    letterSpacing: 0.6,
  );

  @override
  Widget build(BuildContext context) =>
      Text(title.toUpperCase(), style: _style);
}

class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? 'P'
        : name.trim().split(' ').take(2).map((e) => e[0].toUpperCase()).join();

    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          photoUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(initials),
        ),
      );
    }

    return _avatarFallback(initials);
  }

  Widget _avatarFallback(String initials) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF8A6F59),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66ECD9C6)),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: OcgColors.ivory,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TreatmentHeroCard extends StatelessWidget {
  const _TreatmentHeroCard({
    required this.progress,
    required this.stageLabel,
    required this.stageName,
    required this.mesesTotal,
    required this.mesesRestantes,
    required this.citasRegistradas,
  });

  final int progress;
  final String stageLabel;
  final String stageName;
  final int? mesesTotal;
  final int? mesesRestantes;
  final int? citasRegistradas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OcgColors.ivory.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OcgColors.ivory.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 152,
            height: 152,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 152,
                  height: 152,
                  child: CircularProgressIndicator(
                    value: progress / 100,
                    strokeWidth: 14,
                    backgroundColor: const Color(0x55ECD9C6),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      OcgColors.ivory,
                    ),
                  ),
                ),

                Text(
                  '$progress%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: OcgColors.ivory.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'En tratamiento',
                    style: TextStyle(
                      color: OcgColors.ivory,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  stageLabel,
                  style: const TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stageName,
                  style: TextStyle(
                    color: OcgColors.ivory.withOpacity(0.85),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MiniMetric(
                      title: 'Meses',
                      value: mesesTotal == null
                          ? '--'
                          : '${mesesTotal! < 0 ? 0 : mesesTotal}',
                    ),
                    _metricDivider(),
                    _MiniMetric(
                      title: 'Restantes',
                      value: mesesRestantes == null
                          ? '--'
                          : '${mesesRestantes! < 0 ? 0 : mesesRestantes}',
                    ),
                    _metricDivider(),
                    _MiniMetric(
                      title: 'Visitas',
                      value: '${citasRegistradas ?? 0}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricDivider() => Container(
    width: 1,
    height: 28,
    color: OcgColors.ivory.withOpacity(0.25),
    margin: const EdgeInsets.symmetric(horizontal: 10),
  );
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: OcgColors.ivory,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: OcgColors.ivory.withOpacity(0.72),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({this.cita, this.fallback});

  final AppointmentModel? cita;
  final DateTime? fallback;

  @override
  Widget build(BuildContext context) {
    final fecha = cita?.fechaHora as DateTime? ?? fallback;
    if (fecha == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECD9C6)),
        ),
        child: const Text(
          'No tienes una próxima cita registrada.',
          style: TextStyle(color: Color(0xFF8A6F59)),
        ),
      );
    }

    final day = fecha.day.toString().padLeft(2, '0');
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECD9C6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122C2016),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 62,
            decoration: BoxDecoration(
              color: OcgColors.espresso,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  months[fecha.month - 1],
                  style: const TextStyle(color: OcgColors.ivory, fontSize: 10),
                ),
                Text(
                  day,
                  style: const TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Próxima cita',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1410),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hourLabel(fecha),
                  style: const TextStyle(
                    color: Color(0xFF8A6F59),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2EDE8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Detalle disponible en Citas',
                    style: TextStyle(
                      color: const Color(0xFF8A6F59),
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hourLabel(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${h12.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.total,
    required this.saldo,
    required this.pagoPercent,
    required this.onGoToPayments,
  });

  final double total;
  final double saldo;
  final int? pagoPercent;
  final VoidCallback onGoToPayments;

  @override
  Widget build(BuildContext context) {
    final pagado = (total - saldo).clamp(0, total);
    final percent = pagoPercent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECD9C6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122C2016),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _moneyBlock('Total tratamiento', _formatCop(total)),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFECD9C6)),
              Expanded(
                child: _moneyBlock(
                  'Saldo pendiente',
                  _formatCop(saldo),
                  valueColor: const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (percent != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pagado',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A6F59)),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF166534),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: percent / 100,
                backgroundColor: const Color(0xFFF2EDE8),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF166534),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Aún no hay base suficiente para calcular porcentaje de pago.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8A6F59)),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGoToPayments,
              icon: const Icon(Icons.credit_card, size: 16),
              label: const Text('Realizar pago'),
              style: ElevatedButton.styleFrom(
                backgroundColor: OcgColors.espresso,
                foregroundColor: OcgColors.ivory,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyBlock(
    String label,
    String value, {
    Color valueColor = const Color(0xFF1A1410),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8A6F59),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCop(num value) {
    final digits = value.round().toString();
    final withDots = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );
    return '\$$withDots';
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.title,
    required this.dateLabel,
    required this.done,
    required this.current,
  });

  final String title;
  final String dateLabel;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final bg = current ? const Color(0xFFF2EDE8) : Colors.white;
    final border = current ? const Color(0xFFE0C9B3) : const Color(0xFFECD9C6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? const Color(0xFF166534)
                  : (current ? OcgColors.espresso : const Color(0xFFECD9C6)),
            ),
            child: Icon(
              done
                  ? Icons.check
                  : (current ? Icons.star : Icons.circle_outlined),
              size: 14,
              color: done || current ? Colors.white : const Color(0xFF8A6F59),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF1A1410),
                    fontSize: 13,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: Color(0xFF8A6F59),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (current)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8DED3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Actual',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: OcgColors.espresso,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TratamientoSection extends ConsumerWidget {
  const _TratamientoSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) return const SizedBox.shrink();

    final patientAsync = ref.watch(patientByIdProvider(userId));
    final historyAsync = ref.watch(stageHistoryProvider(userId));
    final appointmentsAsync = ref.watch(patientAppointmentsProvider(userId));

    return patientAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const OcgEmptyState(
        icon: Icons.error_outline,
        title: 'No se pudo cargar tu tratamiento',
      ),
      data: (patient) {
        if (patient == null) {
          return const OcgEmptyState(
            icon: Icons.medical_services_outlined,
            title: 'Sin tratamiento activo',
            subtitle: 'Contacta a la clínica para información.',
          );
        }

        return historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const OcgEmptyState(
            icon: Icons.error_outline,
            title: 'No se pudo cargar el historial',
          ),
          data: (historial) {
            final stageIndex = TreatmentStage.values
                .indexOf(patient.etapaActual)
                .clamp(0, TreatmentStage.values.length - 1);
            final progress = _progressByStage(patient.etapaActual);
            final phase = _phaseFromProgress(progress);

            final citasRealizadas = appointmentsAsync.asData?.value
                ?.where((a) => a.estado == AppointmentStatus.completada)
                .length;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.paddingOf(context).top + 20,
                      20,
                      18,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [OcgColors.espresso, OcgColors.bronze],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mi tratamiento',
                          style: TextStyle(
                            color: OcgColors.ivory,
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          patient.tipoTratamiento == null
                              ? 'Seguimiento clínico de ortodoncia'
                              : 'Tratamiento ${patient.tipoTratamiento!.name}',
                          style: TextStyle(
                            color: OcgColors.ivory.withOpacity(0.78),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _TreatmentSummaryTopCard(
                          progress: progress,
                          fechaInicio: patient.fechaInicio,
                          fechaEstimadaFin: patient.fechaEstimadaFin,
                          citasRealizadas: citasRealizadas,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PhaseBar(phase: phase),
                        const SizedBox(height: 14),
                        _CurrentStageCard(
                          stageName:
                              stageNames[patient.etapaActual] ??
                              patient.etapaActual.name,
                          description:
                              stageDescriptions[patient.etapaActual] ??
                              'Avance clínico en curso.',
                          progress: progress,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Etapas del tratamiento',
                          style: TextStyle(
                            color: Color(0xFF1A1410),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...TreatmentStage.values.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final stage = entry.value;
                          final completed = idx < stageIndex;
                          final current = idx == stageIndex;
                          final pending = idx > stageIndex;

                          final historyMatch = historial
                              .where((h) => h.etapaNueva == stage)
                              .toList();

                          final stageDate = historyMatch.isNotEmpty
                              ? (historyMatch.first.fechaEfectiva ??
                                    historyMatch.first.fechaCambio)
                              : (idx == 0 ? patient.fechaInicio : null);

                          return _StageTimelineTile(
                            stageIndex: idx + 1,
                            stageName: stageNames[stage] ?? stage.name,
                            description:
                                stageDescriptions[stage] ??
                                'Sin descripción clínica disponible.',
                            completed: completed,
                            current: current,
                            pending: pending,
                            date: stageDate,
                            notes: historyMatch.firstOrNull?.notas,
                          );
                        }),
                        const SizedBox(height: 8),
                        if (historial.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Historial clínico',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          StageHistoryList(
                            historial: historial,
                            isAdmin: false,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TreatmentSummaryTopCard extends StatelessWidget {
  const _TreatmentSummaryTopCard({
    required this.progress,
    required this.fechaInicio,
    required this.fechaEstimadaFin,
    required this.citasRealizadas,
  });

  final int progress;
  final DateTime fechaInicio;
  final DateTime? fechaEstimadaFin;
  final int? citasRealizadas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.ivory.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OcgColors.ivory.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 138,
            height: 138,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 138,
                  height: 138,
                  child: CircularProgressIndicator(
                    value: progress / 100,
                    strokeWidth: 13,
                    backgroundColor: const Color(0x55ECD9C6),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      OcgColors.ivory,
                    ),
                  ),
                ),
                Text(
                  '$progress%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryTile(title: 'Inicio', value: _fmtDate(fechaInicio)),
                _SummaryTile(
                  title: 'Estimado fin',
                  value: fechaEstimadaFin == null
                      ? 'Sin fecha'
                      : _fmtDate(fechaEstimadaFin!),
                ),
                _SummaryTile(
                  title: 'Citas realizadas',
                  value: citasRealizadas == null ? '--' : '$citasRealizadas',
                ),
                const _SummaryTile(
                  title: 'Doctor principal',
                  value: 'Sin registro',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OcgColors.ivory.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: OcgColors.ivory.withOpacity(0.78),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: OcgColors.ivory,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseBar extends StatelessWidget {
  const _PhaseBar({required this.phase});
  final int phase;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final current = i + 1 == phase;
        final done = i + 1 < phase;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == 4 ? 0 : 6),
            height: 10,
            decoration: BoxDecoration(
              color: done
                  ? OcgColors.espresso
                  : (current
                        ? const Color(0xFF8A6F59)
                        : const Color(0xFFEADBCB)),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

class _CurrentStageCard extends StatelessWidget {
  const _CurrentStageCard({
    required this.stageName,
    required this.description,
    required this.progress,
  });

  final String stageName;
  final String description;
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: OcgColors.bronze),
              const SizedBox(width: 6),
              const Text(
                '¡Vas muy bien!',
                style: TextStyle(
                  color: OcgColors.espresso,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '$progress%',
                style: const TextStyle(
                  color: OcgColors.bronze,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stageName,
            style: const TextStyle(
              color: Color(0xFF1A1410),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF6E5644),
              height: 1.45,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTimelineTile extends StatelessWidget {
  const _StageTimelineTile({
    required this.stageIndex,
    required this.stageName,
    required this.description,
    required this.completed,
    required this.current,
    required this.pending,
    required this.date,
    required this.notes,
  });

  final int stageIndex;
  final String stageName;
  final String description;
  final bool completed;
  final bool current;
  final bool pending;
  final DateTime? date;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final badgeText = completed
        ? 'Completada'
        : (current ? 'Actual' : 'Pendiente');
    final badgeColor = completed
        ? const Color(0xFF166534)
        : (current ? OcgColors.espresso : const Color(0xFF8A6F59));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed
                      ? const Color(0xFF166534)
                      : (current
                            ? OcgColors.espresso
                            : const Color(0xFFEADBCB)),
                ),
              ),
              Container(width: 2, height: 78, color: const Color(0xFFE5D5C6)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: current ? const Color(0xFFFFF8F2) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: current
                      ? const Color(0xFFE0C9B3)
                      : const Color(0xFFECD9C6),
                  width: current ? 1.4 : 1,
                ),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                initiallyExpanded: current,
                collapsedIconColor: const Color(0xFF8A6F59),
                iconColor: OcgColors.espresso,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Fase $stageIndex',
                          style: const TextStyle(
                            color: Color(0xFF8A6F59),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stageName,
                      style: TextStyle(
                        color: const Color(0xFF1A1410),
                        fontSize: 14,
                        fontWeight: current ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                subtitle: date == null
                    ? const Text(
                        'Sin fecha registrada',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF8A6F59),
                        ),
                      )
                    : Text(
                        '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF8A6F59),
                        ),
                      ),
                children: [
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF6E5644),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  if (notes != null && notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2EDE8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notes!.trim(),
                        style: const TextStyle(
                          color: Color(0xFF6E5644),
                          fontSize: 11.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
