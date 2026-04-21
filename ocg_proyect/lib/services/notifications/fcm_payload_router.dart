import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';

class FcmPayloadRouter {
  const FcmPayloadRouter();

  void routeFromPayload(
    GoRouter router,
    Map<String, dynamic> data, {
    String? userRole,
  }) {
    final route = _resolveRoute(data, userRole: userRole);
    if (route == null || route.isEmpty) return;
    router.go(route);
  }

  String? _resolveRoute(Map<String, dynamic> data, {String? userRole}) {
    final explicitRoute = (data['route'] ?? '').toString().trim();
    if (explicitRoute.isNotEmpty) {
      return explicitRoute;
    }

    final type = (data['type'] ?? '').toString().trim();
    final patientId = (data['patientId'] ?? data['entityId'] ?? '')
        .toString()
        .trim();

    switch (type) {
      case 'patient_notification':
        return RouteNames.patientNotifications;
      case 'appointment':
        return userRole == 'admin'
            ? RouteNames.adminAppointments
            : RouteNames.patientAppointments;
      case 'payment':
        return userRole == 'admin'
            ? RouteNames.adminPayments
            : RouteNames.patientPayments;
      case 'simulation':
        return userRole == 'admin'
            ? RouteNames.adminSimulator
            : RouteNames.patientSimulations;
      case 'patient_detail':
        if (patientId.isEmpty) return RouteNames.adminPatients;
        return RouteNames.adminPatientDetail.replaceFirst(
          ':patientId',
          patientId,
        );
      default:
        return userRole == 'admin'
            ? RouteNames.adminDashboard
            : RouteNames.patientHome;
    }
  }
}
