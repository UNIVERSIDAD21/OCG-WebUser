import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/domain/appointments_business_rules.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _seedAvailability(BuildContext context) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'seedAvailability',
      );
      await callable.call(<String, dynamic>{'days': 90});

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disponibilidad inicial creada para 90 días.'),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'No se pudo inicializar disponibilidad.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo inicializar disponibilidad.')),
      );
    }
  }

  Future<void> _initializeAllPayments(BuildContext context) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'initializeAllPaymentDocuments',
      );
      final result = await callable.call();
      final data = (result.data as Map?)?.cast<String, dynamic>() ?? const {};
      final created = data['created'];
      final message =
          data['message']?.toString() ?? 'Inicialización completada.';

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$message (creados: $created)')));
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'No se pudo inicializar pagos.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo inicializar pagos.')),
      );
    }
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar tu sesión de administrador?'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(authNotifierProvider).isLoading;
    final appointmentsAsync = ref.watch(appointmentsProvider);
    final patientsAsync = ref.watch(patientsStreamProvider);

    final dashboardBody = _DashboardBody(
      ref: ref,
      onSignOut: () => _handleSignOut(context, ref),
      loading: loading,
      appointmentsAsync: appointmentsAsync,
      patientsAsync: patientsAsync,
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      return AdminWebShell(title: 'Dashboard', child: dashboardBody);
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 0,
      title: 'Dashboard',
      appBarActions: [
        TextButton.icon(
          onPressed: () => _initializeAllPayments(context),
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: const Text('Inicializar pagos'),
        ),
        IconButton(
          tooltip: 'Inicializar disponibilidad (90 días)',
          onPressed: () => _seedAvailability(context),
          icon: const Icon(Icons.auto_awesome_motion_outlined),
        ),
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
      showMobileAppBar: false,
      body: dashboardBody,
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.ref,
    required this.onSignOut,
    required this.loading,
    required this.appointmentsAsync,
    required this.patientsAsync,
  });

  final WidgetRef ref;
  final VoidCallback onSignOut;
  final bool loading;
  final AsyncValue<List<AppointmentModel>> appointmentsAsync;
  final AsyncValue<List<PatientModel>> patientsAsync;

  @override
  Widget build(BuildContext context) {
    final appointments =
        appointmentsAsync.asData?.value ?? const <AppointmentModel>[];
    final patients = patientsAsync.asData?.value ?? const <PatientModel>[];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final todaysAppointments =
        appointments
            .where(
              (a) =>
                  !a.fechaHora.isBefore(todayStart) &&
                  a.fechaHora.isBefore(tomorrowStart) &&
                  AppointmentsBusinessRules.shouldIncludeInDayAgenda(a.estado),
            )
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

    final pendingConfirm = todaysAppointments
        .where((a) => a.estado == AppointmentStatus.programada)
        .length;

    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final canceladasSemana = appointments
        .where(
          (a) =>
              a.estado == AppointmentStatus.cancelada &&
              a.fechaHora.isAfter(sevenDaysAgo),
        )
        .length;

    final nuevosPacientes30d = patients
        .where(
          (p) =>
              p.createdAt != null &&
              p.createdAt!.isAfter(now.subtract(const Duration(days: 30))),
        )
        .length;

    final citasSinConfirmar2h = todaysAppointments
        .where(
          (a) =>
              a.estado == AppointmentStatus.programada &&
              a.fechaHora.isAfter(now) &&
              a.fechaHora.isBefore(now.add(const Duration(hours: 2))),
        )
        .length;

    final perfilesPendientes = patients
        .where((p) => p.tipoTratamiento == null || p.telefono.trim().isEmpty)
        .length;

    final pagosVencidos = patients
        .where(
          (p) =>
              p.saldoPendiente > 0 &&
              p.fechaProximoPago != null &&
              p.fechaProximoPago!.isBefore(todayStart),
        )
        .length;

    final isMobile = MediaQuery.of(context).size.width <= 800;

    if (isMobile) {
      return _MobileAdminDashboard(
        ref: ref,
        todaysAppointments: todaysAppointments,
        pendingConfirm: pendingConfirm,
        canceladasSemana: canceladasSemana,
        nuevosPacientes30d: nuevosPacientes30d,
        citasSinConfirmar2h: citasSinConfirmar2h,
        perfilesPendientes: perfilesPendientes,
        pagosVencidos: pagosVencidos,
        loadingAppointments: appointmentsAsync.isLoading,
        appointmentsError: appointmentsAsync.hasError,
      );
    }

    return _WebAdminDashboard(
      ref: ref,
      todaysAppointments: todaysAppointments,
      pendingConfirm: pendingConfirm,
      canceladasSemana: canceladasSemana,
      nuevosPacientes30d: nuevosPacientes30d,
      citasSinConfirmar2h: citasSinConfirmar2h,
      perfilesPendientes: perfilesPendientes,
      pagosVencidos: pagosVencidos,
      loadingAppointments: appointmentsAsync.isLoading,
      appointmentsError: appointmentsAsync.hasError,
    );
  }
}

