import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';

class FcmPayloadRouter {
  const FcmPayloadRouter();

  void routeFromPayload(
    GoRouter router,
    Map<String, dynamic> data, {
    String? userRole,
  }) {
    final route = resolveRoute(data, userRole: userRole);
    if (route == null || route.isEmpty) return;
    router.go(route);
  }

  String? resolveRoute(Map<String, dynamic> data, {String? userRole}) {
    final explicitRoute = (data['route'] ?? '').toString().trim();
    if (explicitRoute.isNotEmpty) {
      return explicitRoute;
    }

    final type = (data['type'] ?? '').toString().trim();
    final entityType = (data['entityType'] ?? '').toString().trim();
    final patientId = (data['patientId'] ?? data['recipientId'] ?? '').toString().trim();

    if (_isAppointmentType(type) || entityType == 'appointment') {
      return userRole == 'admin'
          ? RouteNames.adminAppointments
          : RouteNames.patientAppointments;
    }

    if (_isPaymentType(type) || entityType == 'payment') {
      return userRole == 'admin'
          ? RouteNames.adminPayments
          : RouteNames.patientPayments;
    }

    if (_isTreatmentType(type) || entityType == 'treatment') {
      return userRole == 'admin'
          ? (patientId.isEmpty
                ? RouteNames.adminTreatments
                : RouteNames.adminPatientDetail.replaceFirst(':patientId', patientId))
          : RouteNames.patientHome;
    }

    switch (type) {
      case 'patient_notification':
        return RouteNames.patientNotifications;
      case 'simulation':
        return userRole == 'admin'
            ? RouteNames.adminSimulator
            : RouteNames.patientSimulations;
      case 'patient_detail':
        if (patientId.isEmpty) return RouteNames.adminPatients;
        return RouteNames.adminPatientDetail.replaceFirst(':patientId', patientId);
      default:
        return userRole == 'admin'
            ? RouteNames.adminDashboard
            : RouteNames.patientNotifications;
    }
  }

  bool _isAppointmentType(String type) {
    return type == 'appointment' ||
        type == 'appointment_created' ||
        type == 'appointment_cancelled' ||
        type == 'appointment_rescheduled' ||
        type == 'appointment_reminder';
  }

  bool _isPaymentType(String type) {
    return type == 'payment' ||
        type == 'payment_received' ||
        type == 'payment_due';
  }

  bool _isTreatmentType(String type) {
    return type == 'treatment' ||
        type == 'treatment_stage_updated';
  }
}
