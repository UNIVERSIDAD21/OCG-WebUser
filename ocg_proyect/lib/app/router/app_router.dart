import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/dashboard/presentation/admin_dashboard_screen.dart';
import '../../features/dashboard/presentation/admin_patients_screen.dart';
import '../../features/dashboard/presentation/patient_appointments_screen.dart';
import '../../features/dashboard/presentation/patient_home_screen.dart';
import '../../features/patients/presentation/patient_detail_screen.dart';
import '../../features/patients/presentation/patient_form_screen.dart';
import '../../features/patients/presentation/patient_profile_screen.dart';
import 'route_names.dart';

bool _isPublicRoute(String location) {
  return location == RouteNames.login || location == RouteNames.forgotPassword;
}

bool _isAdminRoute(String location) => location.startsWith('/admin');
bool _isPatientRoute(String location) => location.startsWith('/patient');

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userRole = ref.watch(userRoleProvider);

  return GoRouter(
    initialLocation: RouteNames.login,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isLoggedIn = authState.asData?.value != null;

      if (authState.isLoading) return null;

      if (!isLoggedIn) {
        return _isPublicRoute(location) ? null : RouteNames.login;
      }

      // Anti-race authState vs role: no navegar a zonas protegidas hasta resolver el rol.
      if (userRole.isLoading) {
        return _isPublicRoute(location) ? null : RouteNames.login;
      }

      final role = userRole.asData?.value;
      final effectiveRole = role == 'admin' ? 'admin' : 'patient';

      if (_isPublicRoute(location)) {
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
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.adminPatients,
        builder: (context, state) => const AdminPatientsScreen(),
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
    ],
  );
});
