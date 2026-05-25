import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_app_check/firebase_app_check.dart';
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

  // App Check: debug provider para desarrollo (evita error 403 "App attestation failed")
  // En producción se debe configurar Play Integrity con el SHA-256 correcto
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  );


  runApp(const ProviderScope(child: OcgApp()));
}
