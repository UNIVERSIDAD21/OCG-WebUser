import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Consultation Firestore rules', () {
    test('admin can create and update patient consultation documents', () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('match /consultations/{consultationId}'));
      expect(rules, contains('allow read: if isAdmin();'));
      expect(rules, contains('allow create, update: if isAdmin() &&'));
      expect(rules, contains('incomingPatientMatches(patientId)'));
      expect(
        rules,
        contains(
          "(!('id' in request.resource.data) || request.resource.data.id == consultationId)",
        ),
      );
    });
  });

  group('Consultation web upload safety', () {
    test('clinical consultation does not use dart:io uploads', () {
      final source = File(
        'lib/features/consultation/presentation/consultation_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains("import 'dart:io'")));
      expect(source, isNot(contains('putFile(')));
      expect(source, isNot(contains('signatureClinicalFileId')));
      expect(source, isNot(contains("category: 'consentimiento'")));
      expect(source, contains('withData: true'));
      expect(source, contains('saveCompletedConsultation'));
    });
  });
}