class _MobileAdminDashboard extends StatelessWidget {
  const _MobileAdminDashboard({
    required this.ref,
    required this.todaysAppointments,
    required this.pendingConfirm,
    required this.canceladasSemana,
    required this.nuevosPacientes30d,
    required this.citasSinConfirmar2h,
    required this.perfilesPendientes,
    required this.pagosVencidos,
    required this.loadingAppointments,
    required this.appointmentsError,
  });

  final WidgetRef ref;
  final List<AppointmentModel> todaysAppointments;
  final int pendingConfirm;
  final int canceladasSemana;
  final int nuevosPacientes30d;
  final int citasSinConfirmar2h;
  final int perfilesPendientes;
  final int pagosVencidos;
  final bool loadingAppointments;
  final bool appointmentsError;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const wd = [
      'LUNES',
      'MARTES',
      'MIÉRCOLES',
      'JUEVES',
      'VIERNES',
      'SÁBADO',
      'DOMINGO',
    ];
    const months = [
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];
    final dateLabel =
        '${wd[now.weekday - 1]} ${now.day} DE ${months[now.month - 1]} · ${now.year}';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              18,
              MediaQuery.paddingOf(context).top + 14,
              18,
              18,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF21170F), OcgColors.espresso],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Builder(
                      builder: (ctx) => InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Scaffold.of(ctx).openDrawer(),
                        child: Container(
                          width: 38,
                          height: 38,
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
                        'Panel Admin',
                        style: TextStyle(
                          color: OcgColors.ivory,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: OcgColors.ivory.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.notifications_none,
                        color: OcgColors.ivory,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: OcgColors.bronze,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'AD',
                        style: TextStyle(
                          color: OcgColors.ivory,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: OcgColors.ivory.withOpacity(0.68),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.45,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Buenos días, Admin',
                  style: TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Centro operativo del día',
                  style: TextStyle(
                    color: OcgColors.ivory.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1E2C2016),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.35,
                  children: [
                    _MobileKpiMini(
                      value: '${todaysAppointments.length}',
                      title: 'Citas hoy',
                      subtitle: 'programadas',
                      bg: const Color(0xFFF6EFE7),
                    ),
                    _MobileKpiMini(
                      value: '$pendingConfirm',
                      title: 'Sin confirmar',
                      subtitle: 'pendientes',
                      bg: const Color(0xFFFFF4D8),
                    ),
                    _MobileKpiMini(
                      value: '$canceladasSemana',
                      title: 'Canceladas',
                      subtitle: 'últimos 7 días',
                      bg: const Color(0xFFFFECEC),
                    ),
                    _MobileKpiMini(
                      value: '$nuevosPacientes30d',
                      title: 'Nuevos',
                      subtitle: 'últimos 30 días',
                      bg: const Color(0xFFEFF8F0),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _MobileSectionTitle('Acceso rápido'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MobileQuickCard(
                        icon: Icons.people_outline,
                        label: 'Pacientes',
                        onTap: () => context.go(RouteNames.adminPatients),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MobileQuickCard(
                        icon: Icons.calendar_month_outlined,
                        label: 'Agenda',
                        onTap: () => context.go(RouteNames.adminAppointments),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MobileQuickCard(
                        icon: Icons.person_add_outlined,
                        label: 'Nuevo paciente',
                        onTap: () => context.go(RouteNames.adminPatients),
                        emphasized: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _MobileSectionTitle('Alertas operativas'),
                const SizedBox(height: 10),
                _MobileAlertCard(
                  icon: Icons.schedule,
                  title:
                      '$citasSinConfirmar2h cita${citasSinConfirmar2h == 1 ? '' : 's'} sin confirmar',
                  subtitle: 'Revisar próximas 2 horas',
                  bg: const Color(0xFFFFF4D8),
                  iconColor: OcgColors.warning,
                ),
                const SizedBox(height: 8),
                _MobileAlertCard(
                  icon: Icons.description_outlined,
                  title: '$perfilesPendientes perfiles incompletos',
                  subtitle: 'Pendientes de actualización',
                  bg: const Color(0xFFF6EFE7),
                  iconColor: OcgColors.bronze,
                ),
                const SizedBox(height: 8),
                _MobileAlertCard(
                  icon: Icons.payments_outlined,
                  title: '$pagosVencidos pagos vencidos',
                  subtitle: 'Seguimiento financiero requerido',
                  bg: const Color(0xFFFFECEC),
                  iconColor: OcgColors.error,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: _MobileSectionTitle('Agenda de hoy')),
                    TextButton(
                      onPressed: () => context.go(RouteNames.adminAppointments),
                      child: const Text(
                        'Ver todo >',
                        style: TextStyle(
                          color: OcgColors.bronze,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (loadingAppointments)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (appointmentsError)
                  const Text('No se pudo cargar la agenda del día.')
                else if (todaysAppointments.isEmpty)
                  const Text('No hay citas programadas para hoy.')
                else
                  ...todaysAppointments
                      .take(8)
                      .map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MobileAgendaCard(appointment: a, ref: ref),
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

class _WebAdminDashboard extends StatelessWidget {
  const _WebAdminDashboard({
    required this.ref,
    required this.todaysAppointments,
    required this.pendingConfirm,
    required this.canceladasSemana,
    required this.nuevosPacientes30d,
    required this.citasSinConfirmar2h,
    required this.perfilesPendientes,
    required this.pagosVencidos,
    required this.loadingAppointments,
    required this.appointmentsError,
  });

  final WidgetRef ref;
  final List<AppointmentModel> todaysAppointments;
  final int pendingConfirm;
  final int canceladasSemana;
  final int nuevosPacientes30d;
  final int citasSinConfirmar2h;
  final int perfilesPendientes;
  final int pagosVencidos;
  final bool loadingAppointments;
  final bool appointmentsError;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const wd = [
      'LUNES',
      'MARTES',
      'MIÉRCOLES',
      'JUEVES',
      'VIERNES',
      'SÁBADO',
      'DOMINGO',
    ];
    const months = [
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];
    final dateLabel =
        '${wd[now.weekday - 1]} ${now.day} DE ${months[now.month - 1]} · ${now.year}';

    final kpiGrid = GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 2.0,
      children: [
        _MobileKpiMini(
          value: '${todaysAppointments.length}',
          title: 'Citas hoy',
          subtitle: 'programadas',
          bg: const Color(0xFFF6EFE7),
          onTap: () => context.go(RouteNames.adminAppointments),
        ),
        _MobileKpiMini(
          value: '$pendingConfirm',
          title: 'Sin confirmar',
          subtitle: 'pendientes',
          bg: const Color(0xFFFFF4D8),
          onTap: () => context.go(RouteNames.adminAppointments),
        ),
        _MobileKpiMini(
          value: '$canceladasSemana',
          title: 'Canceladas',
          subtitle: 'últimos 7 días',
          bg: const Color(0xFFFFECEC),
          onTap: () => context.go(RouteNames.adminAppointments),
        ),
        _MobileKpiMini(
          value: '$nuevosPacientes30d',
          title: 'Nuevos',
          subtitle: 'últimos 30 días',
          bg: const Color(0xFFEFF8F0),
          onTap: () => context.go(RouteNames.adminPatients),
        ),
      ],
    );

    final quick = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MobileSectionTitle('Acceso rápido'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MobileQuickCard(
                icon: Icons.people_outline,
                label: 'Pacientes',
                onTap: () => context.go(RouteNames.adminPatients),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MobileQuickCard(
                icon: Icons.calendar_month_outlined,
                label: 'Agenda',
                onTap: () => context.go(RouteNames.adminAppointments),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MobileQuickCard(
          icon: Icons.person_add_outlined,
          label: 'Nuevo paciente',
          onTap: () => context.go(RouteNames.adminPatients),
          emphasized: true,
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 1100;
              final left = Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1C1208),
                      Color(0xFF2C2016),
                      Color(0xFF3A281B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.fromLTRB(42, 34, 42, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6E5442),
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Buenos días,\nAdmin',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: OcgColors.ivory,
                        height: 1.04,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Centro operativo del día',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9A735C)),
                    ),
                  ],
                ),
              );

              final agendaItems = todaysAppointments.take(5).toList();

              final right = Container(
                height: 318,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDFC),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE8DDD2)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Expanded(
                                child: _MobileSectionTitle('Agenda de hoy'),
                              ),
                              if (todaysAppointments.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6EFE7),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: const Color(0xFFE2D0BC),
                                    ),
                                  ),
                                  child: Text(
                                    '${agendaItems.length}/5',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9A735C),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.go(RouteNames.adminAppointments),
                          child: const Text(
                            'Ver todo >',
                            style: TextStyle(
                              color: OcgColors.bronze,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Builder(
                        builder: (_) {
                          if (loadingAppointments) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (appointmentsError) {
                            return const Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                'No se pudo cargar la agenda del día.',
                              ),
                            );
                          }
                          if (todaysAppointments.isEmpty) {
                            return const Align(
                              alignment: Alignment.topLeft,
                              child: Text('No hay citas programadas para hoy.'),
                            );
                          }

                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                ...agendaItems.map(
                                  (a) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _MobileAgendaCard(
                                      appointment: a,
                                      ref: ref,
                                    ),
                                  ),
                                ),
                                if (todaysAppointments.length > 5)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Mostrando las primeras 5 citas del día.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9A735C),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );

              if (narrow) {
                return Column(
                  children: [left, const SizedBox(height: 14), right],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [left, const SizedBox(height: 10), kpiGrid],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [right, const SizedBox(height: 10), quick],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final split = constraints.maxWidth >= 1100;

              if (split) {
                return const SizedBox.shrink();
              }

              return Column(
                children: [kpiGrid, const SizedBox(height: 14), quick],
              );
            },
          ),
          const SizedBox(height: 16),
          const _MobileSectionTitle('Alertas operativas'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 1100 ? 3 : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: cols == 3 ? 2.7 : 4.0,
                children: [
                  _MobileAlertCard(
                    icon: Icons.schedule,
                    title:
                        '$citasSinConfirmar2h cita${citasSinConfirmar2h == 1 ? '' : 's'} sin confirmar',
                    subtitle: 'Revisar próximas 2 horas',
                    bg: const Color(0xFFFFF9ED),
                    iconColor: const Color(0xFFC99730),
                  ),
                  _MobileAlertCard(
                    icon: Icons.description_outlined,
                    title: '$perfilesPendientes perfiles incompletos',
                    subtitle: 'Pendientes de actualización',
                    bg: const Color(0xFFFBF8F4),
                    iconColor: OcgColors.bronze,
                  ),
                  _MobileAlertCard(
                    icon: Icons.payments_outlined,
                    title: '$pagosVencidos pagos vencidos',
                    subtitle: 'Seguimiento financiero requerido',
                    bg: const Color(0xFFFFF4F4),
                    iconColor: OcgColors.error,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MobileSectionTitle extends StatelessWidget {
  const _MobileSectionTitle(this.title);
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

class _MobileKpiMini extends StatelessWidget {
  const _MobileKpiMini({
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: OcgColors.ink,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: OcgColors.espresso,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF7E6754)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileQuickCard extends StatelessWidget {
  const _MobileQuickCard({
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
          border: Border.all(
            color: emphasized ? OcgColors.espresso : const Color(0xFFE7D6C6),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: emphasized
                    ? OcgColors.ivory.withOpacity(0.14)
                    : const Color(0xFFF2EDE8),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: fg),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileAlertCard extends StatelessWidget {
  const _MobileAlertCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.iconColor,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x26C4A890)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: OcgColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF7B6654),
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

class _MobileAgendaCard extends StatelessWidget {
  const _MobileAgendaCard({required this.appointment, required this.ref});

  final AppointmentModel appointment;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (appointment.estado) {
      AppointmentStatus.programada => ('Sin confirmar', OcgColors.warning),
      AppointmentStatus.confirmada => ('Confirmada', const Color(0xFF1565C0)),
      AppointmentStatus.completada => ('Completada', OcgColors.success),
      AppointmentStatus.cancelada => ('Cancelada', OcgColors.error),
      AppointmentStatus.noAsistio => ('No asistió', OcgColors.error),
      AppointmentStatus.reprogramada => ('Reprogramada', Colors.purple),
    };

    final initials = appointment.patientName.trim().isEmpty
        ? 'P'
        : appointment.patientName
              .trim()
              .split(' ')
              .where((e) => e.isNotEmpty)
              .take(2)
              .map((e) => e[0].toUpperCase())
              .join();

    final canConfirm = appointment.estado == AppointmentStatus.programada;
    final canComplete = appointment.estado == AppointmentStatus.confirmada;
    final canReschedule =
        appointment.estado == AppointmentStatus.programada ||
        appointment.estado == AppointmentStatus.confirmada;
    final canCancel =
        appointment.estado == AppointmentStatus.programada ||
        appointment.estado == AppointmentStatus.confirmada;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7D6C6)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFFF2EDE8),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.patientName.isEmpty
                            ? 'Paciente sin nombre'
                            : appointment.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: OcgColors.ink,
                        ),
                      ),
                      Text(
                        '${_TodayAgendaCard._fmtHour(appointment.fechaHora)} · ${_TodayAgendaCard._tipoLabel(appointment.tipo)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7B6654),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${appointment.duracionMinutos} min · ${appointment.patientPhone.isEmpty ? 'Sin teléfono' : appointment.patientPhone}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A735C),
                        ),
                      ),
                      if ((appointment.notas ?? '').trim().isNotEmpty)
                        Text(
                          appointment.notas!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9A735C),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEFE2D6)),
          Row(
            children: [
              _AgendaActionCell(
                icon: Icons.check_circle_outline,
                label: 'Confirmar',
                color: OcgColors.success,
                enabled: canConfirm,
                onTap: () =>
                    _TodayAgendaCard(
                      ref: ref,
                      loading: false,
                      hasError: false,
                      appointments: const [],
                    )._updateStatus(
                      context,
                      appointment,
                      AppointmentStatus.confirmada,
                    ),
              ),
              _AgendaActionCell(
                icon: Icons.task_alt,
                label: 'Completar',
                color: OcgColors.success,
                enabled: canComplete,
                onTap: () =>
                    _TodayAgendaCard(
                      ref: ref,
                      loading: false,
                      hasError: false,
                      appointments: const [],
                    )._updateStatus(
                      context,
                      appointment,
                      AppointmentStatus.completada,
                    ),
              ),
              _AgendaActionCell(
                icon: Icons.edit_calendar_outlined,
                label: 'Reprogramar',
                color: OcgColors.bronze,
                enabled: canReschedule,
                onTap: () => _TodayAgendaCard(
                  ref: ref,
                  loading: false,
                  hasError: false,
                  appointments: const [],
                )._showRescheduleDialog(context, appointment),
              ),
              _AgendaActionCell(
                icon: Icons.cancel_outlined,
                label: 'Cancelar',
                color: OcgColors.error,
                enabled: canCancel,
                onTap: () =>
                    _TodayAgendaCard(
                      ref: ref,
                      loading: false,
                      hasError: false,
                      appointments: const [],
                    )._updateStatus(
                      context,
                      appointment,
                      AppointmentStatus.cancelada,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgendaActionCell extends StatelessWidget {
  const _AgendaActionCell({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? color : const Color(0xFFC2B3A5);
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 58,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Color(0xFFEFE2D6), width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({
    required this.citasSinConfirmar2h,
    required this.perfilesPendientes,
    required this.pagosVencidos,
  });

  final int citasSinConfirmar2h;
  final int perfilesPendientes;
  final int pagosVencidos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alertas operativas',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 8),
          _AlertRow(
            label: 'Citas en < 2h sin confirmar',
            value: citasSinConfirmar2h,
          ),
          _AlertRow(
            label: 'Perfiles pendientes de completar',
            value: perfilesPendientes,
          ),
          _AlertRow(label: 'Pagos vencidos', value: pagosVencidos),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final isCritical = value > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isCritical
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            size: 16,
            color: isCritical ? OcgColors.warning : OcgColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isCritical ? OcgColors.warning : OcgColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayAgendaCard extends StatelessWidget {
  const _TodayAgendaCard({
    required this.ref,
    required this.loading,
    required this.hasError,
    required this.appointments,
  });

  final WidgetRef ref;
  final bool loading;
  final bool hasError;
  final List<AppointmentModel> appointments;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agenda de hoy',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasError)
            const Text('No se pudo cargar la agenda del día.')
          else if (appointments.isEmpty)
            const Text('No hay citas programadas para hoy.')
          else
            ...appointments.map(
              (a) => Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OcgColors.mist,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OcgColors.bronze.withOpacity(0.18)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: OcgColors.ivory,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _fmtHour(a.fechaHora),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.patientName.isEmpty
                                    ? 'Paciente sin nombre'
                                    : a.patientName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_tipoLabel(a.tipo)} • ${a.duracionMinutos} min',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: OcgColors.ink.withOpacity(0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(status: a.estado),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (a.estado == AppointmentStatus.programada)
                          _ActionBtn(
                            tooltip: 'Confirmar',
                            icon: Icons.check_circle_outline,
                            color: OcgColors.success,
                            onTap: () => _updateStatus(
                              context,
                              a,
                              AppointmentStatus.confirmada,
                            ),
                          ),
                        if (a.estado == AppointmentStatus.confirmada)
                          _ActionBtn(
                            tooltip: 'Completar',
                            icon: Icons.task_alt,
                            color: OcgColors.success,
                            onTap: () => _updateStatus(
                              context,
                              a,
                              AppointmentStatus.completada,
                            ),
                          ),
                        if (a.estado == AppointmentStatus.programada ||
                            a.estado == AppointmentStatus.confirmada)
                          _ActionBtn(
                            tooltip: 'Reprogramar',
                            icon: Icons.edit_calendar_outlined,
                            color: OcgColors.bronze,
                            onTap: () => _showRescheduleDialog(context, a),
                          ),
                        if (a.estado == AppointmentStatus.programada ||
                            a.estado == AppointmentStatus.confirmada)
                          _ActionBtn(
                            tooltip: 'Cancelar',
                            icon: Icons.cancel_outlined,
                            color: OcgColors.error,
                            onTap: () => _updateStatus(
                              context,
                              a,
                              AppointmentStatus.cancelada,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    AppointmentModel appointment,
    AppointmentStatus status,
  ) async {
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(appointment.id, status);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado de cita actualizado.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    }
  }

  Future<void> _showRescheduleDialog(
    BuildContext context,
    AppointmentModel appointment,
  ) async {
    final existingAppointments =
        ref.read(appointmentsProvider).asData?.value ??
        const <AppointmentModel>[];
    DateTime selected = appointment.fechaHora.add(const Duration(days: 1));

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        DateTime localSelected = selected;

        List<AppointmentTimeSlot> slotsForDay(DateTime day) {
          return AppointmentsBusinessRules.buildDailySlots(
            day: day,
            existingAppointments: existingAppointments,
            durationMinutes: appointment.duracionMinutos,
            excludeAppointmentId: appointment.id,
            stepMinutes: AppointmentsBusinessRules.slotStepMinutes,
          );
        }

        return StatefulBuilder(
          builder: (ctx, setDs) => AlertDialog(
            title: const Text('Reprogramar cita'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Nueva fecha: ${_fmtDateTime(localSelected)}'),
                    subtitle: const Text(
                      'Horario laboral L-V 08:00-12:00 / 14:00-18:00 · Sáb 08:00-12:00',
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: localSelected,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 120)),
                      );
                      if (d == null) return;
                      final firstAvailable = slotsForDay(
                        d,
                      ).where((s) => s.isAvailable).firstOrNull;
                      setDs(() {
                        localSelected =
                            firstAvailable?.start ??
                            DateTime(
                              d.year,
                              d.month,
                              d.day,
                              AppointmentsBusinessRules.workdayStartHour,
                              0,
                            );
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: slotsForDay(localSelected).map((slot) {
                      final label =
                          '${slot.start.hour.toString().padLeft(2, '0')}:${slot.start.minute.toString().padLeft(2, '0')}';
                      return ChoiceChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            color: slot.isAvailable
                                ? OcgColors.espresso
                                : Colors.grey.shade600,
                          ),
                        ),
                        selected:
                            slot.start == localSelected && slot.isAvailable,
                        disabledColor: Colors.grey.shade300,
                        selectedColor: OcgColors.sand,
                        onSelected: slot.isAvailable
                            ? (_) => setDs(() => localSelected = slot.start)
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => popDialog(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OcgColors.bronze,
                  foregroundColor: OcgColors.ivory,
                ),
                onPressed: () => popDialog(ctx, localSelected),
                child: const Text('Reprogramar'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    final workingHoursError =
        AppointmentsBusinessRules.validateWithinWorkingHours(
          start: result,
          durationMinutes: appointment.duracionMinutos,
        );
    if (workingHoursError != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(workingHoursError)));
      return;
    }

    final hasConflict = AppointmentsBusinessRules.hasTimeConflict(
      existingAppointments: existingAppointments,
      newStart: result,
      durationMinutes: appointment.duracionMinutos,
      excludeAppointmentId: appointment.id,
    );
    if (hasConflict) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ese horario está ocupado o dentro del buffer de 10 min.',
          ),
        ),
      );
      return;
    }

    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .rescheduleAppointment(
            originalId: appointment.id,
            newAppointment: appointment.copyWith(
              id: '',
              fechaHora: result,
              estado: AppointmentStatus.programada,
            ),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita reprogramada exitosamente.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo reprogramar: $e')));
    }
  }

  static String _fmtDateTime(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${d.year} ${hour12.toString().padLeft(2, '0')}:$minute $suffix';
  }

  static String _tipoLabel(AppointmentType t) => switch (t) {
    AppointmentType.valoracion => 'Valoración',
    AppointmentType.control => 'Control',
    AppointmentType.instalacion => 'Instalación',
    AppointmentType.urgencia => 'Urgencia',
    AppointmentType.alta => 'Alta',
  };

  static String _fmtHour(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AppointmentStatus.programada => ('Programada', OcgColors.bronze),
      AppointmentStatus.confirmada => ('Confirmada', const Color(0xFF1565C0)),
      AppointmentStatus.completada => ('Completada', OcgColors.success),
      AppointmentStatus.cancelada => ('Cancelada', OcgColors.error),
      AppointmentStatus.noAsistio => ('No asistió', OcgColors.error),
      AppointmentStatus.reprogramada => ('Reprogramada', Colors.purple),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OcgColors.ivory,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: OcgColors.bronze, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OcgColors.espresso,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.of(context).size.width > 800) return const SizedBox.shrink();

    final loading = ref.watch(authNotifierProvider).isLoading;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: loading
            ? null
            : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text(
                      '¿Deseas cerrar tu sesión de administrador?',
                    ),
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
                    const SnackBar(content: Text('No se pudo cerrar sesión.')),
                  );
                }
              },
        icon: const Icon(Icons.logout, color: OcgColors.error),
        label: const Text(
          'Cerrar sesión',
          style: TextStyle(color: OcgColors.error),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: OcgColors.error.withOpacity(0.08),
          side: BorderSide(color: OcgColors.error.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
