import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firebase App Check — usamos providers de producción siempre.
  // El provider debug (AndroidProvider.debug / AppleProvider.debug)
  // tiene rate-limiting muy agresivo que causa "Too many attempts"
  // cuando se hacen varias operaciones Firestore en ráfaga.
  // Los providers de producción (playIntegrity, appAttest) no tienen
  // este problema y funcionan correctamente incluso en debug builds.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
    );
  }

  runApp(const ProviderScope(child: OcgApp()));
}
