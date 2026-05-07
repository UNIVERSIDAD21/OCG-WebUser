import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';

class FcmPayloadRouter {
  const FcmPayloadRouter();

  static const _allowedPatientSections = {
    'resumen',
    'tratamientos',
    'pagos',
    'docs',
    'documentos',
    'historial',
    'citas',
    'simulador',
  };

  static const _allowedStaticRoutes = {
    RouteNames.adminRoot,
    RouteNames.adminDashboard,
    RouteNames.adminPatients,
    RouteNames.adminAppointments,
    RouteNames.adminTreatments,
    RouteNames.adminPayments,
    RouteNames.adminSimulator,
    RouteNames.adminProfile,
    RouteNames.adminNotifications,
    RouteNames.patientRoot,
    RouteNames.patientHome,
    RouteNames.patientAppointments,
    RouteNames.patientPayments,
    RouteNames.patientSimulations,
    RouteNames.patientNotifications,
    RouteNames.patientProfile,
  };

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
    final explicitRoute = (data['route'] ?? data['targetRoute'] ?? '')
        .toString()
        .trim();
    if (explicitRoute.isNotEmpty) {
      if (_isAllowedInternalRoute(explicitRoute)) {
        return explicitRoute;
      }
      _logRejectedRoute(explicitRoute, data, userRole: userRole);
    }

    return _fallbackRoute(data, userRole: userRole);
  }

  String _fallbackRoute(Map<String, dynamic> data, {String? userRole}) {
    final role = userRole == 'admin' ? 'admin' : 'patient';
    final type = (data['type'] ?? '').toString().trim();
    final entityType = (data['entityType'] ?? '').toString().trim();
    final patientId = _patientIdFromPayload(data, role);

    if (_isAppointmentType(type) || entityType == 'appointment') {
      if (role == 'admin' && patientId.isNotEmpty) {
        return _adminPatientSectionRoute(patientId, 'citas');
      }
      return role == 'admin'
          ? RouteNames.adminAppointments
          : RouteNames.patientAppointments;
    }

    if (_isPaymentType(type) || entityType == 'payment') {
      if (role == 'admin' && patientId.isNotEmpty) {
        return _adminPatientSectionRoute(patientId, 'pagos');
      }
      return role == 'admin'
          ? RouteNames.adminPayments
          : RouteNames.patientPayments;
    }

    if (_isSimulationType(type) || entityType == 'simulation') {
      if (role == 'admin') {
        return patientId.isEmpty
            ? RouteNames.adminSimulator
            : _adminPatientSectionRoute(patientId, 'simulador');
      }
      return RouteNames.patientSimulations;
    }

    if (_isTreatmentType(type) || entityType == 'treatment') {
      if (role == 'admin') {
        return patientId.isEmpty
            ? RouteNames.adminTreatments
            : _adminPatientSectionRoute(patientId, 'tratamientos');
      }
      return RouteNames.patientHome;
    }

    switch (type) {
      case 'patient_notification':
        return RouteNames.patientNotifications;
      case 'patient_detail':
        if (patientId.isEmpty) return RouteNames.adminPatients;
        return RouteNames.adminPatientDetail.replaceFirst(
          ':patientId',
          patientId,
        );
      default:
        return role == 'admin'
            ? RouteNames.adminRoot
            : RouteNames.patientNotifications;
    }
  }

  bool _isAllowedInternalRoute(String route) {
    final lowerRoute = route.toLowerCase();
    if (!route.startsWith('/')) return false;
    if (lowerRoute.startsWith('http://') || lowerRoute.startsWith('https://')) {
      return false;
    }
    if (route.startsWith('//') || route.contains('://')) return false;

    final uri = Uri.tryParse(route);
    if (uri == null || uri.hasAuthority) return false;
    if (uri.fragment.isNotEmpty) return false;

    final path = uri.path;
    final segments = uri.pathSegments;
    if (segments.any((segment) => segment.contains('.'))) return false;

    if (_allowedStaticRoutes.contains(path)) {
      return uri.queryParameters.isEmpty;
    }

    if (_isAdminPatientDetailRoute(uri)) return true;

    return false;
  }

  bool _isAdminPatientDetailRoute(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length != 3 ||
        segments[0] != 'admin' ||
        segments[1] != 'patients') {
      return false;
    }

    final patientId = segments[2].trim();
    if (patientId.isEmpty || patientId == 'new') return false;

    final queryKeys = uri.queryParameters.keys.toSet();
    if (queryKeys.isEmpty) return true;
    if (queryKeys.length != 1 || !queryKeys.contains('section')) return false;

    final section = uri.queryParameters['section'] ?? '';
    return _allowedPatientSections.contains(section);
  }

  String _patientIdFromPayload(Map<String, dynamic> data, String role) {
    final patientId = (data['patientId'] ?? '').toString().trim();
    if (patientId.isNotEmpty) return patientId;

    // recipientId solo es un patientId confiable para notificaciones del paciente.
    if (role == 'patient') {
      return (data['recipientId'] ?? '').toString().trim();
    }

    return '';
  }

  String _adminPatientSectionRoute(String patientId, String section) {
    final detailRoute = RouteNames.adminPatientDetail.replaceFirst(
      ':patientId',
      Uri.encodeComponent(patientId),
    );
    return '$detailRoute?section=$section';
  }

  void _logRejectedRoute(
    String route,
    Map<String, dynamic> data, {
    String? userRole,
  }) {
    debugPrint(
      'Notification route rejected: '
      '{ route: $route, '
      'type: ${(data['type'] ?? '').toString()}, '
      'entityType: ${(data['entityType'] ?? '').toString()}, '
      'userRole: ${userRole ?? ''} }',
    );
  }

  bool _isAppointmentType(String type) {
    return type == 'appointment' ||
        type == 'appointment_created' ||
        type == 'appointment_cancelled' ||
        type == 'appointment_rescheduled' ||
        type == 'appointment_reminder' ||
        type == 'appointment_pending_confirmation';
  }

  bool _isPaymentType(String type) {
    return type == 'payment' ||
        type == 'payment_received' ||
        type == 'payment_due' ||
        type == 'payment_reported' ||
        type == 'payment_pending_validation' ||
        type == 'payment_failed' ||
        type == 'payment_overdue' ||
        type == 'payment_due_soon';
  }

  bool _isSimulationType(String type) {
    return type == 'simulation' || type == 'simulation_ready';
  }

  bool _isTreatmentType(String type) {
    return type == 'treatment' || type == 'treatment_stage_updated';
  }
}
