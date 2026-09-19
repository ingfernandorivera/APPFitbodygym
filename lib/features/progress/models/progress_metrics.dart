import '../../training/models/workout_plan.dart';
import '../../training/models/workout_session.dart';

class ExerciseProgress {
  ExerciseProgress(this.name);
  final String name;
  SetResult? best, first, latest;
  DateTime? firstDate, latestDate;
}

class ProgressMetrics {
  ProgressMetrics(
    List<WorkoutSession> history, {
    WorkoutPlan? plan,
    DateTime? now,
  }) {
    final today = (now ?? DateTime.now()).toLocal();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final end = start.add(const Duration(days: 7));
    final week = history
        .where(
          (s) =>
              !s.completedAt.toLocal().isBefore(start) &&
              s.completedAt.toLocal().isBefore(end) &&
              !s.completedAt.isAfter(today),
        )
        .toList();
    sessionsThisWeek = week.length;
    if (plan != null && plan.days.isNotEmpty) {
      final covered = week
          .where(
            (s) =>
                s.planId == plan.id ||
                s.planId == null && s.planName == plan.name,
          )
          .map((s) => s.dayNumber)
          .where((d) => plan.days.any((p) => p.dayNumber == d))
          .toSet()
          .length;
      adherence = covered / plan.days.length;
    }
    final ordered = List<WorkoutSession>.of(history)
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    for (final session in ordered) {
      durationSeconds += session.durationSeconds;
      for (final result in session.results) {
        skippedExercises += result.completed ? 0 : 1;
        skippedSets += result.sets.where((s) => !s.completed).length;
        for (final set in result.sets.where((s) => s.completed)) {
          totalVolume += set.volume;
          if (set.warmup) continue;
          final item = exercises.putIfAbsent(
            result.exerciseId,
            () => ExerciseProgress(result.exerciseName),
          );
          item.first ??= set;
          item.firstDate ??= session.completedAt;
          item.latest = set;
          item.latestDate = session.completedAt;
          if (item.best == null ||
              set.weightKg > item.best!.weightKg ||
              set.weightKg == item.best!.weightKg &&
                  set.repetitions > item.best!.repetitions) {
            item.best = set;
          }
        }
      }
    }
  }
  int sessionsThisWeek = 0,
      durationSeconds = 0,
      skippedExercises = 0,
      skippedSets = 0;
  double totalVolume = 0;
  double? adherence;
  final exercises = <String, ExerciseProgress>{};
}
