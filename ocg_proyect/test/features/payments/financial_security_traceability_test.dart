import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/payments/data/models/financial_item_model.dart';

void main() {
  group('Financial security and traceability', () {
    test('FinancialItemModel serializa trazabilidad mínima', () {
      final item = FinancialItemModel(
        id: 'initial',
        patientId: 'p1',
        treatmentId: 'tx-1',
        name: 'Inicial',
        normalizedName: 'inicial',
        kind: 'initial',
        amount: 100000,
        deletable: false,
        editableName: true,
        order: 1,
        active: true,
        createdByAdmin: true,
        createdBy: 'admin-1',
        updatedBy: 'admin-2',
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 2),
      );

      final json = item.toJson();
      expect(json['createdBy'], 'admin-1');
      expect(json['updatedBy'], 'admin-2');
      expect(json['createdAt'], isNotNull);
      expect(json['updatedAt'], isNotNull);
    });

    test('firestore.rules deja financialItems solo para admin con audit fields', () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('match /financialItems/{itemId}'));
      expect(rules, contains('allow create, update: if isAdmin() &&'));
      expect(rules, contains('hasAuditFields()'));
      expect(rules, contains('incomingPatientMatches(patientId)'));
      expect(rules, contains('incomingTreatmentMatches(treatmentId)'));
    });
  });
}
