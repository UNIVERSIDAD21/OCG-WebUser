import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/dashboard/presentation/admin_dashboard_screen.dart';
import '../../features/dashboard/presentation/patient_home_screen.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RouteNames.login,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      if (!isLoggedIn) {
        if (state.matchedLocation == RouteNames.login || state.matchedLocation == RouteNames.forgotPassword) {
          return null;
        }
        return RouteNames.login;
      }

      if (state.matchedLocation == RouteNames.login || state.matchedLocation == RouteNames.splash) {
        return RouteNames.patientHome;
      }
      return null;
    },
    routes: [
      GoRoute(path: RouteNames.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: RouteNames.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: RouteNames.adminDashboard, builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(path: RouteNames.patientHome, builder: (_, __) => const PatientHomeScreen()),
    ],
  );
});
