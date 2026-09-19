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
    this.catalogId,
    this.movementPattern,
    this.equipment,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.compound = false,
    this.type = 'strength',
    this.mediaStatus = 'missing',
    this.alternativeIds = const [],
    this.targetMin,
    this.targetMax,
    this.targetRir = 2,
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
  final String? catalogId, movementPattern, equipment;
  String get stableId => catalogId ?? id;
  final List<String> primaryMuscles, secondaryMuscles, alternativeIds;
  final bool compound;
  final String type, mediaStatus;
  final int? targetMin, targetMax;
  final int targetRir;
  int get minReps =>
      targetMin ??
      int.tryParse(RegExp(r'\d+').firstMatch(repetitions)?.group(0) ?? '') ??
      10;
  int get maxReps =>
      targetMax ??
      (RegExp(r'\d+')
              .allMatches(repetitions)
              .map((m) => int.parse(m.group(0)!))
              .lastOrNull ??
          minReps);
  WorkoutExercise copyWith({
    int? sets,
    int? restSeconds,
    int? targetMin,
    int? targetMax,
    int? targetRir,
    String? mediaUrl,
    String? mediaStatus,
  }) => WorkoutExercise.fromJson({
    ...toJson(),
    'sets': ?sets,
    'restSeconds': ?restSeconds,
    'targetMin': ?targetMin,
    'targetMax': ?targetMax,
    'targetRir': ?targetRir,
    if (targetMin != null && targetMax != null)
      'repetitions': '$targetMin-$targetMax',
    'mediaUrl': ?mediaUrl,
    'mediaStatus': ?mediaStatus,
  });

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
    'catalogId': stableId,
    'movementPattern': movementPattern,
    'equipment': equipment,
    'primaryMuscles': primaryMuscles,
    'secondaryMuscles': secondaryMuscles,
    'compound': compound,
    'type': type,
    'mediaStatus': mediaStatus,
    'alternativeIds': alternativeIds,
    'targetMin': minReps,
    'targetMax': maxReps,
    'targetRir': targetRir,
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
        catalogId: json['catalogId'] as String?,
        movementPattern: json['movementPattern'] as String?,
        equipment: json['equipment'] as String?,
        primaryMuscles:
            (json['primaryMuscles'] as List?)?.cast<String>() ?? const [],
        secondaryMuscles:
            (json['secondaryMuscles'] as List?)?.cast<String>() ?? const [],
        alternativeIds:
            (json['alternativeIds'] as List?)?.cast<String>() ?? const [],
        compound: json['compound'] as bool? ?? false,
        type:
            json['type'] as String? ??
            ((json['repetitions'] as String).contains('minut')
                ? 'cardio'
                : 'strength'),
        mediaStatus:
            json['mediaStatus'] as String? ??
            (json['mediaUrl'] == null ? 'missing' : 'video'),
        targetMin: json['targetMin'] as int?,
        targetMax: json['targetMax'] as int?,
        targetRir: json['targetRir'] as int? ?? 2,
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
    this._id,
    this._startDate,
    this.version = 1,
    this.block = 1,
    this.week = 1,
    this.plannedMinutes = 60,
    this.source = 'legacy',
    this.changeReason = '',
  });

  final String? _id;
  String get id => _id ?? 'plan_${createdAt.microsecondsSinceEpoch}';
  final DateTime? _startDate;
  DateTime get startDate => _startDate ?? createdAt;
  final int version, block, week, plannedMinutes;
  final String source, changeReason;
  WorkoutPlan copyWith({
    String? name,
    String? goal,
    List<WorkoutDay>? days,
    int? version,
    String? id,
    String? source,
    String? changeReason,
  }) => WorkoutPlan.fromJson({
    ...toJson(),
    'name': ?name,
    'goal': ?goal,
    if (days != null) 'days': days.map((d) => d.toJson()).toList(),
    'version': ?version,
    'id': ?id,
    'source': ?source,
    'changeReason': ?changeReason,
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
    'id': id,
    'version': version,
    'startDate': startDate.toIso8601String(),
    'block': block,
    'week': week,
    'plannedMinutes': plannedMinutes,
    'source': source,
    'changeReason': changeReason,
  };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
    name: json['name'] as String,
    goal: json['goal'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    days: (json['days'] as List<dynamic>)
        .map((item) => WorkoutDay.fromJson(item as Map<String, dynamic>))
        .toList(),
    isDemo: json['isDemo'] as bool? ?? true,
    id: json['id'] as String?,
    version: json['version'] as int? ?? 1,
    startDate: DateTime.tryParse(json['startDate'] as String? ?? ''),
    block: json['block'] as int? ?? 1,
    week: json['week'] as int? ?? 1,
    plannedMinutes: json['plannedMinutes'] as int? ?? 60,
    source: json['source'] as String? ?? 'legacy',
    changeReason: json['changeReason'] as String? ?? '',
  );
}
