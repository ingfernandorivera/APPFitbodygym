import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../models/workout_plan.dart';
import 'exercise_catalog.dart';

enum CatalogSource { remote, fallback, error }

class CatalogResult {
  const CatalogResult(this.exercises, this.source, {this.message});
  final List<WorkoutExercise> exercises;
  final CatalogSource source;
  final String? message;
}

class ExerciseCatalogRepository {
  const ExerciseCatalogRepository({this.fetchRows});
  final Future<List<Map<String, dynamic>>> Function()? fetchRows;
  Future<List<WorkoutExercise>> load() async => (await loadResult()).exercises;
  Future<CatalogResult> loadResult() async {
    if (fetchRows == null && !SupabaseConfig.isConfigured) {
      return const CatalogResult(
        ExerciseCatalog.exercises,
        CatalogSource.fallback,
        message:
            'Catálogo local disponible. El catálogo remoto no está configurado.',
      );
    }
    try {
      // select(*) también funciona antes de aplicar la migración de metadatos.
      final rows = fetchRows != null
          ? await fetchRows!()
          : await Supabase.instance.client
                .from('exercise_catalog')
                .select()
                .eq('is_active', true)
                .order('name');
      final remote = rows.map((row) => fromRow(row)).toList();
      if (remote.isEmpty) {
        return const CatalogResult(
          ExerciseCatalog.exercises,
          CatalogSource.fallback,
          message: 'El catálogo remoto está vacío. Usamos el catálogo local.',
        );
      }
      final merged = {for (final e in ExerciseCatalog.exercises) e.stableId: e};
      for (final e in remote) {
        merged[e.stableId] = e;
      }
      return CatalogResult(merged.values.toList(), CatalogSource.remote);
    } catch (_) {
      return const CatalogResult(
        ExerciseCatalog.exercises,
        CatalogSource.error,
        message:
            'No se pudo cargar el catálogo remoto. Usamos el catálogo local; puedes reintentar.',
      );
    }
  }

  static String normalize(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúñ]'), '');
  static WorkoutExercise fromRow(Map<String, dynamic> row) {
    final name = row['name'] as String;
    final local = ExerciseCatalog.exercises
        .where(
          (e) => e.id == row['slug'] || normalize(e.name) == normalize(name),
        )
        .firstOrNull;
    final metadata = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    final media = row['media_url'] as String?;
    return WorkoutExercise.fromJson({
      if (local != null) ...local.toJson(),
      'id': local?.id ?? row['slug'] ?? row['id'],
      'catalogId': local?.stableId ?? row['slug'] ?? row['id'],
      'name': name,
      'muscleGroup': row['muscle_group'] ?? 'General',
      'equipment': local?.equipment ?? row['equipment'],
      'sets': local?.sets ?? 3,
      'repetitions': local?.repetitions ?? '10-12',
      'restSeconds': local?.restSeconds ?? 60,
      'instructions': row['instructions'] ?? '',
      'mediaUrl': media,
      'mediaStatus': media == null || media.isEmpty
          ? 'missing'
          : row['media_type'] == 'video'
          ? 'video'
          : 'image',
      'movementPattern': metadata['movementPattern'] ?? local?.movementPattern,
      'primaryMuscles':
          metadata['primaryMuscles'] ?? local?.primaryMuscles ?? <String>[],
      'secondaryMuscles':
          metadata['secondaryMuscles'] ?? local?.secondaryMuscles ?? <String>[],
      'alternativeIds':
          metadata['alternativeIds'] ?? local?.alternativeIds ?? <String>[],
      'difficulty': metadata['difficulty'] ?? local?.difficulty ?? 'Intermedio',
      'compound': metadata['compound'] ?? local?.compound ?? false,
      'type': metadata['type'] ?? local?.type ?? 'strength',
    });
  }

  Future<WorkoutPlan> enrichWorkoutPlan(WorkoutPlan plan) async {
    final catalog = await load();
    return plan.copyWith(
      days: plan.days
          .map(
            (d) => WorkoutDay(
              dayNumber: d.dayNumber,
              title: d.title,
              focus: d.focus,
              exercises: d.exercises.map((e) {
                final match = catalog
                    .where(
                      (c) =>
                          c.stableId == e.stableId ||
                          normalize(c.name) == normalize(e.name),
                    )
                    .firstOrNull;
                return match == null
                    ? e
                    : e.copyWith(
                        mediaUrl: match.mediaUrl,
                        mediaStatus: match.mediaStatus,
                      );
              }).toList(),
            ),
          )
          .toList(),
    );
  }
}
