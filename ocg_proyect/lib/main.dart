import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'firebase_options.dart';

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

  // Firebase SDKs como Functions y Storage consultan App Check internamente.
  // En Firebase Console los servicios están SIN enforcement, así que OCG no
  // debe depender de attestation para funcionar. Por eso usamos provider debug
  // por defecto incluso en builds release locales/sideloaded: evita que
  // Play Integrity/App Attest bloquee con 403 "App attestation failed".
  //
  // Solo activar attestation real para una build publicada/configurada con:
  // --dart-define=OCG_USE_PRODUCTION_APP_CHECK=true
  //
  // No llamamos getToken() ni setTokenAutoRefreshEnabled(): Firebase maneja el
  // token cuando lo necesita y evitamos el loop "Too many attempts".
  if (!kIsWeb) {
    const useProductionAppCheck = bool.fromEnvironment(
      'OCG_USE_PRODUCTION_APP_CHECK',
    );

    await FirebaseAppCheck.instance.activate(
      providerAndroid: useProductionAppCheck
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: useProductionAppCheck
          ? const AppleAppAttestWithDeviceCheckFallbackProvider()
          : const AppleDebugProvider(),
    );
  }

  runApp(const ProviderScope(child: OcgApp()));
}
