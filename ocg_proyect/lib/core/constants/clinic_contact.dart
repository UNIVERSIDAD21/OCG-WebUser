class ClinicContact {
  ClinicContact._();

  static const String whatsappNumber = String.fromEnvironment(
    'OCG_CLINIC_WHATSAPP',
    defaultValue: '573133169251',
  );

  static const String clinicName = 'OCG Clinica';

  static String get whatsappDigits =>
      whatsappNumber.replaceAll(RegExp(r'\D'), '');
}
