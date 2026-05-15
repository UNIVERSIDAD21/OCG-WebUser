import 'package:cloud_functions/cloud_functions.dart';

typedef EpaycoCallableInvoker = Future<dynamic> Function(Map<String, dynamic> data);

class EpaycoService {
  EpaycoService({
    FirebaseFunctions? functions,
    EpaycoCallableInvoker? createEpaycoCheckoutInvoker,
  }) : _functions = functions,
       _createEpaycoCheckoutInvoker = createEpaycoCheckoutInvoker;

  final FirebaseFunctions? _functions;
  final EpaycoCallableInvoker? _createEpaycoCheckoutInvoker;

  Future<String> createPaymentSession({
    required String patientId,
    required String treatmentId,
    required double monto,
    required String patientEmail,
    required String patientName,
    double? saldoPendiente,
  }) async {
    final cleanTreatmentId = treatmentId.trim();
    if (cleanTreatmentId.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'No se puede iniciar el pago sin un treatmentId válido.',
      );
    }
    if (monto <= 0) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'El monto debe ser mayor a cero.',
      );
    }
    if (saldoPendiente == null || saldoPendiente <= 0) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'No existe una cuenta válida con saldo pendiente para este tratamiento.',
      );
    }
    if (monto > saldoPendiente) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'El monto no puede superar el saldo pendiente del tratamiento.',
      );
    }

    final payload = {
      'patientId': patientId,
      'treatmentId': cleanTreatmentId,
      'monto': monto,
      'patientEmail': patientEmail,
      'patientName': patientName,
    };

    final dynamic rawResult;
    if (_createEpaycoCheckoutInvoker != null) {
      rawResult = await _createEpaycoCheckoutInvoker(payload);
    } else {
      final functions = _functions ?? FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createPayuSession');
      rawResult = await callable.call(payload);
    }

    final dynamic resultData = rawResult is HttpsCallableResult
        ? rawResult.data
        : rawResult;
    final data = (resultData as Map?)?.cast<String, dynamic>() ?? const {};
    final url = (data['checkoutUrl'] ?? '').toString();
    if (url.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'No se recibió checkoutUrl desde createEpaycoCheckout.',
      );
    }
    return url;
  }
}
