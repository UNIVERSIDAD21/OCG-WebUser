import '../../../payments/data/models/payment_model.dart';
import '../../../treatment/data/models/patient_treatment.dart';
import '../models/patient_data_resolution.dart';
import '../models/patient_model.dart';

class PatientDataResolutionService {
  const PatientDataResolutionService();

  EffectivePatientDataResolution resolve({
    required PatientModel patient,
    required List<PatientTreatment> newTreatments,
    required PaymentModel? legacyPayment,
    required List<PaymentModel> treatmentPayments,
    required List<PaymentTransaction> legacyTransactions,
    required List<PaymentTransaction> treatmentTransactions,
  }) {
    final hasLegacyTreatmentProjection = patient.tipoTratamiento != null;
    final hasNewTreatments = newTreatments.isNotEmpty;
    final hasLegacyPaymentAccount = legacyPayment != null;
    final hasNewPaymentAccounts = treatmentPayments.isNotEmpty;
    final hasLegacyTransactions = legacyTransactions.isNotEmpty;
    final hasNewTransactions = treatmentTransactions.isNotEmpty;

    final mode = _resolveMode(
      hasLegacyTreatmentProjection: hasLegacyTreatmentProjection,
      hasNewTreatments: hasNewTreatments,
      hasLegacyPaymentAccount: hasLegacyPaymentAccount,
      hasNewPaymentAccounts: hasNewPaymentAccounts,
      hasLegacyTransactions: hasLegacyTransactions,
      hasNewTransactions: hasNewTransactions,
    );

    final effectiveTreatments = _resolveTreatments(
      patient: patient,
      newTreatments: newTreatments,
      hasLegacyTreatmentProjection: hasLegacyTreatmentProjection,
    );

    final paymentAccounts = _resolvePaymentAccounts(
      patient: patient,
      treatments: effectiveTreatments,
      legacyPayment: legacyPayment,
      treatmentPayments: treatmentPayments,
    );

    final transactions = _resolveTransactions(
      legacyTransactions,
      treatmentTransactions,
    );

    final primaryTreatmentId = effectiveTreatments
        .where((t) => t.isPrimary)
        .map((t) => t.id)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);

    return EffectivePatientDataResolution(
      patient: patient,
      mode: mode,
      treatments: effectiveTreatments,
      paymentAccounts: paymentAccounts,
      transactions: transactions,
      hasLegacyTreatmentProjection: hasLegacyTreatmentProjection,
      hasNewTreatments: hasNewTreatments,
      hasLegacyPaymentAccount: hasLegacyPaymentAccount,
      hasNewPaymentAccounts: hasNewPaymentAccounts,
      hasLegacyTransactions: hasLegacyTransactions,
      hasNewTransactions: hasNewTransactions,
      primaryTreatmentId: primaryTreatmentId,
    );
  }

  PatientDataMode _resolveMode({
    required bool hasLegacyTreatmentProjection,
    required bool hasNewTreatments,
    required bool hasLegacyPaymentAccount,
    required bool hasNewPaymentAccounts,
    required bool hasLegacyTransactions,
    required bool hasNewTransactions,
  }) {
    final hasLegacy =
        hasLegacyTreatmentProjection ||
        hasLegacyPaymentAccount ||
        hasLegacyTransactions;
    final hasNew =
        hasNewTreatments || hasNewPaymentAccounts || hasNewTransactions;

    if (hasLegacy && hasNew) return PatientDataMode.mixto;
    if (hasNew) return PatientDataMode.nuevoPuro;
    return PatientDataMode.legacyPuro;
  }

  List<PatientTreatment> _resolveTreatments({
    required PatientModel patient,
    required List<PatientTreatment> newTreatments,
    required bool hasLegacyTreatmentProjection,
  }) {
    final byId = <String, PatientTreatment>{
      for (final treatment in newTreatments) treatment.id: treatment,
    };

    if (hasLegacyTreatmentProjection) {
      final legacy = PatientTreatment.fromLegacyPatient(patient);
      final duplicate = newTreatments.any(
        (item) => _sameTreatment(item, legacy),
      );
      if (!duplicate) {
        byId[legacy.id] = legacy;
      }
    }

    final items = byId.values.toList()
      ..sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return items;
  }

  List<EffectivePatientPaymentAccount> _resolvePaymentAccounts({
    required PatientModel patient,
    required List<PatientTreatment> treatments,
    required PaymentModel? legacyPayment,
    required List<PaymentModel> treatmentPayments,
  }) {
    final accounts = <String, EffectivePatientPaymentAccount>{};

    for (final payment in treatmentPayments) {
      final treatmentId = (payment.id == patient.id || payment.id.isEmpty)
          ? null
          : payment.id;
      final key = treatmentId ?? 'payment:${payment.patientId}:${payment.id}';
      accounts[key] = EffectivePatientPaymentAccount(
        payment: payment,
        treatmentId: treatmentId,
        isLegacy: false,
        source: 'treatment-payment',
      );
    }

    if (legacyPayment != null) {
      final primary = treatments.cast<PatientTreatment?>().firstWhere(
        (item) => item?.isPrimary == true,
        orElse: () => null,
      );
      final matched = primary != null && accounts.containsKey(primary.id);
      if (!matched) {
        accounts['legacy:${patient.id}'] = EffectivePatientPaymentAccount(
          payment: legacyPayment,
          treatmentId: primary?.id,
          isLegacy: true,
          source: 'legacy-payment',
        );
      }
    }

    return accounts.values.toList();
  }

  List<PaymentTransaction> _resolveTransactions(
    List<PaymentTransaction> legacyTransactions,
    List<PaymentTransaction> treatmentTransactions,
  ) {
    final merged = <String, PaymentTransaction>{};
    for (final tx in legacyTransactions) {
      merged[_txKey(tx)] = tx;
    }
    for (final tx in treatmentTransactions) {
      merged[_txKey(tx)] = tx;
    }
    final items = merged.values.toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return items;
  }

  bool _sameTreatment(PatientTreatment a, PatientTreatment b) {
    return a.tipoBase == b.tipoBase &&
        a.subtipo == b.subtipo &&
        a.fechaInicio == b.fechaInicio &&
        a.totalTratamiento == b.totalTratamiento;
  }

  String _txKey(PaymentTransaction tx) {
    if (tx.id.trim().isNotEmpty) return 'id:${tx.id.trim()}';
    return [
      tx.treatmentId ?? 'legacy',
      tx.metodo.name,
      tx.monto.toStringAsFixed(2),
      tx.fecha.toUtc().millisecondsSinceEpoch,
      tx.referencia ?? '',
      tx.payuTransactionId ?? '',
    ].join('|');
  }
}
