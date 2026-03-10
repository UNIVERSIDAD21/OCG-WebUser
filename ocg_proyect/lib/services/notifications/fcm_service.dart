import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  FcmService({FirebaseMessaging? messaging}) : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-blocked' || e.code == 'permission-default' || e.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }
}
