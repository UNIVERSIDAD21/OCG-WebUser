import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
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

  try {
    final role = await authService.getUserRole();

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
  } on FirebaseException catch (error) {
    if (error.code == 'permission-denied') {
      debugPrint(
        'USER ROLE CHECK OMITIDO: permission-denied durante estabilización para ${user.uid}',
      );
      return 'patient';
    }
    rethrow;
  }
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

  unawaited(() async {
    await fcmService.initialize(
      authService: authService,
      resolveRole: resolveRole,
      router: router,
    );
  }());
});

class AuthNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> signIn(String email, String password) async {
    developer.log(
      'AuthNotifier.signIn start',
      name: 'ocg.auth',
      error: {'email': email.trim()},
    );
    state = const AsyncLoading();
    try {
      final authService = ref.read(authServiceProvider);
      final credential = await authService.signIn(email, password);
      developer.log(
        'AuthNotifier.signIn after authService.signIn',
        name: 'ocg.auth',
        error: {'uid': credential.user?.uid},
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        ref.read(fcmServiceProvider).resetSyncState();
        developer.log(
          'AuthNotifier.signIn before getUserRole',
          name: 'ocg.auth',
          error: {'uid': uid},
        );
        final role = await authService.getUserRole();
        developer.log(
          'AuthNotifier.signIn after getUserRole',
          name: 'ocg.auth',
          error: {'uid': uid, 'role': role},
        );
        final effectiveRole = role == 'admin' ? 'admin' : 'patient';

        if (effectiveRole == 'patient') {
          developer.log(
            'AuthNotifier.signIn before currentPatientProfileExists',
            name: 'ocg.auth',
            error: {'uid': uid},
          );
          final exists = await authService.currentPatientProfileExists();
          developer.log(
            'AuthNotifier.signIn after currentPatientProfileExists',
            name: 'ocg.auth',
            error: {'uid': uid, 'exists': exists},
          );
          if (!exists) {
            await authService.signOut();
            throw FirebaseAuthException(
              code: 'invalid-credential',
              message: 'Correo o contraseña incorrectos',
            );
          }
        }

        ref.invalidate(userRoleProvider);
        unawaited(() async {
          try {
            developer.log(
              'AuthNotifier.signIn spawning registerCurrentDeviceAfterLogin',
              name: 'ocg.auth',
              error: {'uid': uid, 'role': effectiveRole},
            );
            await ref
                .read(fcmServiceProvider)
                .registerCurrentDeviceAfterLogin(
                  authService: authService,
                  resolveRole: () async => effectiveRole,
                );
            developer.log(
              'AuthNotifier.signIn registerCurrentDeviceAfterLogin completed',
              name: 'ocg.auth',
              error: {'uid': uid},
            );
          } catch (error, stackTrace) {
            developer.log(
              'AuthNotifier.signIn registerCurrentDeviceAfterLogin failed without blocking login',
              name: 'ocg.auth',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }());
      }

      state = const AsyncData(null);
      developer.log('AuthNotifier.signIn end', name: 'ocg.auth');
    } catch (error, stackTrace) {
      developer.log(
        'AuthNotifier.signIn failed',
        name: 'ocg.auth',
        error: error,
        stackTrace: stackTrace,
      );
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

    final result = await AsyncValue.guard(() async {
      final role = await ref.read(userRoleProvider.future);
      if (role == 'admin' || role == 'patient') {
        await ref
            .read(fcmServiceProvider)
            .clearCurrentUserDeviceToken(
              authService: authService,
              role: role!,
              source: 'auth_notifier.sign_out',
            );
      }
      await authService.signOut();
    });

    ref.invalidate(authStateProvider);
    ref.invalidate(userRoleProvider);
    state = result.hasError ? result : const AsyncData(null);
  }
}
