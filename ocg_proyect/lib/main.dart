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

  // Firebase App Check — en modo debug usamos providers de debug
  // con auto-refresh habilitado para evitar "Too many attempts".
  // En release se usan providers de producción (playIntegrity/
  // appAttest) que requieren registro del APK en Google Play.
  //
  // ⚠️ No usar AndroidProvider.playIntegrity en modo debug:
  // retorna 403 "App attestation failed" porque la app debug
  // no está registrada en Google Play Console.
  if (!kIsWeb) {
    final androidProvider = kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity;
    final appleProvider = kDebugMode
        ? AppleProvider.debug
        : AppleProvider.appAttestWithDeviceCheckFallback;

    await FirebaseAppCheck.instance.activate(
      androidProvider: androidProvider,
      appleProvider: appleProvider,
    );

    // Forzar auto-refresh para reducir presión sobre el token
    // de debug (evita ciclos de refresh agresivos que agotan
    // la cuota y causan "Too many attempts").
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  }

  runApp(const ProviderScope(child: OcgApp()));
}
