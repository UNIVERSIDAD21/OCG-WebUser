import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/payments/services/payu_service.dart';

void main() {
  group('PayuService.createPaymentSession', () {
    test('envía treatmentId al callable createPayuSession', () async {
      Map<String, dynamic>? captured;
      final service = PayuService(
        createPayuSessionInvoker: (payload) async {
          captured = Map<String, dynamic>.from(payload);
          return {'checkoutUrl': 'https://payu.test/checkout'};
        },
      );

      final url = await service.createPaymentSession(
        patientId: 'p1',
        treatmentId: 'tx-1',
        monto: 100,
        saldoPendiente: 100,
        patientEmail: 'a@b.com',
        patientName: 'Paciente',
      );

      expect(url, 'https://payu.test/checkout');
      expect(captured, isNotNull);
      expect(captured!['patientId'], 'p1');
      expect(captured!['treatmentId'], 'tx-1');
      expect(captured!['monto'], 100.0);
    });

    test('rechaza treatmentId vacío antes de llamar backend', () async {
      final service = PayuService();

      await expectLater(
        () => service.createPaymentSession(
          patientId: 'p1',
          treatmentId: '   ',
          monto: 100,
          saldoPendiente: 100,
          patientEmail: 'a@b.com',
          patientName: 'Paciente',
        ),
        throwsA(
          isA<FirebaseFunctionsException>().having(
            (error) => error.code,
            'code',
            'invalid-argument',
          ),
        ),
      );
    });

    test('rechaza monto mayor al saldo pendiente antes de backend', () async {
      final service = PayuService();

      await expectLater(
        () => service.createPaymentSession(
          patientId: 'p1',
          treatmentId: 'tx-1',
          monto: 500,
          saldoPendiente: 200,
          patientEmail: 'a@b.com',
          patientName: 'Paciente',
        ),
        throwsA(
          isA<FirebaseFunctionsException>().having(
            (error) => error.code,
            'code',
            'failed-precondition',
          ),
        ),
      );
    });

    test('rechaza cuenta sin saldo pendiente válido', () async {
      final service = PayuService();

      await expectLater(
        () => service.createPaymentSession(
          patientId: 'p1',
          treatmentId: 'tx-1',
          monto: 100,
          saldoPendiente: 0,
          patientEmail: 'a@b.com',
          patientName: 'Paciente',
        ),
        throwsA(
          isA<FirebaseFunctionsException>().having(
            (error) => error.code,
            'code',
            'failed-precondition',
          ),
        ),
      );
    });

    test('falla con error claro si backend no devuelve checkoutUrl', () async {
      final service = PayuService(
        createPayuSessionInvoker: (_) async => {'referencia': 'REF-1'},
      );

      await expectLater(
        () => service.createPaymentSession(
          patientId: 'p1',
          treatmentId: 'tx-1',
          monto: 100,
          saldoPendiente: 100,
          patientEmail: 'a@b.com',
          patientName: 'Paciente',
        ),
        throwsA(
          isA<FirebaseFunctionsException>().having(
            (error) => error.message,
            'message',
            contains('checkoutUrl'),
          ),
        ),
      );
    });
  });
}
