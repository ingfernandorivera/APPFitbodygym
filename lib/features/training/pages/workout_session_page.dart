import 'dart:async';
import 'package:flutter/material.dart';
import '../data/workout_history_store.dart';
import '../data/training_rules.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import '../widgets/exercise_video_player.dart';

class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({
    super.key,
    required this.planName,
    required this.day,
    this.planId,
    this.planVersion = 1,
    this.historyStore,
    this.storageUserId,
  });
  final String planName;
  final String? planId, storageUserId;
  final int planVersion;
  final WorkoutDay day;
  final WorkoutHistoryStore? historyStore;
  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  late final store =
      widget.historyStore ??
      WorkoutHistoryStore(storageUserId: widget.storageUserId);
  late final inputs = widget.day.exercises.map(_ExerciseInput.new).toList();
  final elapsed = Stopwatch()..start();
  final restClock = Stopwatch();
  Timer? timer;
  int prescribedRest = 0;
  bool saving = false;
  String? error;
  final previous = <String, ExerciseResult>{};
  int get remaining =>
      (prescribedRest - restClock.elapsed.inSeconds).clamp(0, prescribedRest);
  @override
  void initState() {
    super.initState();
    loadPrevious();
  }

  Future<void> loadPrevious() async {
    try {
      final history = await store.load();
      if (!mounted) return;
      setState(() {
        for (final session in history) {
          for (final r in session.results) {
            if (r.completed || r.discomfort) {
              previous.putIfAbsent(r.exerciseId, () => r);
            }
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudo leer el rendimiento anterior.');
      }
    }
  }

  void startRest(int seconds, {bool reset = false}) {
    timer?.cancel();
    if (reset || seconds != prescribedRest || remaining == 0) {
      restClock.reset();
      prescribedRest = seconds;
    }
    restClock.start();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (remaining == 0) {
          restClock.stop();
          timer?.cancel();
        }
      });
    });
    setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    elapsed.stop();
    restClock.stop();
    for (final input in inputs) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> finish() async {
    if (!inputs.any((e) => e.sets.any((s) => s.completed))) {
      setState(() => error = 'Completa al menos una serie antes de finalizar.');
      return;
    }
    if (inputs.any((e) => e.sets.any((s) => s.completed && !s.valid))) {
      setState(
        () => error = 'Revisa peso y repeticiones de las series completadas.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await store.add(
        WorkoutSession(
          planName: widget.planName,
          planId: widget.planId,
          planVersion: widget.planVersion,
          dayNumber: widget.day.dayNumber,
          dayTitle: widget.day.title,
          completedAt: DateTime.now(),
          durationSeconds: elapsed.elapsed.inSeconds,
          results: inputs.map((i) => i.result()).toList(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo guardar la sesión. Tus datos siguen aquí; reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Día ${widget.day.dayNumber}')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.day.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text(
          'RIR: repeticiones que aún podrías hacer. 0 = ninguna; 1–3 = quedan esas repeticiones; 4+ = quedan cuatro o más.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('Descanso: $remaining s'),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: prescribedRest == 0
                          ? null
                          : () => startRest(prescribedRest),
                      child: const Text('Iniciar / continuar'),
                    ),
                    TextButton(
                      onPressed: () {
                        timer?.cancel();
                        setState(() => restClock.stop());
                      },
                      child: const Text('Pausar'),
                    ),
                    TextButton(
                      onPressed: () {
                        timer?.cancel();
                        setState(() {
                          restClock.stop();
                          restClock.reset();
                        });
                      },
                      child: const Text('Reiniciar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ...inputs.map((input) {
          final ex = input.exercise;
          final last = previous[ex.stableId];
          final suggestion = const WorkoutProgression().suggest(ex, last);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${ex.sets} series · ${ex.minReps}–${ex.maxReps}${ex.type == 'cardio' ? ' minutos' : ' reps'} · RIR ${ex.targetRir}',
                  ),
                  if (ex.mediaStatus == 'video' && ex.mediaUrl != null)
                    TextButton.icon(
                      onPressed: () => ExerciseVideoPlayer.showVideoModal(
                        context,
                        title: ex.name,
                        videoUrl: ex.mediaUrl!,
                        instructions: ex.instructions,
                      ),
                      icon: const Icon(Icons.play_circle),
                      label: const Text('Ver técnica'),
                    ),
                  if (last != null)
                    Text(
                      'Anterior: ${last.sets.where((s) => s.completed).map((s) => '${s.weightKg} kg × ${s.repetitions} · RIR ${s.rir}').join(' / ')}',
                    ),
                  Text(suggestion.message),
                  if (suggestion.weightKg != null)
                    Text('Carga orientativa: ${suggestion.weightKg} kg'),
                  ...input.sets.asMap().entries.map((entry) {
                    final index = entry.key;
                    final series = entry.value;
                    return Padding(
                      key: ObjectKey(series),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('Serie ${index + 1}'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: series.weight,
                                  enabled: !series.completed && !saving,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Peso (kg)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: series.reps,
                                  enabled: !series.completed && !saving,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: ex.type == 'cardio'
                                        ? 'Minutos'
                                        : 'Reps',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Eliminar serie',
                                onPressed:
                                    !saving &&
                                        input.sets.length > 1 &&
                                        !series.completed
                                    ? () {
                                        setState(
                                          () => input.sets.removeAt(index),
                                        );
                                        series.dispose();
                                      }
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ],
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              const Text('RIR '),
                              DropdownButton<int>(
                                value: series.rir,
                                items: List.generate(
                                  5,
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(i == 4 ? '4+' : i.toString()),
                                  ),
                                ),
                                onChanged: saving || series.completed
                                    ? null
                                    : (v) => setState(() => series.rir = v!),
                              ),
                              const Text(' Calentamiento'),
                              Checkbox(
                                value: series.warmup,
                                onChanged: saving || series.completed
                                    ? null
                                    : (v) => setState(() => series.warmup = v!),
                              ),
                              Checkbox(
                                value: series.completed,
                                onChanged: saving
                                    ? null
                                    : (v) {
                                        if (v == true && !series.valid) {
                                          setState(
                                            () => error =
                                                'Introduce peso válido (0–1000 kg) y repeticiones/minutos (1–100).',
                                          );
                                          return;
                                        }
                                        setState(() {
                                          series.completed = v!;
                                          error = null;
                                        });
                                        if (v == true) {
                                          startRest(
                                            ex.restSeconds,
                                            reset: true,
                                          );
                                        }
                                      },
                              ),
                              const Text('Hecha'),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: !saving && input.sets.length < 6
                            ? () => setState(() => input.sets.add(_SetInput()))
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir serie'),
                      ),
                      TextButton(
                        onPressed: () => startRest(ex.restSeconds, reset: true),
                        child: Text('Descansar ${ex.restSeconds} s'),
                      ),
                    ],
                  ),
                  TextField(
                    controller: input.notes,
                    enabled: !saving,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: 'Notas'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Molestia o dolor'),
                    value: input.discomfort,
                    onChanged: saving
                        ? null
                        : (v) => setState(() => input.discomfort = v),
                  ),
                  if (input.discomfort)
                    const Text(
                      'Detén este ejercicio si hay dolor. Si persiste o es intenso, consulta a un profesional.',
                    ),
                ],
              ),
            ),
          );
        }),
        FilledButton(
          onPressed: saving ? null : finish,
          child: Text(saving ? 'Guardando…' : 'Finalizar entrenamiento'),
        ),
        const SizedBox(height: 30),
      ],
    ),
  );
}

