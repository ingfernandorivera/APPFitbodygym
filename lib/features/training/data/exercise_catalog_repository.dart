import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/workout_plan.dart';
import 'exercise_catalog.dart';

class ExerciseCatalogRepository {
  const ExerciseCatalogRepository();

  Future<List<WorkoutExercise>> load() async {
    if (!SupabaseConfig.isConfigured) return ExerciseCatalog.exercises;

    try {
      final rows = await Supabase.instance.client
          .from('exercise_catalog')
          .select('id,name,muscle_group,instructions,media_url')
          .eq('is_active', true)
          .order('name');
      final remote = (rows as List<dynamic>)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
      return remote.isEmpty ? ExerciseCatalog.exercises : remote;
    } catch (_) {
      return ExerciseCatalog.exercises;
    }
  }

  /// Vincula automáticamente las URLs de videos y detalles del catálogo a los ejercicios de una rutina.
  Future<WorkoutPlan> enrichWorkoutPlan(WorkoutPlan plan) async {
    final catalog = await load();
    if (catalog.isEmpty) return plan;

    final catalogMapById = {for (final e in catalog) e.id.toLowerCase(): e};
    final catalogMapByName = {
      for (final e in catalog) _normalizeName(e.name): e,
    };

    final enrichedDays = plan.days.map((day) {
      final enrichedExercises = day.exercises.map((exercise) {
        if (exercise.mediaUrl != null && exercise.mediaUrl!.isNotEmpty) {
          return exercise;
        }

        final normalizedExName = _normalizeName(exercise.name);
        var match =
            catalogMapById[exercise.id.toLowerCase()] ??
            catalogMapByName[normalizedExName];

        if (match == null) {
          for (final catExercise in catalog) {
            final catNorm = _normalizeName(catExercise.name);
            if (catNorm.contains(normalizedExName) ||
                normalizedExName.contains(catNorm)) {
              match = catExercise;
              break;
            }
          }
        }

        if (match != null) {
          return WorkoutExercise(
            id: exercise.id,
            name: exercise.name,
            muscleGroup: exercise.muscleGroup.isNotEmpty
                ? exercise.muscleGroup
                : match.muscleGroup,
            sets: exercise.sets,
            repetitions: exercise.repetitions,
            restSeconds: exercise.restSeconds,
            instructions:
                exercise.instructions.isNotEmpty &&
                    exercise.instructions != 'Sigue la demostración del video.'
                ? exercise.instructions
                : match.instructions,
            commonMistakes: exercise.commonMistakes.isNotEmpty
                ? exercise.commonMistakes
                : match.commonMistakes,
            alternative: exercise.alternative.isNotEmpty
                ? exercise.alternative
                : match.alternative,
            difficulty: exercise.difficulty,
            mediaUrl: match.mediaUrl,
          );
        }
        return exercise;
      }).toList();

      return WorkoutDay(
        dayNumber: day.dayNumber,
        title: day.title,
        focus: day.focus,
        exercises: enrichedExercises,
      );
    }).toList();

    return WorkoutPlan(
      name: plan.name,
      goal: plan.goal,
      createdAt: plan.createdAt,
      days: enrichedDays,
      isDemo: plan.isDemo,
    );
  }

  static String _normalizeName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúñ]'), '');

  WorkoutExercise _fromRow(Map<String, dynamic> row) => WorkoutExercise(
    id: row['id'] as String,
    name: row['name'] as String,
    muscleGroup: row['muscle_group'] as String? ?? 'General',
    sets: 3,
    repetitions: '10-12',
    restSeconds: 60,
    instructions:
        row['instructions'] as String? ?? 'Sigue la demostración del video.',
    commonMistakes: 'Evita usar impulso y mantén el movimiento controlado.',
    alternative: 'Consulta una alternativa con tu entrenador.',
    difficulty: 'Intermedio',
    mediaUrl: row['media_url'] as String?,
  );
}
