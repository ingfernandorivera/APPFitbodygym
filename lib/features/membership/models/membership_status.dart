class MembershipStatus {
  const MembershipStatus({
    required this.name,
    required this.end,
    required this.days,
    required this.active,
    this.authorized = false,
  });

  final String name;
  final DateTime? end;
  final int days;
  final bool active;
  final bool authorized;

  factory MembershipStatus.fromData(
    Map<String, dynamic> data, {
    DateTime? now,
  }) {
    final end = DateTime.tryParse('${data['membership_end']}');
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final days = end?.difference(startOfToday).inDays ?? -1;

    final authorizedUntil = DateTime.tryParse(
      '${data['authorized_access_expires_at'] ?? ''}',
    );
    final authorizedAccess = data['authorized_access'] == true &&
        (authorizedUntil == null || !authorizedUntil.isBefore(startOfToday));

    return MembershipStatus(
      name: '${data['full_name'] ?? ''}',
      end: end,
      days: days,
      active: (data['membership_active'] == true && days >= 0) ||
          authorizedAccess,
      authorized: authorizedAccess,
    );
  }
}
