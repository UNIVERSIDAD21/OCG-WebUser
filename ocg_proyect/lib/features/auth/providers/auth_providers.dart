import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../services/notifications/fcm_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;

  final authService = ref.watch(authServiceProvider);
  final role = await authService.getUserRole();

  // Guard global de sesión: si el usuario es paciente pero su perfil ya no
  // existe (o está inactivo), invalidamos sesión inmediatamente.
  if (role == 'patient') {
    final exists = await authService.currentPatientProfileExists();
    if (!exists) {
      ref
          .read(authInvalidSessionMessageProvider.notifier)
          .set('Correo o contraseña incorrectos');
      await authService.signOut();
      return null;
    }
  }

  return role;
});

class AuthInvalidSessionMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final authInvalidSessionMessageProvider =
    NotifierProvider<AuthInvalidSessionMessageNotifier, String?>(
      AuthInvalidSessionMessageNotifier.new,
    );

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);

final fcmBootstrapProvider = Provider<void>((ref) {
  final authService = ref.watch(authServiceProvider);
  final fcmService = ref.watch(fcmServiceProvider);
  final router = ref.watch(appRouterProvider);

  Future<String?> resolveRole() async =>
      await ref.read(userRoleProvider.future);

  unawaited(
    fcmService.initialize(
      authService: authService,
      resolveRole: resolveRole,
      router: router,
    ),
  );

  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) async {
    final previousUser = previous?.asData?.value;
    final nextUser = next.asData?.value;
    final currentRole = await resolveRole();

    if (previousUser != null && nextUser == null) {
      if (currentRole == 'admin' || currentRole == 'patient') {
        await fcmService.clearCurrentUserDeviceToken(
          authService: authService,
          role: currentRole!,
        );
      }
      return;
    }

    if (nextUser != null) {
      await fcmService.syncCurrentUserDeviceToken(
        authService: authService,
        resolveRole: resolveRole,
      );
    }
  });
});

class AuthNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      final authService = ref.read(authServiceProvider);
      final credential = await authService.signIn(email, password);

      final uid = credential.user?.uid;
      if (uid != null) {
        final role = await authService.getUserRole();
        final effectiveRole = role == 'admin' ? 'admin' : 'patient';

        // Regla de seguridad: si el usuario es paciente y su documento
        // ya no existe (o está inactivo), bloquear sin revelar detalle.
        if (effectiveRole == 'patient') {
          final exists = await authService.currentPatientProfileExists();
          if (!exists) {
            await authService.signOut();
            throw FirebaseAuthException(
              code: 'invalid-credential',
              message: 'Correo o contraseña incorrectos',
            );
          }
        }

        ref.invalidate(userRoleProvider);
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
    try {
      final authService = ref.read(authServiceProvider);
      await authService.registerPatientSelf(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> createPatientByAdmin({
    required String email,
    required String password,
    String? displayName,
    String? treatmentType,
    double? totalTreatment,
  }) async {
    state = const AsyncLoading();
    try {
      final authService = ref.read(authServiceProvider);
      await authService.createPatientByAdmin(
        email: email,
        password: password,
        displayName: displayName,
        treatmentType: treatmentType,
        totalTreatment: totalTreatment,
      );
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    try {
      await ref.read(authServiceProvider).resetPassword(email);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final authService = ref.read(authServiceProvider);
    final role = await ref.read(userRoleProvider.future);

    final result = await AsyncValue.guard(() async {
      if (role == 'admin' || role == 'patient') {
        await ref
            .read(fcmServiceProvider)
            .clearCurrentUserDeviceToken(authService: authService, role: role!);
      }
      await authService.signOut();
    });

    ref.invalidate(authStateProvider);
    ref.invalidate(userRoleProvider);
    state = result.hasError ? result : const AsyncData(null);
  }
}
