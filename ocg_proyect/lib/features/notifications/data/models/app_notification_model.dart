import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    this.channel,
    this.appointmentId,
    this.treatmentId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String recipientId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final String? channel;
  final String? appointmentId;
  final String? treatmentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return AppNotificationModel(
      id: id ?? (json['id'] ?? '').toString(),
      recipientId: (json['recipientId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'generic').toString(),
      read: (json['read'] as bool?) ?? false,
      channel: json['channel']?.toString(),
      appointmentId: json['appointmentId']?.toString(),
      treatmentId: json['treatmentId']?.toString(),
      createdAt: _parseNullableDate(json['createdAt']),
      updatedAt: _parseNullableDate(json['updatedAt']),
    );
  }
}
