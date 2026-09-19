import '../../assessment/models/training_profile.dart';
import '../models/workout_plan.dart';
import 'exercise_catalog.dart';
import 'training_rules.dart';

/// Nombre conservado para compatibilidad con los callers anteriores.
class DemoWorkoutGenerator {
  DemoWorkoutGenerator({
    List<WorkoutExercise>? exercises,
    DateTime Function()? clock,
  }) : catalog = exercises ?? ExerciseCatalog.exercises,
       clock = clock ?? DateTime.now;
  final List<WorkoutExercise> catalog;
  final DateTime Function() clock;
  WorkoutPlan generate(TrainingProfile profile) {
    if (profile.daysPerWeek < 1 ||
        profile.daysPerWeek > 7 ||
        profile.minutesPerSession < 15) {
      throw ArgumentError('Disponibilidad inválida.');
    }
    final beginner = normalized(profile.experience).contains('princip');
    final strength = normalized(profile.goal).contains('fuerza');
    final cardioGoal =
        normalized(profile.goal).contains('grasa') ||
        normalized(profile.goal).contains('resistencia');
    final preferences = normalized(profile.preferences);
    final pool = catalog
        .where((e) => allowedExercise(e, profile))
        .where(
          (e) => !(preferences.contains('sin cardio') && e.type == 'cardio'),
        )
        .toList();
    if (pool.length < 2) {
      throw StateError(
        'No hay suficientes ejercicios compatibles. Revisa el equipo y las limitaciones con tu entrenador.',
      );
    }
    final days = <WorkoutDay>[];
    final estimator = const WorkoutDurationEstimator();
    for (var day = 0; day < profile.daysPerWeek; day++) {
      final candidates = List<WorkoutExercise>.of(pool);
      int score(WorkoutExercise e) {
        var value = 0;
        final lower = [
          'squat',
          'hinge',
          'hip_extension',
          'knee_flexion',
          'ankle',
        ].contains(e.movementPattern);
        if (profile.daysPerWeek >= 4 && lower == day.isOdd) value += 40;
        if (profile.priorityMuscles.any(
          (m) => normalized(e.muscleGroup).contains(normalized(m)),
        )) {
          value += 20;
        }
        if (preferences.contains('mancuerna') && e.equipment == 'dumbbell') {
          value += 12;
        }
        if (preferences.contains('maquina') && e.equipment == 'machine') {
          value += 12;
        }
        if ((cardioGoal || preferences.contains('cardio')) &&
            e.type == 'cardio') {
          value += 25;
        }
        if (e.compound) value += 10;
        if (days.isNotEmpty &&
            days.last.exercises.any((p) => p.stableId == e.stableId)) {
          value -= 30;
        }
        if (e.mediaStatus == 'video') value += 1;
        return value;
      }

      candidates.sort((a, b) {
        final diff = score(b).compareTo(score(a));
        return diff != 0
            ? diff
            : ((pool.indexOf(a) + day) % pool.length).compareTo(
                (pool.indexOf(b) + day) % pool.length,
              );
      });
      final selected = <WorkoutExercise>[];
      for (final e in candidates) {
        final prescribed = e.type == 'cardio'
            ? e.copyWith(sets: 1, targetMin: 5, targetMax: 5, restSeconds: 0)
            : e.copyWith(
                sets: beginner ? 2 : (profile.daysPerWeek >= 5 ? 3 : 4),
                targetMin: strength ? 6 : 10,
                targetMax: strength ? 8 : 12,
                targetRir: beginner ? 3 : 2,
                restSeconds: strength && e.compound
                    ? 120
                    : e.compound
                    ? 75
                    : 45,
              );
        final trial = WorkoutDay(
          dayNumber: day + 1,
          title: '',
          focus: '',
          exercises: [...selected, prescribed],
        );
        if (estimator.minutes(trial) <= profile.minutesPerSession &&
            selected.length < (beginner ? 5 : 7) &&
            (!beginner ||
                trial.exercises.fold<int>(0, (s, e) => s + e.sets) <= 12)) {
          selected.add(prescribed);
        }
      }
      if (days.isNotEmpty &&
          selected.length == days.last.exercises.length &&
          selected.every(
            (e) => days.last.exercises.any((p) => p.stableId == e.stableId),
          ) &&
          selected.length > 1) {
        selected.removeLast();
      }
      selected.sort(
        (a, b) =>
            (a.type == 'cardio'
                    ? 2
                    : a.compound
                    ? 0
                    : 1)
                .compareTo(
                  b.type == 'cardio'
                      ? 2
                      : b.compound
                      ? 0
                      : 1,
                ),
      );
      if (selected.isEmpty) {
        throw StateError(
          'El tiempo disponible no permite una sesión compatible.',
        );
      }
      days.add(
        WorkoutDay(
          dayNumber: day + 1,
          title: profile.daysPerWeek >= 4
              ? (day.isEven ? 'Énfasis superior' : 'Énfasis inferior')
              : 'Cuerpo completo ${day + 1}',
          focus: profile.goal,
          exercises: selected,
        ),
      );
    }
    final now = clock();
    final plan = WorkoutPlan(
      name: 'Rutina personalizada inicial',
      goal: profile.goal,
      createdAt: now,
      startDate: now,
      days: days,
      plannedMinutes: profile.minutesPerSession,
      source: 'rules',
      isDemo: false,
      changeReason: 'Plan inicial según evaluación',
    );
    final issues = WorkoutPlanValidator(
      catalog,
    ).validate(plan, profile: profile);
    if (issues.isNotEmpty) throw StateError(issues.join('\n'));
    return plan;
  }
}
