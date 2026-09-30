import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../assessment/data/training_profile_store.dart';
import '../../assessment/models/training_profile.dart';
import '../../assessment/pages/training_assessment_page.dart';
import '../../profile/data/app_user_profile_store.dart';
import '../../profile/models/app_user_profile.dart';
import '../../training/data/demo_workout_generator.dart';
import '../../training/data/exercise_catalog.dart';
import '../../training/data/training_rules.dart';
import '../../training/data/workout_plan_store.dart';
import '../../training/models/workout_plan.dart';
import '../data/ai_chat_service.dart';
import '../data/chat_cache_store.dart';
import '../data/workout_proposal_validator.dart';
import '../models/ai_chat_response.dart';

class UserProfileContext {
  const UserProfileContext({
    this.trainingProfile,
    this.appProfile,
  });

  final TrainingProfile? trainingProfile;
  final AppUserProfile? appProfile;

  String? get fullName =>
      appProfile?.fullName.isNotEmpty == true ? appProfile!.fullName : null;

  int? get age {
    if (trainingProfile?.age != null && trainingProfile!.age > 0) {
      return trainingProfile!.age;
    }
    if (appProfile?.birthDate.isNotEmpty == true) {
      final date = DateTime.tryParse(appProfile!.birthDate);
      if (date != null) {
        final now = DateTime.now();
        var calculated = now.year - date.year;
        if (now.month < date.month ||
            (now.month == date.month && now.day < date.day)) {
          calculated--;
        }
        return calculated;
      }
    }
    return null;
  }

  double? get weightKg => trainingProfile?.weightKg;
  double? get heightCm => trainingProfile?.heightCm;
  String get gender => trainingProfile?.gender ?? 'Sin indicar';

  String get goal {
    if (appProfile?.goal.isNotEmpty == true) return appProfile!.goal;
    if (trainingProfile?.goal.isNotEmpty == true) return trainingProfile!.goal;
    return 'Salud y acondicionamiento';
  }

  String get limitations {
    final list = <String>[];
    if (appProfile?.limitations.isNotEmpty == true) {
      list.add(appProfile!.limitations);
    }
    if (trainingProfile?.limitations.isNotEmpty == true &&
        !list.contains(trainingProfile!.limitations)) {
      list.add(trainingProfile!.limitations);
    }
    return list.isNotEmpty ? list.join(', ') : 'Ninguna indicada';
  }

  int get daysPerWeek => trainingProfile?.daysPerWeek ?? 3;
  int get minutesPerSession => trainingProfile?.minutesPerSession ?? 60;
  String get experience => trainingProfile?.experience ?? 'Intermedio';
  String get equipment => trainingProfile?.equipment ?? 'Gimnasio completo';
  List<String> get priorityMuscles =>
      trainingProfile?.priorityMuscles ?? const [];

  Map<String, dynamic> toMergedMap() {
    return {
      if (fullName != null) 'fullName': fullName,
      if (age != null) 'age': age,
      if (weightKg != null) 'weightKg': weightKg,
      if (heightCm != null) 'heightCm': heightCm,
      'gender': gender,
      'goal': goal,
      'limitations': limitations,
      'daysPerWeek': daysPerWeek,
      'minutesPerSession': minutesPerSession,
      'experience': experience,
      'equipment': equipment,
      'priorityMuscles': priorityMuscles,
      if (trainingProfile != null) ...trainingProfile!.toJson(),
    };
  }
}

class AiChatPage extends StatefulWidget {
  const AiChatPage({
    super.key,
    required this.onOpenTraining,
    this.profileStore,
    this.planStore,
    this.chatService,
    this.cacheStore,
    this.storageUserId,
  });

  final VoidCallback onOpenTraining;
  final TrainingProfileStore? profileStore;
  final WorkoutPlanStore? planStore;
  final AiChatService? chatService;
  final ChatCacheStore? cacheStore;
  final String? storageUserId;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _ChatMessage {
  _ChatMessage(
    this.text, {
    this.fromUser = false,
    this.response,
    this.status = 'pending',
  });
  final AiChatResponse? response;
  String status;
  Map<String, dynamic> toJson() => {
    'text': text,
    'fromUser': fromUser,
    'status': status,
    if (response != null) 'response': response!.toJson(),
  };

  final String text;
  final bool fromUser;
}

class _AiChatPageState extends State<AiChatPage> {
  late final aiChatService = widget.chatService ?? AiChatService();
  late final profileStore =
      widget.profileStore ??
      TrainingProfileStore(storageUserId: widget.storageUserId);
  late final appProfileStore =
      AppUserProfileStore(storageUserId: profileStore.userId);
  late final planStore =
      widget.planStore ?? WorkoutPlanStore(storageUserId: profileStore.userId);
  late final cacheStore =
      widget.cacheStore ?? ChatCacheStore(storageUserId: profileStore.userId);
  String? cacheError;
  bool loading = true;
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final messages = <_ChatMessage>[
    _ChatMessage(
      'Hola. Puedo ayudarte a crear o modificar tu rutina, revisar tus datos de perfil y responder dudas sobre tu entrenamiento. ¿Qué necesitas?',
    ),
  ];
  var working = false;

  @override
  void initState() {
    super.initState();
    loadCache();
  }

