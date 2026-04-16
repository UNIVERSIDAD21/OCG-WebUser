import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patients/providers/patients_provider.dart';
import '../data/models/app_notification_model.dart';
import '../data/models/scheduled_notification_model.dart';
import '../data/repositories/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(firestoreProvider));
});

final userNotificationsProvider =
    StreamProvider.family<List<AppNotificationModel>, String>((ref, recipientId) {
  return ref.watch(notificationsRepositoryProvider).watchUserNotifications(recipientId);
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
}

final notificationsActionsProvider =
    AsyncNotifierProvider<NotificationsActionsNotifier, void>(
  NotificationsActionsNotifier.new,
);
