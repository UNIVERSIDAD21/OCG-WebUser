import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/app/router/route_names.dart';
import 'package:ocg_proyect/services/notifications/fcm_payload_router.dart';

void main() {
  group('FcmPayloadRouter', () {
    final payloadRouter = FcmPayloadRouter();

    test('usa route explícita si viene en payload', () {
      final route = payloadRouter.resolveRoute({
        'route': RouteNames.patientNotifications,
      }, userRole: 'patient');

      expect(route, RouteNames.patientNotifications);
    });

    test('appointment enruta a admin agenda', () {
      final route = payloadRouter.resolveRoute({
        'type': 'appointment',
      }, userRole: 'admin');
      expect(route, RouteNames.adminAppointments);
    });

    test('payment enruta a patient payments', () {
      final route = payloadRouter.resolveRoute({
        'type': 'payment',
      }, userRole: 'patient');
      expect(route, RouteNames.patientPayments);
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

    test('si no reconoce payload cae al home según rol', () {
      final route = payloadRouter.resolveRoute(const {}, userRole: 'patient');
      expect(route, RouteNames.patientHome);
    });
  });
}
