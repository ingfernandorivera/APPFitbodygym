import 'package:flutter/material.dart';

import '../data/workout_history_store.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';

class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({
    super.key,
    required this.planName,
    required this.day,
  });

  final String planName;
  final WorkoutDay day;

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  late final List<_ExerciseInput> inputs;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    inputs = widget.day.exercises.map(_ExerciseInput.new).toList();
  }

  @override
  void dispose() {
    for (final input in inputs) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> finishWorkout() async {
    if (!inputs.any((input) => input.completed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marca al menos un ejercicio como completado.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    final session = WorkoutSession(
      planName: widget.planName,
      dayNumber: widget.day.dayNumber,
      dayTitle: widget.day.title,
      completedAt: DateTime.now(),
      results: inputs.map((input) => input.toResult()).toList(),
    );
    await WorkoutHistoryStore().add(session);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Día ${widget.day.dayNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.day.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(widget.day.focus),
          const SizedBox(height: 16),
          ...List.generate(inputs.length, (index) {
            final input = inputs[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: input.completed,
                      title: Text(input.exercise.name),
                      subtitle: Text(
                        '${input.exercise.sets} series · ${input.exercise.repetitions} reps',
                      ),
                      onChanged: (value) =>
                          setState(() => input.completed = value ?? false),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: input.weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Peso usado',
                              suffixText: 'kg',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: input.repetitionsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Reps hechas',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Dificultad: ${_difficultyLabel(input.difficulty)}'),
                    Slider(
                      value: input.difficulty.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '${input.difficulty}',
                      onChanged: (value) =>
                          setState(() => input.difficulty = value.round()),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: saving ? null : finishWorkout,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Finalizar entrenamiento'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _difficultyLabel(int value) => switch (value) {
    1 => 'Muy fácil',
    2 => 'Fácil',
    3 => 'Adecuada',
    4 => 'Difícil',
    _ => 'Muy difícil',
  };
}

class _ExerciseInput {
  _ExerciseInput(this.exercise);

  final WorkoutExercise exercise;
  final weightController = TextEditingController();
  final repetitionsController = TextEditingController();
  bool completed = false;
  int difficulty = 3;

  ExerciseResult toResult() => ExerciseResult(
    exerciseId: exercise.id,
    exerciseName: exercise.name,
    completed: completed,
    weightKg: double.tryParse(weightController.text.replaceAll(',', '.')),
    repetitions: int.tryParse(repetitionsController.text),
    difficulty: difficulty,
  );

  void dispose() {
    weightController.dispose();
    repetitionsController.dispose();
  }
}
