import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'models/notification_model.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase.initializeApp debe estar configurado en el bootstrap principal.
  debugPrint('[Push][background] ${message.messageId} ${message.data}');
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  final StreamController<NotificationNavigationIntent>
      _navigationIntentController =
      StreamController<NotificationNavigationIntent>.broadcast();

  Stream<NotificationNavigationIntent> get navigationIntents =>
      _navigationIntentController.stream;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<User?>? _authSub;
  String? _lastSyncedUserId;
  String? _lastSyncedRole;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.setAutoInitEnabled(true);
    await _requestPermissions();
    await _syncCurrentUserToken();

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      final current = _auth.currentUser;
      if (current == null) return;
      await saveTokenForUser(
        userId: current.uid,
        role: _lastSyncedRole ?? 'unknown',
        token: token,
      );
    });

    FirebaseMessaging.onMessage.listen((message) async {
      await _persistIncomingMessage(
        message,
        NotificationDeliveryState.received,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _persistIncomingMessage(message, NotificationDeliveryState.opened);
      _emitNavigationIntent(message.data);
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await _persistIncomingMessage(initial, NotificationDeliveryState.opened);
      _emitNavigationIntent(initial.data);
    }

    _authSub = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        await markCurrentUserTokensInactive();
        _lastSyncedUserId = null;
        _lastSyncedRole = null;
        return;
      }
      await _syncCurrentUserToken();
    });
  }

  Future<PushNotificationPermissionState> _requestPermissions() async {
    if (kIsWeb) {
      return PushNotificationPermissionState.authorized;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );

    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
        return PushNotificationPermissionState.authorized;
      case AuthorizationStatus.denied:
        return PushNotificationPermissionState.denied;
      case AuthorizationStatus.provisional:
        return PushNotificationPermissionState.provisional;
      case AuthorizationStatus.notDetermined:
        return PushNotificationPermissionState.notDetermined;
    }
  }

  Future<void> _syncCurrentUserToken() async {
    final current = _auth.currentUser;
    if (current == null) return;

    final token = await _messaging.getToken();
    if ((token ?? '').trim().isEmpty) return;

    final role = await _resolveRole(current.uid);
    _lastSyncedUserId = current.uid;
    _lastSyncedRole = role;

    await saveTokenForUser(
      userId: current.uid,
      role: role,
      token: token!,
    );
  }

  Future<String> _resolveRole(String uid) async {
    try {
      final adminDoc = await _firestore.collection('admins').doc(uid).get();
      if (adminDoc.exists) return 'admin';
      final patientDoc = await _firestore.collection('patients').doc(uid).get();
      if (patientDoc.exists) return 'patient';
    } catch (_) {}
    return 'unknown';
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'unknown';
    }
  }

  Future<void> saveTokenForUser({
    required String userId,
    required String role,
    required String token,
    String? deviceId,
  }) async {
    final now = DateTime.now();
    final ref = _firestore.collection('fcmTokens').doc(token);
    final snapshot = await ref.get();
    final createdAt = snapshot.data()?['createdAt'] is Timestamp
        ? (snapshot.data()!['createdAt'] as Timestamp).toDate()
        : now;

    final record = NotificationTokenRecord(
      userId: userId,
      role: role,
      platform: _platformLabel(),
      token: token,
      active: true,
      createdAt: createdAt,
      updatedAt: now,
      lastSeenAt: now,
      deviceId: deviceId,
    );

    await ref.set(record.toJson(), SetOptions(merge: true));
  }

  Future<void> markCurrentUserTokensInactive() async {
    final userId = _lastSyncedUserId;
    if ((userId ?? '').isEmpty) return;

    final query = await _firestore
        .collection('fcmTokens')
        .where('userId', isEqualTo: userId)
        .where('platform', isEqualTo: _platformLabel())
        .where('active', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.set(doc.reference, {
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _persistIncomingMessage(
    RemoteMessage message,
    NotificationDeliveryState state,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final title = message.notification?.title ??
        (message.data['title'] ?? '').toString();
    final body = message.notification?.body ??
        (message.data['body'] ?? '').toString();
    final intent = NotificationNavigationIntent.fromData(message.data);
    final record = InAppNotificationRecord(
      userId: user.uid,
      type: intent.type,
      title: title,
      body: body,
      deliveryState: state,
      createdAt: DateTime.now(),
      data: message.data,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .add(record.toJson());
  }

  void _emitNavigationIntent(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    final intent = NotificationNavigationIntent.fromData(data);
    _navigationIntentController.add(intent);
  }

  Future<PushNotificationPermissionState> getCurrentPermissionState() async {
    final settings = await _messaging.getNotificationSettings();
    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
        return PushNotificationPermissionState.authorized;
      case AuthorizationStatus.denied:
        return PushNotificationPermissionState.denied;
      case AuthorizationStatus.provisional:
        return PushNotificationPermissionState.provisional;
      case AuthorizationStatus.notDetermined:
        return PushNotificationPermissionState.notDetermined;
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _authSub?.cancel();
    _navigationIntentController.close();
  }
}
