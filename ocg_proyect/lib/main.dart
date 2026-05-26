import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'firebase_options.dart';

const _webRecaptchaSiteKey = String.fromEnvironment(
  'FIREBASE_APP_CHECK_WEB_SITE_KEY',
);

ReCaptchaV3Provider _releaseWebAppCheckProvider() {
  if (_webRecaptchaSiteKey.isEmpty) {
    throw StateError(
      'FIREBASE_APP_CHECK_WEB_SITE_KEY is required for web release builds. '
      'Pass it with --dart-define=FIREBASE_APP_CHECK_WEB_SITE_KEY=<site-key>.',
    );
  }

  return ReCaptchaV3Provider(_webRecaptchaSiteKey);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Evita overlays de depuración visual (líneas amarillas de baseline, etc.)
  // cuando fueron activados accidentalmente desde herramientas de inspección.
  assert(() {
    debugPaintBaselinesEnabled = false;
    debugPaintSizeEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugRepaintRainbowEnabled = false;
    return true;
  }());

  await initializeDateFormatting('es_CO');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check: debug provider para desarrollo (evita error 403 "App attestation failed")
  // En producción se debe configurar Play Integrity con el SHA-256 correcto
  await FirebaseAppCheck.instance.activate(
    providerWeb: kIsWeb
        ? (kDebugMode ? WebDebugProvider() : _releaseWebAppCheckProvider())
        : null,
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );

  runApp(const ProviderScope(child: OcgApp()));
}
