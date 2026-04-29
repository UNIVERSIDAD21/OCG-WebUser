import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/notification_model.dart';
import '../data/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

final pushPermissionStateProvider =
    FutureProvider<PushNotificationPermissionState>((ref) async {
      return ref.watch(notificationServiceProvider).getCurrentPermissionState();
    });

final notificationNavigationIntentsProvider =
    StreamProvider<NotificationNavigationIntent>((ref) {
      return ref.watch(notificationServiceProvider).navigationIntents;
    });

final pushBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(notificationServiceProvider).initialize();
});
