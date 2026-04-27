import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models/payment_model.dart';
import '../data/repositories/payments_repository.dart';

class PdfReceiptService {
  PdfReceiptService(this._paymentsRepository);

  final PaymentsRepository _paymentsRepository;

  Future<String> generateAndUpload({
    required String patientId,
    required String transactionId,
    required PaymentTransaction transaction,
    required PaymentModel paymentSummary,
    required String patientName,
    required String patientDocument,
    String? treatmentId,
  }) async {
    final currency = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat("d 'de' MMMM 'de' y, hh:mm a", 'es_CO');

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'OCG Clinica Dental',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('NIT: 901.234.567-8'),
              pw.Text('Telefono: +57 300 000 0000'),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'RECIBO DE PAGO  #${transactionId.substring(0, transactionId.length >= 8 ? 8 : transactionId.length)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Fecha: ${dateFmt.format(transaction.fecha)}'),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Paciente: ${_ascii(patientName)}'),
              pw.Text(
                'Documento: ${patientDocument.isEmpty ? 'No registrado' : _ascii(patientDocument)}',
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Concepto: Tratamiento de ortodoncia OCG Clinica'),
              pw.Text(
                'Metodo de pago: ${_paymentMethodLabel(transaction.metodo)}',
              ),
              if ((transaction.referencia ?? '').isNotEmpty)
                pw.Text('Referencia: ${transaction.referencia}'),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Valor pagado: ${currency.format(transaction.monto)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Saldo pendiente: ${currency.format(paymentSummary.saldoPendiente)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Spacer(),
              pw.Text(
                'Este documento es prueba de pago. Conserve este recibo.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final ref = FirebaseStorage.instance.ref(
      'payments/$patientId/recibos/$transactionId.pdf',
    );
    await ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
    final url = await ref.getDownloadURL();

    await _paymentsRepository.updateTransactionReceiptUrl(
      patientId: patientId,
      transactionId: transactionId,
      reciboUrl: url,
      treatmentId: treatmentId ?? transaction.treatmentId,
    );

    return url;
  }

  String _paymentMethodLabel(PaymentMethod method) => switch (method) {
    PaymentMethod.efectivo => 'Efectivo',
    PaymentMethod.transferencia => 'Transferencia bancaria',
    PaymentMethod.payu => 'PayU',
  };

  String _ascii(String value) {
    return value
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N');
  }
}
