import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/training_profile_store.dart';
import '../models/assessment_rules.dart';
import '../models/assessment_step.dart';
import '../models/training_profile.dart';
import '../widgets/assessment_choice.dart';

class TrainingAssessmentPage extends StatefulWidget {
  const TrainingAssessmentPage({
    super.key,
    this.initialProfile,
    this.store,
    this.initialStep,
  });
  final TrainingProfile? initialProfile;
  final TrainingProfileStore? store;
  final int? initialStep;

  @override
  State<TrainingAssessmentPage> createState() => _TrainingAssessmentPageState();
}

class _TrainingAssessmentPageState extends State<TrainingAssessmentPage> {
  late final store = widget.store ?? TrainingProfileStore();
  final formKey = GlobalKey<FormState>();
  final scroll = ScrollController();
  final headingFocus = FocusNode();
  final controllers = <String, TextEditingController>{};
  Map<String, dynamic> answers = {};
  Future<void> pending = Future.value();
  int step = 0;
  bool loading = true;
  bool busy = false;
  bool canLeave = false;
  bool draftSaved = false;
  String? error;
  String? saveError;
  int draftRevision = 0;
  String? loadError;

  AssessmentStep get current => assessmentSteps[step];
  String get unit => answers['weightUnit'] as String? ?? 'kg';

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final profile = widget.initialProfile ?? await store.load();
      final draft = await store.loadDraft();
      if (!mounted) return;
      final data = profile?.toJson() ?? <String, dynamic>{};
      final initialUnit = profile?.weightUnit ?? 'kg';
      answers = {
        ...data,
        'weightUnit': initialUnit,
        'weight': profile == null
            ? ''
            : weightFromKg(profile.weightKg, initialUnit).toStringAsFixed(1),
        'targetWeight': profile?.targetWeightKg == null
            ? ''
            : weightFromKg(
                profile!.targetWeightKg!,
                initialUnit,
              ).toStringAsFixed(1),
      };
      for (final key in [
        'age',
        'heightCm',
        'sleepHours',
        'hydrationLiters',
        'daysPerWeek',
        'minutesPerSession',
      ]) {
        answers[key] = data[key]?.toString() ?? '';
      }
      if (draft != null) {
        if (draft['version'] != 1 ||
            draft['answers'] is! Map ||
            draft['step'] is! int) {
          throw const FormatException('Borrador incompatible');
        }
        answers = Map<String, dynamic>.from(draft['answers'] as Map);
        step = (draft['step'] as int).clamp(0, assessmentSteps.length - 1);
        draftSaved = true;
      }
      if (widget.initialStep != null) {
        step = widget.initialStep!.clamp(0, assessmentSteps.length - 1);
      }

