import '../../assessment/models/training_profile.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';

String normalized(String value) => value
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

class PlanIssue {
  const PlanIssue(this.code, this.path, this.message);
  final String code, path, message;
  @override
  String toString() => '$path: $message';
}

class WorkoutDurationEstimator {
  const WorkoutDurationEstimator();
  int exerciseSeconds(WorkoutExercise e) => e.type == 'cardio'
      ? e.minReps * 60
      : e.sets * (e.maxReps * 4 + 10) + (e.sets - 1) * e.restSeconds;
  int daySeconds(WorkoutDay day) =>
      300 +
      day.exercises.fold<int>(0, (sum, e) => sum + exerciseSeconds(e) + 45);
  int minutes(WorkoutDay day) => (daySeconds(day) / 60).ceil();
}

bool allowedExercise(WorkoutExercise e, TrainingProfile profile) {
  final limitations = normalized(profile.limitations);
  if (limitations.contains('rodilla') &&
      [
        'squat',
        'lunge',
        'knee_flexion',
        'cardio',
      ].contains(e.movementPattern)) {
    return false;
  }
  if (limitations.contains('hombro') &&
      ['vertical_push', 'shoulder_abduction'].contains(e.movementPattern)) {
    return false;
  }
  if ((limitations.contains('lumbar') || limitations.contains('espalda')) &&
      e.movementPattern == 'hinge') {
    return false;
  }
  final equipment = normalized(profile.equipment);
  final place = normalized(profile.trainingLocation);
  final home = place.contains('casa') || place.contains('aire libre');
  final preferences = normalized(profile.preferences);
  if (preferences.contains('sin mancuernas') && e.equipment == 'dumbbell') {
    return false;
  }
  if (preferences.contains('sin maquinas') && e.equipment == 'machine') {
    return false;
  }
  if (e.equipment == 'bodyweight') return true;
  if (equipment.contains('sin equipo') || equipment.contains('peso corporal')) {
    return false;
  }
  if (equipment.contains('mancuerna') &&
      !equipment.contains('maquina') &&
      !equipment.contains('completo')) {
    return e.equipment == 'dumbbell';
  }
  if (home) return equipment.contains('mancuerna') && e.equipment == 'dumbbell';
  return true;
}

class WorkoutPlanValidator {
  WorkoutPlanValidator(this.catalog);
  final List<WorkoutExercise> catalog;
  List<PlanIssue> validate(WorkoutPlan plan, {TrainingProfile? profile}) {
    final issues = <PlanIssue>[];
    void issue(String code, String path, String message) =>
        issues.add(PlanIssue(code, path, message));
    if (plan.days.isEmpty || plan.days.length > 7) {
      issue('days', 'plan', 'Elige entre 1 y 7 días.');
    }
    if (plan.plannedMinutes < 15 || plan.plannedMinutes > 240) {
      issue(
        'duration',
        'plan',
        'La duración debe estar entre 15 y 240 minutos.',
      );
    }
    if (plan.version < 1 || plan.block < 1 || plan.week < 1) {
      issue('version', 'plan', 'Versión, bloque y semana deben ser positivos.');
    }
    final days = <int>{};
    final known = {for (final e in catalog) e.stableId: e};
    for (final day in plan.days) {
      final path = 'Día ${day.dayNumber}';
      if (day.dayNumber < 1 || day.dayNumber > 7 || !days.add(day.dayNumber)) {
        issue('days', path, 'Número de día inválido o repetido.');
      }
      if (day.exercises.isEmpty) {
        issue('empty', path, 'Añade al menos un ejercicio.');
      }
      final ids = <String>{};
      for (final e in day.exercises) {
        final location = '$path / ${e.name}';
        final canonical = known[e.stableId];
        if (canonical == null) {
          issue(
            'unknown_id',
            location,
            'El ejercicio no pertenece al catálogo.',
          );
        }
        if (!ids.add(e.stableId)) {
          issue('duplicate', location, 'El ejercicio está repetido.');
        }
        if (e.sets < 1 || e.sets > 6) {
          issue('sets', location, 'Usa entre 1 y 6 series.');
        }
        if (e.restSeconds < 0 ||
            e.restSeconds > 300 ||
            e.type != 'cardio' && e.restSeconds < 15) {
          issue(
            'rest',
            location,
            'Descanso fuera de rango (15–300 s; cardio puede usar 0).',
          );
        }
        if (e.minReps < 1 ||
            e.maxReps < e.minReps ||
            e.maxReps > 50 ||
            e.targetRir < 0 ||
            e.targetRir > 4) {
          issue('range', location, 'Rango de repeticiones o RIR inválido.');
        }
        if (canonical != null &&
            profile != null &&
            !allowedExercise(canonical, profile)) {
          issue(
            'limitation',
            location,
            'No es compatible con tu equipo o limitaciones registradas.',
          );
        }
        if (canonical != null &&
            (e.type != canonical.type ||
                e.movementPattern != canonical.movementPattern ||
                e.equipment != canonical.equipment)) {
          issue(
            'metadata',
            location,
            'Los metadatos no coinciden con el catálogo.',
          );
        }
      }
      if (const WorkoutDurationEstimator().minutes(day) > plan.plannedMinutes ||
          profile != null &&
              const WorkoutDurationEstimator().minutes(day) >
                  profile.minutesPerSession) {
        issue('duration', path, 'La sesión supera el tiempo disponible.');
      }
      if (profile != null &&
          normalized(profile.experience).contains('princip') &&
          day.exercises.fold<int>(0, (s, e) => s + e.sets) > 12) {
        issue('volume', path, 'El volumen inicial supera 12 series.');
      }
    }
    if (profile != null && plan.days.length > profile.daysPerWeek) {
      issue('frequency', 'plan', 'La frecuencia supera tus días disponibles.');
    }
    return issues;
  }
}

enum ProgressionKind { increase, maintain, reduce, stop }

class ProgressionSuggestion {
  const ProgressionSuggestion(this.kind, this.message, {this.weightKg});
  final ProgressionKind kind;
  final String message;
  final double? weightKg;
}

class WorkoutProgression {
  const WorkoutProgression();
  ProgressionSuggestion suggest(
    WorkoutExercise prescription,
    ExerciseResult? previous,
  ) {
    if (previous?.discomfort ?? false) {
      return const ProgressionSuggestion(
        ProgressionKind.stop,
        'Detén el ejercicio si hay dolor. Consulta a un profesional si persiste o es intenso.',
      );
    }
    final sets =
        previous?.sets.where((s) => s.completed && !s.warmup).toList() ?? [];
    if (sets.isEmpty) {
      return const ProgressionSuggestion(
        ProgressionKind.maintain,
        'Empieza con una carga cómoda; deja 2–3 repeticiones posibles.',
      );
    }
    final weight = sets.last.weightKg;
    if (sets.any((s) => s.repetitions < prescription.minReps)) {
      return ProgressionSuggestion(
        ProgressionKind.reduce,
        'Reduce la carga aproximadamente un 10 % y revisa la técnica.',
        weightKg: (weight * .9 * 10).round() / 10,
      );
    }
    if (sets.length >= prescription.sets &&
        sets.every(
          (s) => s.repetitions >= prescription.maxReps && s.rir >= 2,
        )) {
      return ProgressionSuggestion(
        ProgressionKind.increase,
        'Puedes subir la carga un 2,5 %; conserva series y frecuencia.',
        weightKg: (weight * 1.025 * 10).round() / 10,
      );
    }
    return ProgressionSuggestion(
      ProgressionKind.maintain,
      'Mantén la carga y las series; completa el rango con control.',
      weightKg: weight,
    );
  }
}
