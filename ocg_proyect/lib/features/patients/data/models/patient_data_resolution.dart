import '../../../payments/data/models/payment_model.dart';
import '../../../treatment/data/models/patient_treatment.dart';
import 'patient_model.dart';

enum PatientDataMode { legacyPuro, nuevoPuro, mixto }

class EffectivePatientPaymentAccount {
  const EffectivePatientPaymentAccount({
    required this.payment,
    this.treatmentId,
    required this.isLegacy,
    required this.source,
  });

  final PaymentModel payment;
  final String? treatmentId;
  final bool isLegacy;
  final String source;
}

class EffectivePatientDataResolution {
  const EffectivePatientDataResolution({
    required this.patient,
    required this.mode,
    required this.treatments,
    required this.paymentAccounts,
    required this.transactions,
    required this.hasLegacyTreatmentProjection,
    required this.hasNewTreatments,
    required this.hasLegacyPaymentAccount,
    required this.hasNewPaymentAccounts,
    required this.hasLegacyTransactions,
    required this.hasNewTransactions,
    this.primaryTreatmentId,
  });

  final PatientModel patient;
  final PatientDataMode mode;
  final List<PatientTreatment> treatments;
  final List<EffectivePatientPaymentAccount> paymentAccounts;
  final List<PaymentTransaction> transactions;
  final bool hasLegacyTreatmentProjection;
  final bool hasNewTreatments;
  final bool hasLegacyPaymentAccount;
  final bool hasNewPaymentAccounts;
  final bool hasLegacyTransactions;
  final bool hasNewTransactions;
  final String? primaryTreatmentId;

  bool get isLegacyPuro => mode == PatientDataMode.legacyPuro;
  bool get isNuevoPuro => mode == PatientDataMode.nuevoPuro;
  bool get isMixto => mode == PatientDataMode.mixto;
}
