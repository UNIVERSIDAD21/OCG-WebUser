import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/payments/services/payu_service.dart';

void main() {
  group('PayuService.createPaymentSession', () {
    test('rechaza treatmentId vacío antes de llamar backend', () async {
      final service = PayuService();

      await expectLater(
        () => service.createPaymentSession(
          patientId: 'p1',
          treatmentId: '   ',
          monto: 100,
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
  });
}
