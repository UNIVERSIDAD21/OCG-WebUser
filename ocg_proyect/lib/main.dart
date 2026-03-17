import 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'permission-blocked' &&
        e.code != 'permission-default' &&
        e.code != 'permission-denied') {
      rethrow;
    }
  }

  FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);

  runApp(const ProviderScope(child: OcgApp()));
}
