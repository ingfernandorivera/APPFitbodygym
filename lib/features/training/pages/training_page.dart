import 'package:flutter/material.dart';

import '../data/workout_plan_store.dart';
import '../models/workout_plan.dart';
import 'exercise_library_page.dart';
import 'workout_result_page.dart';
import 'workout_session_page.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  late Future<WorkoutPlan?> planFuture;

  @override
  void initState() {
    super.initState();
    planFuture = WorkoutPlanStore().load();
  }

  void reload() => setState(() => planFuture = WorkoutPlanStore().load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkoutPlan?>(
      future: planFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final plan = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Entrenamiento',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Biblioteca de ejercicios',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExerciseLibraryPage(),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (plan == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.fitness_center, size: 52),
                    SizedBox(height: 16),
                    Text(
                      'Aún no tienes una rutina activa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Créala desde el botón principal de Inicio.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    child: Icon(Icons.assignment_outlined),
                  ),
                  title: Text(plan.name),
                  subtitle: Text(
                    '${plan.days.length} días por semana · ${plan.goal}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutResultPage(plan: plan),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Entrenamiento del día',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ...plan.days.map(
                (day) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(child: Text('${day.dayNumber}')),
                    title: Text(day.title),
                    subtitle: Text(
                      '${day.focus}\n${day.exercises.length} ejercicios',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () async {
                      final completed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkoutSessionPage(planName: plan.name, day: day),
                        ),
                      );
                      if (completed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Entrenamiento guardado en Progreso.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
