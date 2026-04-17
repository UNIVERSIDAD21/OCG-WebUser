import 'package:cloud_firestore/cloud_firestore.dart';

class TreatmentFinancialSummaryModel {
  const TreatmentFinancialSummaryModel({
    required this.currency,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.itemsCount,
    this.lastPricingUpdateAt,
  });

  final String currency;
  final double subtotalAmount;
  final double discountAmount;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final int itemsCount;
  final DateTime? lastPricingUpdateAt;

  factory TreatmentFinancialSummaryModel.fromJson(Map<String, dynamic> json) {
    return TreatmentFinancialSummaryModel(
      currency: (json['currency'] ?? 'COP').toString(),
      subtotalAmount: _toDouble(json['subtotalAmount']),
      discountAmount: _toDouble(json['discountAmount']),
      totalAmount: _toDouble(json['totalAmount']),
      paidAmount: _toDouble(json['paidAmount']),
      pendingAmount: _toDouble(json['pendingAmount']),
      itemsCount: (json['itemsCount'] as num?)?.toInt() ?? 0,
      lastPricingUpdateAt: _parseNullableDate(json['lastPricingUpdateAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'currency': currency,
        'subtotalAmount': subtotalAmount,
        'discountAmount': discountAmount,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'pendingAmount': pendingAmount,
        'itemsCount': itemsCount,
        'lastPricingUpdateAt': lastPricingUpdateAt == null
            ? null
            : Timestamp.fromDate(lastPricingUpdateAt!),
      };

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
