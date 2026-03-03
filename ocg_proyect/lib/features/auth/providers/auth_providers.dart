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

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      final credential = await authService.signIn(email, password);

      final role = await authService.getUserRole();
      final token = await ref.read(fcmServiceProvider).getToken();
      final uid = credential.user?.uid;

      if (uid != null && role != null && token != null && token.isNotEmpty) {
        try {
          await authService.updateFcmToken(uid, role, token);
        } catch (_) {
          // No bloquear login por fallo de escritura de token FCM.
        }
      }
      ref.invalidate(userRoleProvider);
    });
  }

  Future<void> registerPatient({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authServiceProvider).registerPatient(
            email: email,
            password: password,
            displayName: displayName,
          );
    });
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authServiceProvider).resetPassword(email);
    });
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    ref.invalidate(authStateProvider);
    ref.invalidate(userRoleProvider);
  }
}
