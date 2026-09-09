class TrainingProfile {
  const TrainingProfile({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.goal,
    required this.experience,
    required this.daysPerWeek,
    required this.minutesPerSession,
    required this.preferences,
    required this.limitations,
    this.weightUnit = 'kg',
  });

  final double weightKg;
  final double heightCm;
  final int age;
  final String goal;
  final String experience;
  final int daysPerWeek;
  final int minutesPerSession;
  final String preferences;
  final String limitations;
  final String weightUnit;

  Map<String, dynamic> toJson() => {
    'weightKg': weightKg,
    'heightCm': heightCm,
    'age': age,
    'goal': goal,
    'experience': experience,
    'daysPerWeek': daysPerWeek,
    'minutesPerSession': minutesPerSession,
    'preferences': preferences,
    'limitations': limitations,
    'weightUnit': weightUnit,
  };

  factory TrainingProfile.fromJson(Map<String, dynamic> json) {
    return TrainingProfile(
      weightKg: (json['weightKg'] as num).toDouble(),
      heightCm: (json['heightCm'] as num).toDouble(),
      age: json['age'] as int,
      goal: json['goal'] as String,
      experience: json['experience'] as String,
      daysPerWeek: json['daysPerWeek'] as int,
      minutesPerSession: json['minutesPerSession'] as int,
      preferences: json['preferences'] as String? ?? '',
      limitations: json['limitations'] as String? ?? '',
      weightUnit: json['weightUnit'] as String? ?? 'kg',
    );
  }
}
