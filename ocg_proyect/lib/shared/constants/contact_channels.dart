class ContactChannels {
  ContactChannels._();

  /// Número de soporte WhatsApp en formato internacional, solo dígitos.
  /// Configurar con:
  /// --dart-define=OCG_CLINIC_WHATSAPP=573001112233
  static const String clinicWhatsapp = String.fromEnvironment(
    'OCG_CLINIC_WHATSAPP',
    defaultValue: '',
  );
}
