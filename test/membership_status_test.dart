import 'package:flutter_test/flutter_test.dart';
import 'package:fit_body_gym/features/membership/models/membership_status.dart';

void main() {
  final now = DateTime(2026, 10, 30);

  test('manual authorization allows access without an active membership', () {
    final status = MembershipStatus.fromData({
      'full_name': 'Cliente autorizado',
      'membership_active': false,
      'membership_end': '2026-10-01',
      'app_access_status': 'active',
      'app_access_expires_at': '2026-11-30T23:59:59.999Z',
    }, now: now);

    expect(status.active, isTrue);
    expect(status.manualAccess, isTrue);
  });

  test('expired manual authorization does not allow access', () {
    final status = MembershipStatus.fromData({
      'membership_active': false,
      'app_access_status': 'active',
      'app_access_expires_at': '2026-10-29T23:59:59.999Z',
    }, now: now);

    expect(status.active, isFalse);
  });

  test('revocation blocks access even when membership is active', () {
    final status = MembershipStatus.fromData({
      'membership_active': true,
      'membership_end': '2026-11-30',
      'app_access_status': 'revoked',
    }, now: now);

    expect(status.active, isFalse);
  });
}
