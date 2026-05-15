class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  static const String adminRoot = '/admin';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminPatients = '/admin/patients';
  static const String adminAppointments = '/admin/appointments';
  static const String adminPatientDetail = '/admin/patients/:patientId';
  static const String adminPatientNew = '/admin/patients/new';
  static const String adminPatientEdit = '/admin/patients/:patientId/edit';

  static const String adminTreatments = '/admin/treatments';
  static const String adminPayments = '/admin/payments';
  static const String adminSimulator = '/admin/simulator';
  static const String adminProfile = '/admin/profile';
  static const String adminNotifications = '/admin/notifications';

  static const String patientRoot = '/patient';
  static const String patientHome = '/patient/home';
  static const String patientTreatment = '/patient/treatment';
  static const String patientAppointments = '/patient/appointments';
  static const String patientProfile = '/patient/profile';
  static const String patientNotifications = '/patient/notifications';
  static const String patientClinicalFiles = '/patient/clinical-files';
  static const String patientPayments = '/patient/payments';
  static const String patientSimulations = '/patient/simulations';
  static const String patientEpaycoCheckout = '/patient/payments/checkout';

  // Deprecated alias
  @Deprecated('Use patientEpaycoCheckout')
  static const String patientPayuCheckout = patientEpaycoCheckout;

  // Consultación clínica (desde cita)
  static const String adminConsultation = '/admin/consultation';
}
