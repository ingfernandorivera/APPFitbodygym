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
    this.bodyRepresentation = 'Neutral',
    this.bodyShape = 'Sin indicar',
    this.bodyFatEstimate,
    this.targetWeightKg,
    this.schedule = 'Flexible',
    this.trainingLocation = 'Gimnasio',
    this.equipment = 'Sin indicar',
    this.priorityMuscles = const [],
    this.motivations = const [],
    this.dailyActivity = 'Sin indicar',
    this.sleepHours,
    this.hydrationLiters,
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

  final String bodyRepresentation;
  final String bodyShape;
  final double? bodyFatEstimate;
  final double? targetWeightKg;
  final String schedule;
  final String trainingLocation;
  final String equipment;
  final List<String> priorityMuscles;
  final List<String> motivations;
  final String dailyActivity;
  final double? sleepHours;
  final double? hydrationLiters;

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
    'schemaVersion': 2,
    'bodyRepresentation': bodyRepresentation,
    'bodyShape': bodyShape,
    'bodyFatEstimate': bodyFatEstimate,
    'targetWeightKg': targetWeightKg,
    'schedule': schedule,
    'trainingLocation': trainingLocation,
    'equipment': equipment,
    'priorityMuscles': priorityMuscles,
    'motivations': motivations,
    'dailyActivity': dailyActivity,
    'sleepHours': sleepHours,
    'hydrationLiters': hydrationLiters,
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
      weightUnit: json['weightUnit'] == 'lb' ? 'lb' : 'kg',
      bodyRepresentation: json['bodyRepresentation'] as String? ?? 'Neutral',
      bodyShape: json['bodyShape'] as String? ?? 'Sin indicar',
      bodyFatEstimate: (json['bodyFatEstimate'] as num?)?.toDouble(),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      schedule: json['schedule'] as String? ?? 'Flexible',
      trainingLocation: json['trainingLocation'] as String? ?? 'Gimnasio',
      equipment: json['equipment'] as String? ?? 'Sin indicar',
      priorityMuscles:
          (json['priorityMuscles'] as List?)?.whereType<String>().toList() ??
          const [],
      motivations:
          (json['motivations'] as List?)?.whereType<String>().toList() ??
          const [],
      dailyActivity: json['dailyActivity'] as String? ?? 'Sin indicar',
      sleepHours: (json['sleepHours'] as num?)?.toDouble(),
      hydrationLiters: (json['hydrationLiters'] as num?)?.toDouble(),
    );
  }
}
