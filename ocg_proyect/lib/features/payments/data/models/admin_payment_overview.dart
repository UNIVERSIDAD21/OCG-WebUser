import '../../../patients/data/models/patient_model.dart';
import 'payment_model.dart';

enum AdminPaymentsFilter { todos, vencido, pagado, pendiente }

class AdminPaymentEntry {
  const AdminPaymentEntry({
    required this.patient,
    required this.payment,
    this.latestTransaction,
  });

  final PatientModel patient;
  final PaymentModel payment;
  final PaymentTransaction? latestTransaction;

  double get latestPaymentAmount => latestTransaction?.monto ?? 0;
  DateTime? get latestPaymentDate => latestTransaction?.fecha;
  double get totalPaid =>
      payment.montoPagado.clamp(0, double.infinity).toDouble();
  double get saldoPendiente =>
      payment.saldoPendiente.clamp(0, double.infinity).toDouble();

  PaymentStatus get financialStatus => PaymentModel.calcularEstado(
    saldoPendiente: payment.saldoPendiente,
    fechaProximoPago: payment.fechaProximoPago,
  );

  bool matchesFilter(AdminPaymentsFilter filter) {
    switch (filter) {
      case AdminPaymentsFilter.todos:
        return true;
      case AdminPaymentsFilter.vencido:
        return financialStatus == PaymentStatus.vencido;
      case AdminPaymentsFilter.pagado:
        return financialStatus == PaymentStatus.pagadoTotal;
      case AdminPaymentsFilter.pendiente:
        return financialStatus != PaymentStatus.vencido &&
            financialStatus != PaymentStatus.pagadoTotal;
    }
  }

  String get financialStatusLabel {
    switch (financialStatus) {
      case PaymentStatus.vencido:
        return 'Vencido';
      case PaymentStatus.pagadoTotal:
        return 'Pagado';
      case PaymentStatus.pendiente:
        return 'Pendiente';
      case PaymentStatus.alDia:
        return 'Al día';
    }
  }

  String get latestPaymentMethodLabel {
    final method = latestTransaction?.metodo;
    switch (method) {
      case PaymentMethod.efectivo:
        return 'Efectivo';
      case PaymentMethod.transferencia:
        return 'Transferencia';
      case PaymentMethod.payu:
        return 'PayU';
      case null:
        return 'Sin pagos';
    }
  }
}

class AdminPaymentsOverview {
  const AdminPaymentsOverview({
    required this.entries,
    required this.totalDebt,
    required this.transactionsThisMonth,
  });

  final List<AdminPaymentEntry> entries;
  final double totalDebt;
  final int transactionsThisMonth;

  List<AdminPaymentEntry> entriesForFilter(AdminPaymentsFilter filter) {
    return entries.where((entry) => entry.matchesFilter(filter)).toList();
  }

  List<AdminPaymentEntry> get overdueEntries =>
      entriesForFilter(AdminPaymentsFilter.vencido);

  List<AdminPaymentEntry> get recentIncomeEntries {
    final items =
        entries
            .where(
              (entry) =>
                  entry.latestPaymentDate != null &&
                  entry.latestPaymentAmount > 0 &&
                  entry.totalPaid > 0,
            )
            .toList()
          ..sort(
            (a, b) => b.latestPaymentDate!.compareTo(a.latestPaymentDate!),
          );
    return items;
  }
}
