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
import '../../features/dashboard/presentation/patient_appointments_screen.dart';
import '../../features/dashboard/presentation/patient_home_screen.dart';
import '../../features/notifications/presentation/patient_notifications_screen.dart';
import '../../features/patients/presentation/patient_detail_screen.dart';
import '../../features/patients/presentation/patient_form_screen.dart';
import '../../features/patients/presentation/patient_profile_screen.dart';
import '../../features/payments/presentation/payu_checkout_screen.dart';
import '../../features/simulator/presentation/patient_simulations_screen.dart';
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
          return PatientDetailScreen(patientId: patientId);
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
        path: RouteNames.patientAppointments,
        builder: (context, state) => const PatientAppointmentsScreen(),
      ),
      GoRoute(
        path: RouteNames.patientProfile,
        builder: (context, state) => const PatientProfileScreen(),
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
        builder: (context, state) => const PatientSimulationsScreen(),
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

class _AuthResolvingScreen extends StatelessWidget {
  const _AuthResolvingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
