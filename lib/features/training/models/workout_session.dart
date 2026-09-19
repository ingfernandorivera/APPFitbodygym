class SetResult {
  const SetResult({
    this.weightKg = 0,
    required this.repetitions,
    this.rir = 2,
    this.completed = false,
    this.warmup = false,
  }) : assert(weightKg >= 0),
       assert(repetitions >= 0),
       assert(rir >= 0 && rir <= 4);
  final double weightKg;
  final int repetitions, rir;
  final bool completed, warmup;
  double get volume => completed ? weightKg * repetitions : 0;
  Map<String, dynamic> toJson() => {
    'weightKg': weightKg,
    'repetitions': repetitions,
    'rir': rir,
    'completed': completed,
    'warmup': warmup,
  };
  factory SetResult.fromJson(Map<String, dynamic> json) {
    final weight = (json['weightKg'] as num?)?.toDouble() ?? 0;
    final reps = json['repetitions'] as int? ?? 0;
    final rir = json['rir'] as int? ?? 2;
    if (!weight.isFinite || weight < 0 || reps < 0 || rir < 0 || rir > 4) {
      throw const FormatException('Serie fuera de rango.');
    }
    return SetResult(
      weightKg: weight,
      repetitions: reps,
      rir: rir,
      completed: json['completed'] as bool? ?? false,
      warmup: json['warmup'] as bool? ?? false,
    );
  }
}

class ExerciseResult {
  const ExerciseResult({
    required this.exerciseId,
    required this.exerciseName,
    this._completed = false,
    this._weightKg,
    this._repetitions,
    this.difficulty = 3,
    this._sets,
    this.notes = '',
    this.discomfort = false,
  });
  final String exerciseId, exerciseName, notes;
  final bool discomfort;
  final List<SetResult>? _sets;
  final bool _completed;
  final double? _weightKg;
  final int? _repetitions;
  final int difficulty;
  // Los resultados antiguos representan una sola serie; no se inventan series.
  List<SetResult> get sets =>
      _sets ??
      [
        SetResult(
          weightKg: _weightKg ?? 0,
          repetitions: _repetitions ?? 0,
          rir: (5 - difficulty).clamp(0, 4),
          completed: _completed,
        ),
      ];
  bool get completed => sets.any((s) => s.completed);
  double? get weightKg => _weightKg ?? sets.lastOrNull?.weightKg;
  int? get repetitions => _repetitions ?? sets.lastOrNull?.repetitions;
  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'completed': completed,
    'weightKg': weightKg,
    'repetitions': repetitions,
    'difficulty': difficulty,
    'sets': sets.map((s) => s.toJson()).toList(),
    'notes': notes,
    'discomfort': discomfort,
  };
  factory ExerciseResult.fromJson(Map<String, dynamic> json) => ExerciseResult(
    exerciseId: json['exerciseId'] as String,
    exerciseName: json['exerciseName'] as String,
    completed: json['completed'] as bool? ?? false,
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    repetitions: json['repetitions'] as int?,
    difficulty: json['difficulty'] as int? ?? 3,
    sets: (json['sets'] as List?)
        ?.map((s) => SetResult.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList(),
    notes: json['notes'] as String? ?? '',
    discomfort: json['discomfort'] as bool? ?? false,
  );
}

class WorkoutSession {
  const WorkoutSession({
    required this.planName,
    required this.dayNumber,
    required this.dayTitle,
    required this.completedAt,
    required this.results,
    this.durationSeconds = 0,
    this.planId,
    this.planVersion = 1,
  });
  final String planName, dayTitle;
  final String? planId;
  final int dayNumber, durationSeconds, planVersion;
  final DateTime completedAt;
  final List<ExerciseResult> results;
  int get completedExercises => results.where((r) => r.completed).length;
  Map<String, dynamic> toJson() => {
    'planName': planName,
    'dayNumber': dayNumber,
    'dayTitle': dayTitle,
    'completedAt': completedAt.toIso8601String(),
    'results': results.map((r) => r.toJson()).toList(),
    'durationSeconds': durationSeconds,
    'planId': planId,
    'planVersion': planVersion,
  };
  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    planName: json['planName'] as String,
    dayNumber: json['dayNumber'] as int,
    dayTitle: json['dayTitle'] as String,
    completedAt: DateTime.parse(json['completedAt'] as String),
    results: (json['results'] as List)
        .map(
          (r) => ExerciseResult.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList(),
    durationSeconds: json['durationSeconds'] as int? ?? 0,
    planId: json['planId'] as String?,
    planVersion: json['planVersion'] as int? ?? 1,
  );
}
