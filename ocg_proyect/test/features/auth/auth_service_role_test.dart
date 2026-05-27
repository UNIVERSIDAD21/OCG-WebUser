import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/services/firebase/auth_service.dart';

void main() {
  group('adminDocGrantsAdmin', () {
    test('accepts current and legacy admin documents', () {
      expect(adminDocGrantsAdmin({'role': 'admin'}), isTrue);
      expect(adminDocGrantsAdmin({'email': 'admin@ocg.com'}), isTrue);
      expect(adminDocGrantsAdmin({'admin': true}), isTrue);
    });

    test('rejects explicitly demoted or disabled admin documents', () {
      expect(adminDocGrantsAdmin({'role': 'patient'}), isFalse);
      expect(adminDocGrantsAdmin({'role': 'admin', 'admin': false}), isFalse);
      expect(adminDocGrantsAdmin({'role': 'admin', 'active': false}), isFalse);
      expect(adminDocGrantsAdmin({'role': 'admin', 'disabled': true}), isFalse);
      expect(adminDocGrantsAdmin(null), isFalse);
    });
  });
}
