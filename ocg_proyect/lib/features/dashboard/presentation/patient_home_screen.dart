// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../../shared/widgets/profile_photo_avatar.dart';
import '../../../shared/widgets/ocg_loading_state.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../clinical_files/presentation/patient_shared_clinical_files_screen.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../patients/presentation/patient_profile_screen.dart';
import '../../patients/presentation/patient_viewer_mode.dart';
import '../../payments/presentation/patient_payments_screen.dart';
import '../../notifications/presentation/patient_notifications_screen.dart';
import '../../simulator/presentation/patient_simulations_screen.dart';
import 'patient_appointments_screen.dart';
import '../../treatment/data/models/patient_treatment.dart';
import '../../treatment/presentation/widgets/stage_history_list.dart';
import '../../treatment/providers/patient_treatments_provider.dart';
import '../../treatment/providers/treatment_provider.dart';
import 'widgets/patient_bottom_nav.dart';

enum PatientTreatmentInitialView { overview, payments, clinicalFiles }

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({
    super.key,
    this.patientIdOverride,
    this.isAdminView = false,
    this.initialSection = 0,
    this.initialTreatmentView = PatientTreatmentInitialView.overview,
  });

  final String? patientIdOverride;
  final bool isAdminView;
  final int initialSection;
  final PatientTreatmentInitialView initialTreatmentView;

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  late int _selectedIndex;
  late PatientTreatmentInitialView _treatmentView;

  void _openNotificationsSheet(String patientId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: true,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.88,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F5F0),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: OcgColors.espresso.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 10, 10, 8),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Notificaciones',
                                  style: TextStyle(
                                    color: OcgColors.espresso,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cerrar notificaciones',
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: PatientNotificationsScreen(
                            embedded: true,
                            patientIdOverride: widget.isAdminView
                                ? patientId
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSection.clamp(0, 4);
    _treatmentView = widget.initialTreatmentView;
  }

  @override
  void didUpdateWidget(covariant PatientHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection ||
        oldWidget.initialTreatmentView != widget.initialTreatmentView) {
      _selectedIndex = widget.initialSection.clamp(0, 4);
      _treatmentView = widget.initialTreatmentView;
    }
  }

  void _openTreatmentView(PatientTreatmentInitialView view) {
    setState(() {
      _selectedIndex = 2;
      _treatmentView = view;
    });
  }

  void _selectBottomNav(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 2) {
        _treatmentView = PatientTreatmentInitialView.overview;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;
    final effectivePatientId = (widget.patientIdOverride?.isNotEmpty == true)
        ? widget.patientIdOverride!
        : (user?.uid ?? '');

    final overrideForAdmin = widget.isAdminView ? effectivePatientId : null;

    final sections = [
      _InicioSection(
        userId: effectivePatientId,
        onOpenProfile: () => setState(() => _selectedIndex = 4),
        onOpenPayments: () =>
            _openTreatmentView(PatientTreatmentInitialView.payments),
        onOpenClinicalFiles: () =>
            _openTreatmentView(PatientTreatmentInitialView.clinicalFiles),
        onOpenAlerts: () => _openNotificationsSheet(effectivePatientId),
      ),
      PatientAppointmentsScreen(
        embedded: true,
        patientIdOverride: overrideForAdmin,
        viewerMode: widget.isAdminView
            ? PatientViewerMode.adminViewer
            : PatientViewerMode.patient,
      ),
      _TratamientoSection(
        userId: effectivePatientId,
        currentView: _treatmentView,
        onViewChanged: (view) => setState(() => _treatmentView = view),
        onOpenPayments: () => setState(
          () => _treatmentView = PatientTreatmentInitialView.payments,
        ),
        onOpenClinicalFiles: () => setState(
          () => _treatmentView = PatientTreatmentInitialView.clinicalFiles,
        ),
        onOpenAppointments: () => setState(() => _selectedIndex = 1),
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
        onSelected: _selectBottomNav,
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
  const _InicioSection({
    required this.userId,
    this.onOpenProfile,
    this.onOpenPayments,
    this.onOpenClinicalFiles,
    this.onOpenAlerts,
  });
  final String userId;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenPayments;
  final VoidCallback? onOpenClinicalFiles;
  final VoidCallback? onOpenAlerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) return const SizedBox.shrink();

    final patientAsync = ref.watch(patientByIdProvider(userId));
    final appointmentsAsync = ref.watch(patientAppointmentsProvider(userId));
    final historyAsync = ref.watch(stageHistoryProvider(userId));
    final user = ref.watch(authStateProvider).asData?.value;

    return patientAsync.when(
      loading: () => OcgLoadingState(),
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
                        if (onOpenAlerts != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: onOpenAlerts,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: OcgColors.ivory.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: OcgColors.ivory.withOpacity(0.16),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: OcgColors.ivory,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: onOpenProfile,
                          child: ProfilePhotoAvatar(
                            label: nombre,
                            photoUrl: patient.fotoUrl,
                            radius: 21,
                          ),
                        ),
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
                      citasRegistradas: appointmentsAsync.asData?.value.length,
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
                      onGoToPayments:
                          onOpenPayments ??
                          () => context.go(RouteNames.patientPayments),
                    ),
                    const SizedBox(height: 18),
                    _ClinicalFilesShortcutCard(
                      onTap:
                          onOpenClinicalFiles ??
                          () => context.go(RouteNames.patientClinicalFiles),
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
    final fecha = cita?.fechaHora ?? fallback;
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
                  child: const Text(
                    'Detalle disponible en Citas',
                    style: TextStyle(color: Color(0xFF8A6F59), fontSize: 11.5),
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

class _ClinicalFilesShortcutCard extends StatelessWidget {
  const _ClinicalFilesShortcutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x331565C0)),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Color(0x1F1565C0),
              child: Icon(
                Icons.folder_shared_outlined,
                color: Color(0xFF1565C0),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mis archivos clínicos',
                    style: TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Ver documentos e imágenes compartidos por la clínica.',
                    style: TextStyle(
                      color: OcgColors.bronze,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Color(0xFF1565C0)),
          ],
        ),
      ),
    );
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

