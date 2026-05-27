import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Clinical files Firestore rules', () {
    test('top-level clinical file reads do not depend on write payloads', () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('match /clinicalFiles/{fileId}'));
      expect(rules, contains('allow read: if isAdmin() ||'));
      expect(rules, contains('allow create, update: if isAdmin() &&'));
      expect(
        rules,
        contains(
          r"get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role != 'patient'",
        ),
      );
      expect(
        rules,
        isNot(
          contains('allow read, create, update: if isAdmin() &&'),
        ),
      );
    });
  });
}
