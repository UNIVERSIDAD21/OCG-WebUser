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

  // Firebase App Check — siempre activado porque Firebase Console
  // tiene enforcement habilitado para Cloud Functions.
  //
  // En debug: AndroidProvider.debug que genera token local.
  // El token debug aparece en logcat como:
  //   "Debug App Check token: <token>"
  // Si Firebase lo rechaza, copia ese token y regístralo en:
  //   Firebase Console → App Check → Apps → tu app → Debug tokens
  //
  // En release: Play Integrity / App Attest (requiere APK firmado en Play).
  //
  // ⚠️ NUNCA usar setTokenAutoRefreshEnabled en debug:
  // causa "Too many attempts" porque el token debug se refresca en loop.
  if (!kIsWeb) {
    final androidProvider = kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug;
    final appleProvider = kReleaseMode
        ? AppleProvider.appAttestWithDeviceCheckFallback
        : AppleProvider.debug;

    await FirebaseAppCheck.instance.activate(
      androidProvider: androidProvider,
      appleProvider: appleProvider,
    );
    // Auto-refresh SOLO en release
    if (kReleaseMode) {
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    }

    // En debug, imprimir el token para registrarlo en Firebase Console.
    // Busca en logcat: "🔥 APP_CHECK_DEBUG_TOKEN:"
    if (!kReleaseMode) {
      try {
        final result = await FirebaseAppCheck.instance.getToken();
        // ignore: avoid_print
        if (result != null) {
          final tokenStr = (result as dynamic).token?.toString() ?? '';
          if (tokenStr.isNotEmpty) {
            print('🔥 APP_CHECK_DEBUG_TOKEN: $tokenStr');
          }
        }
      } catch (_) {
        // ignore: avoid_print
        print('⚠️ No se pudo obtener token App Check en debug.');
      }
    }
  }

  runApp(const ProviderScope(child: OcgApp()));
}
