import 'package:cloud_functions/cloud_functions.dart';

class PayuService {
  PayuService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<String> createPaymentSession({
    required String patientId,
    required double monto,
    required String patientEmail,
    required String patientName,
  }) async {
    final callable = _functions.httpsCallable('createPayuSession');
    final result = await callable.call({
      'patientId': patientId,
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
