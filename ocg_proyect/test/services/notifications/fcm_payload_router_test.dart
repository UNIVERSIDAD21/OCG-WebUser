import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/app/router/route_names.dart';
import 'package:ocg_proyect/services/notifications/fcm_payload_router.dart';

void main() {
  group('FcmPayloadRouter', () {
    final payloadRouter = FcmPayloadRouter();

    test('route válida admin patient detail con section=citas se acepta', () {
      final route = payloadRouter.resolveRoute({
        'route': '/admin/patients/p1?section=citas',
        'type': 'appointment',
        'entityType': 'appointment',
      }, userRole: 'admin');

      expect(route, '/admin/patients/p1?section=citas');
    });

    test('route https://google.com se rechaza y cae a fallback seguro', () {
      final route = payloadRouter.resolveRoute({
        'route': 'https://google.com',
        'type': 'payment',
        'entityType': 'payment',
        'patientId': 'p1',
      }, userRole: 'admin');

      expect(route, '/admin/patients/p1?section=pagos');
    });

    test('route admin/patients/123 sin slash se rechaza', () {
      final route = payloadRouter.resolveRoute({
        'route': 'admin/patients/123',
        'type': 'appointment',
        'entityType': 'appointment',
        'patientId': '123',
      }, userRole: 'admin');

      expect(route, '/admin/patients/123?section=citas');
    });

    test('route /ruta-rara se rechaza y hace fallback', () {
      final route = payloadRouter.resolveRoute({
        'route': '/ruta-rara',
        'type': 'unknown',
      }, userRole: 'admin');

      expect(route, RouteNames.adminRoot);
    });

    test('admin appointment sin route con patientId abre section=citas', () {
      final route = payloadRouter.resolveRoute({
        'type': 'appointment',
        'entityType': 'appointment',
        'patientId': 'p1',
      }, userRole: 'admin');

      expect(route, '/admin/patients/p1?section=citas');
    });

    test('admin payment sin route con patientId abre section=pagos', () {
      final route = payloadRouter.resolveRoute({
        'type': 'payment',
        'entityType': 'payment',
        'patientId': 'p1',
      }, userRole: 'admin');

      expect(route, '/admin/patients/p1?section=pagos');
    });

    test('admin simulation sin route con patientId abre section=simulador', () {
      final route = payloadRouter.resolveRoute({
        'type': 'simulation',
        'entityType': 'simulation',
        'patientId': 'p1',
      }, userRole: 'admin');

      expect(route, '/admin/patients/p1?section=simulador');
    });

    test('admin simulation sin patientId abre simulador admin', () {
      final route = payloadRouter.resolveRoute({
        'type': 'simulation',
        'entityType': 'simulation',
      }, userRole: 'admin');

      expect(route, RouteNames.adminSimulator);
    });

    test('patient appointment abre /patient/appointments', () {
      final route = payloadRouter.resolveRoute({
        'type': 'appointment',
        'entityType': 'appointment',
      }, userRole: 'patient');

      expect(route, RouteNames.patientAppointments);
    });

    test('patient payment abre /patient/payments', () {
      final route = payloadRouter.resolveRoute({
        'type': 'payment',
        'entityType': 'payment',
      }, userRole: 'patient');

      expect(route, RouteNames.patientPayments);
    });

    test('patient document abre /patient/clinical-files', () {
      final route = payloadRouter.resolveRoute({
        'type': 'clinical_file_shared',
        'entityType': 'clinical_file',
      }, userRole: 'patient');

      expect(route, RouteNames.patientClinicalFiles);
    });

    test('patient simulation abre /patient/simulations', () {
      final route = payloadRouter.resolveRoute({
        'type': 'simulation_ready',
        'entityType': 'simulation',
      }, userRole: 'patient');

      expect(route, RouteNames.patientSimulations);
    });

    test('patient profile abre /patient/profile', () {
      final route = payloadRouter.resolveRoute({
        'type': 'patient_profile',
        'entityType': 'profile',
      }, userRole: 'patient');

      expect(route, RouteNames.patientProfile);
    });

    test('route explícita /patient/clinical-files de paciente se acepta', () {
      final route = payloadRouter.resolveRoute({
        'route': RouteNames.patientClinicalFiles,
        'type': 'document_shared',
      }, userRole: 'patient');

      expect(route, RouteNames.patientClinicalFiles);
    });

    test('unknown admin abre /admin', () {
      final route = payloadRouter.resolveRoute({
        'type': 'unknown',
      }, userRole: 'admin');

      expect(route, RouteNames.adminRoot);
    });

    test('unknown patient abre /patient/notifications', () {
      final route = payloadRouter.resolveRoute({
        'type': 'unknown',
      }, userRole: 'patient');

      expect(route, RouteNames.patientNotifications);
    });

    test('route explícita válida de paciente se acepta', () {
      final route = payloadRouter.resolveRoute({
        'route': RouteNames.patientNotifications,
      }, userRole: 'patient');

      expect(route, RouteNames.patientNotifications);
    });

    test('patient_detail usa patientId del payload', () {
      final route = payloadRouter.resolveRoute({
        'type': 'patient_detail',
        'patientId': 'abc123',
      }, userRole: 'admin');

      expect(
        route,
        RouteNames.adminPatientDetail.replaceFirst(':patientId', 'abc123'),
      );
    });
  });
}
