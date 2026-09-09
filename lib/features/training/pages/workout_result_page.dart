import 'package:flutter/material.dart';

import '../data/workout_plan_store.dart';
import '../models/workout_plan.dart';

class WorkoutResultPage extends StatefulWidget {
  const WorkoutResultPage({super.key, required this.plan});
  final WorkoutPlan plan;

  @override
  State<WorkoutResultPage> createState() => _WorkoutResultPageState();
}

class _WorkoutResultPageState extends State<WorkoutResultPage> {
  bool saving = false;
  bool saved = false;

  Future<void> savePlan() async {
    setState(() => saving = true);
    await WorkoutPlanStore().save(widget.plan);
    if (!mounted) return;
    setState(() {
      saving = false;
      saved = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rutina guardada como activa')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu rutina')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.plan.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text('Objetivo: ${widget.plan.goal}'),
          if (widget.plan.isDemo) ...[
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
          const SizedBox(height: 12),
          ...widget.plan.days.map(
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
                        trailing: const Icon(
                          Icons.image_outlined,
                          semanticLabel: 'Multimedia pendiente',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: saving || saved ? null : savePlan,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(saved ? Icons.check : Icons.bookmark_add_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                saved ? 'Rutina activa' : 'Guardar como rutina activa',
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
