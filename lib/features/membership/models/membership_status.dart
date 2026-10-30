class MembershipStatus {
  const MembershipStatus({
    required this.name,
    required this.end,
    required this.days,
    required this.active,
    this.manualAccess = false,
  });

  final String name;
  final DateTime? end;
  final int days;
  final bool active;
  final bool manualAccess;

  factory MembershipStatus.fromData(
    Map<String, dynamic> data, {
    DateTime? now,
  }) {
    final end = DateTime.tryParse('${data['membership_end']}');
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final days = end?.difference(startOfToday).inDays ?? -1;
    final appStatus = '${data['app_access_status'] ?? 'not_enabled'}';
    final appAccessEnd = DateTime.tryParse('${data['app_access_expires_at']}');
    final appAccessDays = appAccessEnd?.difference(startOfToday).inDays ?? -1;
    final manualAccess = appStatus == 'active' && appAccessDays >= 0;
    final membershipAccess = data['membership_active'] == true && days >= 0;
    final revoked = appStatus == 'revoked';

    return MembershipStatus(
      name: '${data['full_name'] ?? ''}',
      end: end,
      days: days,
      active: !revoked && (membershipAccess || manualAccess),
      manualAccess: manualAccess,
    );
  }
}
