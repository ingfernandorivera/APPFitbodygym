import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/workout_history_store.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import 'exercise_detail_page.dart';
import 'workout_result_page.dart';

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
  late final List<_ExerciseInput> inputs;
  final elapsed = Stopwatch()..start();
  final restClock = Stopwatch();
  Timer? elapsedTimer;
  Timer? restTimer;
  int prescribedRest = 0;
  bool saving = false;
  String? error;
  final previous = <String, ExerciseResult>{};

  int get remaining =>
      (prescribedRest - restClock.elapsed.inSeconds).clamp(0, prescribedRest);

  @override
  void initState() {
    super.initState();
    inputs = widget.day.exercises.map(_ExerciseInput.new).toList();
    // Ticker para el reloj superior en vivo
    elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
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
    restTimer?.cancel();
    if (reset || seconds != prescribedRest || remaining == 0) {
      restClock.reset();
      prescribedRest = seconds;
    }
    restClock.start();
    restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (remaining == 0) {
          restClock.stop();
          restTimer?.cancel();
        }
      });
    });
    setState(() {});
  }

  void pauseRest() {
    restTimer?.cancel();
    restClock.stop();
    setState(() {});
  }

  void resumeRest() {
    if (remaining > 0) {
      restClock.start();
      restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (remaining == 0) {
            restClock.stop();
            restTimer?.cancel();
          }
        });
      });
      setState(() {});
    }
  }

  void addRestTime(int extraSeconds) {
    setState(() {
      prescribedRest += extraSeconds;
    });
  }

  void stopRest() {
    restTimer?.cancel();
    restClock.stop();
    restClock.reset();
    setState(() {
      prescribedRest = 0;
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatSeconds(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    elapsedTimer?.cancel();
    restTimer?.cancel();
    elapsed.stop();
    restClock.stop();
    for (final input in inputs) {
      input.dispose();
    }
    super.dispose();
  }

  void _toggleExerciseCompletion(_ExerciseInput input) {
    setState(() {
      if (input.isCompleted) {
        input.setCompleted(false);
      } else {
        input.setCompleted(true);
        startRest(input.exercise.restSeconds, reset: true);
      }
    });
  }

  Future<void> _openExerciseDetail(_ExerciseInput input) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailPage(
          exercise: input.exercise,
          setsCount: input.sets.length,
          repsText: input.repsSummary,
          weightKg: input.currentWeight,
          restSeconds: input.exercise.restSeconds,
          onSaveCustomization: (setsCount, repsText, weightKg, restSeconds) {
            setState(() {
              input.applyCustomization(
                setsCount: setsCount,
                repsText: repsText,
                weightKg: weightKg,
              );
            });
          },
          onStartRest: (seconds) {
            startRest(seconds, reset: true);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> finish() async {
    if (!inputs.any((e) => e.sets.any((s) => s.completed))) {
      setState(
        () => error =
            'Completa al menos un ejercicio o serie antes de finalizar.',
      );
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
  Widget build(BuildContext context) {
    final pendingInputs = inputs.where((e) => !e.isCompleted).toList();
    final completedInputs = inputs.where((e) => e.isCompleted).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          _formatDuration(elapsed.elapsed),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Detalle de la rutina',
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutResultPage(
                    plan: WorkoutPlan(
                      name: widget.planName,
                      goal: 'Entrenamiento activo',
                      createdAt: DateTime.now(),
                      days: [widget.day],
                      version: widget.planVersion,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de descanso activo si el temporizador está corriendo
          if (remaining > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: AppColors.brand, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Descanso: ${_formatSeconds(remaining)}',
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => addRestTime(30),
                    child: const Text(
                      '+30s',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      restClock.isRunning
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      color: AppColors.brand,
                    ),
                    onPressed: restClock.isRunning ? pauseRest : resumeRest,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white60,
                      size: 20,
                    ),
                    onPressed: stopRest,
                  ),
                ],
              ),
            ),
          // Lista de ejercicios
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                // Título de la sesión y acción
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.day.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (widget.day.focus.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.day.focus,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutResultPage(
                              plan: WorkoutPlan(
                                name: widget.planName,
                                goal: 'Entrenamiento activo',
                                createdAt: DateTime.now(),
                                days: [widget.day],
                                version: widget.planVersion,
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Editar rutina',
                        style: TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                // Indicación superior
                if (completedInputs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${completedInputs.length} de ${inputs.length} ejercicios completados',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                // LISTADO DE EJERCICIOS PENDIENTES
                ...pendingInputs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final input = entry.value;
                  return _buildExerciseCard(
                    input: input,
                    index: index + 1,
                    isCompleted: false,
                  );
                }),
                // SECCIÓN "COMPLETADOS" (Indicación 4 y 5)
                if (completedInputs.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Completados',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...completedInputs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final input = entry.value;
                    return _buildExerciseCard(
                      input: input,
                      index: pendingInputs.length + index + 1,
                      isCompleted: true,
                    );
                  }),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Botón fijo inferior "Finalizar entrenamiento"
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D0E),
              border: Border(top: BorderSide(color: Color(0xFF1E1E22))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                onPressed: saving ? null : finish,
                child: Text(
                  saving ? 'Guardando…' : 'Finalizar entrenamiento',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard({
    required _ExerciseInput input,
    required int index,
    required bool isCompleted,
  }) {
    final ex = input.exercise;
    final cardBg = isCompleted
        ? const Color(0xFF141416)
        : const Color(0xFF1B1B1E);
    final border = isCompleted
        ? const Color(0xFF222226)
        : const Color(0xFF2C2C32);
    final textColor = isCompleted ? AppColors.textMuted : Colors.white;

    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: Column(
        children: [
          // Fila principal del ejercicio
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Checkbox a la izquierda (Indicación 4 y 5)
                GestureDetector(
                  key: ValueKey('exercise_check_${ex.stableId}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleExerciseCompletion(input),
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isCompleted
                            ? Colors.white
                            : const Color(0xFF55555F),
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            size: 20,
                            color: Colors.black,
                          )
                        : null,
                  ),
                ),
                // Contenido del ejercicio que abre detalle y video
                Expanded(
                  child: InkWell(
                    onTap: () => _openExerciseDetail(input),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        // Miniatura con número (Screenshot 2)
                        Stack(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: const Color(0xFF242428),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.fitness_center,
                                  size: 26,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '$index',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Nombre y repeticiones
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex.name,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${input.sets.length}x ${input.repsSummary}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Flecha a la derecha para ver detalle y video (Screenshot 2)
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF7E7E88),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Fila inferior: tiempo de descanso sugerido y botón Play
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_formatSeconds(ex.restSeconds)} (Descanso entre series)',
                    style: TextStyle(
                      color: isCompleted ? Colors.white38 : Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Iniciar descanso',
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    color: isCompleted
                        ? Colors.white38
                        : AppColors.brand,
                    size: 28,
                  ),
                  onPressed: () => startRest(ex.restSeconds, reset: true),
                ),
              ],
            ),
          ),
          // Panel compacto de series para edición precisa y compatibilidad con tests
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              children: [
                ...input.sets.asMap().entries.map((entry) {
                  final setIndex = entry.key;
                  final s = entry.value;
                  return Padding(
                    key: ObjectKey(s),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'S${setIndex + 1}',
                          style: TextStyle(
                            color: isCompleted
                                ? AppColors.textMuted
                                : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: s.weight,
                              enabled: !saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: TextStyle(
                                color: isCompleted
                                    ? AppColors.textMuted
                                    : Colors.white,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Peso (kg)',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: s.reps,
                              enabled: !saving,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: isCompleted
                                    ? AppColors.textMuted
                                    : Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: ex.type == 'cardio'
                                    ? 'Minutos'
                                    : 'Reps',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Checkbox(
                          value: s.completed,
                          onChanged: saving
                              ? null
                              : (v) {
                                  setState(() {
                                    s.completed = v ?? false;
                                  });
                                  if (v == true) {
                                    startRest(ex.restSeconds, reset: true);
                                  }
                                },
                        ),
                      ],
                    ),
                  );
                }),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: !saving && input.sets.length < 8
                          ? () => setState(() => input.sets.add(_SetInput()))
                          : null,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Añadir serie',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openExerciseDetail(input),
                      child: const Text(
                        'Ver video técnica',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetInput {
  final weight = TextEditingController(text: '0');
  final reps = TextEditingController(text: '12');
  int rir = 2;
  bool completed = false;
  bool warmup = false;

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
    : sets = List.generate(
        exercise.sets.clamp(1, 6),
        (_) => _SetInput()..reps.text = exercise.minReps.toString(),
      );

  final WorkoutExercise exercise;
  final List<_SetInput> sets;
  final notes = TextEditingController();
  bool discomfort = false;

  bool get isCompleted => sets.isNotEmpty && sets.every((s) => s.completed);

  void setCompleted(bool val) {
    for (final s in sets) {
      s.completed = val;
      if (val) {
        if (s.reps.text.isEmpty) s.reps.text = exercise.minReps.toString();
        if (s.weight.text.isEmpty) s.weight.text = '0';
      }
    }
  }

  String get repsSummary {
    if (exercise.minReps == exercise.maxReps) {
      return '${exercise.minReps}';
    }
    return '${exercise.minReps} a ${exercise.maxReps}';
  }

  double get currentWeight {
    for (final s in sets) {
      final w = s.kg;
      if (w != null && w > 0) return w;
    }
    return 0;
  }

  void applyCustomization({
    required int setsCount,
    required String repsText,
    required double weightKg,
  }) {
    while (sets.length < setsCount) {
      sets.add(_SetInput());
    }
    while (sets.length > setsCount) {
      final removed = sets.removeLast();
      removed.dispose();
    }
    final parsedReps =
        int.tryParse(RegExp(r'\d+').firstMatch(repsText)?.group(0) ?? '') ??
        exercise.minReps;
    for (final s in sets) {
      s.reps.text = parsedReps.toString();
      s.weight.text = weightKg.truncateToDouble() == weightKg
          ? weightKg.toInt().toString()
          : weightKg.toString();
    }
  }

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
