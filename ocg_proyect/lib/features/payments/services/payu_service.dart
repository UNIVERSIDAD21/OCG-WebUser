import 'package:cloud_functions/cloud_functions.dart';

class PayuService {
  PayuService({FirebaseFunctions? functions}) : _functions = functions;

  final FirebaseFunctions? _functions;

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
        message: 'No se puede iniciar PayU sin un treatmentId válido.',
      );
    }
    if (monto <= 0) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'El monto debe ser mayor a cero.',
      );
    }
    if (saldoPendiente != null && monto > saldoPendiente) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'El monto no puede superar el saldo pendiente del tratamiento.',
      );
    }

    final functions = _functions ?? FirebaseFunctions.instance;
    final callable = functions.httpsCallable('createPayuSession');
    final result = await callable.call({
      'patientId': patientId,
      'treatmentId': cleanTreatmentId,
      'monto': monto,
      'patientEmail': patientEmail,
      'patientName': patientName,
    });

    final data = (result.data as Map?)?.cast<String, dynamic>() ?? const {};
    final url = (data['checkoutUrl'] ?? '').toString();
    if (url.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'No se recibió checkoutUrl desde createPayuSession.',
      );
    }
    return url;
  }
}
