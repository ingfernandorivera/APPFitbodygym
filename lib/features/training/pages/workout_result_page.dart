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
      backgroundColor: const Color(0xFF0D0D0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0E),
        elevation: 0,
        title: const Text(
          'Tu rutina',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tarjeta Hero de Resumen del Plan
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F1F24), Color(0xFF141417)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.15),
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
                            size: 15,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Rutina activa · versión ${plan.version}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plan.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Objetivo: ${plan.goal}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PlanBadge(
                      icon: Icons.calendar_view_week_rounded,
                      text: '${plan.days.length} días/sem',
                    ),
                    _PlanBadge(
                      icon: Icons.repeat_rounded,
                      text: '${plan.totalWeeks} semanas',
                    ),
                    _PlanBadge(
                      icon: Icons.timer_outlined,
                      text: '${plan.plannedMinutes} min/sesión',
                    ),
                  ],
                ),
              ],
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
              margin: const EdgeInsets.only(bottom: 14),
              color: const Color(0xFF17171B),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF282830)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: day.dayNumber == 1,
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${day.dayNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    'Día ${day.dayNumber}: ${day.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${day.exercises.length} ejercicios · ${day.focus}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: day.exercises
                      .asMap()
                      .entries
                      .map((entry) {
                        final idx = entry.key + 1;
                        final exercise = entry.value;
                        final hasVideo =
                            exercise.mediaUrl != null &&
                            exercise.mediaUrl!.isNotEmpty;
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2C2C34)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '$idx',
                                    style: const TextStyle(
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${exercise.muscleGroup} · ${exercise.sets} series × ${exercise.repetitions} reps · ${exercise.restSeconds}s descanso',
                                      style: const TextStyle(
                                        color: AppColors.brand,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (exercise.instructions.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        exercise.instructions,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (hasVideo)
                                IconButton(
                                  tooltip: 'Ver video de la técnica',
                                  icon: const Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: AppColors.brand,
                                    size: 32,
                                  ),
                                  onPressed: () {
                                    ExerciseVideoPlayer.showVideoModal(
                                      context,
                                      title: exercise.name,
                                      videoUrl: exercise.mediaUrl!,
                                      instructions: exercise.instructions,
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF25252C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brand),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
