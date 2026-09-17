import 'package:flutter/material.dart';

import '../data/exercise_catalog_repository.dart';
import '../models/workout_plan.dart';
import '../widgets/exercise_video_player.dart';

class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({super.key});

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  String query = '';
  late final Future<List<WorkoutExercise>> exercisesFuture;

  @override
  void initState() {
    super.initState();
    exercisesFuture = const ExerciseCatalogRepository().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca de ejercicios')),
      body: FutureBuilder<List<WorkoutExercise>>(
        future: exercisesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final normalized = query.trim().toLowerCase();
          final exercises = snapshot.data!.where((exercise) {
            return normalized.isEmpty ||
                exercise.name.toLowerCase().contains(normalized) ||
                exercise.muscleGroup.toLowerCase().contains(normalized);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SearchBar(
                hintText: 'Buscar ejercicio o músculo',
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 16),
              ...exercises.map((exercise) => _ExerciseCard(exercise: exercise)),
              if (exercises.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No se encontraron ejercicios.')),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(
          child: Icon(Icons.fitness_center, size: 18),
        ),
        title: Text(exercise.name),
        subtitle: Text('${exercise.muscleGroup} · ${exercise.difficulty}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exercise.mediaUrl case final url?) ...[
            ExerciseVideoPlayer(url: url),
            const SizedBox(height: 12),
          ],
          Text(
            '${exercise.sets} series · ${exercise.repetitions} reps · '
            '${exercise.restSeconds}s descanso',
          ),
          const SizedBox(height: 12),
          const Text('Técnica', style: TextStyle(fontWeight: FontWeight.w700)),
          Text(exercise.instructions),
          const SizedBox(height: 10),
          const Text(
            'Errores comunes',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(exercise.commonMistakes),
          const SizedBox(height: 10),
          const Text(
            'Alternativa',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(exercise.alternative),
        ],
      ),
    );
  }
}
