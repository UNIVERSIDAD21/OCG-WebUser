import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/app_notification_model.dart';
import '../models/scheduled_notification_model.dart';

class NotificationsRepository {
  NotificationsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _db.collection(FirestorePaths.notifications);

  CollectionReference<Map<String, dynamic>> get _scheduledRef =>
      _db.collection(FirestorePaths.scheduledNotifications);

  Stream<List<AppNotificationModel>> watchUserNotifications(String recipientId) {
    return _notificationsRef
        .where('recipientId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotificationModel.fromJson(doc.data(), id: doc.id))
              .toList(),
        );
  }

  Stream<List<ScheduledNotificationModel>> watchAppointmentReminders(String appointmentId) {
    return _scheduledRef
        .where('appointmentId', isEqualTo: appointmentId)
        .orderBy('scheduledFor')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ScheduledNotificationModel.fromJson(doc.data(), id: doc.id))
              .toList(),
        );
  }

  Future<void> markAsRead(String notificationId) {
    return _notificationsRef.doc(notificationId).update({
      'read': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead(String recipientId) async {
    final snapshot = await _notificationsRef
        .where('recipientId', isEqualTo: recipientId)
        .where('read', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'read': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
