import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import '../firebase/auth_service.dart';
import 'fcm_payload_router.dart';

const _androidChannelId = 'ocg_clinica_push';
const _androidChannelName = 'OCG Push';
const _androidChannelDescription =
    'Notificaciones push operativas y clínicas de OCG';
const _deviceIdKey = 'fcm_device_installation_id';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class FcmService {
  FcmService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    FcmPayloadRouter? payloadRouter,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _payloadRouter = payloadRouter ?? const FcmPayloadRouter();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FcmPayloadRouter _payloadRouter;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  Future<void> initialize({
    required AuthService authService,
    required Future<String?> Function() resolveRole,
    required GoRouter router,
  }) async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initializeLocalNotifications(
      router: router,
      resolveRole: resolveRole,
    );
    await _requestPermissionIfNeeded();

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
    });

    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) async {
      await _handleNotificationNavigation(
        message.data,
        router: router,
        resolveRole: resolveRole,
      );
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleNotificationNavigation(
        initialMessage.data,
        router: router,
        resolveRole: resolveRole,
      );
    }

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      await syncCurrentUserDeviceToken(
        authService: authService,
        resolveRole: resolveRole,
        overrideToken: token,
        source: 'messaging.onTokenRefresh',
      );
    });
  }

  Future<void> syncCurrentUserDeviceToken({
    required AuthService authService,
    required Future<String?> Function() resolveRole,
    String? overrideToken,
    String source = 'manual',
  }) async {
    if (kIsWeb) return;
    final user = authService.currentUser;
    if (user == null) return;
    final role = await resolveRole();
    if (role != 'admin' && role != 'patient') {
      developer.log(
        'skip syncCurrentUserDeviceToken: role unresolved',
        name: 'ocg.fcm',
        error: {'uid': user.uid, 'source': source, 'role': role},
      );
      return;
    }
    final String effectiveRole = role!;

    final token = overrideToken ?? await getToken();
    if (token == null || token.isEmpty) {
      developer.log(
        'skip syncCurrentUserDeviceToken: empty token',
        name: 'ocg.fcm',
        error: {'uid': user.uid, 'role': effectiveRole, 'source': source},
      );
      return;
    }

    final deviceId = await getOrCreateDeviceId();
    await authService.upsertFcmDeviceToken(
      uid: user.uid,
      role: effectiveRole,
      token: token,
      deviceId: deviceId,
      platform: 'android',
    );
    developer.log(
      'FCM token synced',
      name: 'ocg.fcm',
      error: {
        'uid': user.uid,
        'role': effectiveRole,
        'deviceId': deviceId,
        'tokenPreview': _tokenPreview(token),
        'source': source,
      },
    );
  }

  Future<void> clearCurrentUserDeviceToken({
    required AuthService authService,
    required String role,
    String source = 'manual',
  }) async {
    if (kIsWeb) return;
    final user = authService.currentUser;
    if (user == null) return;
    final deviceId = await getOrCreateDeviceId();
    await authService.deleteFcmDeviceToken(
      uid: user.uid,
      role: role,
      deviceId: deviceId,
    );
    developer.log(
      'FCM token cleared',
      name: 'ocg.fcm',
      error: {
        'uid': user.uid,
        'role': role,
        'deviceId': deviceId,
        'source': source,
      },
    );
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-blocked' ||
          e.code == 'permission-default' ||
          e.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final created = base64UrlEncode(bytes).replaceAll('=', '');
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  Future<void> _requestPermissionIfNeeded() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-blocked' &&
          e.code != 'permission-default' &&
          e.code != 'permission-denied') {
        rethrow;
      }
    }
  }

  Future<void> _initializeLocalNotifications({
    required GoRouter router,
    required Future<String?> Function() resolveRole,
  }) async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final data = jsonDecode(payload) as Map<String, dynamic>;
        await _handleNotificationNavigation(
          data,
          router: router,
          resolveRole: resolveRole,
        );
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      developer.log(
        'foreground push ignored: no visible content',
        name: 'ocg.fcm',
        error: {'data': message.data},
      );
      return;
    }
    developer.log(
      'foreground push received',
      name: 'ocg.fcm',
      error: {
        'messageId': message.messageId,
        'title': title,
        'body': body,
        'data': message.data,
      },
    );
    await _localNotifications.show(
      message.messageId.hashCode ^ (title ?? '').hashCode ^ (body ?? '').hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _handleNotificationNavigation(
    Map<String, dynamic> data, {
    required GoRouter router,
    required Future<String?> Function() resolveRole,
  }) async {
    final role = await resolveRole();
    _payloadRouter.routeFromPayload(router, data, userRole: role);
  }

  String _tokenPreview(String token) {
    if (token.length <= 18) return token;
    return '${token.substring(0, 10)}…${token.substring(token.length - 6)}';
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _messageOpenedSub?.cancel();
    _initialized = false;
  }
}
