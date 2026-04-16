class FirestorePaths {
  FirestorePaths._();

  static const String admins = 'admins';
  static const String patients = 'patients';
  static const String appointments = 'appointments';
  static const String payments = 'payments';
  static const String simulations = 'simulations';
  static const String notifications = 'notifications';
  static const String scheduledNotifications = 'scheduledNotifications';
  static const String availability = 'availability';
  static const String treatmentCatalog = 'treatmentCatalog';

  static String adminDoc(String adminId) => 'admins/$adminId';
  static String patientDoc(String patientId) => 'patients/$patientId';
  static String patientClinicalFiles(String patientId) => 'patients/$patientId/clinicalFiles';
  static String stageHistory(String patientId) => 'patients/$patientId/stageHistory';
  static String patientTreatments(String patientId) => 'patients/$patientId/treatments';
  static String patientTreatmentDoc(String patientId, String treatmentId) =>
      'patients/$patientId/treatments/$treatmentId';
  static String treatmentStageHistory(String patientId, String treatmentId) =>
      'patients/$patientId/treatments/$treatmentId/stageHistory';
  static String treatmentFinancialItems(String patientId, String treatmentId) =>
      'patients/$patientId/treatments/$treatmentId/financialItems';
  static String transactions(String paymentId) => 'payments/$paymentId/transactions';
  static String patientSimulations(String patientId) => 'patients/$patientId/simulations';
  static String treatmentCatalogDoc(String catalogTreatmentId) =>
      'treatmentCatalog/$catalogTreatmentId';
}
