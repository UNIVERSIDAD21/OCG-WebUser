import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../presentation/web/common/web_layout_context.dart';
import '../../features/dashboard/presentation/admin_appointments_screen.dart';
import '../../features/dashboard/presentation/admin_dashboard_screen.dart';
import '../../features/dashboard/presentation/admin_modules_screens.dart';
import '../../features/dashboard/presentation/admin_mobile_shell.dart';
import '../../features/dashboard/presentation/admin_notifications_screen.dart';
import '../../features/dashboard/presentation/admin_patients_screen.dart';
import '../../features/dashboard/presentation/admin_profile_screen.dart';
import '../../features/dashboard/presentation/patient_home_screen.dart';
import '../../features/notifications/presentation/patient_notifications_screen.dart';
import '../../features/patients/presentation/patient_detail_screen.dart';
import '../../features/patients/presentation/patient_form_screen.dart';
import '../../features/payments/presentation/payu_checkout_screen.dart';
import 'route_names.dart';

bool _isPublicRoute(String location) {
  return location == RouteNames.login || location == RouteNames.forgotPassword;
}

bool _isAdminRoute(String location) => location.startsWith('/admin');
bool _isPatientRoute(String location) => location.startsWith('/patient');

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this.ref) {
    _authSub = ref.listen<AsyncValue<dynamic>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
    _roleSub = ref.listen<AsyncValue<dynamic>>(
      userRoleProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref ref;
  ProviderSubscription<AsyncValue<dynamic>>? _authSub;
  ProviderSubscription<AsyncValue<dynamic>>? _roleSub;

  @override
  void dispose() {
    _authSub?.close();
    _roleSub?.close();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authState = ref.read(authStateProvider);
      final userRole = ref.read(userRoleProvider);
      final isLoggedIn = authState.asData?.value != null;
      final authFlowLoading = ref.read(authNotifierProvider).isLoading;
      developer.log(
        'router redirect evaluate',
        name: 'ocg.router',
        error: {
          'location': location,
          'authLoading': authState.isLoading,
          'authFlowLoading': authFlowLoading,
          'isLoggedIn': isLoggedIn,
          'roleLoading': userRole.isLoading,
          'roleValue': userRole.asData?.value,
        },
      );

      if (authState.isLoading || authFlowLoading) {
        return location == RouteNames.splash ? null : RouteNames.splash;
      }

      if (!isLoggedIn) {
        if (location == RouteNames.splash) return RouteNames.login;
        return _isPublicRoute(location) ? null : RouteNames.login;
      }

      if (userRole.isLoading) {
        // Nunca renderizar zonas protegidas mientras resolvemos rol/perfil.
        // Evita el rebote visual login -> home -> login en sesiones inválidas.
        return location == RouteNames.splash ? null : RouteNames.splash;
      }

      final role = userRole.asData?.value;
      if (role == null) {
        return location == RouteNames.splash ? null : RouteNames.splash;
      }
      final effectiveRole = role == 'admin' ? 'admin' : 'patient';

      if (location == RouteNames.splash || _isPublicRoute(location)) {
        return effectiveRole == 'admin'
            ? RouteNames.adminDashboard
            : RouteNames.patientHome;
      }

      if (effectiveRole == 'admin' && _isPatientRoute(location)) {
        return RouteNames.adminDashboard;
      }

      if (effectiveRole == 'patient' && _isAdminRoute(location)) {
        return RouteNames.patientHome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const _AuthResolvingScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.adminRoot,
        redirect: (context, state) => RouteNames.adminDashboard,
      ),
      GoRoute(
        path: RouteNames.adminDashboard,
        builder: (context, state) => const _AdminTabRoute(
          mobileIndex: 0,
          desktopChild: AdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminPatients,
        builder: (context, state) => const _AdminTabRoute(
          mobileIndex: 1,
          desktopChild: AdminPatientsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminAppointments,
        builder: (context, state) => const _AdminTabRoute(
          mobileIndex: 2,
          desktopChild: AdminAppointmentsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminTreatments,
        builder: (context, state) => const AdminTreatmentsScreen(),
      ),
      GoRoute(
        path: RouteNames.adminPayments,
        builder: (context, state) => const AdminPaymentsScreen(),
      ),
      GoRoute(
        path: RouteNames.adminSimulator,
        builder: (context, state) => const _AdminTabRoute(
          mobileIndex: 3,
          desktopChild: AdminSimulatorScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminProfile,
        builder: (context, state) => const _AdminTabRoute(
          mobileIndex: 4,
          desktopChild: AdminProfileScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminNotifications,
        builder: (context, state) => const AdminNotificationsScreen(),
      ),
      GoRoute(
        path: RouteNames.adminPatientDetail,
        builder: (context, state) {
          final patientId = state.pathParameters['patientId'] ?? '';
          if (WebLayoutContext.useDesktopShell(context)) {
            return PatientDetailScreen(patientId: patientId);
          }
          return AdminMobileShell(
            initialIndex: 1,
            detailChild: PatientDetailScreen(
              patientId: patientId,
              embeddedInAdminMobileShell: true,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.adminPatientNew,
        builder: (context, state) => const PatientFormScreen(),
      ),
      GoRoute(
        path: RouteNames.adminPatientEdit,
        builder: (context, state) {
          final patientId = state.pathParameters['patientId'] ?? '';
          return PatientFormScreen(patientId: patientId);
        },
      ),
      GoRoute(
        path: RouteNames.patientRoot,
        redirect: (context, state) => RouteNames.patientHome,
      ),
      GoRoute(
        path: RouteNames.patientHome,
        builder: (context, state) => const PatientHomeScreen(),
      ),
      GoRoute(
        path: RouteNames.patientTreatment,
        builder: (context, state) => const PatientHomeScreen(initialSection: 2),
      ),
      GoRoute(
        path: RouteNames.patientAppointments,
        builder: (context, state) => const PatientHomeScreen(initialSection: 1),
      ),
      GoRoute(
        path: RouteNames.patientProfile,
        builder: (context, state) => const PatientHomeScreen(initialSection: 4),
      ),
      GoRoute(
        path: RouteNames.patientNotifications,
        builder: (context, state) => const PatientNotificationsScreen(),
      ),
      GoRoute(
        path: RouteNames.patientClinicalFiles,
        builder: (context, state) => const PatientHomeScreen(
          initialSection: 2,
          initialTreatmentView: PatientTreatmentInitialView.clinicalFiles,
        ),
      ),
      GoRoute(
        path: RouteNames.patientPayments,
        builder: (context, state) => const PatientHomeScreen(
          initialSection: 2,
          initialTreatmentView: PatientTreatmentInitialView.payments,
        ),
      ),
      GoRoute(
        path: RouteNames.patientSimulations,
        builder: (context, state) => const PatientHomeScreen(initialSection: 3),
      ),
      GoRoute(
        path: RouteNames.patientPayuCheckout,
        builder: (context, state) {
          final url = state.uri.queryParameters['checkoutUrl'] ?? '';
          return PayuCheckoutScreen(checkoutUrl: url);
        },
      ),
    ],
  );
});

class _AdminTabRoute extends StatelessWidget {
  const _AdminTabRoute({required this.mobileIndex, required this.desktopChild});

  final int mobileIndex;
  final Widget desktopChild;

  @override
  Widget build(BuildContext context) {
    if (WebLayoutContext.useDesktopShell(context)) {
      return desktopChild;
    }

    return AdminMobileShell(initialIndex: mobileIndex);
  }
}

class _AuthResolvingScreen extends StatefulWidget {
  const _AuthResolvingScreen();

  @override
  State<_AuthResolvingScreen> createState() => _AuthResolvingScreenState();
}

class _AuthResolvingScreenState extends State<_AuthResolvingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
    );
    _scale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 1, curve: Curves.elasticOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEDE8DC),
                  Color(0xFFF5F0E6),
                  Color(0xFFE8E0D4),
                  Color(0xFFF0EBDD),
                ],
              ),
            ),
          ),

          // ── Decorative blobs ──
          Positioned(
            top: -100,
            right: -60,
            child: _SplashBlob(size: 300, color: const Color(0x38C8AF8C)),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: _SplashBlob(size: 250, color: const Color(0x28B49B78)),
          ),
          Positioned(
            top: 220,
            left: -30,
            child: _SplashBlob(size: 130, color: const Color(0x1A8C6239)),
          ),

          // ── Floating dots ──
          const _SplashDot(top: 120, right: 50, size: 4, delayMs: 200),
          const _SplashDot(top: 200, right: 80, size: 3, delayMs: 700),
          const _SplashDot(bottom: 180, left: 70, size: 5, delayMs: 1200),
          const _SplashDot(bottom: 280, left: 40, size: 3, delayMs: 1800),

          // ── Center content ──
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ScaleTransition(
                  scale: _scale,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2C2016), Color(0xFF5B3C26)],
                        ),
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2C2016).withOpacity(0.18),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'OCG',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Tagline
                FadeTransition(
                  opacity: _fade,
                  child: const Text(
                    'Human Bionics',
                    style: TextStyle(
                      color: Color(0xFF6E5442),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom loading indicator ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 48,
            left: 0,
            right: 0,
            child: Center(
              child: _SplashLoadingBar(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _SplashBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0, 0.7],
        ),
      ),
    );
  }
}

class _SplashDot extends StatefulWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double size;
  final int delayMs;

  const _SplashDot({
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.size,
    required this.delayMs,
  });

  @override
  State<_SplashDot> createState() => _SplashDotState();
}

class _SplashDotState extends State<_SplashDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, __) {
        final y = -3 + 6 * _dotCtrl.value;
        final opacity = 0.15 + 0.15 * _dotCtrl.value;
        return Positioned(
          top: widget.top,
          right: widget.right,
          bottom: widget.bottom,
          left: widget.left,
          child: Transform.translate(
            offset: Offset(0, y),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: const Color(0xFF8C6239).withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SplashLoadingBar extends StatefulWidget {
  @override
  State<_SplashLoadingBar> createState() => _SplashLoadingBarState();
}

class _SplashLoadingBarState extends State<_SplashLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barCtrl;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: AnimatedBuilder(
          animation: _barCtrl,
          builder: (_, __) {
            final t = _barCtrl.value;
            final left = t < 0.5 ? 0.0 : (t - 0.5) * 2 * 72;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Container(color: const Color(0xFFD9CCBE)),
                ),
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC8AF8C), Color(0xFF8A6F59)],
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
