class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  static const String adminDashboard = '/admin/dashboard';
  static const String adminPatients = '/admin/patients';
  static const String adminAppointments = '/admin/appointments';
  static const String adminPatientDetail = '/admin/patients/:patientId';
  static const String adminPatientNew = '/admin/patients/new';
  static const String adminPatientEdit = '/admin/patients/:patientId/edit';

  static const String patientHome = '/patient/home';
  static const String patientAppointments = '/patient/appointments';
  static const String patientProfile = '/patient/profile';
  static const String patientPayments = '/patient/payments';
  static const String patientPayuCheckout = '/patient/payments/checkout';
}