  Future<void> loadCache() async {
    try {
      final saved = await cacheStore.load();
      if (!mounted) return;

      final training = await profileStore.load();
      final appUser = await appProfileStore.load();
      final userContext = UserProfileContext(
        trainingProfile: training,
        appProfile: appUser,
      );
      final activeWorkout = await planStore.load();

      final restored = <_ChatMessage>[];
      for (final m in saved) {
        final text = m['text'] as String;
        final fromUser = m['fromUser'] as bool? ?? false;
        final status = m['status'] as String? ?? 'pending';
        AiChatResponse? response;
        if (m['response'] != null) {
          try {
            response = AiChatResponse.parse(m['response']);
          } catch (_) {}
        }
        if (!fromUser && (response == null || !response.action.isProposal)) {
          if (_hasRoutineProposalContent(text)) {
            final focus = _extractRequestedFocus(text);
            final days = _extractRequestedDays(text);
            response = _createFocusProposal(
              userContext: userContext,
              currentPlan: activeWorkout,
              focusMuscles: focus,
              requestedDays: days,
              customReply: text,
            );
          }
        }
        restored.add(
          _ChatMessage(
            text,
            fromUser: fromUser,
            status: status,
            response: response,
          ),
        );
      }

      if (restored.isNotEmpty) {
        setState(() {
          messages.clear();
          messages.addAll(restored);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => cacheError = 'No se pudo cargar la conversación local.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> persist() async {
    try {
      await cacheStore.save(messages.map((m) => m.toJson()).toList());
      if (mounted) setState(() => cacheError = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => cacheError = 'No se pudo guardar la conversación local.',
        );
      }
    }
  }

  Future<void> changeProposal(_ChatMessage message, bool apply) async {
    if (working) return;
    setState(() => working = true);
    try {
      if (apply) {
        final profile = await profileStore.load();
        final saved = await WorkoutProposalValidator(ExerciseCatalog.exercises)
            .apply(
              message.response!.action,
              confirmed: true,
              store: planStore,
              profile: profile,
            );
        if (!mounted) return;
        setState(() => message.status = 'applied');
        addMessage('Rutina guardada y verificada. Versión ${saved.version}.');
      } else {
        setState(() => message.status = 'cancelled');
      }
      await persist();
    } catch (_) {
      if (mounted) {
        addMessage(
          'No se pudo aplicar: la propuesta puede ser inválida, estar desactualizada o haber fallado el guardado. Revisa la rutina y reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> localProposal() async {
    if (working || loading) return;
    setState(() => working = true);
    try {
      final profile = await profileStore.load();
      if (profile == null) {
        if (mounted) {
          addMessage('Completa primero tu evaluación para crear una rutina.');
        }
        return;
      }
      final current = await planStore.load();
      final isNew = current == null;
      final plan = DemoWorkoutGenerator()
          .generate(profile)
          .copyWith(id: current?.id, version: (current?.version ?? 0) + 1);
      final response = AiChatResponse(
        reply:
            'Propuesta de rutina adaptada a tu evaluación. Revisa los días y ejercicios antes de aplicar.',
        action: AiWorkoutAction(
          type: isNew ? AiActionType.proposeWorkout : AiActionType.modifyWorkout,
          plan: plan,
          expectedVersion: current?.version ?? 0,
          expectedPlanId: current?.id,
        ),
      );
      if (mounted) {
        setState(
          () => messages.add(_ChatMessage(response.reply, response: response)),
        );
      }
      await persist();
    } catch (_) {
      if (mounted) {
        addMessage(
          'No se pudo crear una rutina compatible. Revisa tiempo, equipo y limitaciones en tu evaluación.',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  int? _extractRequestedDays(String text) {
    final lower = text.toLowerCase();
    final match = RegExp(r'(\d+)\s*d[ií]as?').firstMatch(lower);
    if (match != null) {
      final n = int.tryParse(match.group(1)!);
      if (n != null && n >= 1 && n <= 7) return n;
    }
    if (lower.contains('un dia') || lower.contains('un día')) return 1;
    if (lower.contains('dos dias') || lower.contains('dos días')) return 2;
    if (lower.contains('tres dias') || lower.contains('tres días')) return 3;
    if (lower.contains('cuatro dias') || lower.contains('cuatro días')) return 4;
    if (lower.contains('cinco dias') || lower.contains('cinco días')) return 5;
    if (lower.contains('seis dias') || lower.contains('seis días')) return 6;
    if (lower.contains('siete dias') || lower.contains('siete días')) return 7;
    return null;
  }

  bool _looksLikeRoutineOrMentionsApply(String text) {
    return _hasRoutineProposalContent(text);
  }

  WorkoutExercise? _matchExercise(String rawName, int sets, int minReps, int maxReps) {
    final norm = normalized(rawName)
        .replaceAll('*', '')
        .replaceAll(':', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('/', ' ')
        .trim();

    // 1. Coincidencia directa por nombre
    for (final e in ExerciseCatalog.exercises) {
      final eNorm = normalized(e.name);
      if (norm == eNorm || norm.contains(eNorm) || eNorm.contains(norm)) {
        return e.copyWith(
          sets: sets,
          targetMin: minReps,
          targetMax: maxReps,
        );
      }
    }

    // 2. Coincidencia por palabras clave
    WorkoutExercise? bestMatch;
    for (final e in ExerciseCatalog.exercises) {
      // Pecho
      if (norm.contains('plano') && (norm.contains('barra') || norm.contains('banca')) && e.id == 'bench_press_barbell') {
        bestMatch = e; break;
      }
      if (norm.contains('inclinado') && norm.contains('mancuerna') && e.id == 'incline_dumbbell_press') {
        bestMatch = e; break;
      }
      if (norm.contains('inclinado') && norm.contains('barra') && e.id == 'incline_barbell_press') {
        bestMatch = e; break;
      }
      if (norm.contains('inclinado') && (norm.contains('maquina') || norm.contains('pecho')) && e.id == 'incline_chest_machine') {
        bestMatch = e; break;
      }
      if (norm.contains('apertura') && (norm.contains('inclinad') || norm.contains('superior')) && e.id == 'incline_dumbbell_flyes') {
        bestMatch = e; break;
      }
      if (norm.contains('apertura') && (norm.contains('mancuerna') || norm.contains('plano') || norm.contains('pecho')) && e.id == 'dumbbell_flyes') {
        bestMatch = e; break;
      }
      if ((norm.contains('peck') || norm.contains('pec-deck') || norm.contains('contractor')) && e.id == 'pec_deck') {
        bestMatch = e; break;
      }
      if ((norm.contains('fondo') || norm.contains('dip')) && (norm.contains('paralela') || norm.contains('pecho')) && e.id == 'parallel_dips') {
        bestMatch = e; break;
      }
      if (norm.contains('cerrado') && e.id == 'close_grip_bench_press') {
        bestMatch = e; break;
      }
      if (norm.contains('declinado') && e.id == 'decline_dumbbell_press') {
        bestMatch = e; break;
      }
      if ((norm.contains('flexion') || norm.contains('lagartija') || norm.contains('push')) &&
          (norm.contains('elevad') || norm.contains('pies')) && e.id == 'elevated_push_ups') {
        bestMatch = e; break;
      }
      if ((norm.contains('flexion') || norm.contains('lagartija') || norm.contains('push')) &&
          (norm.contains('diamante') || norm.contains('juntas')) && e.id == 'diamond_push_ups') {
        bestMatch = e; break;
      }
      if (norm.contains('cruce') && norm.contains('polea') && e.id == 'pec_deck') {
        bestMatch = e; break;
      }
      if ((norm.contains('press') || norm.contains('empuje')) && (norm.contains('maquina') || norm.contains('guiada')) && e.id == 'chest_press_machine') {
        bestMatch = e; break;
      }
      if (norm.contains('press de banca') && e.id == 'bench_press_barbell') {
        bestMatch = e; break;
      }
      if (norm.contains('press de pecho') && e.id == 'chest_press_machine') {
        bestMatch = e; break;
      }

      // Espalda
      if (norm.contains('jalon') && e.id == 'lat_pulldown') {
        bestMatch = e; break;
      }
      if (norm.contains('remo') && norm.contains('barra') && e.id == 'barbell_row') {
        bestMatch = e; break;
      }
      if (norm.contains('remo') && (norm.contains('maquina') || norm.contains('sentado')) && e.id == 'seated_row') {
        bestMatch = e; break;
      }

      // Piernas
      if (norm.contains('sentadilla') && norm.contains('barra') && e.id == 'squat_barbell') {
        bestMatch = e; break;
      }
      if (norm.contains('sentadilla') && e.id == 'goblet_squat') {
        bestMatch = e; break;
      }
      if (norm.contains('prensa') && e.id == 'leg_press') {
        bestMatch = e; break;
      }
      if ((norm.contains('pantorrilla') || norm.contains('gemelo')) && e.id == 'calf_raise') {
        bestMatch = e; break;
      }
      if ((norm.contains('femoral') || norm.contains('isquio')) && e.id == 'leg_curl') {
        bestMatch = e; break;
      }
      if (norm.contains('peso muerto') && e.id == 'romanian_deadlift_barbell') {
        bestMatch = e; break;
      }

      // Brazos y hombros
      if (norm.contains('curl') && (norm.contains('barra') || norm.contains('biceps') || norm.contains('bíceps')) && e.id == 'bicep_curl_barbell') {
        bestMatch = e; break;
      }
      if (norm.contains('extension') && (norm.contains('triceps') || norm.contains('tríceps')) && e.id == 'tricep_extension_dumbbell') {
        bestMatch = e; break;
      }
      if (norm.contains('face pull') && e.id == 'face_pull') {
        bestMatch = e; break;
      }
      if (norm.contains('militar') && e.id == 'military_press') {
        bestMatch = e; break;
      }
    }

    if (bestMatch != null) {
      return bestMatch.copyWith(
        sets: sets,
        targetMin: minReps,
        targetMax: maxReps,
      );
    }

    // 3. Fallback: buscar cualquier ejercicio del catálogo que comparta alguna palabra clave
    for (final e in ExerciseCatalog.exercises) {
      final words = normalized(e.name).split(' ').where((w) => w.length > 3);
      for (final w in words) {
        if (norm.contains(w)) {
          return e.copyWith(
            sets: sets,
            targetMin: minReps,
            targetMax: maxReps,
          );
        }
      }
    }

    return null;
  }

  WorkoutPlan? _parseWorkoutPlanFromAiText(
    String text, {
    required WorkoutPlan? currentPlan,
    required String planName,
    required String goal,
    required int daysCount,
  }) {
    final lines = text.split('\n');
    final parsedDays = <WorkoutDay>[];
    int currentDayNum = 0;
    String currentDayTitle = '';
    final currentDayExercises = <WorkoutExercise>[];
    final dayRegex = RegExp(
      r'(?:####\s*|###\s*|\*\*)?D[íi]a\s+(\d+)\s*[:–—\-]\s*([^\n\*]+)(?:\*\*)?',
      caseSensitive: false,
    );

    void finishCurrentDay() {
      if (currentDayNum > 0 && currentDayExercises.isNotEmpty) {
        parsedDays.add(
          WorkoutDay(
            dayNumber: currentDayNum,
            title: currentDayTitle.isNotEmpty ? currentDayTitle : 'Día $currentDayNum',
            focus: goal,
            exercises: List.of(currentDayExercises),
          ),
        );
        currentDayExercises.clear();
      }
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      final dayMatch = dayRegex.firstMatch(line);
      if (dayMatch != null) {
        finishCurrentDay();
        currentDayNum = int.tryParse(dayMatch.group(1) ?? '') ?? (parsedDays.length + 1);
        currentDayTitle = (dayMatch.group(2) ?? '').replaceAll('*', '').trim();
        continue;
      }

      if (currentDayNum > 0 && (line.startsWith('-') || line.startsWith('*') || line.startsWith('•'))) {
        final cleaned = line.replaceFirst(RegExp(r'^[-*•]\s*'), '').trim();
        final parts = cleaned.split(RegExp(r'[:–—-]'));
        final rawName = parts[0].replaceAll('*', '').trim();

        int sets = 3;
        int minReps = 10;
        int maxReps = 12;

        final setsMatch = RegExp(r'(\d+)\s*series', caseSensitive: false).firstMatch(cleaned);
        if (setsMatch != null) sets = int.tryParse(setsMatch.group(1) ?? '') ?? 3;

        final repsMatch = RegExp(
          r'(\d+)(?:\s*[-–a]\s*(\d+))?\s*(?:reps|repeticiones)',
          caseSensitive: false,
        ).firstMatch(cleaned);
        if (repsMatch != null) {
          minReps = int.tryParse(repsMatch.group(1) ?? '') ?? 10;
          maxReps = int.tryParse(repsMatch.group(2) ?? '') ?? minReps;
        } else if (cleaned.toLowerCase().contains('fallo')) {
          minReps = 8;
          maxReps = 12;
        }

        var exercise = _matchExercise(rawName, sets, minReps, maxReps);
        if (exercise == null) {
          final fallbackMuscle = goal.toLowerCase();
          exercise = ExerciseCatalog.exercises.firstWhere(
            (e) => !currentDayExercises.any((ce) => ce.stableId == e.stableId) &&
                (fallbackMuscle.contains('pecho')
                    ? (e.primaryMuscles.contains('Pecho') || e.muscleGroup.toLowerCase().contains('pecho'))
                    : true),
            orElse: () => ExerciseCatalog.exercises.first,
          ).copyWith(sets: sets, targetMin: minReps, targetMax: maxReps);
        }

        if (!currentDayExercises.any((e) => e.stableId == exercise!.stableId)) {
          currentDayExercises.add(exercise);
        }
      }
    }
    finishCurrentDay();

    if (parsedDays.isEmpty) return null;

    return WorkoutPlan(
      id: currentPlan?.id,
      version: (currentPlan?.version ?? 0) + 1,
      name: planName,
      goal: goal,
      plannedMinutes: 60,
      days: parsedDays,
      changeReason: 'Rutina adaptada con los ejercicios exactos solicitados',
      createdAt: DateTime.now(),
      block: 1,
      week: 1,
      source: 'ai',
      isDemo: false,
    );
  }

  WorkoutPlan _generateTargetedPlan(
    TrainingProfile profile, {
    required WorkoutPlan? currentPlan,
    required List<String> focusMuscles,
    required int daysCount,
    required String planName,
    required String focusStr,
  }) {
    final effectiveDays = (daysCount >= 1 && daysCount <= 7)
        ? daysCount
        : profile.daysPerWeek;

    final effectiveProfile = profile.copyWith(
      daysPerWeek: effectiveDays,
      priorityMuscles: focusMuscles.isNotEmpty
          ? focusMuscles
          : profile.priorityMuscles,
    );

    final targetedPool = ExerciseCatalog.exercises
        .where((e) => allowedExercise(e, effectiveProfile))
        .where((e) {
          if (focusMuscles.isEmpty) return true;
          return focusMuscles.any((m) {
            final normM = normalized(m);
            return normalized(e.muscleGroup).contains(normM) ||
                e.primaryMuscles.any((p) => normalized(p).contains(normM));
          });
        })
        .toList();

    final generalPool = ExerciseCatalog.exercises
        .where((e) => allowedExercise(e, effectiveProfile))
        .toList();

    final pool = targetedPool.isNotEmpty ? targetedPool : generalPool;

    final days = <WorkoutDay>[];
    for (var day = 0; day < effectiveDays; day++) {
      final selected = <WorkoutExercise>[];
      final dayPool = List<WorkoutExercise>.of(pool);

      for (var i = 0; i < dayPool.length && selected.length < 4; i++) {
        final exercise = dayPool[(i + day * 2) % dayPool.length];
        if (!selected.any((e) => e.stableId == exercise.stableId)) {
          selected.add(
            exercise.copyWith(
              sets: 3,
              targetMin: 8,
              targetMax: 12,
              targetRir: 2,
              restSeconds: 75,
            ),
          );
        }
      }

      if (selected.length < 3) {
        for (final ex in generalPool) {
          if (selected.length >= 3) break;
          if (!selected.any((e) => e.stableId == ex.stableId)) {
            selected.add(
              ex.copyWith(
                sets: 3,
                targetMin: 10,
                targetMax: 12,
                restSeconds: 60,
              ),
            );
          }
        }
      }

      final dayLetter = String.fromCharCode(65 + day);
      final dayTitle = focusMuscles.isNotEmpty
          ? '${focusMuscles.join(' + ')} $dayLetter'
          : 'Día ${day + 1}';

      days.add(
        WorkoutDay(
          dayNumber: day + 1,
          title: dayTitle,
          focus: focusStr,
          exercises: selected,
        ),
      );
    }

    return WorkoutPlan(
      id: currentPlan?.id,
      version: (currentPlan?.version ?? 0) + 1,
      name: planName,
      goal: focusStr,
      plannedMinutes: 60,
      days: days,
      changeReason: 'Rutina adaptada con mayor énfasis en $focusStr según tu solicitud',
      createdAt: DateTime.now(),
      block: 1,
      week: 1,
      source: 'ai',
      isDemo: false,
    );
  }

  Future<void> _applyRoutineFromMessage(_ChatMessage message) async {
    if (working) return;
    setState(() => working = true);
    try {
      final training = await profileStore.load();
      final appUser = await appProfileStore.load();
      final userContext = UserProfileContext(
        trainingProfile: training,
        appProfile: appUser,
      );
      final activeWorkout = await planStore.load();
      final focus = _extractRequestedFocus(message.text);
      final days = _extractRequestedDays(message.text);

      final proposal = _createFocusProposal(
        userContext: userContext,
        currentPlan: activeWorkout,
        focusMuscles: focus,
        requestedDays: days,
        customReply: message.text,
      );

      final profile = await profileStore.load();
      final saved = await WorkoutProposalValidator(ExerciseCatalog.exercises)
          .apply(
            proposal.action,
            confirmed: true,
            store: planStore,
            profile: profile,
          );

      if (!mounted) return;
      setState(() {
        message.status = 'applied';
      });
      addMessage(
        '¡Rutina guardada y verificada como versión ${saved.version}! Ya puedes comenzar a entrenar en tu sección Entrenar.',
      );
      await persist();
    } catch (_) {
      if (mounted) {
        addMessage(
          'No se pudo aplicar la rutina directamente. Pulsa "Crear mi rutina" abajo para generarla con tu evaluación.',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> restore() async {
    setState(() => working = true);
    try {
      final saved = await planStore.restorePrevious();
      if (mounted) {
        addMessage(
          'Versión anterior restaurada y verificada como versión ${saved.version}.',
        );
      }
      await persist();
    } catch (_) {
      if (mounted) {
        addMessage(
          'No se pudo restaurar. Puede que no exista una versión anterior o que el guardado haya fallado.',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget proposalCard(_ChatMessage message) {
    final action = message.response!.action;
    final plan = action.plan!;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message.text),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: message.status == 'applied'
                  ? Colors.green.shade600
                  : colors.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    message.status == 'applied'
                        ? Icons.check_circle
                        : Icons.auto_awesome,
                    color: message.status == 'applied'
                        ? Colors.green
                        : colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Propuesta: versión ${action.expectedVersion} → ${plan.version}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${plan.days.length} días de entrenamiento · hasta ${plan.plannedMinutes} min por sesión',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              if (plan.changeReason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  plan.changeReason,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              const Divider(height: 20),
              ...plan.days.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Día ${d.dayNumber}: ${d.title} (${d.focus})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d.exercises
                            .map((e) =>
                                '${e.name} (${e.sets}×${e.minReps}–${e.maxReps})')
                            .join(' · '),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (message.status == 'pending')
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed:
                          working ? null : () => changeProposal(message, true),
                      child: const Text('Aplicar'),
                    ),
                    TextButton(
                      onPressed:
                          working ? null : () => changeProposal(message, false),
                      child: const Text('Cancelar'),
                    ),
                  ],
                )
              else if (message.status == 'applied')
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Rutina aplicada en Entrenar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.fitness_center, size: 16),
                      onPressed: widget.onOpenTraining,
                      label: const Text('Ir a Entrenar'),
                    ),
                  ],
                )
              else
                Text(
                  message.status == 'invalid'
                      ? 'Propuesta inválida; no se puede aplicar.'
                      : 'Propuesta cancelada',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.error,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void addMessage(String text, {bool fromUser = false}) {
    setState(() => messages.add(_ChatMessage(text, fromUser: fromUser)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> reviewProfile() async {
    final saved = await profileStore.load();
    if (!mounted) return;
    final result = await Navigator.push<TrainingProfile>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TrainingAssessmentPage(initialProfile: saved, store: profileStore),
      ),
    );
    if (result != null && mounted) {
      addMessage(
        'Evaluacion actualizada. Cuando quieras, puedo generar una nueva rutina con esos datos.',
      );
    }
  }

  bool _isAskingAboutProfileData(String text) {
    final norm = text.toLowerCase().trim();
    const triggers = [
      'mis datos',
      'mi perfil',
      'mi edad',
      'mi peso',
      'mi estatura',
      'mi altura',
      'mi objetivo',
      'mis objetivos',
      'mi condicion',
      'mi condición',
      'mis limitaciones',
      'cuanto peso',
      'cuánto peso',
      'que edad tengo',
      'qué edad tengo',
      'que datos tienes de mi',
      'qué datos tienes de mí',
      'ver mis datos',
      'mostrar mis datos',
      'ver mi perfil',
    ];
    return triggers.any((t) => norm.contains(t));
  }

  String _formatProfileDataResponse(
    UserProfileContext ctx,
    WorkoutPlan? activePlan,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Aquí tienes los datos registrados en tu perfil y evaluación:\n',
    );
    if (ctx.fullName != null && ctx.fullName!.isNotEmpty) {
      buffer.writeln('• **Nombre:** ${ctx.fullName}');
    }
    if (ctx.age != null) {
      buffer.writeln('• **Edad:** ${ctx.age} años');
    }
    if (ctx.weightKg != null) {
      buffer.writeln('• **Peso:** ${ctx.weightKg!.toStringAsFixed(1)} kg');
    }
    if (ctx.heightCm != null) {
      buffer.writeln('• **Estatura:** ${ctx.heightCm!.toStringAsFixed(0)} cm');
    }
    buffer.writeln('• **Género:** ${ctx.gender}');
    buffer.writeln('• **Objetivo:** ${ctx.goal}');
    buffer.writeln('• **Nivel de experiencia:** ${ctx.experience}');
    buffer.writeln('• **Días por semana:** ${ctx.daysPerWeek} días');
    buffer.writeln('• **Tiempo por sesión:** ${ctx.minutesPerSession} min');
    buffer.writeln('• **Equipo:** ${ctx.equipment}');
    buffer.writeln('• **Condición o limitaciones:** ${ctx.limitations}');
    if (ctx.priorityMuscles.isNotEmpty) {
      buffer.writeln(
        '• **Músculos prioritarios:** ${ctx.priorityMuscles.join(', ')}',
      );
    }
    if (activePlan != null) {
      buffer.writeln(
        '• **Rutina activa:** ${activePlan.name} (${activePlan.days.length} días · ${activePlan.goal})',
      );
    } else {
      buffer.writeln('• **Rutina activa:** Aún no has creado una rutina.');
    }
    buffer.writeln(
      '\nPuedes pedirme en cualquier momento que modifique o reoriente tu rutina, o editar tus datos desde la pestaña Perfil.',
    );
    return buffer.toString();
  }

  bool _isRoutineChangeRequest(String text) {
    final norm = text.toLowerCase().trim();
    if (norm.isEmpty) return false;

    const directPhrases = [
      'cambiar mi rutina',
      'modificar mi rutina',
      'cambiar rutina',
      'modificar rutina',
      'la modifique tu',
      'la modifiques tu',
      'la modifiques tú',
      'modifique tu mi rutina',
      'modifiques mi rutina',
      'dejes en entrenar',
      'dejar en entrenar',
      'dejarla en entrenar',
      'dejala en entrenar',
      'ponla en entrenar',
      'ponmela en entrenar',
      'guardar en entrenar',
      'guardala en entrenar',
      'en entrenar',
      'no aparece el boton',
      'no aparece el botón',
      'no veo el boton',
      'no veo el botón',
      'boton aplicar',
      'botón aplicar',
      'aplicar rutina',
      'aplicar esta rutina',
      'aplicar la rutina',
      'no tengo tiempo para anotarla',
      'no tngoo tiempo',
      'no tengo tiempo',
      'para anotarla',
      'anotarla',
      'crear mi rutina',
      'crear rutina',
      'generar rutina',
      'hacer mi rutina',
      'armar mi rutina',
      'armar rutina',
      'reorganizar mi rutina',
      'reorganizar la rutina',
      'adaptar mi rutina',
      'rutina enfocada',
      'enfocada a',
      'enfocada en',
      'enfocado a',
      'enfocado en',
      'mas enfocado',
      'más enfocado',
      'mas enfocada',
      'más enfocada',
      'enfasis en',
      'énfasis en',
      'poner mas pecho',
      'poner más pecho',
      'poner mas piernas',
      'poner más piernas',
      'poner mas brazos',
      'poner más brazos',
      'poner mas espalda',
      'poner más espalda',
    ];

    if (directPhrases.any((p) => norm.contains(p))) return true;

    final hasRoutineWord = norm.contains('rutina') ||
        norm.contains('entrenamiento') ||
        norm.contains('ejercicios');
    final hasActionWord = norm.contains('modific') ||
        norm.contains('cambi') ||
        norm.contains('actualiz') ||
        norm.contains('ajust') ||
        norm.contains('cre') ||
        norm.contains('arm') ||
        norm.contains('dej') ||
        norm.contains('pon') ||
        norm.contains('aplic') ||
        norm.contains('guard');

    return hasRoutineWord && hasActionWord;
  }

  bool _hasRoutineProposalContent(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return false;

    // Descartar saludos, confirmaciones y resúmenes de perfil
    if (lower.startsWith('¡hola') ||
        lower.startsWith('hola') ||
        lower.contains('¡hola de nuevo') ||
        lower.contains('hola de nuevo') ||
        lower.startsWith('¡rutina guardada') ||
        lower.startsWith('rutina guardada') ||
        lower.startsWith('versión anterior') ||
        lower.startsWith('evaluacion actualizada') ||
        lower.contains('datos registrados en tu perfil') ||
        lower.contains('no pude conectar') ||
        lower.contains('no se pudo crear')) {
      return false;
    }

    final hasDay1 = lower.contains('día 1') || lower.contains('dia 1');
    final hasSetsOrReps = lower.contains('series') ||
        lower.contains('repeticiones') ||
        lower.contains('reps') ||
        RegExp(r'\d+\s*[x×]\s*\d+').hasMatch(lower);

    // Debe tener al menos Día 1 y especificaciones de series/reps
    if (!hasDay1 || !hasSetsOrReps) {
      return false;
    }

    final hasDay2 = lower.contains('día 2') || lower.contains('dia 2');
    final hasMultipleExerciseBullets =
        RegExp(r'[-*•]\s+[a-zA-ZáéíóúÁÉÍÓÚ]').allMatches(text).length >= 2;

    return hasDay2 || hasMultipleExerciseBullets;
  }

  List<String> _extractMusclesFromText(String text) {
    final norm = text.toLowerCase();
    final result = <String>[];
    if (norm.contains('pecho') || norm.contains('pectoral')) result.add('Pecho');
    if (norm.contains('pierna') ||
        norm.contains('cuadriceps') ||
        norm.contains('cuádriceps') ||
        norm.contains('isquio') ||
        norm.contains('femoral') ||
        norm.contains('pantorrilla') ||
        norm.contains('gemelo')) {
      result.add('Piernas');
    }
    if (norm.contains('espalda') || norm.contains('dorsal')) result.add('Espalda');
    if (norm.contains('hombro') || norm.contains('deltoide')) result.add('Hombros');
    if (norm.contains('brazo') ||
        norm.contains('biceps') ||
        norm.contains('bíceps') ||
        norm.contains('triceps') ||
        norm.contains('tríceps')) {
      result.add('Brazos');
    }
    if (norm.contains('gluteo') || norm.contains('glúteo')) result.add('Glúteos');
    if (norm.contains('abdomen') || norm.contains('core')) result.add('Core');
    return result;
  }

  List<String> _extractRequestedFocus(String text, [List<String>? extraTexts]) {
    // 1. Extraer del texto principal (ej. el mensaje actual del usuario)
    final fromMain = _extractMusclesFromText(text);
    if (fromMain.isNotEmpty) {
      return fromMain;
    }
    // 2. Solo si el texto principal no menciona músculos, buscar en los mensajes previos más recientes
    if (extraTexts != null && extraTexts.isNotEmpty) {
      for (final t in extraTexts.reversed) {
        final fromPrev = _extractMusclesFromText(t);
        if (fromPrev.isNotEmpty) {
          return fromPrev;
        }
      }
    }
    return [];
  }

  AiChatResponse _createFocusProposal({
    required UserProfileContext userContext,
    required WorkoutPlan? currentPlan,
    required List<String> focusMuscles,
    int? requestedDays,
    String? customReply,
  }) {
    final baseProfile = userContext.trainingProfile ??
        TrainingProfile(
          weightKg: userContext.weightKg ?? 70,
          heightCm: userContext.heightCm ?? 170,
          age: userContext.age ?? 25,
          goal: userContext.goal,
          experience: userContext.experience,
          daysPerWeek: userContext.daysPerWeek,
          minutesPerSession: userContext.minutesPerSession,
          preferences: '',
          limitations: userContext.limitations,
          equipment: userContext.equipment,
        );

    final effectiveDays = (requestedDays != null && requestedDays >= 1 && requestedDays <= 7)
        ? requestedDays
        : baseProfile.daysPerWeek;

    final effectiveProfile = baseProfile.copyWith(
      daysPerWeek: effectiveDays,
      priorityMuscles: focusMuscles.isNotEmpty
          ? focusMuscles
          : (baseProfile.priorityMuscles.isNotEmpty
              ? baseProfile.priorityMuscles
              : const ['Pecho', 'Piernas']),
    );

    final focusStr = focusMuscles.isNotEmpty
        ? focusMuscles.join(' y ')
        : effectiveProfile.goal;

    final planName = focusMuscles.isNotEmpty
        ? 'Rutina con énfasis en $focusStr'
        : (currentPlan?.name ?? 'Rutina adaptada');

    WorkoutPlan? newPlan;

    // 1. Prioridad: Si la IA redactó un desglose de rutina en texto, parseamos sus días y ejercicios exactos
    if (customReply != null && _hasRoutineProposalContent(customReply)) {
      newPlan = _parseWorkoutPlanFromAiText(
        customReply,
        currentPlan: currentPlan,
        planName: planName,
        goal: focusStr,
        daysCount: effectiveDays,
      );
    }

    // 2. Si no se pudo parsear de la IA, generamos un plan enfocado directamente en los músculos solicitados
    newPlan ??= _generateTargetedPlan(
      effectiveProfile,
      currentPlan: currentPlan,
      focusMuscles: focusMuscles,
      daysCount: effectiveDays,
      planName: planName,
      focusStr: focusStr,
    );

    final isNew = currentPlan == null;
    final replyText = customReply ??
        '¡Listo! He configurado tu rutina con énfasis en $focusStr ($effectiveDays días, ${effectiveProfile.minutesPerSession} min/sesión). Revisa el desglose a continuación y presiona el botón "Aplicar rutina a mi plan" para dejarla guardada y lista en tu sección de Entrenar.';

    return AiChatResponse(
      reply: replyText,
      action: AiWorkoutAction(
        type: isNew ? AiActionType.proposeWorkout : AiActionType.modifyWorkout,
        plan: newPlan,
        expectedVersion: currentPlan?.version ?? 0,
        expectedPlanId: currentPlan?.id,
      ),
    );
  }

  Future<void> sendMessage([String? suggested]) async {
    final text = (suggested ?? controller.text).trim();
    if (text.isEmpty || working || loading) return;
    controller.clear();
    addMessage(text, fromUser: true);
    setState(() => working = true);
    try {
      await persist();

      final training = await profileStore.load();
      final appUser = await appProfileStore.load();
      final userContext = UserProfileContext(
        trainingProfile: training,
        appProfile: appUser,
      );
      final activeWorkout = await planStore.load();

      // 1. Consulta directa sobre datos de perfil o evaluación
      if (_isAskingAboutProfileData(text)) {
        final profileResponse = _formatProfileDataResponse(
          userContext,
          activeWorkout,
        );
        addMessage(profileResponse);
        await persist();
        return;
      }

      final isChangeRequest = _isRoutineChangeRequest(text);
      final focusMuscles = _extractRequestedFocus(
        text,
        messages.map((m) => m.text).toList(),
      );

      final history = messages
          .take(messages.length - 1)
          .skip(messages.length > 7 ? messages.length - 7 : 0)
          .map(
            (message) => {
              'role': message.fromUser ? 'user' : 'assistant',
              'content': message.text,
            },
          )
          .toList();

      AiChatResponse? reply;
      try {
        reply = await aiChatService.reply(
          message: text,
          history: history,
          trainingProfile: userContext.toMergedMap(),
          activeWorkout: activeWorkout?.toJson(),
        );
      } catch (_) {
        // En caso de error de red o saldo, si pidió cambiar la rutina, generamos propuesta local
        if (isChangeRequest) {
          final requestedDays = _extractRequestedDays(text);
          reply = _createFocusProposal(
            userContext: userContext,
            currentPlan: activeWorkout,
            focusMuscles: focusMuscles,
            requestedDays: requestedDays,
          );
        } else {
          rethrow;
        }
      }

      // Convertimos en propuesta interactiva cuando la IA entregó una rutina estructurada
      // o cuando el usuario solicitó explícitamente cambiar su rutina a músculos específicos.
      final shouldAttachProposal = _hasRoutineProposalContent(reply.reply) ||
          (isChangeRequest && focusMuscles.isNotEmpty);

      if (shouldAttachProposal && !reply.action.isProposal) {
        final focusMusclesInReply = _extractRequestedFocus(text, [reply.reply]);
        final targetMuscles = focusMusclesInReply.isNotEmpty ? focusMusclesInReply : focusMuscles;
        final requestedDays = _extractRequestedDays(text) ?? _extractRequestedDays(reply.reply);
        reply = _createFocusProposal(
          userContext: userContext,
          currentPlan: activeWorkout,
          focusMuscles: targetMuscles,
          requestedDays: requestedDays,
          customReply: reply.reply,
        );
      }

      if (mounted) {
        final issues = reply.action.isProposal
            ? WorkoutProposalValidator(
                ExerciseCatalog.exercises,
              ).validate(reply.action, current: activeWorkout, profile: training)
            : [];
        setState(
          () => messages.add(
            _ChatMessage(
              reply!.reply,
              response: reply,
              status: issues.isEmpty ? 'pending' : 'invalid',
            ),
          ),
        );
        if (issues.isNotEmpty) addMessage(issues.join('\n'));
        await persist();
      }
    } on FunctionException catch (error) {
      if (!mounted) return;
      final details = error.details;
      final message = details is Map && details['error'] is String
          ? details['error'] as String
          : 'No pude conectar con el asistente. Intenta nuevamente.';
      addMessage(message);
      await persist();
    } catch (_) {
      if (mounted) {
        addMessage('No pude conectar con el asistente. Intenta nuevamente.');
        await persist();
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget quickAction(String label, IconData icon, VoidCallback onPressed) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: working || loading ? null : onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (cacheError != null)
          TextButton(
            onPressed: persist,
            child: Text('${cacheError!} Reintentar'),
          ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return Align(
                alignment: message.fromUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 620),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: message.fromUser
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: message.response?.action.isProposal == true
                      ? proposalCard(message)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message.text),
                            if (!message.fromUser &&
                                _looksLikeRoutineOrMentionsApply(message.text)) ...[
                              const SizedBox(height: 12),
                              if (message.status == 'applied')
                                Wrap(
                                  spacing: 12,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                                        SizedBox(width: 4),
                                        Text(
                                          'Rutina aplicada en Entrenar',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    FilledButton.tonalIcon(
                                      icon: const Icon(Icons.fitness_center, size: 16),
                                      onPressed: widget.onOpenTraining,
                                      label: const Text('Ir a Entrenar'),
                                    ),
                                  ],
                                )
                              else
                                FilledButton.icon(
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text('Aplicar esta rutina a mi plan'),
                                  onPressed: working
                                      ? null
                                      : () => _applyRoutineFromMessage(message),
                                ),
                            ],
                          ],
                        ),
                ),
              );
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              quickAction('Crear mi rutina', Icons.auto_awesome, localProposal),
              const SizedBox(width: 8),
              quickAction('Restaurar versión anterior', Icons.restore, restore),
              const SizedBox(width: 8),
              quickAction(
                'Editar evaluacion',
                Icons.edit_outlined,
                reviewProfile,
              ),
              const SizedBox(width: 8),
              quickAction(
                'Ir a Entrenar',
                Icons.fitness_center,
                widget.onOpenTraining,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !working && !loading,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Escribe lo que necesitas...',
                      prefixIcon: Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Enviar',
                  onPressed: working || loading ? null : sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.surfaceContainerHighest,
                    disabledForegroundColor: colors.onSurfaceVariant,
                    minimumSize: const Size.square(56),
                  ),
                  icon: working
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 27),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
