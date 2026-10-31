import 'package:fit_body_gym/features/membership/models/membership_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 30);

  test('authorized access unlocks features without an active membership', () {
    final status = MembershipStatus.fromData({
      'full_name': 'Fernando',
      'membership_active': false,
      'membership_end': '2026-10-09',
      'authorized_access': true,
      'authorized_access_expires_at': '2026-12-31',
    }, now: today);

    expect(status.active, isTrue);
    expect(status.authorizedAccess, isTrue);
  });

  test('expired authorized access does not unlock features', () {
    final status = MembershipStatus.fromData({
      'membership_active': false,
      'membership_end': '2026-10-09',
      'authorized_access': true,
      'authorized_access_expires_at': '2026-10-29',
    }, now: today);

    expect(status.active, isFalse);
    expect(status.authorizedAccess, isFalse);
  });
}