class _SetInput {
  final weight = TextEditingController(text: '0'),
      reps = TextEditingController();
  int rir = 2;
  bool completed = false, warmup = false;
  double? get kg => double.tryParse(weight.text.replaceAll(',', '.'));
  int? get count => int.tryParse(reps.text);
  bool get valid =>
      kg != null &&
      kg!.isFinite &&
      kg! >= 0 &&
      kg! <= 1000 &&
      count != null &&
      count! > 0 &&
      count! <= 100;
  SetResult result() => SetResult(
    weightKg: valid ? kg! : 0,
    repetitions: valid ? count! : 0,
    rir: rir,
    completed: completed,
    warmup: warmup,
  );
  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

class _ExerciseInput {
  _ExerciseInput(this.exercise)
    : sets = List.generate(exercise.sets.clamp(1, 6), (_) => _SetInput());
  final WorkoutExercise exercise;
  final List<_SetInput> sets;
  final notes = TextEditingController();
  bool discomfort = false;
  ExerciseResult result() => ExerciseResult(
    exerciseId: exercise.stableId,
    exerciseName: exercise.name,
    sets: sets.map((s) => s.result()).toList(),
    notes: notes.text,
    discomfort: discomfort,
  );
  void dispose() {
    notes.dispose();
    for (final s in sets) {
      s.dispose();
    }
  }
}
