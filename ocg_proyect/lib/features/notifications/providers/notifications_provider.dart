import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../services/notifications/notification_navigation_service.dart';
import '../data/models/app_notification_model.dart';
import '../data/models/scheduled_notification_model.dart';
import '../data/repositories/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(firestoreProvider));
});

final notificationNavigationServiceProvider = Provider<NotificationNavigationService>((ref) {
  return const NotificationNavigationService();
});

final userNotificationsProvider =
    StreamProvider.family<List<AppNotificationModel>, String>((ref, recipientId) {
  return ref.watch(notificationsRepositoryProvider).watchUserNotifications(recipientId);
});

final unreadNotificationsCountProvider = Provider.family<int, String>((ref, recipientId) {
  final items = ref.watch(userNotificationsProvider(recipientId)).asData?.value ?? const <AppNotificationModel>[];
  return items.where((item) => !item.read).length;
});

final appointmentRemindersProvider =
    StreamProvider.family<List<ScheduledNotificationModel>, String>((ref, appointmentId) {
  return ref.watch(notificationsRepositoryProvider).watchAppointmentReminders(appointmentId);
});

class NotificationsActionsNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> markAsRead(String notificationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(notificationsRepositoryProvider).markAsRead(notificationId);
    });
  }

  Future<void> markAllAsRead(String recipientId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(notificationsRepositoryProvider).markAllAsRead(recipientId);
    });
  }

  Future<void> openNotification(AppNotificationModel notification) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (!notification.read) {
        await ref.read(notificationsRepositoryProvider).markAsRead(notification.id);
      }

      final router = ref.read(appRouterProvider);
      final userRole = await ref.read(userRoleProvider.future);
      ref.read(notificationNavigationServiceProvider).openFromStoredNotification(
        router,
        notification,
        userRole: userRole,
      );
    });
  }
}

final notificationsActionsProvider =
    AsyncNotifierProvider<NotificationsActionsNotifier, void>(
  NotificationsActionsNotifier.new,
);
