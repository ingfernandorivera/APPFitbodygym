import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/workout_plan.dart';
import '../widgets/exercise_video_player.dart';

class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({
    super.key,
    required this.exercise,
    required this.setsCount,
    required this.repsText,
    required this.weightKg,
    required this.restSeconds,
    this.onSaveCustomization,
    this.onStartRest,
  });

  final WorkoutExercise exercise;
  final int setsCount;
  final String repsText;
  final double weightKg;
  final int restSeconds;
  final void Function(
    int setsCount,
    String repsText,
    double weightKg,
    int restSeconds,
  )?
  onSaveCustomization;
  final void Function(int seconds)? onStartRest;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  late int setsCount;
  late String repsText;
  late double weightKg;
  late int restSeconds;

  @override
  void initState() {
    super.initState();
    setsCount = widget.setsCount;
    repsText = widget.repsText;
    weightKg = widget.weightKg;
    restSeconds = widget.restSeconds;
  }

  void _notifyChange() {
    widget.onSaveCustomization?.call(
      setsCount,
      repsText,
      weightKg,
      restSeconds,
    );
  }

  String _formatRest(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _editSeriesAndReps() async {
    final result = await showModalBottomSheet<_SeriesRepsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditSeriesRepsSheet(
        initialSets: setsCount,
        initialReps: repsText,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        setsCount = result.sets;
        if (result.reps.isNotEmpty) {
          repsText = result.reps;
        }
      });
      _notifyChange();
    }
  }

  Future<void> _editWeight() async {
    final updatedWeight = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditWeightSheet(
        initialWeight: weightKg,
      ),
    );

    if (updatedWeight != null && mounted) {
      setState(() {
        weightKg = updatedWeight.clamp(0, 1000);
      });
      _notifyChange();
    }
  }

  Future<void> _editRest() async {
    final updatedSeconds = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tiempo de descanso entre series',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [30, 45, 60, 90, 120, 180].map((s) {
                  final isSelected = s == restSeconds;
                  return ChoiceChip(
                    label: Text('${s}s (${_formatRest(s)})'),
                    selected: isSelected,
                    selectedColor: AppColors.brand,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: const Color(0xFF2A2A2E),
                    onSelected: (val) {
                      if (val) Navigator.pop(ctx, s);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );

    if (updatedSeconds != null && mounted) {
      setState(() => restSeconds = updatedSeconds);
      _notifyChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo =
        widget.exercise.mediaUrl != null &&
        widget.exercise.mediaUrl!.isNotEmpty;
    final displayWeight = weightKg.truncateToDouble() == weightKg
        ? weightKg.toInt().toString()
        : weightKg.toString();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.exercise.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Reproductor de video grande con reproducción automática en bucle
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: const Color(0xFF1E1E22),
              child: hasVideo
                  ? ExerciseVideoPlayer(
                      url: widget.exercise.mediaUrl!,
                      autoPlay: true,
                      startMuted: true,
                    )
                  : AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.fitness_center_rounded,
                              size: 56,
                              color: AppColors.brand,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.exercise.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.exercise.muscleGroup,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Nombre del ejercicio
          Text(
            widget.exercise.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.exercise.muscleGroup} · ${widget.exercise.difficulty}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          // Tarjetas editables lado a lado
          Row(
            children: [
              // Card Series y Repeticiones
              Expanded(
                child: InkWell(
                  onTap: _editSeriesAndReps,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2C2C32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Series y Repeticiones',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${setsCount}x $repsText',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Card Carga (kg)
              Expanded(
                child: InkWell(
                  onTap: _editWeight,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2C2C32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Carga (kg)',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayWeight,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Fila de descanso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2C2C32)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_formatRest(restSeconds)} (Descanso entre series)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Modificar descanso',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: Colors.white70,
                  ),
                  onPressed: _editRest,
                ),
                IconButton(
                  tooltip: 'Iniciar descanso',
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.brand,
                    size: 32,
                  ),
                  onPressed: () {
                    widget.onStartRest?.call(restSeconds);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text(
                          'Descanso de ${_formatRest(restSeconds)} iniciado.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Instrucciones de técnica
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2C2C32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.brand,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Técnica y ejecución',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.exercise.instructions,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                if (widget.exercise.commonMistakes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Errores comunes a evitar:',
                    style: TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.exercise.commonMistakes,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SeriesRepsResult {
  const _SeriesRepsResult(this.sets, this.reps);
  final int sets;
  final String reps;
}

class _EditSeriesRepsSheet extends StatefulWidget {
  const _EditSeriesRepsSheet({
    required this.initialSets,
    required this.initialReps,
  });

  final int initialSets;
  final String initialReps;

  @override
  State<_EditSeriesRepsSheet> createState() => _EditSeriesRepsSheetState();
}

class _EditSeriesRepsSheetState extends State<_EditSeriesRepsSheet> {
  late int _sets;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _sets = widget.initialSets;
    _repsController = TextEditingController(text: widget.initialReps);
  }

  @override
  void dispose() {
    _repsController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _SeriesRepsResult(_sets, _repsController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Editar Series y Repeticiones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Número de series:',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: _sets > 1 ? () => setState(() => _sets--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.brand,
                ),
                Text(
                  '$_sets',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: _sets < 8 ? () => setState(() => _sets++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.brand,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Repeticiones por serie:',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ej. 12 a 15, 10, o al fallo',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _save,
                child: const Text(
                  'Guardar cambios',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditWeightSheet extends StatefulWidget {
  const _EditWeightSheet({required this.initialWeight});
  final double initialWeight;

  @override
  State<_EditWeightSheet> createState() => _EditWeightSheetState();
}

class _EditWeightSheetState extends State<_EditWeightSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialWeight == 0
          ? ''
          : (widget.initialWeight.truncateToDouble() == widget.initialWeight
                ? widget.initialWeight.toInt().toString()
                : widget.initialWeight.toString()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Editar Carga (kg)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'Peso en kilogramos',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: '0',
                hintStyle: const TextStyle(color: Colors.white38),
                suffixText: 'kg',
                suffixStyle: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.bold,
                ),
                filled: true,
                fillColor: const Color(0xFF2A2A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ajustes rápidos:',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [2.5, 5.0, 10.0, 20.0].map((inc) {
                return ActionChip(
                  label: Text('+$inc kg'),
                  backgroundColor: const Color(0xFF2A2A2E),
                  side: const BorderSide(color: Color(0xFF3A3A40)),
                  labelStyle: const TextStyle(color: Colors.white),
                  onPressed: () {
                    final curr =
                        double.tryParse(
                          _controller.text.replaceAll(',', '.'),
                        ) ??
                        0;
                    final next = curr + inc;
                    _controller.text =
                        next.truncateToDouble() == next
                            ? next.toInt().toString()
                            : next.toString();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _save,
                child: const Text(
                  'Guardar carga',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
