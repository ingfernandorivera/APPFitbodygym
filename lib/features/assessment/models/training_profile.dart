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
    this.gender = 'Hombre',
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
  final String gender;
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
    'gender': gender,
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
      gender: json['gender'] as String? ?? 'Hombre',
      weightUnit: json['weightUnit'] == 'lb' ? 'lb' : 'kg',
      bodyRepresentation: json['bodyRepresentation'] as String? ?? 'Neutral',
      bodyShape: json['bodyShape'] as String? ?? 'Sin indicar',
      bodyFatEstimate: (json['bodyFatEstimate'] as num?)?.toDouble(),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      schedule: json['schedule'] as String? ?? 'Flexible',
      trainingLocation: json['trainingLocation'] as String? ?? 'Gimnasio',
      equipment: json['equipment'] as String? ?? 'Gimnasio completo',
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

  TrainingProfile copyWith({
    double? weightKg,
    double? heightCm,
    int? age,
    String? goal,
    String? experience,
    int? daysPerWeek,
    int? minutesPerSession,
    String? preferences,
    String? limitations,
    String? gender,
    String? weightUnit,
    String? bodyRepresentation,
    String? bodyShape,
    double? bodyFatEstimate,
    double? targetWeightKg,
    String? schedule,
    String? trainingLocation,
    String? equipment,
    List<String>? priorityMuscles,
    List<String>? motivations,
    String? dailyActivity,
    double? sleepHours,
    double? hydrationLiters,
  }) => TrainingProfile(
    weightKg: weightKg ?? this.weightKg,
    heightCm: heightCm ?? this.heightCm,
    age: age ?? this.age,
    goal: goal ?? this.goal,
    experience: experience ?? this.experience,
    daysPerWeek: daysPerWeek ?? this.daysPerWeek,
    minutesPerSession: minutesPerSession ?? this.minutesPerSession,
    preferences: preferences ?? this.preferences,
    limitations: limitations ?? this.limitations,
    gender: gender ?? this.gender,
    weightUnit: weightUnit ?? this.weightUnit,
    bodyRepresentation: bodyRepresentation ?? this.bodyRepresentation,
    bodyShape: bodyShape ?? this.bodyShape,
    bodyFatEstimate: bodyFatEstimate ?? this.bodyFatEstimate,
    targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    schedule: schedule ?? this.schedule,
    trainingLocation: trainingLocation ?? this.trainingLocation,
    equipment: equipment ?? this.equipment,
    priorityMuscles: priorityMuscles ?? this.priorityMuscles,
    motivations: motivations ?? this.motivations,
    dailyActivity: dailyActivity ?? this.dailyActivity,
    sleepHours: sleepHours ?? this.sleepHours,
    hydrationLiters: hydrationLiters ?? this.hydrationLiters,
  );
}
