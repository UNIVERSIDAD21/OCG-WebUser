import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/payments/providers/payments_provider.dart';
import 'package:ocg_proyect/features/payments/services/epayco_service.dart';

class _RecordingEpaycoService extends EpaycoService {
  Map<String, dynamic>? lastCall;
  int callCount = 0;

  @override
  Future<String> createPaymentSession({
    required String patientId,
    required String treatmentId,
    required double monto,
    required String patientEmail,
    required String patientName,
    double? saldoPendiente,
  }) async {
    callCount += 1;
    lastCall = {
      'patientId': patientId,
      'treatmentId': treatmentId,
      'monto': monto,
      'patientEmail': patientEmail,
      'patientName': patientName,
      'saldoPendiente': saldoPendiente,
    };
    return 'https://epayco.test/checkout';
  }
}

void main() {
  group('InitiatePayuPaymentNotifier', () {
    test('falla si monto supera saldoPendiente', () async {
      final service = _RecordingEpaycoService();
      final container = ProviderContainer(
        overrides: [
          epaycoServiceProvider.overrideWith((ref) => service),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        () => container.read(initiateEpaycoPaymentProvider.notifier).initiate(
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
      expect(service.callCount, 0);
      expect(
        container.read(initiateEpaycoPaymentProvider),
        isA<AsyncError<String?>>(),
      );
    });

    test('falla si treatmentId está vacío', () async {
      final service = _RecordingEpaycoService();
      final container = ProviderContainer(
        overrides: [
          epaycoServiceProvider.overrideWith((ref) => service),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        () => container.read(initiateEpaycoPaymentProvider.notifier).initiate(
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
      expect(service.callCount, 0);
      expect(
        container.read(initiateEpaycoPaymentProvider),
        isA<AsyncError<String?>>(),
      );
    });

    test('falla si saldoPendiente es cero o negativo sin llamar backend', () async {
      final service = _RecordingEpaycoService();
      final container = ProviderContainer(
        overrides: [epaycoServiceProvider.overrideWith((ref) => service)],
      );
      addTearDown(container.dispose);

      await expectLater(
        () => container.read(initiateEpaycoPaymentProvider.notifier).initiate(
          patientId: 'p1',
          treatmentId: 'tx-1',
          monto: 100,
          saldoPendiente: 0,
          patientEmail: 'a@b.com',
          patientName: 'Paciente',
        ),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(service.callCount, 0);
      expect(
        container.read(initiateEpaycoPaymentProvider),
        isA<AsyncError<String?>>(),
      );
    });

    test('llama backend solo con treatmentId válido', () async {
      final service = _RecordingEpaycoService();
      final container = ProviderContainer(
        overrides: [epaycoServiceProvider.overrideWith((ref) => service)],
      );
      addTearDown(container.dispose);

      final url = await container.read(initiateEpaycoPaymentProvider.notifier).initiate(
        patientId: 'p1',
        treatmentId: 'tx-1',
        monto: 100,
        saldoPendiente: 100,
        patientEmail: 'a@b.com',
        patientName: 'Paciente',
      );

      expect(url, 'https://epayco.test/checkout');
      expect(service.lastCall?['treatmentId'], 'tx-1');
      expect(service.lastCall?['saldoPendiente'], 100.0);
    });
  });
}
