import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firebase/auth_service.dart';
import '../../../services/notifications/fcm_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final fcmServiceProvider = Provider<FcmService>((ref) => FcmService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  return ref.watch(authServiceProvider).getUserRole();
});

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> _updateFcmTokenAfterLogin({
    required String uid,
    required String role,
  }) async {
    final authService = ref.read(authServiceProvider);
    final token = await ref.read(fcmServiceProvider).getToken();

    if (token == null || token.isEmpty) return;

    try {
      await authService.updateFcmToken(uid, role, token);
    } catch (_) {
      // No bloquear flujo principal por fallo de escritura de token FCM.
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      final authService = ref.read(authServiceProvider);
      final credential = await authService.signIn(email, password);

      ref.invalidate(userRoleProvider);

      final uid = credential.user?.uid;
      if (uid != null) {
        unawaited(() async {
          try {
            final role = await authService.getUserRole();
            final effectiveRole = role == 'admin' ? 'admin' : 'patient';
            await _updateFcmTokenAfterLogin(uid: uid, role: effectiveRole);
          } catch (_) {
            // Evitar errores no capturados en background durante login web.
          }
        }());
      }

      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> registerPatient({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      final credential = await authService.registerPatient(
        email: email,
        password: password,
        displayName: displayName,
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        unawaited(_updateFcmTokenAfterLogin(uid: uid, role: 'patient'));
      }

      ref.invalidate(authStateProvider);
      ref.invalidate(userRoleProvider);
    });
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authServiceProvider).resetPassword(email);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(authServiceProvider).signOut();
    });

    ref.invalidate(authStateProvider);
    ref.invalidate(userRoleProvider);
    state = result.hasError ? result : const AsyncData(null);
  }
}
