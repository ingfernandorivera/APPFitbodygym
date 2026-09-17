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
