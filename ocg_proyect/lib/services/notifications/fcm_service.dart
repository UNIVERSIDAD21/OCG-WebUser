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

typedef FcmPlatformResolver = String? Function();

String? resolveFcmPlatform({
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  if (isWeb) return 'web';
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    default:
      return null;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class FcmService {
  FcmService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    FcmPayloadRouter? payloadRouter,
    FcmPlatformResolver? platformResolver,
  }) : _messaging = messaging,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _payloadRouter = payloadRouter ?? const FcmPayloadRouter(),
       _platformResolver = platformResolver ?? (() => resolveFcmPlatform());

  final FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FcmPayloadRouter _payloadRouter;
  final FcmPlatformResolver _platformResolver;

  FirebaseMessaging get _messagingInstance => _messaging ?? FirebaseMessaging.instance;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  Future<void>? _syncInFlight;
  String? _lastSyncedFingerprint;

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

    final initialMessage = await _messagingInstance.getInitialMessage();
    if (initialMessage != null) {
      await _handleNotificationNavigation(
        initialMessage.data,
        router: router,
        resolveRole: resolveRole,
      );
    }

    _tokenRefreshSub = _messagingInstance.onTokenRefresh.listen((token) async {
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        developer.log(
          'skip token refresh sync: no authenticated user',
          name: 'ocg.fcm',
        );
        return;
      }
      await syncCurrentUserDeviceToken(
        authService: authService,
        resolveRole: resolveRole,
        overrideToken: token,
        source: 'messaging.onTokenRefresh',
      );
    });
  }

  Future<void> registerCurrentDeviceAfterLogin({
    required AuthService authService,
    required Future<String?> Function() resolveRole,
  }) async {
    developer.log(
      'FcmService.registerCurrentDeviceAfterLogin start',
      name: 'ocg.fcm',
    );
    await syncCurrentUserDeviceToken(
      authService: authService,
      resolveRole: resolveRole,
      source: 'auth_notifier.sign_in_success',
    );
    developer.log(
      'FcmService.registerCurrentDeviceAfterLogin end',
      name: 'ocg.fcm',
    );
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

    await syncResolvedDeviceToken(
      uid: user.uid,
      upsertToken: ({
        required uid,
        required role,
        required token,
        required deviceId,
        required platform,
      }) {
        return authService.upsertFcmDeviceToken(
          uid: uid,
          role: role,
          token: token,
          deviceId: deviceId,
          platform: platform,
        );
      },
      resolveRole: resolveRole,
      overrideToken: overrideToken,
      source: source,
    );
  }

  Future<void> syncResolvedDeviceToken({
    required String uid,
    required Future<void> Function({
      required String uid,
      required String role,
      required String token,
      required String deviceId,
      required String platform,
    }) upsertToken,
    required Future<String?> Function() resolveRole,
    String? overrideToken,
    String source = 'manual',
  }) async {
    if (kIsWeb) return;
    if (uid.trim().isEmpty) return;
    final platform = _platformResolver();
    if (platform == null || platform == 'web') return;

    final role = await resolveRole();
    final bool hasResolvedRole = role == 'admin' || role == 'patient';
    final String effectiveRole = hasResolvedRole ? role! : 'unknown';

    if (!hasResolvedRole) {
      developer.log(
        'role unresolved on client; continuing token sync via backend role inference',
        name: 'ocg.fcm',
        error: {'uid': uid, 'source': source, 'role': role},
      );
    }

    final token = overrideToken ?? await getToken();
    if (token == null || token.isEmpty) {
      debugPrint('FCM TOKEN: null o vacío');
      return;
    }

    final deviceId = await getOrCreateDeviceId();
    final fingerprint = '$uid|$deviceId|$token|$platform';

    if (_syncInFlight != null) {
      developer.log(
        'sync omitido por in-flight guard',
        name: 'ocg.fcm',
        error: {'uid': uid, 'deviceId': deviceId, 'source': source},
      );
      return _syncInFlight!;
    }

    if (_lastSyncedFingerprint == fingerprint) {
      developer.log(
        'sync omitido por mismo token ya sincronizado',
        name: 'ocg.fcm',
        error: {
          'uid': uid,
          'deviceId': deviceId,
          'tokenPreview': _tokenPreview(token),
          'platform': platform,
          'source': source,
        },
      );
      return;
    }

    final future = () async {
      await upsertToken(
        uid: uid,
        role: effectiveRole,
        token: token,
        deviceId: deviceId,
        platform: platform,
      );
      _lastSyncedFingerprint = fingerprint;
    }();

    _syncInFlight = future;
    try {
      await future;
    } finally {
      _syncInFlight = null;
    }
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
    _lastSyncedFingerprint = null;
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
      return await _messagingInstance.getToken();
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
      await _messagingInstance.requestPermission(alert: true, badge: true, sound: true);
      await _messagingInstance.setForegroundNotificationPresentationOptions(
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
  }

  Future<void> _initializeLocalNotifications({
    required GoRouter router,
    required Future<String?> Function() resolveRole,
  }) async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
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
    await _localNotifications.show(
      message.messageId.hashCode ^
          (title ?? '').hashCode ^
          (body ?? '').hashCode,
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
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
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

  void resetSyncState() {
    _lastSyncedFingerprint = null;
    _syncInFlight = null;
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _messageOpenedSub?.cancel();
    _initialized = false;
    _lastSyncedFingerprint = null;
    _syncInFlight = null;
  }
}
