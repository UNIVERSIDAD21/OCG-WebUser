import 'package:cloud_firestore/cloud_firestore.dart';

enum PushNotificationPermissionState {
  authorized,
  denied,
  provisional,
  notDetermined,
  unsupported,
}

enum NotificationMessageType {
  appointmentCreated,
  appointmentConfirmed,
  appointmentCancelled,
  appointmentRescheduled,
  appointmentReminder,
  paymentRegistered,
  paymentDue,
  treatmentUpdated,
  generalMessage,
  unknown,
}

enum NotificationDeliveryState { received, opened, read }

class NotificationTokenRecord {
  const NotificationTokenRecord({
    required this.userId,
    required this.role,
    required this.platform,
    required this.token,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
    this.deviceId,
  });

  final String userId;
  final String role;
  final String platform;
  final String token;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastSeenAt;
  final String? deviceId;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role,
      'platform': platform,
      'token': token,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'deviceId': deviceId,
    };
  }
}

class NotificationNavigationIntent {
  const NotificationNavigationIntent({
    required this.type,
    required this.route,
    required this.targetId,
    this.patientId,
    this.appointmentId,
    this.paymentId,
    this.treatmentId,
    this.createdAt,
    this.rawData = const <String, dynamic>{},
  });

  final NotificationMessageType type;
  final String route;
  final String targetId;
  final String? patientId;
  final String? appointmentId;
  final String? paymentId;
  final String? treatmentId;
  final String? createdAt;
  final Map<String, dynamic> rawData;

  factory NotificationNavigationIntent.fromData(Map<String, dynamic> data) {
    final typeRaw = (data['type'] ?? '').toString();
    NotificationMessageType parsedType;
    switch (typeRaw) {
      case 'appointment_created':
        parsedType = NotificationMessageType.appointmentCreated;
        break;
      case 'appointment_confirmed':
        parsedType = NotificationMessageType.appointmentConfirmed;
        break;
      case 'appointment_cancelled':
        parsedType = NotificationMessageType.appointmentCancelled;
        break;
      case 'appointment_rescheduled':
        parsedType = NotificationMessageType.appointmentRescheduled;
        break;
      case 'appointment_reminder':
        parsedType = NotificationMessageType.appointmentReminder;
        break;
      case 'payment_registered':
        parsedType = NotificationMessageType.paymentRegistered;
        break;
      case 'payment_due':
        parsedType = NotificationMessageType.paymentDue;
        break;
      case 'treatment_updated':
        parsedType = NotificationMessageType.treatmentUpdated;
        break;
      case 'general_message':
        parsedType = NotificationMessageType.generalMessage;
        break;
      default:
        parsedType = NotificationMessageType.unknown;
    }

    return NotificationNavigationIntent(
      type: parsedType,
      route: (data['route'] ?? '').toString(),
      targetId: (data['targetId'] ?? '').toString(),
      patientId: data['patientId']?.toString(),
      appointmentId: data['appointmentId']?.toString(),
      paymentId: data['paymentId']?.toString(),
      treatmentId: data['treatmentId']?.toString(),
      createdAt: data['createdAt']?.toString(),
      rawData: data,
    );
  }
}

class InAppNotificationRecord {
  const InAppNotificationRecord({
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.deliveryState,
    required this.createdAt,
    required this.data,
  });

  final String userId;
  final NotificationMessageType type;
  final String title;
  final String body;
  final NotificationDeliveryState deliveryState;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'body': body,
      'deliveryState': deliveryState.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'data': data,
    };
  }
}
