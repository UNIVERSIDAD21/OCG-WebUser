import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduledNotificationModel {
  const ScheduledNotificationModel({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.channel,
    required this.kind,
    required this.status,
    required this.scheduledFor,
    this.treatmentId,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.providerMessageId,
    this.errorCode,
    this.errorMessage,
    this.sentAt,
    this.payloadSnapshot,
  });

  final String id;
  final String appointmentId;
  final String patientId;
  final String channel;
  final String kind;
  final String status;
  final DateTime scheduledFor;
  final String? treatmentId;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final String? providerMessageId;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? sentAt;
  final Map<String, dynamic>? payloadSnapshot;

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime _parseDate(dynamic value) {
    return _parseNullableDate(value) ?? DateTime.now();
  }

  factory ScheduledNotificationModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return ScheduledNotificationModel(
      id: id ?? (json['id'] ?? '').toString(),
      appointmentId: (json['appointmentId'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      channel: (json['channel'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      scheduledFor: _parseDate(json['scheduledFor']),
      treatmentId: json['treatmentId']?.toString(),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      lastAttemptAt: _parseNullableDate(json['lastAttemptAt']),
      providerMessageId: json['providerMessageId']?.toString(),
      errorCode: json['errorCode']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
      sentAt: _parseNullableDate(json['sentAt']),
      payloadSnapshot: (json['payloadSnapshot'] as Map?)?.cast<String, dynamic>(),
    );
  }
}
