import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  FcmService({FirebaseMessaging? messaging}) : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Future<String?> getToken() => _messaging.getToken();
}
