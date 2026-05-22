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

  // Firebase App Check — solo en release.
  // En debug builds locales App Check falla con "App attestation failed"
  // porque el APK debug no está registrado en Google Play Console.
  // El debug provider también falla si no hay debug token en Firebase Console.
  //
  // ⚠️ En producción (kReleaseMode) se requiere App Check con Play Integrity.
  if (!kIsWeb && kReleaseMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  }

  runApp(const ProviderScope(child: OcgApp()));
}
