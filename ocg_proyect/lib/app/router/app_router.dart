import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/dashboard/presentation/admin_dashboard_screen.dart';
import '../../features/dashboard/presentation/admin_patients_screen.dart';
import '../../features/dashboard/presentation/patient_appointments_screen.dart';
import '../../features/dashboard/presentation/patient_home_screen.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userRole = ref.watch(userRoleProvider);

  return GoRouter(
    initialLocation: RouteNames.login,
    redirect: (context, state) {
      final isLoggedIn = authState.asData?.value != null;
      final isLoading = authState.isLoading || userRole.isLoading;

      if (isLoading) return null;

      if (!isLoggedIn) {
        const allowed = [RouteNames.login, RouteNames.forgotPassword];
        if (!allowed.contains(state.matchedLocation)) return RouteNames.login;
        return null;
      }

      final role = userRole.asData?.value;

      if (state.matchedLocation == RouteNames.login) {
        return role == 'admin' ? RouteNames.adminDashboard : RouteNames.patientHome;
      }

      if (role == 'admin' && state.matchedLocation.startsWith('/patient')) {
        return RouteNames.adminDashboard;
      }

      if (role == 'patient' && state.matchedLocation.startsWith('/admin')) {
        return RouteNames.patientHome;
      }

      return null;
    },
    routes: [
      GoRoute(path: RouteNames.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: RouteNames.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: RouteNames.adminDashboard, builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: RouteNames.adminPatients, builder: (context, state) => const AdminPatientsScreen()),
      GoRoute(path: RouteNames.patientHome, builder: (context, state) => const PatientHomeScreen()),
      GoRoute(path: RouteNames.patientAppointments, builder: (context, state) => const PatientAppointmentsScreen()),
    ],
  );
});
