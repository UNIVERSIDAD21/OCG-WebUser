import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/services/notifications/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('resolveFcmPlatform', () {
    test('Android -> android', () {
      expect(
        resolveFcmPlatform(isWeb: false, platform: TargetPlatform.android),
        'android',
      );
    });

    test('iOS -> ios', () {
      expect(
        resolveFcmPlatform(isWeb: false, platform: TargetPlatform.iOS),
        'ios',
      );
    });

    test('Web -> web', () {
      expect(resolveFcmPlatform(isWeb: true), 'web');
    });

    test('plataforma no soportada retorna null controlado', () {
      expect(
        resolveFcmPlatform(isWeb: false, platform: TargetPlatform.windows),
        isNull,
      );
    });
  });

  group('FcmService syncResolvedDeviceToken', () {
    test('con resolver iOS sube token con platform ios', () async {
      final service = FcmService(platformResolver: () => 'ios');
      Map<String, String>? captured;

      await service.syncResolvedDeviceToken(
        uid: 'u1',
        resolveRole: () async => 'patient',
        overrideToken: 'token-ios',
        upsertToken: ({required uid, required role, required token, required deviceId, required platform}) async {
          captured = {
            'uid': uid,
            'role': role,
            'token': token,
            'deviceId': deviceId,
            'platform': platform,
          };
        },
      );

      expect(captured, isNotNull);
      expect(captured!['platform'], 'ios');
      expect(captured!['uid'], 'u1');
    });

    test('con resolver Android sube token con platform android', () async {
      final service = FcmService(platformResolver: () => 'android');
      Map<String, String>? captured;

      await service.syncResolvedDeviceToken(
        uid: 'u1',
        resolveRole: () async => 'admin',
        overrideToken: 'token-android',
        upsertToken: ({required uid, required role, required token, required deviceId, required platform}) async {
          captured = {
            'uid': uid,
            'role': role,
            'token': token,
            'deviceId': deviceId,
            'platform': platform,
          };
        },
      );

      expect(captured, isNotNull);
      expect(captured!['platform'], 'android');
      expect(captured!['role'], 'admin');
    });

    test('si no hay token no llama backend', () async {
      final service = FcmService(platformResolver: () => 'ios');
      var calls = 0;

      await service.syncResolvedDeviceToken(
        uid: 'u1',
        resolveRole: () async => 'patient',
        overrideToken: '',
        upsertToken: ({required uid, required role, required token, required deviceId, required platform}) async {
          calls += 1;
        },
      );

      expect(calls, 0);
    });

    test('si no hay uid autenticado no llama backend', () async {
      final service = FcmService(platformResolver: () => 'ios');
      var calls = 0;

      await service.syncResolvedDeviceToken(
        uid: '',
        resolveRole: () async => 'patient',
        overrideToken: 'token-ios',
        upsertToken: ({required uid, required role, required token, required deviceId, required platform}) async {
          calls += 1;
        },
      );

      expect(calls, 0);
    });

    test('si plataforma es web no llama backend', () async {
      final service = FcmService(platformResolver: () => 'web');
      var calls = 0;

      await service.syncResolvedDeviceToken(
        uid: 'u1',
        resolveRole: () async => 'patient',
        overrideToken: 'token-web',
        upsertToken: ({required uid, required role, required token, required deviceId, required platform}) async {
          calls += 1;
        },
      );

      expect(calls, 0);
    });
  });
}
