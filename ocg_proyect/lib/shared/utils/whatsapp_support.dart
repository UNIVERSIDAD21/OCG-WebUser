import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppSupport {
  WhatsAppSupport._();

  static Future<bool> openChat({
    required String phoneDigits,
    required String message,
  }) async {
    if (phoneDigits.trim().isEmpty) return false;

    final encodedMessage = Uri.encodeComponent(message);
    final normalizedPhone = phoneDigits.replaceAll(RegExp(r'\D'), '');

    final webUrl = Uri.parse('https://wa.me/$normalizedPhone?text=$encodedMessage');

    if (kIsWeb) {
      return launchUrl(webUrl, webOnlyWindowName: '_blank');
    }

    final appUrl = Uri.parse('whatsapp://send?phone=$normalizedPhone&text=$encodedMessage');

    final openedApp = await launchUrl(
      appUrl,
      mode: LaunchMode.externalApplication,
    );
    if (openedApp) return true;

    return launchUrl(
      webUrl,
      mode: LaunchMode.externalApplication,
    );
  }
}
