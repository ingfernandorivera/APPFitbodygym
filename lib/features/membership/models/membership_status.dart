class MembershipStatus {
  const MembershipStatus({
    required this.name,
    required this.end,
    required this.days,
    required this.active,
    this.authorizedAccess = false,
    this.authorizedAccessExpiresAt,
  });

  final String name;
  final DateTime? end;
  final int days;
  final bool active;
  final bool authorizedAccess;
  final DateTime? authorizedAccessExpiresAt;

  factory MembershipStatus.fromData(
    Map<String, dynamic> data, {
    DateTime? now,
  }) {
    final end = DateTime.tryParse('${data['membership_end']}');
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final days = end?.difference(startOfToday).inDays ?? -1;
    final authorizedAccessExpiresAt = DateTime.tryParse(
      '${data['authorized_access_expires_at'] ?? data['app_access_expires_at']}',
    );
    final accessEnabled =
        data['authorized_access'] == true ||
        data['app_access_status'] == 'active';
    final authorizedAccess =
        accessEnabled &&
        (authorizedAccessExpiresAt == null ||
            !authorizedAccessExpiresAt.isBefore(startOfToday));
    final paidMembershipActive = data['membership_active'] == true && days >= 0;

    return MembershipStatus(
      name: '${data['full_name'] ?? ''}',
      end: end,
      days: days,
      active: paidMembershipActive || authorizedAccess,
      authorizedAccess: authorizedAccess,
      authorizedAccessExpiresAt: authorizedAccessExpiresAt,
    );
  }
}
