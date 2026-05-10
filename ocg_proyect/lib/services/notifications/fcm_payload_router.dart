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
    RouteNames.patientTreatment,
    RouteNames.patientAppointments,
    RouteNames.patientPayments,
    RouteNames.patientClinicalFiles,
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
    final role = userRole == 'admin' ? 'admin' : 'patient';
    final type = (data['type'] ?? '').toString().trim();
    final entityType = (data['entityType'] ?? '').toString().trim();

    // ── Admin blindaje: convertir rutas paciente a rutas admin
    // antes de cualquier otro procesamiento. Sin esto el redirect
    // global del router manda al admin al dashboard.
    if (role == 'admin') {
      final adminRoute = _resolveAdminRoute(
        explicitRoute,
        data,
        type: type,
        entityType: entityType,
      );
      if (adminRoute != null) return adminRoute;
    }

    if (explicitRoute.isNotEmpty) {
      final normalizedRoute = _normalizeExplicitRoute(
        explicitRoute,
        role: role,
        type: type,
        entityType: entityType,
      );
      if (normalizedRoute != null) return normalizedRoute;
      if (_isAllowedInternalRoute(explicitRoute)) {
        return explicitRoute;
      }
      _logRejectedRoute(explicitRoute, data, userRole: userRole);
    }

    return _fallbackRoute(
      data,
      userRole: userRole,
      roleOverride: role,
      typeOverride: type,
      entityTypeOverride: entityType,
    );
  }

  static bool _entityMatches(String entityType, String keyword) {
    return entityType.toLowerCase().contains(keyword);
  }

  /// Convierte cualquier ruta/indicio paciente a su equivalente admin.
  /// NUNCA retorna null para admins — siempre devuelve una ruta admin.
  String? _resolveAdminRoute(
    String explicitRoute,
    Map<String, dynamic> data, {
    required String type,
    required String entityType,
  }) {
    final patientId = _patientIdFromPayload(data, 'admin');

    // Si hay una ruta explícita de paciente, convertirla a admin.
    if (explicitRoute.isNotEmpty && explicitRoute.startsWith('/patient')) {
      final uri = Uri.tryParse(explicitRoute);
      if (uri != null) {
        final converted = _convertPatientRouteToAdmin(uri, patientId);
        if (converted != null) return converted;

        // Fallback: si no pudimos convertir la ruta paciente (p.ej. patientId
        // vacío), resolvemos semánticamente por tipo de notificación.
        if (_isTreatmentNotification(type, entityType)) {
          return RouteNames.adminTreatments;
        }
        if (_isSimulationType(type) || _entityMatches(entityType, 'simulation') || _entityMatches(entityType, 'simulador')) {
          return RouteNames.adminSimulator;
        }
        if (_isPaymentType(type) || _entityMatches(entityType, 'payment') || _entityMatches(entityType, 'pago')) {
          return RouteNames.adminPayments;
        }
        // Último recurso: volver al detalle del paciente si hay ID,
        // o a la lista de pacientes.
        if (patientId.isNotEmpty) {
          return _adminPatientSectionRoute(patientId, 'resumen');
        }
        return RouteNames.adminPatients;
      }
    }

    // Sin ruta explícita: resolver semánticamente por tipo.
    if (explicitRoute.isEmpty) {
      if (_isTreatmentNotification(type, entityType)) {
        return patientId.isEmpty
            ? RouteNames.adminTreatments
            : _adminPatientSectionRoute(patientId, 'tratamientos');
      }
      if (_isAppointmentType(type) || _entityMatches(entityType, 'appointment') || _entityMatches(entityType, 'cita')) {
        return patientId.isEmpty
            ? RouteNames.adminAppointments
            : _adminPatientSectionRoute(patientId, 'citas');
      }
      if (_isPaymentType(type) || _entityMatches(entityType, 'payment') || _entityMatches(entityType, 'pago')) {
        return RouteNames.adminPayments;
      }
      if (_isSimulationType(type) || _entityMatches(entityType, 'simulation') || _entityMatches(entityType, 'simulador')) {
        return patientId.isEmpty
            ? RouteNames.adminSimulator
            : _adminPatientSectionRoute(patientId, 'simulador');
      }
    }

    return null;
  }

  /// Convierte una URI de paciente a la ruta admin equivalente.
  String? _convertPatientRouteToAdmin(Uri uri, String patientId) {
    final path = uri.path;
    final section = uri.queryParameters['section'] ?? '';

    if (path == RouteNames.patientHome || path == RouteNames.patientRoot ||
        path == RouteNames.patientTreatment) {
      // Home o tratamiento → tratamientos si es notificación de tratamiento,
      // sino la sección del query param, sino detalle paciente genérico.
      if (patientId.isNotEmpty) {
        final targetSection = section.isNotEmpty ? section : 'tratamientos';
        return _adminPatientSectionRoute(patientId, targetSection);
      }
      return RouteNames.adminPatients;
    }

    if (path == RouteNames.patientAppointments) {
      return patientId.isEmpty
          ? RouteNames.adminAppointments
          : _adminPatientSectionRoute(patientId, 'citas');
    }

    if (path == RouteNames.patientPayments ||
        path == RouteNames.patientClinicalFiles) {
      return RouteNames.adminPayments;
    }

    if (path == RouteNames.patientSimulations) {
      return patientId.isEmpty
          ? RouteNames.adminSimulator
          : _adminPatientSectionRoute(patientId, 'simulador');
    }

    if (path == RouteNames.patientProfile) {
      return patientId.isEmpty
          ? RouteNames.adminPatients
          : _adminPatientSectionRoute(patientId, 'resumen');
    }

    if (path == RouteNames.patientNotifications) {
      return RouteNames.adminNotifications;
    }

    // Ruta paciente no reconocida → fallback al detalle del paciente.
    if (patientId.isNotEmpty) {
      return _adminPatientSectionRoute(patientId, 'resumen');
    }
    return RouteNames.adminPatients;
  }

  String? _normalizeExplicitRoute(
    String route, {
    required String role,
    required String type,
    required String entityType,
  }) {
    if (role != 'patient') return null;

    final uri = Uri.tryParse(route);
    if (uri == null || uri.hasAuthority) return null;

    // Notificaciones con ruta genérica del home: priorizar el destino
    // semántico según tipo de notificación para no abrir Inicio cuando
    // el evento pertenece a otra sección.
    if (uri.path == RouteNames.patientHome && uri.queryParameters.isEmpty) {
      if (_isTreatmentNotification(type, entityType)) {
        return RouteNames.patientTreatment;
      }
      if (_isAppointmentType(type) || _entityMatches(entityType, 'appointment') || _entityMatches(entityType, 'cita')) {
        return RouteNames.patientAppointments;
      }
      if (_isSimulationType(type) || _entityMatches(entityType, 'simulation') || _entityMatches(entityType, 'simulador')) {
        return RouteNames.patientSimulations;
      }
      if (_isPaymentType(type) || _entityMatches(entityType, 'payment') || _entityMatches(entityType, 'pago')) {
        return RouteNames.patientPayments;
      }
      if (_isClinicalFileType(type) || _isClinicalFileEntity(entityType)) {
        return RouteNames.patientClinicalFiles;
      }
    }

    return null;
  }

  bool _isTreatmentNotification(String type, String entityType) {
    return _isTreatmentType(type) ||
        entityType.toLowerCase().contains('treatment') ||
        entityType.toLowerCase().contains('tratamiento');
  }

  String _fallbackRoute(
    Map<String, dynamic> data, {
    String? userRole,
    String? roleOverride,
    String? typeOverride,
    String? entityTypeOverride,
  }) {
    final role = roleOverride ?? (userRole == 'admin' ? 'admin' : 'patient');
    final type = typeOverride ?? (data['type'] ?? '').toString().trim();
    final entityType =
        entityTypeOverride ?? (data['entityType'] ?? '').toString().trim();
    final patientId = _patientIdFromPayload(data, role);

    if (_isAppointmentType(type) || _entityMatches(entityType, 'appointment') || _entityMatches(entityType, 'cita')) {
      if (role == 'admin' && patientId.isNotEmpty) {
        return _adminPatientSectionRoute(patientId, 'citas');
      }
      return role == 'admin'
          ? RouteNames.adminAppointments
          : RouteNames.patientAppointments;
    }

    if (_isPaymentType(type) || _entityMatches(entityType, 'payment') || _entityMatches(entityType, 'pago')) {
      if (role == 'admin' && patientId.isNotEmpty) {
        return _adminPatientSectionRoute(patientId, 'pagos');
      }
      return role == 'admin'
          ? RouteNames.adminPayments
          : RouteNames.patientPayments;
    }

    if (role == 'patient' &&
        (_isClinicalFileType(type) || _isClinicalFileEntity(entityType))) {
      return RouteNames.patientClinicalFiles;
    }

    if (_isSimulationType(type) || _entityMatches(entityType, 'simulation') || _entityMatches(entityType, 'simulador')) {
      if (role == 'admin') {
        return patientId.isEmpty
            ? RouteNames.adminSimulator
            : _adminPatientSectionRoute(patientId, 'simulador');
      }
      return RouteNames.patientSimulations;
    }

    if (role == 'patient' &&
        (_isProfileType(type) || _entityMatches(entityType, 'profile') || _entityMatches(entityType, 'perfil'))) {
      return RouteNames.patientProfile;
    }

    if (_isTreatmentNotification(type, entityType)) {
      if (role == 'admin') {
        return patientId.isEmpty
            ? RouteNames.adminTreatments
            : _adminPatientSectionRoute(patientId, 'tratamientos');
      }
      return RouteNames.patientTreatment;
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

    // recipientId es un patientId confiable tanto para pacientes
    // como para admins (cuando el admin ve notificaciones de un paciente
    // específico, recipientId = id del paciente).
    final recipientId = (data['recipientId'] ?? '').toString().trim();
    if (recipientId.isNotEmpty) return recipientId;

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

  bool _isTreatmentType(String type) {
    final t = type.toLowerCase();
    return t.contains('treatment') || t.contains('tratamiento');
  }

  bool _isAppointmentType(String type) {
    final t = type.toLowerCase();
    return t.contains('appointment') || t.contains('cita');
  }

  bool _isPaymentType(String type) {
    final t = type.toLowerCase();
    return t.contains('payment') || t.contains('pago') || t.contains('payu');
  }

  bool _isSimulationType(String type) {
    final t = type.toLowerCase();
    return t.contains('simulation') || t.contains('simulador');
  }

  bool _isClinicalFileType(String type) {
    final t = type.toLowerCase();
    return t.contains('clinical_file') ||
        t.contains('clinical') ||
        t.contains('document') ||
        t.contains('archivo') ||
        t.contains('documento');
  }

  bool _isClinicalFileEntity(String entityType) {
    final e = entityType.toLowerCase();
    return e.contains('clinical') ||
        e.contains('document') ||
        e.contains('treatment_file') ||
        e.contains('treatmentFile');
  }

  bool _isProfileType(String type) {
    final t = type.toLowerCase();
    return t.contains('profile') || t.contains('perfil');
  }
}
