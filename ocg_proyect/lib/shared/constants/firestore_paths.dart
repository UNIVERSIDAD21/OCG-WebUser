class FirestorePaths {
  FirestorePaths._();

  static const String admins = 'admins';
  static const String patients = 'patients';
  static const String appointments = 'appointments';
  static const String payments = 'payments';
  static const String simulations = 'simulations';
  static const String notifications = 'notifications';

  static String adminDoc(String adminId) => 'admins/$adminId';
  static String patientDoc(String patientId) => 'patients/$patientId';
  static String stageHistory(String patientId) => 'patients/$patientId/stageHistory';
  static String transactions(String paymentId) => 'payments/$paymentId/transactions';
}
