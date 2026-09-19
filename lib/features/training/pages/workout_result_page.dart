import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/exercise_catalog_repository.dart';
import '../models/workout_plan.dart';
import '../widgets/exercise_video_player.dart';

class WorkoutResultPage extends StatefulWidget {
  const WorkoutResultPage({super.key, required this.plan});
  final WorkoutPlan plan;

  @override
  State<WorkoutResultPage> createState() => _WorkoutResultPageState();
}

class _WorkoutResultPageState extends State<WorkoutResultPage> {
  late WorkoutPlan plan;

  @override
  void initState() {
    super.initState();
    plan = widget.plan;
    _enrichPlan();
  }

  Future<void> _enrichPlan() async {
    final enriched = await const ExerciseCatalogRepository().enrichWorkoutPlan(
      widget.plan,
    );
    if (mounted) {
      setState(() {
        plan = enriched;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu rutina')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(plan.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Objetivo: ${plan.goal}'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Rutina activa · versión ${plan.version}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (plan.isDemo) ...[
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Vista de demostración: debe revisarse antes de usarla como indicación profesional.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...plan.days.map(
            (day) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: day.dayNumber == 1,
                title: Text('Día ${day.dayNumber}: ${day.title}'),
                subtitle: Text(day.focus),
                children: day.exercises
                    .map(
                      (exercise) => ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.fitness_center, size: 18),
                        ),
                        title: Text(exercise.name),
                        subtitle: Text(
                          '${exercise.muscleGroup} · ${exercise.sets} series · ${exercise.repetitions} reps · ${exercise.restSeconds}s descanso\n${exercise.instructions}',
                        ),
                        isThreeLine: true,
                        trailing:
                            exercise.mediaStatus == 'video' &&
                                exercise.mediaUrl != null &&
                                exercise.mediaUrl!.isNotEmpty
                            ? IconButton(
                                tooltip: 'Ver video de la técnica',
                                icon: const Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.amber,
                                  size: 30,
                                ),
                                onPressed: () {
                                  ExerciseVideoPlayer.showVideoModal(
                                    context,
                                    title: exercise.name,
                                    videoUrl: exercise.mediaUrl!,
                                    instructions: exercise.instructions,
                                  );
                                },
                              )
                            : const Icon(
                                Icons.videocam_off_outlined,
                                color: Colors.grey,
                              ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
