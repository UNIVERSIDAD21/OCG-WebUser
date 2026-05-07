import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    this.recipientRole,
    this.channel,
    this.targetRoute,
    this.entityId,
    this.entityType,
    this.appointmentId,
    this.treatmentId,
    this.paymentId,
    this.payload = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String recipientId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final String? recipientRole;
  final String? channel;
  final String? targetRoute;
  final String? entityId;
  final String? entityType;
  final String? appointmentId;
  final String? treatmentId;
  final String? paymentId;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, dynamic> _parsePayload(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }

  factory AppNotificationModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    final payload = _parsePayload(json['payload']);
    final entityId = json['entityId']?.toString();
    final entityType = json['entityType']?.toString();

    return AppNotificationModel(
      id: id ?? (json['id'] ?? '').toString(),
      recipientId: (json['recipientId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'generic').toString(),
      read: (json['read'] as bool?) ?? false,
      recipientRole: json['recipientRole']?.toString(),
      channel: json['channel']?.toString(),
      targetRoute: json['targetRoute']?.toString(),
      entityId: entityId,
      entityType: entityType,
      appointmentId:
          json['appointmentId']?.toString() ??
          (entityType == 'appointment' ? entityId : null) ??
          payload['appointmentId']?.toString(),
      treatmentId:
          json['treatmentId']?.toString() ??
          (entityType == 'treatment' ? entityId : null) ??
          payload['treatmentId']?.toString(),
      paymentId:
          json['paymentId']?.toString() ??
          (entityType == 'payment' ? entityId : null) ??
          payload['paymentId']?.toString(),
      payload: payload,
      createdAt: _parseNullableDate(json['createdAt']),
      updatedAt: _parseNullableDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toRoutingPayload() {
    final routeCandidate = targetRoute?.trim() ?? '';
    final routingPayload = <String, dynamic>{
      'type': type,
      'entityId': entityId ?? '',
      'entityType': entityType ?? '',
      'appointmentId':
          appointmentId ?? payload['appointmentId']?.toString() ?? '',
      'treatmentId': treatmentId ?? payload['treatmentId']?.toString() ?? '',
      'paymentId': paymentId ?? payload['paymentId']?.toString() ?? '',
      'patientId': payload['patientId']?.toString() ?? recipientId,
      ...payload,
    };

    routingPayload.remove('route');
    routingPayload.remove('targetRoute');

    if (_isLocalRouteCandidate(routeCandidate)) {
      routingPayload['route'] = routeCandidate;
    }

    return routingPayload;
  }

  bool _isLocalRouteCandidate(String route) {
    final lowerRoute = route.toLowerCase();
    return route.startsWith('/') &&
        !route.startsWith('//') &&
        !lowerRoute.startsWith('http://') &&
        !lowerRoute.startsWith('https://') &&
        !route.contains('://');
  }
}
