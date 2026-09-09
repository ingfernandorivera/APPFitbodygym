class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.repetitions,
    required this.restSeconds,
    required this.instructions,
    required this.commonMistakes,
    required this.alternative,
    required this.difficulty,
    this.mediaUrl,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final int sets;
  final String repetitions;
  final int restSeconds;
  final String instructions;
  final String commonMistakes;
  final String alternative;
  final String difficulty;
  final String? mediaUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'sets': sets,
    'repetitions': repetitions,
    'restSeconds': restSeconds,
    'instructions': instructions,
    'commonMistakes': commonMistakes,
    'alternative': alternative,
    'difficulty': difficulty,
    'mediaUrl': mediaUrl,
  };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        id:
            json['id'] as String? ??
            (json['name'] as String).toLowerCase().replaceAll(' ', '_'),
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String? ?? 'General',
        sets: json['sets'] as int,
        repetitions: json['repetitions'] as String,
        restSeconds: json['restSeconds'] as int,
        instructions: json['instructions'] as String,
        commonMistakes: json['commonMistakes'] as String? ?? '',
        alternative: json['alternative'] as String? ?? '',
        difficulty: json['difficulty'] as String? ?? 'Intermedio',
        mediaUrl: json['mediaUrl'] as String?,
      );
}

class WorkoutDay {
  const WorkoutDay({
    required this.dayNumber,
    required this.title,
    required this.focus,
    required this.exercises,
  });

  final int dayNumber;
  final String title;
  final String focus;
  final List<WorkoutExercise> exercises;

  Map<String, dynamic> toJson() => {
    'dayNumber': dayNumber,
    'title': title,
    'focus': focus,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };

  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
    dayNumber: json['dayNumber'] as int,
    title: json['title'] as String,
    focus: json['focus'] as String,
    exercises: (json['exercises'] as List<dynamic>)
        .map((item) => WorkoutExercise.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.name,
    required this.goal,
    required this.createdAt,
    required this.days,
    this.isDemo = true,
  });

  final String name;
  final String goal;
  final DateTime createdAt;
  final List<WorkoutDay> days;
  final bool isDemo;

  Map<String, dynamic> toJson() => {
    'name': name,
    'goal': goal,
    'createdAt': createdAt.toIso8601String(),
    'days': days.map((day) => day.toJson()).toList(),
    'isDemo': isDemo,
  };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
    name: json['name'] as String,
    goal: json['goal'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    days: (json['days'] as List<dynamic>)
        .map((item) => WorkoutDay.fromJson(item as Map<String, dynamic>))
        .toList(),
    isDemo: json['isDemo'] as bool? ?? true,
  );
}