      for (final spec in assessmentSteps) {
        if (spec.multiple &&
            answers[spec.key] != null &&
            (answers[spec.key] is! List ||
                (answers[spec.key] as List).any((v) => v is! String))) {
          throw const FormatException('Selección inválida');
        }
        if (spec.key == 'bodyFatEstimate') {
          final estimate = answers[spec.key];
          if (estimate != null &&
              (estimate is! num ||
                  !estimate.isFinite ||
                  estimate < 8 ||
                  estimate > 55)) {
            answers[spec.key] = null;
          }
        } else if (!spec.multiple &&
            answers[spec.key] != null &&
            answers[spec.key] is! String) {
          throw const FormatException('Respuesta inválida');
        }
        if (spec.options.isEmpty && spec.key != 'bodyFatEstimate') {
          controllers[spec.key]?.dispose();
          controllers[spec.key] = TextEditingController(
            text: answers[spec.key] as String? ?? '',
          );
        }
      }
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError =
              'No pudimos recuperar tu evaluación. Tus datos no se han sobrescrito.';
        });
      }
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    headingFocus.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> persist() {
    final revision = ++draftRevision;
    final snapshot = <String, dynamic>{
      'version': 1,
      'step': step,
      'answers': Map<String, dynamic>.from(answers),
    };
    pending = pending.then((_) async {
      try {
        await store.saveDraft(snapshot);
        if (mounted && revision == draftRevision) {
          setState(() {
            draftSaved = true;
            saveError = null;
          });
        }
      } catch (_) {
        if (mounted && revision == draftRevision) {
          setState(() {
            draftSaved = false;
            saveError =
                'No se pudo guardar el borrador. Reintenta antes de salir.';
          });
        }
      }
    });
    return pending;
  }

  void change(String key, dynamic value) {
    setState(() {
      answers[key] = value;
      draftSaved = false;
      error = null;
    });
    persist();
  }

  String? validateStep(AssessmentStep spec) {
    final value = answers[spec.key];
    if (spec.multiple) {
      if (!spec.optional && (value is! List || value.isEmpty)) {
        return 'Selecciona al menos una opción.';
      }
    } else if (spec.options.isNotEmpty) {
      if (!spec.optional && (value is! String || value.isEmpty)) {
        return 'Selecciona una opción para continuar.';
      }
    } else if (spec.min != null) {
      final text = value as String? ?? '';
      if (spec.optional && text.trim().isEmpty) return null;
      final isWeight = spec.key == 'weight' || spec.key == 'targetWeight';
      final min = isWeight ? weightFromKg(spec.min!, unit) : spec.min!;
      final max = isWeight ? weightFromKg(spec.max!, unit) : spec.max!;
      return validateAssessmentNumber(
        text,
        min.roundToDouble(),
        max.roundToDouble(),
        integer: spec.integer,
      );
    }
    return null;
  }

  void moveTo(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      step = index;
      error = null;
    });
    persist();
    if (scroll.hasClients) scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) headingFocus.requestFocus();
    });
  }

  Future<void> leave() async {
    if (busy || loading) return;
    if (loadError == null) {
      setState(() => busy = true);
      await persist();
      if (!mounted) return;
      setState(() => busy = false);
      if (!draftSaved) return;
    }
    setState(() => canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> next() async {
    if (busy) return;
    final validation = validateStep(current);
    formKey.currentState?.validate();
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    if (step < assessmentSteps.length - 1) {
      moveTo(step + 1);
      return;
    }
    for (var i = 0; i < assessmentSteps.length; i++) {
      final problem = validateStep(assessmentSteps[i]);
      if (problem != null) {
        moveTo(i);
        setState(() => error = problem);
        return;
      }
    }
    setState(() => busy = true);
    await pending;
    try {
      final profile = TrainingProfile(
        weightKg: weightToKg(assessmentNumber(answers['weight'])!, unit),
        targetWeightKg: assessmentNumber(answers['targetWeight']) == null
            ? null
            : weightToKg(assessmentNumber(answers['targetWeight'])!, unit),
        heightCm: assessmentNumber(answers['heightCm'])!,
        age: assessmentNumber(answers['age'])!.toInt(),
        goal: answers['goal'] as String,
        experience: answers['experience'] as String,
        daysPerWeek: int.parse(answers['daysPerWeek'] as String),
        minutesPerSession: int.parse(answers['minutesPerSession'] as String),
        preferences: (answers['preferences'] as String? ?? '').trim(),
        limitations: (answers['limitations'] as String? ?? '').trim(),
        weightUnit: unit,
        bodyRepresentation:
            answers['bodyRepresentation'] as String? ?? 'Neutral',
        bodyShape: answers['bodyShape'] as String,
        bodyFatEstimate: (answers['bodyFatEstimate'] as num?)?.toDouble(),
        schedule: answers['schedule'] as String,
        trainingLocation: answers['trainingLocation'] as String,
        equipment: answers['equipment'] as String,
        priorityMuscles: List<String>.from(
          answers['priorityMuscles'] as List? ?? [],
        ),
        motivations: List<String>.from(answers['motivations'] as List? ?? []),
        dailyActivity: answers['dailyActivity'] as String,
        sleepHours: assessmentNumber(answers['sleepHours']),
        hydrationLiters: assessmentNumber(answers['hydrationLiters']),
      );
      await store.save(profile);
      if (!mounted) return;
      setState(() => canLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, profile);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'No se pudo guardar la evaluación. Reintenta; tus respuestas siguen aquí.';
        });
      }
    }
  }

  void select(String value) {
    if (current.multiple) {
      final selected = List<String>.from(answers[current.key] as List? ?? []);
      selected.contains(value) ? selected.remove(value) : selected.add(value);
      change(current.key, selected);
    } else {
      if (current.key == 'weightUnit' && value != unit) {
        for (final key in ['weight', 'targetWeight']) {
          final number = assessmentNumber(answers[key]);
          if (number != null) {
            final converted = weightFromKg(
              weightToKg(number, unit),
              value,
            ).toStringAsFixed(1);
            answers[key] = converted;
            controllers[key]?.text = converted;
          }
        }
      }
      change(current.key, value);
    }
  }

  Widget input() {
    if (current.options.isNotEmpty) {
      final saved = answers[current.key];
      final options = [...current.options];
      if (!current.multiple &&
          saved is String &&
          saved.isNotEmpty &&
          !options.contains(saved)) {
        options.add(saved);
      }
      return Column(
        children: [
          if ((current.key == 'bodyRepresentation' ||
                  current.key == 'bodyShape') &&
              answers['bodyRepresentation'] != 'Sin silueta')
            AssessmentBody(
              representation:
                  answers['bodyRepresentation'] as String? ?? 'Neutral',
              fullness: current.key != 'bodyShape'
                  ? .5
                  : saved == 'Delgada'
                  ? .1
                  : saved == 'Robusta'
                  ? .9
                  : .5,
            ),
          for (final option in options) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AssessmentChoice(
                label: current.key == 'daysPerWeek'
                    ? '$option días'
                    : current.key == 'minutesPerSession'
                    ? '$option minutos'
                    : option,
                subtitle: getStepOptionMeta(current.key, option)?.subtitle,
                icon: getStepOptionMeta(current.key, option)?.icon,
                selected: current.multiple
                    ? (saved as List? ?? []).contains(option)
                    : saved == option,
                onTap: () => select(option),
              ),
            ),
          ],
        ],
      );
    }
    if (current.key == 'bodyFatEstimate') {
      final estimate = (answers[current.key] as num?)?.toDouble();
      return Column(
        children: [
          if (answers['bodyRepresentation'] != 'Sin silueta')
            AssessmentBody(
              fullness: ((estimate ?? 28) - 8) / 47,
              representation:
                  answers['bodyRepresentation'] as String? ?? 'Neutral',
            ),
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.brand,
                title: const Text(
                  'Añadir mi estimación orientativa',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Opcional · No es un resultado médico',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                value: estimate != null,
                onChanged: (enabled) =>
                    change(current.key, enabled ? 28.0 : null),
              ),
            ),
          ),
          if (estimate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    visualFatRange(estimate),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rango visual orientativo elegido por ti',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Disminuir',
                  onPressed: estimate > 8
                      ? () =>
                            change(current.key, (estimate - 1).clamp(8.0, 55.0))
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Slider(
                    value: estimate,
                    min: 8,
                    max: 55,
                    divisions: 47,
                    label: visualFatRange(estimate),
                    semanticFormatterCallback: visualFatRange,
                    onChanged: (value) => change(current.key, value),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Aumentar',
                  onPressed: estimate < 55
                      ? () =>
                            change(current.key, (estimate + 1).clamp(8.0, 55.0))
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Rango elegido por ti; no es un resultado calculado.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
    }
    final numeric = current.min != null;
    List<String> presets = const [];
    if (current.key == 'sleepHours') {
      presets = ['6', '7', '7.5', '8', '9'];
    } else if (current.key == 'hydrationLiters') {
      presets = ['1.5', '2', '2.5', '3'];
    } else if (current.key == 'heightCm') {
      presets = ['155', '160', '165', '170', '175', '180', '185', '190'];
    } else if (current.key == 'age') {
      presets = ['20', '25', '30', '35', '40', '45', '50'];
    } else if (current.key == 'weight' || current.key == 'targetWeight') {
      presets = unit == 'kg'
          ? ['60', '65', '70', '75', '80', '85', '90']
          : ['130', '145', '160', '175', '190', '205'];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current.key == 'limitations') ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  color: AppColors.brand,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu seguridad es prioridad',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Si experimentas dolor agudo o molestias físicas preocupantes, detén el ejercicio y consulta a un especialista médico. FitBodyGym no diagnostica ni reemplaza a profesionales de la salud.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        TextFormField(
          key: ValueKey(current.key),
          controller: controllers[current.key],
          keyboardType: numeric
              ? TextInputType.numberWithOptions(decimal: !current.integer)
              : TextInputType.multiline,
          minLines: numeric ? 1 : 3,
          maxLines: numeric ? 1 : 5,
          maxLength: numeric ? 7 : 600,
          textInputAction: numeric
              ? TextInputAction.done
              : TextInputAction.newline,
          onChanged: (value) => change(current.key, value),
          validator: (_) => validateStep(current),
          decoration: InputDecoration(
            labelText: current.optional
                ? 'Tu respuesta (opcional)'
                : 'Tu respuesta',
            suffixText: current.key == 'weight' || current.key == 'targetWeight'
                ? unit
                : current.suffix,
          ),
        ),
        if (current.key == 'limitations') ...[
          const SizedBox(height: 10),
          const Text(
            'Sugerencias rápidas para agregar:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in [
                'Sin molestias',
                'Rodilla sensible',
                'Espalda baja',
                'Hombro sensible',
                'Cuello',
                'Muñeca',
                'Evitar saltos',
              ])
                ActionChip(
                  backgroundColor: AppColors.inputFill,
                  side: const BorderSide(color: AppColors.outline),
                  label: Text(suggestion, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    final currentText =
                        controllers['limitations']?.text.trim() ?? '';
                    final newText =
                        currentText.isEmpty ||
                            currentText == 'Sin molestias' ||
                            suggestion == 'Sin molestias'
                        ? suggestion
                        : '$currentText, $suggestion';
                    controllers['limitations']?.text = newText;
                    change('limitations', newText);
                  },
                ),
            ],
          ),
        ] else if (presets.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Valores comunes:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in presets)
                ActionChip(
                  backgroundColor: controllers[current.key]?.text == p
                      ? AppColors.surfaceHigh
                      : AppColors.inputFill,
                  side: BorderSide(
                    color: controllers[current.key]?.text == p
                        ? AppColors.brand
                        : AppColors.outline,
                  ),
                  label: Text(
                    current.suffix.isNotEmpty ? '$p ${current.suffix}' : p,
                    style: TextStyle(
                      fontSize: 12,
                      color: controllers[current.key]?.text == p
                          ? AppColors.brand
                          : AppColors.textPrimary,
                      fontWeight: controllers[current.key]?.text == p
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onPressed: () {
                    controllers[current.key]?.text = p;
                    change(current.key, p);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canLeave,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !busy) {
        if (step > 0 && loadError == null && !loading) {
          moveTo(step - 1);
        } else {
          leave();
        }
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Tu punto de partida'),
        leading: IconButton(
          tooltip: step == 0 ? 'Guardar y salir' : 'Paso anterior',
          onPressed: busy || loading
              ? null
              : () =>
                    step > 0 && loadError == null ? moveTo(step - 1) : leave(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Guardar y salir',
            onPressed: busy || loading ? null : leave,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loadError!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: restore,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Form(
                    key: formKey,
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.all(24),
                      children: [
                        if (step == 0) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brand.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.brand.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.brand,
                                        ),
                                      ),
                                      child: const Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.bolt,
                                            size: 14,
                                            color: AppColors.brand,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'EVALUACIÓN FITBODYGYM',
                                            style: TextStyle(
                                              color: AppColors.brand,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          size: 16,
                                          color: AppColors.textMuted,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '~2 min',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  '¡Te damos la bienvenida a tu evaluación!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tus respuestas nos permitirán personalizar tu experiencia. Toma solo un par de minutos y puedes completarla con o sin membresía activa.',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (getStepMilestone(step) != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 22),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.brand,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    getStepMilestone(step)!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'PASO ${step + 1} DE ${assessmentSteps.length}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: AppColors.brand,
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.inputFill,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.outline),
                              ),
                              child: Text(
                                '${(((step + 1) / assessmentSteps.length) * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (step + 1) / assessmentSteps.length,
                            minHeight: 7,
                            backgroundColor: AppColors.surfaceHigh,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.brand,
                            ),
                            semanticsLabel:
                                'Progreso de la evaluación: paso ${step + 1} de ${assessmentSteps.length}',
                          ),
                        ),
                        const SizedBox(height: 28),
                        Focus(
                          focusNode: headingFocus,
                          child: Semantics(
                            header: true,
                            child: Text(
                              current.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(current.hint),
                        const SizedBox(height: 24),
                        IgnorePointer(ignoring: busy, child: input()),
                        if (error != null || saveError != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                error ?? saveError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            if (step > 0)
                              OutlinedButton(
                                onPressed: busy ? null : () => moveTo(step - 1),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Text('Atrás'),
                                ),
                              ),
                            FilledButton(
                              onPressed: busy ? null : next,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                child: Text(
                                  busy
                                      ? 'Guardando…'
                                      : step == assessmentSteps.length - 1
                                      ? 'Guardar mi evaluación'
                                      : 'Continuar',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          draftSaved
                              ? 'Borrador guardado en este dispositivo.'
                              : 'Tus respuestas se guardan mientras avanzas.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}