// ─────────────────────────────────────────────────────────────────────────────
// TRATAMIENTO SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _TratamientoSection extends ConsumerStatefulWidget {
  const _TratamientoSection({
    required this.userId,
    required this.currentView,
    required this.onViewChanged,
    this.onOpenPayments,
    this.onOpenClinicalFiles,
    this.onOpenAppointments,
    this.patientIdOverride,
    this.viewerMode = PatientViewerMode.patient,
  });

  final String userId;
  final PatientTreatmentInitialView currentView;
  final ValueChanged<PatientTreatmentInitialView> onViewChanged;
  final VoidCallback? onOpenPayments;
  final VoidCallback? onOpenClinicalFiles;
  final VoidCallback? onOpenAppointments;
  final String? patientIdOverride;
  final PatientViewerMode viewerMode;

  @override
  ConsumerState<_TratamientoSection> createState() =>
      _TratamientoSectionState();
}

class _TratamientoSectionState extends ConsumerState<_TratamientoSection>
    with SingleTickerProviderStateMixin {
  String? _selectedTreatmentId;
  bool _stagesExpanded = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeSlide =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TratamientoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _selectedTreatmentId = null;
      _stagesExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) return const SizedBox.shrink();

    if (widget.currentView == PatientTreatmentInitialView.payments) {
      return _TreatmentEmbeddedSubview(
        title: 'Mis pagos',
        subtitle: 'Consulta tu saldo, abonos e historial.',
        icon: Icons.account_balance_wallet_outlined,
        onBack: () =>
            widget.onViewChanged(PatientTreatmentInitialView.overview),
        child: PatientPaymentsScreen(
          embedded: true,
          patientIdOverride: widget.patientIdOverride,
          viewerMode: widget.viewerMode,
          showEmbeddedHeader: false,
        ),
      );
    }

    if (widget.currentView == PatientTreatmentInitialView.clinicalFiles) {
      return _TreatmentEmbeddedSubview(
        title: 'Documentos clínicos',
        subtitle: 'Archivos compartidos por la clínica.',
        icon: Icons.folder_shared_outlined,
        onBack: () =>
            widget.onViewChanged(PatientTreatmentInitialView.overview),
        child: PatientSharedClinicalFilesScreen(
          embedded: true,
          patientIdOverride: widget.patientIdOverride,
          showEmbeddedHeader: false,
        ),
      );
    }

    final patientAsync = ref.watch(patientByIdProvider(widget.userId));

    return patientAsync.when(
      loading: () => OcgLoadingState(),
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

        final treatments = ref.watch(
          effectivePatientTreatmentsProvider((
            patientId: widget.userId,
            patient: patient,
          )),
        );

        if (treatments.isEmpty) {
          return const OcgEmptyState(
            icon: Icons.medical_services_outlined,
            title: 'Aún no tienes tratamientos registrados',
            subtitle:
                'Cuando la clínica active tu tratamiento podrás seguir aquí tu progreso.',
          );
        }

        final selectedTreatment = _resolveSelectedTreatment(treatments);
        final historyAsync = selectedTreatment.id.startsWith('legacy-primary-')
            ? ref.watch(stageHistoryProvider(widget.userId))
            : ref.watch(
                treatmentStageHistoryProvider((
                  patientId: widget.userId,
                  treatmentId: selectedTreatment.id,
                )),
              );

        return historyAsync.when(
          loading: () => OcgLoadingState(),
          error: (_, __) => const OcgEmptyState(
            icon: Icons.error_outline,
            title: 'No se pudo cargar el historial',
          ),
          data: (historial) {
            final progress = _progressByStage(selectedTreatment.etapaActual);
            final stageIndex = TreatmentStage.values
                .indexOf(selectedTreatment.etapaActual)
                .clamp(0, TreatmentStage.values.length - 1);
            return FadeTransition(
              opacity: _fadeSlide,
              child: SlideTransition(
                position: Tween<Offset>(
                    begin: const Offset(0, 0.03), end: Offset.zero)
                    .animate(_fadeSlide),
                child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Premium header ──────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.paddingOf(context).top + 20,
                      20,
                      22,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          OcgColors.espresso,
                          const Color(0xFF6F5746),
                          const Color(0xFF9A7E69),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tu tratamiento dentro de la clínica',
                                    style: TextStyle(
                                      color: OcgColors.ivory.withOpacity(0.38),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Tratamiento',
                                    style: TextStyle(
                                      color: OcgColors.ivory,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Revisa el avance de tus tratamientos',
                                    style: TextStyle(
                                      color: OcgColors.ivory.withOpacity(0.82),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Live indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: OcgColors.ivory.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: OcgColors.ivory.withOpacity(0.18),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4ADE80),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Activo',
                                    style: TextStyle(
                                      color: OcgColors.ivory,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Treatment selector (only when multiple)
                        if (treatments.length > 1) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 96,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: treatments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final treatment = treatments[index];
                                final selected =
                                    treatment.id == selectedTreatment.id;
                                return _PremiumTreatmentSelectorCard(
                                  treatment: treatment,
                                  selected: selected,
                                  progress: _progressByStage(
                                    treatment.etapaActual,
                                  ),
                                  onTap: () => setState(() {
                                    _selectedTreatmentId = treatment.id;
                                    _stagesExpanded = false;
                                  }),
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 20),
                          // Single treatment — compact premium display
                          _PremiumSingleTreatmentBadge(
                            treatment: selectedTreatment,
                            progress: progress,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Body ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PatientProgressCard(
                          progress: progress,
                          currentStage:
                              stageNames[selectedTreatment.etapaActual] ??
                              selectedTreatment.etapaActual.name,
                          currentStep: stageIndex + 1,
                          totalSteps: TreatmentStage.values.length,
                        ),
                        const SizedBox(height: 18),
                        const _SectionTitle('Gestión de tu tratamiento'),
                        const SizedBox(height: 10),
                        _TreatmentPatientAccessCard(
                          title: 'Mis pagos',
                          subtitle: 'Consulta tu saldo, abonos e historial',
                          icon: Icons.account_balance_wallet_outlined,
                          onTap:
                              widget.onOpenPayments ??
                              () => widget.onViewChanged(
                                PatientTreatmentInitialView.payments,
                              ),
                        ),
                        const SizedBox(height: 10),
                        _TreatmentPatientAccessCard(
                          title: 'Documentos clínicos',
                          subtitle: 'Archivos compartidos por la clínica',
                          icon: Icons.folder_shared_outlined,
                          onTap:
                              widget.onOpenClinicalFiles ??
                              () => widget.onViewChanged(
                                PatientTreatmentInitialView.clinicalFiles,
                              ),
                        ),
                        if (widget.onOpenAppointments != null) ...[
                          const SizedBox(height: 10),
                          _PatientActionButton(
                            icon: Icons.event_note_outlined,
                            label: 'Ver citas relacionadas',
                            onTap: widget.onOpenAppointments!,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _PatientClinicalSummaryCard(
                          treatment: selectedTreatment,
                          lastUpdate: historial.isEmpty
                              ? selectedTreatment.updatedAt
                              : (historial.first.fechaEfectiva ??
                                    historial.first.fechaCambio),
                        ),
                        if (historial.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(
                            'Notas clínicas del tratamiento',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          StageHistoryList(
                            historial: historial,
                            isAdmin: false,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _CollapsibleTreatmentStages(
                          expanded: _stagesExpanded,
                          onToggle: () => setState(
                            () => _stagesExpanded = !_stagesExpanded,
                          ),
                          children: TreatmentStage.values.asMap().entries.map((
                            entry,
                          ) {
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
                                : (idx == 0
                                      ? selectedTreatment.fechaInicio
                                      : null);

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
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
          },
        );
      },
    );
  }

  PatientTreatment _resolveSelectedTreatment(
    List<PatientTreatment> treatments,
  ) {
    if (_selectedTreatmentId != null) {
      for (final treatment in treatments) {
        if (treatment.id == _selectedTreatmentId) return treatment;
      }
    }
    for (final treatment in treatments) {
      if (treatment.isPrimary) return treatment;
    }
    for (final treatment in treatments) {
      if (!treatment.isFinished) return treatment;
    }
    return treatments.first;
  }
}

class _CollapsibleTreatmentStages extends StatelessWidget {
  const _CollapsibleTreatmentStages({
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OcgColors.bronze.withValues(alpha: 0.14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x102C2016),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Etapas del tratamiento',
                      style: TextStyle(
                        color: Color(0xFF1A1410),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: OcgColors.bronze,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: children),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _TreatmentEmbeddedSubview extends StatelessWidget {
  const _TreatmentEmbeddedSubview({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onBack,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            12,
            MediaQuery.paddingOf(context).top + 12,
            18,
            14,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [OcgColors.espresso, Color(0xFF4A3628)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Volver a Tratamiento',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: OcgColors.ivory,
              ),
              const SizedBox(width: 4),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: OcgColors.ivory.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: OcgColors.ivory.withValues(alpha: 0.16),
                  ),
                ),
                child: Icon(icon, color: OcgColors.ivory, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: OcgColors.ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: OcgColors.ivory.withValues(alpha: 0.78),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _TreatmentPatientAccessCard extends StatelessWidget {
  const _TreatmentPatientAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: OcgColors.bronze.withValues(alpha: 0.14)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x102C2016),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EDE8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: OcgColors.espresso),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: OcgColors.bronze,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: OcgColors.bronze),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEW: Premium treatment selector card (multiple treatments)
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumTreatmentSelectorCard extends StatelessWidget {
  const _PremiumTreatmentSelectorCard({
    required this.treatment,
    required this.selected,
    required this.progress,
    required this.onTap,
  });

  final PatientTreatment treatment;
  final bool selected;
  final int progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFFBF7)
              : OcgColors.ivory.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFFE2C4A7)
                : OcgColors.ivory.withOpacity(0.16),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFD4A97A).withOpacity(0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + progress pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    treatment.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? OcgColors.espresso : OcgColors.ivory,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? OcgColors.espresso
                        : OcgColors.ivory.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$progress%',
                    style: TextStyle(
                      color: selected ? OcgColors.ivory : OcgColors.ivory,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Thin progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 3,
                backgroundColor: selected
                    ? const Color(0xFFE4D5C5)
                    : const Color(0xFF3A2A1E),
                valueColor: AlwaysStoppedAnimation<Color>(
                  selected ? OcgColors.espresso : const Color(0xFFD4A97A),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Stage name
            Text(
              stageNames[treatment.etapaActual] ?? treatment.etapaActual.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF6E5644)
                    : OcgColors.ivory.withOpacity(0.58),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEW: Premium single treatment badge (when only one treatment exists)
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumSingleTreatmentBadge extends StatelessWidget {
  const _PremiumSingleTreatmentBadge({
    required this.treatment,
    required this.progress,
  });

  final PatientTreatment treatment;
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: OcgColors.ivory.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OcgColors.ivory.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          // Circular mini progress
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    value: progress / 100,
                    strokeWidth: 4,
                    backgroundColor: OcgColors.ivory.withOpacity(0.18),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFD4A97A),
                    ),
                  ),
                ),
                Text(
                  '$progress%',
                  style: const TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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
                Text(
                  treatment.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stageNames[treatment.etapaActual] ??
                      treatment.etapaActual.name,
                  style: TextStyle(
                    color: OcgColors.ivory.withOpacity(0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: OcgColors.ivory.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              treatment.isPrimary ? 'Principal' : treatment.statusLabel,
              style: const TextStyle(
                color: OcgColors.ivory,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Existing widgets (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _PatientProgressCard extends StatelessWidget {
  const _PatientProgressCard({
    required this.progress,
    required this.currentStage,
    required this.currentStep,
    required this.totalSteps,
  });

  final int progress;
  final String currentStage;
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8D8C8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D2C2016),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progreso del tratamiento',
            style: TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: progress / 100,
                        strokeWidth: 10,
                        backgroundColor: const Color(0xFFE7D8C9),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          OcgColors.bronze,
                        ),
                      ),
                    ),
                    Text(
                      '$progress%',
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
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
                    Text(
                      'Fase actual: $currentStage',
                      style: const TextStyle(
                        color: Color(0xFF1A1410),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$currentStep de $totalSteps etapas completadas',
                      style: const TextStyle(
                        color: Color(0xFF6E5644),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 10,
              backgroundColor: const Color(0xFFE8D8C8),
              valueColor: const AlwaysStoppedAnimation<Color>(OcgColors.bronze),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientClinicalSummaryCard extends StatelessWidget {
  const _PatientClinicalSummaryCard({
    required this.treatment,
    required this.lastUpdate,
  });

  final PatientTreatment treatment;
  final DateTime lastUpdate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8D8C8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D2C2016),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen clínico',
            style: TextStyle(
              color: Color(0xFF1A1410),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Objetivo: seguimiento de ${PatientTreatment.labelForBaseTreatment(treatment.tipoBase).toLowerCase()} para este tratamiento.',
            style: const TextStyle(color: Color(0xFF6E5644), height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            (treatment.notas ?? '').trim().isEmpty
                ? 'Observaciones del ortodoncista: aún no hay notas registradas para este tratamiento.'
                : 'Observaciones del ortodoncista: ${treatment.notas!.trim()}',
            style: const TextStyle(color: Color(0xFF6E5644), height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            'Recomendaciones actuales: consulta pagos y citas desde el contexto del tratamiento activo para evitar mezclar información.',
            style: const TextStyle(color: Color(0xFF6E5644), height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            'Última actualización: ${_fmtDate(lastUpdate)}',
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientActionButton extends StatelessWidget {
  const _PatientActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBF8), Color(0xFFF5ECE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7D8C9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D2C2016),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: OcgColors.espresso),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: OcgColors.espresso,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
