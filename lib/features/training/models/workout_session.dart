class ExerciseResult {
  const ExerciseResult({
    required this.exerciseId,
    required this.exerciseName,
    required this.completed,
    required this.weightKg,
    required this.repetitions,
    required this.difficulty,
  });

  final String exerciseId;
  final String exerciseName;
  final bool completed;
  final double? weightKg;
  final int? repetitions;
  final int difficulty;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'completed': completed,
    'weightKg': weightKg,
    'repetitions': repetitions,
    'difficulty': difficulty,
  };

  factory ExerciseResult.fromJson(Map<String, dynamic> json) => ExerciseResult(
    exerciseId: json['exerciseId'] as String,
    exerciseName: json['exerciseName'] as String,
    completed: json['completed'] as bool? ?? false,
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    repetitions: json['repetitions'] as int?,
    difficulty: json['difficulty'] as int? ?? 3,
  );
}

class WorkoutSession {
  const WorkoutSession({
    required this.planName,
    required this.dayNumber,
    required this.dayTitle,
    required this.completedAt,
    required this.results,
  });

  final String planName;
  final int dayNumber;
  final String dayTitle;
  final DateTime completedAt;
  final List<ExerciseResult> results;

  int get completedExercises =>
      results.where((result) => result.completed).length;

  Map<String, dynamic> toJson() => {
    'planName': planName,
    'dayNumber': dayNumber,
    'dayTitle': dayTitle,
    'completedAt': completedAt.toIso8601String(),
    'results': results.map((result) => result.toJson()).toList(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    planName: json['planName'] as String,
    dayNumber: json['dayNumber'] as int,
    dayTitle: json['dayTitle'] as String,
    completedAt: DateTime.parse(json['completedAt'] as String),
    results: (json['results'] as List<dynamic>)
        .map((item) => ExerciseResult.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
