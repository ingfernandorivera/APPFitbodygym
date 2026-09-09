class AppUserProfile {
  const AppUserProfile({
    required this.fullName,
    required this.birthDate,
    required this.phone,
    required this.goal,
    required this.limitations,
  });

  final String fullName;
  final String birthDate;
  final String phone;
  final String goal;
  final String limitations;

  bool get isEmpty =>
      fullName.isEmpty &&
      birthDate.isEmpty &&
      phone.isEmpty &&
      goal.isEmpty &&
      limitations.isEmpty;

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'birthDate': birthDate,
    'phone': phone,
    'goal': goal,
    'limitations': limitations,
  };

  factory AppUserProfile.empty() => const AppUserProfile(
    fullName: '',
    birthDate: '',
    phone: '',
    goal: '',
    limitations: '',
  );

  factory AppUserProfile.fromJson(Map<String, dynamic> json) => AppUserProfile(
    fullName: '${json['fullName'] ?? ''}',
    birthDate: '${json['birthDate'] ?? ''}',
    phone: '${json['phone'] ?? ''}',
    goal: '${json['goal'] ?? ''}',
    limitations: '${json['limitations'] ?? ''}',
  );
}
