import 'package:flutter_test/flutter_test.dart';
import 'package:fit_body_gym/features/membership/models/membership_status.dart';

void main() {
  group('authorized app access', () {
    final today = DateTime(2026, 10, 29);

    test('unlocks protected modules without a paid membership', () {
      final status = MembershipStatus.fromData({
        'full_name': 'Entrenador autorizado',
        'membership_active': false,
        'membership_end': null,
        'authorized_access': true,
        'authorized_access_expires_at': null,
      }, now: today);

      expect(status.active, isTrue);
      expect(status.authorized, isTrue);
    });

    test('honors an authorization that expires today', () {
      final status = MembershipStatus.fromData({
        'membership_active': false,
        'authorized_access': true,
        'authorized_access_expires_at': '2026-10-29',
      }, now: today);

      expect(status.active, isTrue);
    });

    test('rejects an expired authorization', () {
      final status = MembershipStatus.fromData({
        'membership_active': false,
        'authorized_access': true,
        'authorized_access_expires_at': '2026-10-28',
      }, now: today);

      expect(status.active, isFalse);
    });
  });
}
