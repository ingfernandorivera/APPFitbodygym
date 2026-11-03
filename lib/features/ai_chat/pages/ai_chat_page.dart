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

    final stripped = norm.replaceFirst(RegExp(r'^\d+[\.\)\s-]+\s*'), '').trim();
    final numMatch = RegExp(r'^(\d+)[\.\)\s]').firstMatch(rawName.trim());
    final exNum = numMatch != null ? int.tryParse(numMatch.group(1)!) : null;

    // 0. Si viene con número de ejercicio oficial (1 a 96):
    if (exNum != null && exNum >= 1 && exNum <= 96) {
      final prefix = 'ex_${exNum.toString().padLeft(3, '0')}_';
      for (final e in ExerciseCatalog.exercises) {
        if (e.catalogId?.startsWith(prefix) == true) {
          return e.copyWith(
            sets: sets,
            targetMin: minReps,
            targetMax: maxReps,
          );
        }
      }
    }

    // 1. Coincidencia directa por nombre (o nombre sin prefijo numérico)
    for (final e in ExerciseCatalog.exercises) {
      final eNorm = normalized(e.name);
      if (norm == eNorm ||
          stripped == eNorm ||
          norm.contains(eNorm) ||
          stripped.contains(eNorm) ||
          eNorm.contains(stripped) ||
          eNorm.contains(norm)) {
        return e.copyWith(
          sets: sets,
          targetMin: minReps,
          targetMax: maxReps,
        );
      }
    }

    // 2. Coincidencia por palabras clave avanzadas para el catálogo de 96 ejercicios
    WorkoutExercise? bestMatch;
    for (final e in ExerciseCatalog.exercises) {
      // Pecho (1-14, 96)
      if (norm.contains('belt squat') || norm.contains('sentadilla cinturon') || norm.contains('sentadilla con cinturon')) {
        if (norm.contains('sumo') && e.id == 'belt_squat_sumo') { bestMatch = e; break; }
        if (norm.contains('talon') && e.id == 'belt_squat_calf_raise') { bestMatch = e; break; }
        if (e.id == 'belt_squat') { bestMatch = e; break; }
      }
      // Pecho (1-14, 96) — SOLO si el contexto del día no es de piernas
      if (!_isDayLegs(_dayContext)) {
        if (norm.contains('plano') && (norm.contains('barra') || norm.contains('banca')) && e.id == 'bench_press_barbell') {
          bestMatch = e; break;
        }
        if (norm.contains('inclinado') && norm.contains('cerrado') && e.id == 'close_grip_incline_bench_press') {
          bestMatch = e; break;
        }
        if (norm.contains('inclinado') && norm.contains('mancuerna') && e.id == 'incline_dumbbell_press') {
          bestMatch = e; break;
        }
        if (norm.contains('inclinado') && norm.contains('barra') && e.id == 'incline_barbell_press') {
          bestMatch = e; break;
        }
        if (norm.contains('inclinado') && (norm.contains('maquina') || norm.contains('discos') || norm.contains('pecho')) && e.id == 'incline_chest_machine') {
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
        if (norm.contains('cruce') && norm.contains('polea')) {
          if (norm.contains('alto a bajo') && e.id == 'cable_crossover_high_to_low') { bestMatch = e; break; }
          if (norm.contains('bajo a alto') && e.id == 'cable_crossover_low_to_high') { bestMatch = e; break; }
          if (e.id == 'cable_crossover_mid') { bestMatch = e; break; }
        }
        if (norm.contains('pie') && norm.contains('polea') && (norm.contains('pecho') || norm.contains('press')) && e.id == 'standing_cable_chest_press') {
          bestMatch = e; break;
        }
        if ((norm.contains('fondo') || norm.contains('dip')) && (norm.contains('asistid') || norm.contains('paralela')) && (e.id == 'assisted_dip' || e.id == 'parallel_dips')) {
          bestMatch = e; break;
        }
        if (norm.contains('cerrado') && e.id == 'close_grip_bench_press') {
          bestMatch = e; break;
        }
        if (norm.contains('declinado') && e.id == 'decline_dumbbell_press') {
          bestMatch = e; break;
        }
        if ((norm.contains('press') || norm.contains('empuje')) && (norm.contains('maquina') || norm.contains('guiada')) && e.id == 'incline_chest_machine') {
          bestMatch = e; break;
        }
        if (norm.contains('press de banca') && e.id == 'bench_press_barbell') {
          bestMatch = e; break;
        }
        if (norm.contains('press de pecho') && e.id == 'standing_cable_chest_press') {
          bestMatch = e; break;
        }
      }



      // Espalda y deltoides posteriores (15-28, 95)
      if (norm.contains('descenso escapular') && e.id == 'assisted_scapular_depression') {
        bestMatch = e; break;
      }
      if (norm.contains('dominada') || norm.contains('pull up') || norm.contains('pull-up')) {
        if (norm.contains('supin') && e.id == 'assisted_pull_up_underhand') { bestMatch = e; break; }
        if (norm.contains('neutr') && e.id == 'assisted_pull_up_neutral') { bestMatch = e; break; }
        if (norm.contains('asistid') || norm.contains('pronad')) {
          bestMatch = e.id == 'assisted_pull_up_overhand' ? e : (e.id == 'pull_ups' ? e : bestMatch);
          if (bestMatch != null) break;
        }
        if (e.id == 'pull_ups') { bestMatch = e; break; }
      }
      if (norm.contains('remo') && norm.contains('invertido') && e.id == 'inverted_row_smith') {
        bestMatch = e; break;
      }
      if (norm.contains('inclinado') && (norm.contains('remo') || norm.contains('mancuerna')) && e.id == 'incline_bench_dumbbell_row') {
        bestMatch = e; break;
      }
      if ((norm.contains('barra t') || norm.contains('remo en t') || norm.contains('remo t')) && e.id == 't_bar_row') {
        bestMatch = e; break;
      }
      if (norm.contains('unilateral') && norm.contains('polea') && e.id == 'cable_row_unilateral') {
        bestMatch = e; break;
      }
      if (norm.contains('polea baja') && (e.id == 'low_pulley_row' || e.id == 'seated_row')) {
        bestMatch = e; break;
      }
      if ((norm.contains('pullover') || norm.contains('pull-over') || norm.contains('pull over'))) {
        if (norm.contains('polea') && e.id == 'cable_straight_arm_pullover') { bestMatch = e; break; }
        if (e.id == 'dumbbell_pullover') { bestMatch = e; break; }
      }
      if (norm.contains('apertura inversa')) {
        if (norm.contains('crossover') && e.id == 'reverse_cable_crossover') { bestMatch = e; break; }
        if (e.id == 'reverse_pec_deck') { bestMatch = e; break; }
      }
      if (norm.contains('jalon') || norm.contains('jalón')) {
        if (norm.contains('neutr') && e.id == 'lat_pulldown_close_neutral') { bestMatch = e; break; }
        if (norm.contains('supin') && e.id == 'lat_pulldown_underhand') { bestMatch = e; break; }
        if (e.id == 'lat_pulldown') { bestMatch = e; break; }
      }
      if (norm.contains('remo') && norm.contains('barra') && e.id == 'barbell_row') {
        bestMatch = e; break;
      }
      if (norm.contains('remo') && (norm.contains('maquina') || norm.contains('sentado')) && e.id == 'seated_row') {
        bestMatch = e; break;
      }
      if (norm.contains('remo') && norm.contains('mancuerna') && e.id == 'dumbbell_row') {
        bestMatch = e; break;
      }

      // Piernas (49-72, 87, 88, 90, 93) — alias completos
      if (norm.contains('prensa') || norm.contains('leg press')) {
        if (norm.contains('alta') && e.id == 'leg_press_high_feet') { bestMatch = e; break; }
        if (norm.contains('amplia') && e.id == 'leg_press_wide_stance') { bestMatch = e; break; }
        if (norm.contains('baja') && e.id == 'leg_press_low_feet') { bestMatch = e; break; }
        if (norm.contains('talon') && e.id == 'calf_raise') { bestMatch = e; break; }
        if (e.id == 'leg_press') { bestMatch = e; break; }
      }
      // Sentadilla goblet (IA dice "Sentadilla goblet" o "Sentadilla en máquina")
      if (norm.contains('goblet') && e.id == 'goblet_squat') {
        bestMatch = e; break;
      }
      if (norm.contains('sentadilla') && norm.contains('goblet') && e.id == 'goblet_squat') {
        bestMatch = e; break;
      }
      // Curl de piernas (IA dice "Curl de piernas en máquina", "Leg curl", "Curl femoral")
      if (norm.contains('curl') && (norm.contains('pierna') || norm.contains('leg') || norm.contains('femoral') || norm.contains('isquio')) && e.id == 'leg_curl') {
        bestMatch = e; break;
      }
      if (norm.contains('hip thrust') && e.id == 'hip_thrust_smith') {
        bestMatch = e; break;
      }
      if (norm.contains('puente') && norm.contains('smith') && e.id == 'glute_bridge_smith') {
        bestMatch = e; break;
      }
      if (norm.contains('puente') && (norm.contains('gluteo') || norm.contains('cadera')) && e.id == 'glute_bridge_smith') {
        bestMatch = e; break;
      }
      if (norm.contains('patada') && (norm.contains('gluteo') || norm.contains('polea')) && e.id == 'cable_glute_kickback') {
        bestMatch = e; break;
      }
      if (norm.contains('extension') && norm.contains('gluteo') && e.id == 'glute_extension_machine') {
        bestMatch = e; break;
      }
      if (norm.contains('abduccion') || norm.contains('abducción')) {
        if (norm.contains('polea') && e.id == 'cable_hip_abduction') { bestMatch = e; break; }
        if (e.id == 'seated_hip_abduction_machine') { bestMatch = e; break; }
      }
      if (norm.contains('aduccion') || norm.contains('aducción') && e.id == 'cable_hip_adduction') {
        bestMatch = e; break;
      }
      if (norm.contains('extension') && (norm.contains('cuadriceps') || norm.contains('cuadricep') || norm.contains('pierna'))) {
        if (norm.contains('unilateral') && e.id == 'leg_extension_unilateral') { bestMatch = e; break; }
        if (e.id == 'leg_extension_bilateral') { bestMatch = e; break; }
      }
      if (norm.contains('bulgara') && e.id == 'bulgarian_split_squat_smith') {
        bestMatch = e; break;
      }
      if (norm.contains('split squat') && e.id == 'barbell_split_squat') {
        bestMatch = e; break;
      }
      // Zancadas: estáticas, laterales, con mancuerna, o simplemente "zancadas"
      if (norm.contains('zancada') && e.id == 'dumbbell_lunge') {
        bestMatch = e; break;
      }
      if (norm.contains('pantorrilla') || norm.contains('gemelo') || norm.contains('talon') || norm.contains('talones')) {
        if (norm.contains('smith') && e.id == 'standing_calf_raise_smith') { bestMatch = e; break; }
        if (e.id == 'calf_raise') { bestMatch = e; break; }
      }
      // Elevación de talones (sin contexto de prensa)
      if ((norm.contains('elevacion') || norm.contains('elevación')) && (norm.contains('talon') || norm.contains('pantorrilla'))) {
        if (norm.contains('smith') && e.id == 'standing_calf_raise_smith') { bestMatch = e; break; }
        if (norm.contains('prensa') && e.id == 'calf_raise') { bestMatch = e; break; }
        if (e.id == 'calf_raise') { bestMatch = e; break; }
      }
      if (norm.contains('femoral') || norm.contains('isquio')) {
        if (e.id == 'leg_curl') { bestMatch = e; break; }
      }
      if (norm.contains('peso muerto') || norm.contains('deadlift')) {
        if (norm.contains('rumano') && (norm.contains('mancuerna') || norm.contains('manc')) && e.id == 'dumbbell_rdl') { bestMatch = e; break; }
        if (norm.contains('rumano') && e.id == 'romanian_deadlift_barbell') { bestMatch = e; break; }
        if (norm.contains('sumo') && e.id == 'deadlift_sumo') { bestMatch = e; break; }
        if (e.id == 'deadlift_conventional') { bestMatch = e; break; }
      }


      // Brazos y Hombros (29-48, 89)
      if (norm.contains('predicador')) {
        if (norm.contains('unilateral') && e.id == 'preacher_curl_unilateral_machine') { bestMatch = e; break; }
        if (e.id == 'preacher_curl_machine') { bestMatch = e; break; }
      }
      if (norm.contains('martillo')) {
        if (norm.contains('polea') && e.id == 'cable_hammer_curl') { bestMatch = e; break; }
        if (e.id == 'hammer_curl_dumbbell') { bestMatch = e; break; }
      }
      if (norm.contains('curl') && norm.contains('polea') && e.id == 'low_pulley_bicep_curl') {
        bestMatch = e; break;
      }
      if (norm.contains('curl') && norm.contains('mancuerna') && e.id == 'dumbbell_curl') {
        bestMatch = e; break;
      }
      if (norm.contains('curl') && norm.contains('barra') && (e.id == 'bicep_curl_short_bar' || e.id == 'bicep_curl_barbell')) {
        bestMatch = e; break;
      }
      if (norm.contains('triceps') || norm.contains('tríceps')) {
        if (norm.contains('cuerda') && norm.contains('cabeza') && e.id == 'overhead_cable_tricep_extension') { bestMatch = e; break; }
        if (norm.contains('cuerda') && e.id == 'rope_tricep_pushdown') { bestMatch = e; break; }
        if (norm.contains('barra') && e.id == 'bar_tricep_pushdown') { bestMatch = e; break; }
        if (norm.contains('unilateral') && e.id == 'unilateral_tricep_extension_machine') { bestMatch = e; break; }
        if (norm.contains('maquina') && e.id == 'tricep_extension_machine') { bestMatch = e; break; }
      }
      if (norm.contains('militar')) {
        if (norm.contains('smith') && e.id == 'military_press_smith') { bestMatch = e; break; }
        if (e.id == 'military_press') { bestMatch = e; break; }
      }
      if (norm.contains('hombro') && norm.contains('mancuerna') && (norm.contains('press') || norm.contains('sentado')) && e.id == 'dumbbell_shoulder_press') {
        bestMatch = e; break;
      }
      // "lateral" solo si tiene contexto de hombro/deltoides (no si es "zancada lateral", etc.)
      if (norm.contains('lateral') && (norm.contains('elevacion') || norm.contains('elevación') || norm.contains('hombro') || norm.contains('deltoid'))) {
        if (norm.contains('polea') && e.id == 'cable_lateral_raise') { bestMatch = e; break; }
        if (e.id == 'lateral_raise') { bestMatch = e; break; }
      }
      if (norm.contains('frontal') && e.id == 'cable_front_raise') {
        bestMatch = e; break;
      }
      if (norm.contains('encogimiento') || norm.contains('trapecio') || norm.contains('shrug')) {
        if (norm.contains('polea') && e.id == 'cable_shrugs') { bestMatch = e; break; }
        if (e.id == 'dumbbell_shrugs') { bestMatch = e; break; }
      }
      if (norm.contains('face pull') && e.id == 'face_pull') {
        bestMatch = e; break;
      }

      // Abdomen y Core (75-80, 94)
      if (norm.contains('crunch')) {
        if (norm.contains('polea') && e.id == 'kneeling_cable_crunch') { bestMatch = e; break; }
        if (e.id == 'machine_crunch') { bestMatch = e; break; }
      }
      if (norm.contains('pallof') && e.id == 'pallof_press') {
        bestMatch = e; break;
      }
      if (norm.contains('woodchop') && e.id == 'cable_woodchop') {
        bestMatch = e; break;
      }
      if (norm.contains('hiperextension') || norm.contains('hiperextensión')) {
        if (norm.contains('isometric') && e.id == 'hyperextension_isometric_hold') { bestMatch = e; break; }
        if (norm.contains('cadera') && e.id == 'hyperextension_hip_extension') { bestMatch = e; break; }
        if (e.id == 'hyperextension_45') { bestMatch = e; break; }
      }
      if (norm.contains('plancha') && e.id == 'plank_hold') {
        bestMatch = e; break;
      }
      if (norm.contains('superman') && e.id == 'superman_extension') {
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

    // 3. Fallback filtrado por grupo muscular del día actual.
    // Solo retorna un ejercicio si comparte alguna palabra clave Y es del mismo grupo muscular.
    // Esto evita que ejercicios de pecho/hombros aparezcan en días de piernas, etc.
    if (_dayContext.isNotEmpty) {
      final dayNorm = normalized(_dayContext);
      final muscleKeywords = _extractMuscleKeywords(dayNorm);
      if (muscleKeywords.isNotEmpty) {
        for (final e in ExerciseCatalog.exercises) {
          final eGroup = normalized(e.muscleGroup);
          final ePrimary = e.primaryMuscles.map(normalized).join(' ');
          if (muscleKeywords.any((k) => eGroup.contains(k) || ePrimary.contains(k))) {
            final words = norm.split(' ').where((w) => w.length > 3);
            if (words.any((w) => normalized(e.name).contains(w))) {
              return e.copyWith(sets: sets, targetMin: minReps, targetMax: maxReps);
            }
          }
        }
      }
    }

    // Sin ninguna coincidencia, es mejor retornar null que añadir algo incorrecto.
    return null;
  }

  // Contexto del día actual al parsear ejercicios (se actualiza en _parseWorkoutPlanFromAiText)
  String _dayContext = '';

  /// Retorna true si el contexto del día corresponde a un día de piernas/glúteos/isquiotibiales
  bool _isDayLegs(String ctx) {
    if (ctx.isEmpty) return false;
    final n = normalized(ctx);
    return n.contains('pierna') ||
        n.contains('gluteo') ||
        n.contains('cuadricep') ||
        n.contains('isquio') ||
        n.contains('femoral') ||
        n.contains('pantorrilla') ||
        n.contains('gemelo');
  }

  /// Extrae palabras clave de músculo del título del día para el fallback filtrado
  List<String> _extractMuscleKeywords(String dayNorm) {
    final keywords = <String>[];
    final muscleMap = {
      'pierna': ['cuadricep', 'isquio', 'gluteo', 'gemelo', 'pantorrilla'],
      'cuadricep': ['cuadricep'],
      'isquio': ['isquio', 'femoral'],
      'gluteo': ['gluteo'],
      'espalda': ['espalda', 'dorsal', 'lumbar'],
      'pecho': ['pecho'],
      'hombro': ['hombro', 'deltoid'],
      'brazo': ['bicep', 'tricep', 'brazo'],
      'bicep': ['bicep'],
      'tricep': ['tricep'],
      'abdomen': ['abdomen', 'core', 'abdominal'],
      'core': ['core', 'abdomen'],
    };
    for (final entry in muscleMap.entries) {
      if (dayNorm.contains(entry.key)) {
        keywords.addAll(entry.value);
      }
    }
    return keywords;
  }


  WorkoutPlan? _parseWorkoutPlanFromAiText(
    String text, {
    required WorkoutPlan? currentPlan,
    required String planName,
    required String goal,
    required int daysCount,
    TrainingProfile? profile,
  }) {
    final lines = text.split('\n');
    final parsedDays = <WorkoutDay>[];
    int currentDayNum = 0;
    String currentDayTitle = '';
    String currentDayFocus = '';
    final currentDayExercises = <WorkoutExercise>[];
    final dayRegex = RegExp(
      r'(?:####\s*|###\s*|##\s*|\*\*)?D[íi]a\s+(\d+)(?:\s*\([^)]*\))?\s*[:–—\-]\s*([^\n\*]+)(?:\*\*)?',
      caseSensitive: false,
    );

    String inferDayFocus(String title, List<WorkoutExercise> exercises) {
      final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(title);
      if (parenMatch != null && parenMatch.group(1)!.trim().isNotEmpty) {
        return parenMatch.group(1)!.trim();
      }
      final groups = <String>[];
      for (final ex in exercises) {
        if (!groups.contains(ex.muscleGroup)) {
          groups.add(ex.muscleGroup);
        }
      }
      if (groups.isNotEmpty) {
        return groups.take(3).join(', ');
      }
      return goal;
    }

    void finishCurrentDay() {
      if (currentDayNum > 0 && currentDayExercises.isNotEmpty) {
        final effectiveTitle =
            currentDayTitle.isNotEmpty ? currentDayTitle : 'Día $currentDayNum';
        final effectiveFocus = currentDayFocus.isNotEmpty
            ? currentDayFocus
            : inferDayFocus(effectiveTitle, currentDayExercises);
        parsedDays.add(
          WorkoutDay(
            dayNumber: currentDayNum,
            title: effectiveTitle,
            focus: effectiveFocus,
            exercises: List.of(currentDayExercises),
          ),
        );
        currentDayExercises.clear();
      }
    }

    final maxExercisesPerDay =
        (profile?.minutesPerSession ?? 60) >= 75 ? 6 : 5;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      final dayMatch = dayRegex.firstMatch(line);
      if (dayMatch != null) {
        finishCurrentDay();
        currentDayNum =
            int.tryParse(dayMatch.group(1) ?? '') ?? (parsedDays.length + 1);
        currentDayTitle = (dayMatch.group(2) ?? '').replaceAll('*', '').trim();
        currentDayFocus = '';
        continue;
      }

      final isExerciseLine = currentDayNum > 0 &&
          (line.startsWith('-') ||
              line.startsWith('*') ||
              line.startsWith('•') ||
              RegExp(r'^\d+[\.\)]\s+').hasMatch(line));

      if (isExerciseLine) {
        final cleaned =
            line.replaceFirst(RegExp(r'^([-*•]|\d+[\.\)])\s*'), '').trim();

        int sets = 3;
        int minReps = 10;
        int maxReps = 12;

        // Soportar tanto "4 series x 8-10 reps" como "4x8-10" o "3 × 12"
        final compactSetRep = RegExp(
          r'(\d+)\s*[x×]\s*(\d+)(?:\s*[-–a]\s*(\d+))?',
          caseSensitive: false,
        ).firstMatch(cleaned);
        final setsMatch = RegExp(
          r'(\d+)\s*series',
          caseSensitive: false,
        ).firstMatch(cleaned);
        final repsMatch = RegExp(
          r'(\d+)(?:\s*[-–a]\s*(\d+))?\s*(?:reps|repeticiones)',
          caseSensitive: false,
        ).firstMatch(cleaned);

        if (setsMatch != null) {
          sets = int.tryParse(setsMatch.group(1) ?? '') ?? 3;
        } else if (compactSetRep != null) {
          sets = int.tryParse(compactSetRep.group(1) ?? '') ?? 3;
        }

        if (repsMatch != null) {
          minReps = int.tryParse(repsMatch.group(1) ?? '') ?? 10;
          maxReps = int.tryParse(repsMatch.group(2) ?? '') ?? minReps;
        } else if (compactSetRep != null) {
          minReps = int.tryParse(compactSetRep.group(2) ?? '') ?? 10;
          maxReps = int.tryParse(compactSetRep.group(3) ?? '') ?? minReps;
        } else if (cleaned.toLowerCase().contains('fallo')) {
          minReps = 8;
          maxReps = 12;
        }

        // Extraer el nombre limpio del ejercicio antes de ":" o "—" o del patrón de series
        var rawName = cleaned;
        final colonIdx = rawName.indexOf(':');
        final dashSeparatorIdx =
            RegExp(r'\s+[–—-]\s+').firstMatch(rawName)?.start ?? -1;
        final setsStartIdx = RegExp(
              r'\(?\d+\s*(?:series|[x×]\s*\d+)',
              caseSensitive: false,
            ).firstMatch(rawName)?.start ??
            -1;

        var cutIdx = -1;
        for (final idx in [colonIdx, dashSeparatorIdx, setsStartIdx]) {
          if (idx > 0 && (cutIdx == -1 || idx < cutIdx)) {
            cutIdx = idx;
          }
        }
        if (cutIdx > 0) {
          rawName = rawName.substring(0, cutIdx);
        }
        rawName = rawName.replaceAll('*', '').trim();

        // Actualizar el contexto del día antes de intentar el match
        _dayContext = currentDayTitle.isNotEmpty ? currentDayTitle : goal;

        var exercise = _matchExercise(rawName, sets, minReps, maxReps);

        // Si el ejercicio sugerido por la IA está prohibido por las limitaciones/equipo del usuario,
        // lo reemplazamos automáticamente por un ejercicio seguro compatible del catálogo
        if (exercise != null &&
            profile != null &&
            !allowedExercise(exercise, profile)) {
          final targetMuscleNorm = normalized(exercise.muscleGroup);
          exercise = ExerciseCatalog.exercises
              .firstWhere(
                (e) =>
                    !currentDayExercises.any((ce) => ce.stableId == e.stableId) &&
                    allowedExercise(e, profile) &&
                    (normalized(e.muscleGroup).contains(targetMuscleNorm) ||
                        e.primaryMuscles
                            .any((p) => normalized(p).contains(targetMuscleNorm))),
                orElse: () => ExerciseCatalog.exercises.firstWhere(
                  (e) =>
                      !currentDayExercises.any((ce) => ce.stableId == e.stableId) &&
                      allowedExercise(e, profile),
                  orElse: () => exercise!,
                ),
              )
              .copyWith(sets: sets, targetMin: minReps, targetMax: maxReps);
        }

        // Si no se reconoció el ejercicio, buscar en el catálogo uno compatible con el músculo del día
        if (exercise == null) {
          final dayTitleForFallback =
              currentDayTitle.isNotEmpty ? currentDayTitle : goal;
          final dayFocusNorm = normalized('$dayTitleForFallback $rawName');
          final muscleKeywords = _extractMuscleKeywords(dayFocusNorm);

          final candidates = ExerciseCatalog.exercises.where((e) {
            if (e.catalogId == null || !e.catalogId!.startsWith('ex_')) {
              return false;
            }
            if (currentDayExercises.any((ce) => ce.stableId == e.stableId)) {
              return false;
            }
            if (parsedDays.any(
              (d) => d.exercises.any((pe) => pe.stableId == e.stableId),
            )) {
              return false;
            }
            if (profile != null && !allowedExercise(e, profile)) return false;
            if (muscleKeywords.isNotEmpty) {
              final eGroup = normalized(e.muscleGroup);
              final ePrimary = e.primaryMuscles.map(normalized).join(' ');
              return muscleKeywords
                  .any((k) => eGroup.contains(k) || ePrimary.contains(k));
            }
            return normalized(e.muscleGroup).contains(dayFocusNorm) ||
                e.primaryMuscles.any((p) => normalized(p).contains(dayFocusNorm));
          }).toList();

          if (candidates.isNotEmpty) {
            exercise = candidates.first.copyWith(
              sets: sets,
              targetMin: minReps,
              targetMax: maxReps,
            );
          }
        }

        // Solo añadir si es un ejercicio válido y respeta el límite de la sesión
        if (exercise != null &&
            currentDayExercises.length < maxExercisesPerDay &&
            !currentDayExercises.any((e) => e.stableId == exercise!.stableId)) {
          currentDayExercises.add(exercise);
        }
      }
    }
    finishCurrentDay();

    if (parsedDays.isEmpty) return null;

    int parsedWeeks = currentPlan?.totalWeeks ?? 4;
    final weeksMatch = RegExp(
      r'(?:durante|por|ciclo\s+de|plan\s+de|recomendad[oa]\s+por)?\s*(\d+)\s*semanas?',
      caseSensitive: false,
    ).firstMatch(text);
    if (weeksMatch != null) {
      final w = int.tryParse(weeksMatch.group(1) ?? '');
      if (w != null && w >= 1 && w <= 12) {
        parsedWeeks = w;
      }
    }

    return WorkoutPlan(
      id: currentPlan?.id,
      version: (currentPlan?.version ?? 0) + 1,
      name: planName,
      goal: goal,
      plannedMinutes: profile?.minutesPerSession ?? 60,
      days: parsedDays,
      changeReason: 'Rutina diseñada y verificada por tu Coach IA',
      createdAt: DateTime.now(),
      block: 1,
      week: 1,
      totalWeeks: parsedWeeks,
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
    bool singleMuscleExclusive = false,
  }) {
    final effectiveDays = (daysCount >= 1 && daysCount <= 7)
        ? daysCount
        : profile.daysPerWeek;

    final priorities = focusMuscles.isNotEmpty
        ? focusMuscles
        : profile.priorityMuscles;

    final effectiveProfile = profile.copyWith(
      daysPerWeek: effectiveDays,
      priorityMuscles: priorities,
    );

    final beginner = normalized(effectiveProfile.experience).contains('princip');
    final strength = normalized(effectiveProfile.goal).contains('fuerza');
    final defaultSets = beginner ? 3 : 3;
    final defaultMinReps = strength ? 6 : 8;
    final defaultMaxReps = strength ? 8 : 12;
    final defaultRest = strength ? 90 : 75;
    final sessionMinutes = effectiveProfile.minutesPerSession >= 15
        ? effectiveProfile.minutesPerSession
        : 60;

    final compatiblePool = ExerciseCatalog.exercises
        .where((e) => allowedExercise(e, effectiveProfile))
        .where((e) => e.type != 'cardio')
        .toList();

    bool matchesCategory(WorkoutExercise e, String category) {
      final g = normalized(e.muscleGroup);
      final p = e.primaryMuscles.map(normalized).join(' ');
      final id = e.id;
      final nameNorm = normalized(e.name);
      switch (category) {
        case 'chest':
          return g.contains('pecho');
        case 'back':
          return g.contains('espalda');
        case 'shoulders':
          return g.contains('hombro') || id == 'face_pull';
        case 'quads':
          return (g.contains('pierna') || g.contains('cuadricep')) &&
              (p.contains('cuadricep') ||
                  id.contains('leg_press') ||
                  id.contains('belt_squat') ||
                  id.contains('squat') ||
                  id.contains('leg_extension') ||
                  id.contains('lunge'));
        case 'posterior':
          return g.contains('gluteo') ||
              ((g.contains('pierna') || g.contains('gluteo') || g.contains('isquio')) &&
                  (p.contains('isquio') ||
                      p.contains('femoral') ||
                      p.contains('gluteo') ||
                      id.contains('rdl') ||
                      id.contains('deadlift') ||
                      id.contains('hip_thrust') ||
                      id.contains('glute') ||
                      id.contains('leg_curl') ||
                      id.contains('abduction')));
        case 'calves':
          return g.contains('pantorrilla') ||
              nameNorm.contains('talon') ||
              id.contains('calf');
        case 'biceps':
          return (g.contains('brazo') || g.contains('bicep')) &&
              (p.contains('bicep') || nameNorm.contains('curl'));
        case 'triceps':
          return (g.contains('brazo') || g.contains('tricep')) &&
              (p.contains('tricep') ||
                  nameNorm.contains('tricep') ||
                  id == 'assisted_dip');
        case 'core':
          return g.contains('abdomen') ||
              g.contains('core') ||
              id.contains('crunch') ||
              id.contains('pallof') ||
              id.contains('woodchop') ||
              id.contains('hyperextension');
        default:
          return false;
      }
    }

    String mapMuscleNameToCategory(String muscle) {
      final m = normalized(muscle);
      if (m.contains('pecho')) return 'chest';
      if (m.contains('espalda')) return 'back';
      if (m.contains('hombro')) return 'shoulders';
      if (m.contains('gluteo')) return 'posterior';
      if (m.contains('pierna') || m.contains('cuadricep')) return 'quads';
      if (m.contains('isquio') || m.contains('femoral')) return 'posterior';
      if (m.contains('brazo') || m.contains('bicep')) return 'biceps';
      if (m.contains('tricep')) return 'triceps';
      if (m.contains('abdomen') || m.contains('core')) return 'core';
      return 'chest';
    }

    final estimator = const WorkoutDurationEstimator();
    final maxExercises = beginner
        ? 4
        : (sessionMinutes >= 75 ? 6 : (sessionMinutes >= 50 ? 5 : 4));

    WorkoutExercise prescribe(WorkoutExercise base) {
      final isIsolation = !base.compound;
      return base.copyWith(
        sets: defaultSets,
        targetMin: isIsolation ? 10 : defaultMinReps,
        targetMax: isIsolation ? 15 : defaultMaxReps,
        targetRir: beginner ? 3 : 2,
        restSeconds: isIsolation ? 60 : defaultRest,
      );
    }

    // Caso 1: El usuario pidió explícitamente entrenar SOLO 1 grupo muscular (ej. "solo pecho")
    if (singleMuscleExclusive && focusMuscles.length == 1) {
      final targetMuscle = focusMuscles.first;
      final cat = mapMuscleNameToCategory(targetMuscle);
      final musclePool = compatiblePool
          .where((e) =>
              matchesCategory(e, cat) ||
              (cat == 'quads' && matchesCategory(e, 'posterior')))
          .toList();
      final sourcePool = musclePool.isNotEmpty ? musclePool : compatiblePool;
      final usedAcrossDays = <String>{};
      final days = <WorkoutDay>[];

      for (var day = 0; day < effectiveDays; day++) {
        final selected = <WorkoutExercise>[];
        for (final candidate in sourcePool) {
          if (selected.length >= 4) break;
          if (usedAcrossDays.contains(candidate.stableId) &&
              sourcePool.length >= effectiveDays * 3) {
            continue;
          }
          if (!selected.any((s) => s.stableId == candidate.stableId)) {
            final p = prescribe(candidate);
            final trial = WorkoutDay(
              dayNumber: day + 1,
              title: '',
              focus: '',
              exercises: [...selected, p],
            );
            if (estimator.minutes(trial) <= sessionMinutes) {
              selected.add(p);
              usedAcrossDays.add(candidate.stableId);
            }
          }
        }
        if (selected.length < 3) {
          for (final candidate in sourcePool) {
            if (selected.length >= 4) break;
            if (!selected.any((s) => s.stableId == candidate.stableId)) {
              selected.add(prescribe(candidate));
            }
          }
        }
        final dayLetter = String.fromCharCode(65 + day);
        days.add(
          WorkoutDay(
            dayNumber: day + 1,
            title: '$targetMuscle $dayLetter',
            focus: targetMuscle,
            exercises: selected,
          ),
        );
      }

      return WorkoutPlan(
        id: currentPlan?.id,
        version: (currentPlan?.version ?? 0) + 1,
        name: planName,
        goal: focusStr,
        plannedMinutes: sessionMinutes,
        days: days,
        changeReason: 'Rutina especializada en $focusStr',
        createdAt: DateTime.now(),
        block: 1,
        week: 1,
        source: 'ai',
        isDemo: false,
      );
    }

    // Caso 2: Coach Experto — Split Semanal Completo y Equilibrado
    // Entrena todo el cuerpo con coherencia biomecánica, dando prioridad y mayor volumen
    // a los músculos prioritarios del usuario (ej. Pecho y Piernas) sin descuidar Espalda, Hombros, Brazos y Core.
    final priorityCategories = priorities.map(mapMuscleNameToCategory).toSet();
    final primaryPriorityCat =
        priorityCategories.isNotEmpty ? priorityCategories.first : 'chest';

    List<({String title, String focus, List<String> slots})> buildSplitSpec(
      int numDays,
    ) {
      final hasChestPriority = priorityCategories.contains('chest');
      final hasLegsPriority = priorityCategories.contains('quads') ||
          priorityCategories.contains('posterior');

      final priorityLabel = priorities.isNotEmpty
          ? ' · Énfasis ${priorities.take(2).join(' y ')}'
          : '';

      if (numDays == 1) {
        return [
          (
            title: 'Cuerpo Completo Integral$priorityLabel',
            focus: 'Pecho, Espalda, Piernas, Hombros y Core',
            slots: ['chest', 'quads', 'back', 'posterior', 'shoulders', 'core'],
          ),
        ];
      }
      if (numDays == 2) {
        return [
          (
            title: 'Tren Superior Completo',
            focus: 'Pecho, Espalda, Hombros y Brazos',
            slots: ['chest', 'back', 'chest', 'shoulders', 'triceps', 'biceps'],
          ),
          (
            title: 'Tren Inferior y Core',
            focus: 'Cuádriceps, Glúteos, Isquiotibiales y Pantorrilla',
            slots: ['quads', 'posterior', 'quads', 'posterior', 'calves', 'core'],
          ),
        ];
      }
      if (numDays == 3) {
        // Split Coach Clásico de 3 días: Empuje / Pierna Completa / Tirón + Refuerzo Prioritario
        final reinforcementSlot = hasChestPriority
            ? 'chest'
            : (hasLegsPriority ? 'posterior' : primaryPriorityCat);
        return [
          (
            title: hasChestPriority
                ? 'Empuje y Pecho Prioritario'
                : 'Empuje (Pecho, Hombros y Tríceps)',
            focus: 'Pecho, Hombros y Tríceps',
            slots: [
              'chest',
              'chest',
              'shoulders',
              'shoulders',
              'triceps',
              'chest',
            ],
          ),
          (
            title: hasLegsPriority
                ? 'Pierna Completa Prioritaria'
                : 'Tren Inferior y Glúteos',
            focus: 'Cuádriceps, Isquiotibiales, Glúteos y Pantorrilla',
            slots: [
              'quads',
              'posterior',
              'quads',
              'posterior',
              'calves',
              'core',
            ],
          ),
          (
            title: 'Tirón, Espalda y Estímulo Prioritario',
            focus: priorities.isNotEmpty
                ? 'Espalda, Bíceps y Énfasis ${priorities.first}'
                : 'Espalda, Deltoide Posterior, Bíceps y Core',
            slots: [
              'back',
              'back',
              'shoulders',
              'biceps',
              reinforcementSlot,
              'core',
            ],
          ),
        ];
      }
      if (numDays == 4) {
        // Split Torso / Pierna (Frecuencia 2)
        return [
          (
            title: 'Torso A (Énfasis Pecho, Espalda y Tríceps)',
            focus: 'Pecho, Espalda, Hombro Lateral y Tríceps',
            slots: ['chest', 'back', 'chest', 'shoulders', 'triceps', 'chest'],
          ),
          (
            title: 'Pierna A (Énfasis Cuádriceps, Glúteo y Pantorrilla)',
            focus: 'Cuádriceps, Glúteos, Isquiotibiales y Pantorrilla',
            slots: ['quads', 'quads', 'posterior', 'posterior', 'calves', 'core'],
          ),
          (
            title: 'Torso B (Énfasis Espalda, Hombros, Pecho y Bíceps)',
            focus: 'Espalda, Hombros, Pecho Superior y Bíceps',
            slots: ['back', 'chest', 'back', 'shoulders', 'biceps', 'biceps'],
          ),
          (
            title: 'Pierna B y Core (Énfasis Isquiotibiales y Glúteos)',
            focus: 'Isquiotibiales, Glúteos, Cuádriceps y Abdomen',
            slots: ['posterior', 'posterior', 'quads', 'calves', 'core', 'quads'],
          ),
        ];
      }
      if (numDays == 5) {
        // Push / Pull / Legs / Upper / Lower
        return [
          (
            title: 'Empuje (Pecho, Hombros y Tríceps)',
            focus: 'Pecho, Deltoides y Tríceps',
            slots: ['chest', 'chest', 'shoulders', 'shoulders', 'triceps', 'chest'],
          ),
          (
            title: 'Tirón (Espalda, Hombro Posterior y Bíceps)',
            focus: 'Espalda, Deltoide Posterior y Bíceps',
            slots: ['back', 'back', 'back', 'shoulders', 'biceps', 'biceps'],
          ),
          (
            title: 'Pierna A (Énfasis Cuádriceps y Glúteos)',
            focus: 'Cuádriceps, Glúteos y Pantorrillas',
            slots: ['quads', 'quads', 'posterior', 'quads', 'calves', 'core'],
          ),
          (
            title: 'Tren Superior Prioritario',
            focus: 'Pecho, Espalda, Hombros y Brazos',
            slots: ['chest', 'back', 'shoulders', 'chest', 'triceps', 'biceps'],
          ),
          (
            title: 'Pierna B y Core (Énfasis Isquiotibiales y Glúteos)',
            focus: 'Isquiotibiales, Glúteos, Cuádriceps y Abdomen',
            slots: ['posterior', 'posterior', 'quads', 'posterior', 'calves', 'core'],
          ),
        ];
      }
      // 6 o 7 días: Push / Pull / Legs × 2 (+ Día de Core/Acondicionamiento si es 7)
      final base6 = [
        (
          title: 'Empuje A (Pecho Fuerza, Hombro y Tríceps)',
          focus: 'Pecho, Hombros y Tríceps',
          slots: ['chest', 'chest', 'shoulders', 'shoulders', 'triceps', 'chest'],
        ),
        (
          title: 'Tirón A (Espalda Densidad y Bíceps)',
          focus: 'Espalda, Deltoide Posterior y Bíceps',
          slots: ['back', 'back', 'back', 'shoulders', 'biceps', 'biceps'],
        ),
        (
          title: 'Pierna A (Énfasis Cuádriceps y Pantorrilla)',
          focus: 'Cuádriceps, Glúteos y Pantorrilla',
          slots: ['quads', 'quads', 'posterior', 'quads', 'calves', 'core'],
        ),
        (
          title: 'Empuje B (Pecho Hipertrofia, Deltoide Lateral y Tríceps)',
          focus: 'Pecho Inclinado, Hombros y Tríceps',
          slots: ['chest', 'chest', 'shoulders', 'triceps', 'triceps', 'chest'],
        ),
        (
          title: 'Tirón B (Espalda Amplitud, Trapecio y Bíceps)',
          focus: 'Dorsales, Hombro Posterior y Bíceps',
          slots: ['back', 'back', 'shoulders', 'biceps', 'biceps', 'core'],
        ),
        (
          title: 'Pierna B (Énfasis Isquiotibiales, Glúteos y Core)',
          focus: 'Isquiotibiales, Glúteos, Cuádriceps y Abdomen',
          slots: ['posterior', 'posterior', 'quads', 'posterior', 'calves', 'core'],
        ),
        if (numDays == 7)
          (
            title: 'Puntos Débiles, Core y Movilidad',
            focus: 'Prioridades Musculares y Abdomen',
            slots: [primaryPriorityCat, 'core', 'shoulders', 'biceps', 'triceps'],
          ),
      ];
      return base6;
    }

    final splitSpecs = buildSplitSpec(effectiveDays);
    final usedGlobalIds = <String>{};
    final days = <WorkoutDay>[];

    for (var dayIdx = 0; dayIdx < splitSpecs.length; dayIdx++) {
      final spec = splitSpecs[dayIdx];
      final selected = <WorkoutExercise>[];

      for (final slotCat in spec.slots) {
        if (selected.length >= maxExercises) break;
        final catCandidates = compatiblePool
            .where((e) => matchesCategory(e, slotCat))
            .where((e) => !selected.any((s) => s.stableId == e.stableId))
            .toList();

        if (catCandidates.isEmpty) continue;

        // Priorizar ejercicios compuestos al inicio del día y evitar repetir ejercicios de días previos
        catCandidates.sort((a, b) {
          final aUsed = usedGlobalIds.contains(a.stableId) ? 1 : 0;
          final bUsed = usedGlobalIds.contains(b.stableId) ? 1 : 0;
          if (aUsed != bUsed) return aUsed.compareTo(bUsed);
          final wantCompound = selected.length < 2;
          if (wantCompound && a.compound != b.compound) {
            return b.compound ? 1 : -1;
          }
          return 0;
        });

        for (final chosen in catCandidates) {
          final prescribed = prescribe(chosen);
          final trial = WorkoutDay(
            dayNumber: dayIdx + 1,
            title: spec.title,
            focus: spec.focus,
            exercises: [...selected, prescribed],
          );
          final fitsDuration = estimator.minutes(trial) <= sessionMinutes;
          final fitsBeginnerSets = !beginner ||
              trial.exercises.fold<int>(0, (s, e) => s + e.sets) <= 12;
          if (fitsDuration && fitsBeginnerSets) {
            selected.add(prescribed);
            usedGlobalIds.add(chosen.stableId);
            break;
          }
        }
      }

      // Garantizar al menos 3 ejercicios por día si el tiempo lo permite
      if (selected.length < 3) {
        for (final fallback in compatiblePool) {
          if (selected.length >= 3) break;
          if (selected.any((s) => s.stableId == fallback.stableId)) continue;
          final prescribed = prescribe(fallback);
          final trial = WorkoutDay(
            dayNumber: dayIdx + 1,
            title: spec.title,
            focus: spec.focus,
            exercises: [...selected, prescribed],
          );
          if (estimator.minutes(trial) <= sessionMinutes) {
            selected.add(prescribed);
            usedGlobalIds.add(fallback.stableId);
          }
        }
      }

      days.add(
        WorkoutDay(
          dayNumber: dayIdx + 1,
          title: spec.title,
          focus: spec.focus,
          exercises: selected,
        ),
      );
    }

    final changeReasonText = focusMuscles.isNotEmpty
        ? 'Split completo diseñado por tu Coach con énfasis prioritario en $focusStr'
        : (priorities.isNotEmpty
            ? 'Split semanal equilibrado para ${effectiveProfile.goal} (priorizando ${priorities.join(' y ')})'
            : 'Split semanal estructurado para ${effectiveProfile.goal}');

    return WorkoutPlan(
      id: currentPlan?.id,
      version: (currentPlan?.version ?? 0) + 1,
      name: planName,
      goal: focusStr,
      plannedMinutes: sessionMinutes,
      days: days,
      changeReason: changeReasonText,
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
        norm.contains('ejercicios') ||
        norm.contains('plan') ||
        norm.contains('semana');
    final hasActionWord = norm.contains('modific') ||
        norm.contains('cambi') ||
        norm.contains('actualiz') ||
        norm.contains('ajust') ||
        norm.contains('cre') ||
        norm.contains('arm') ||
        norm.contains('dej') ||
        norm.contains('pon') ||
        norm.contains('aplic') ||
        norm.contains('guard') ||
        norm.contains('necesit') ||
        norm.contains('quier') ||
        norm.contains('dame') ||
        norm.contains('haz') ||
        norm.contains('hac') ||
        norm.contains('distribu') ||
        norm.contains('recomiend') ||
        norm.contains('sugier') ||
        norm.contains('gener') ||
        norm.contains('nuev') ||
        norm.contains('buen');

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

  bool _isExclusiveSingleMuscleRequest(String text) {
    final norm = normalized(text);
    return norm.contains('solo ') ||
        norm.contains('unicamente ') ||
        norm.contains('exclusivamente ') ||
        norm.contains('solamente ') ||
        norm.contains('puro ');
  }

  List<String> _extractRequestedFocus(String text, [List<String>? extraUserTexts]) {
    // 1. Extraer del mensaje actual del usuario
    final fromMain = _extractMusclesFromText(text);
    if (fromMain.isNotEmpty) {
      return fromMain;
    }
    // 2. Solo si el mensaje actual es una confirmación corta (ej. "aplícala", "ponla en entrenar", "deja esa")
    // buscamos en los mensajes previos del propio usuario (nunca en respuestas del asistente)
    final norm = normalized(text);
    final isFollowUpConfirmation = norm.contains('aplic') ||
        norm.contains('entrenar') ||
        norm.contains('guard') ||
        norm.contains('deja') ||
        norm.contains('ponla') ||
        norm.contains('anotar');
    if (isFollowUpConfirmation &&
        extraUserTexts != null &&
        extraUserTexts.isNotEmpty) {
      for (final t in extraUserTexts.reversed) {
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
    bool singleMuscleExclusive = false,
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

    final effectiveDays =
        (requestedDays != null && requestedDays >= 1 && requestedDays <= 7)
            ? requestedDays
            : baseProfile.daysPerWeek;

    final profilePriorities = baseProfile.priorityMuscles.isNotEmpty
        ? baseProfile.priorityMuscles
        : const ['Pecho', 'Piernas'];

    final effectiveProfile = baseProfile.copyWith(
      daysPerWeek: effectiveDays,
      priorityMuscles:
          focusMuscles.isNotEmpty ? focusMuscles : profilePriorities,
    );

    final focusStr = focusMuscles.isNotEmpty
        ? focusMuscles.join(' y ')
        : effectiveProfile.goal;

    final planName = focusMuscles.isNotEmpty
        ? 'Rutina con énfasis en $focusStr'
        : 'Rutina Coach: ${effectiveProfile.goal}';

    WorkoutPlan? parsedFromAi;

    // 1. Si la IA redactó un desglose de rutina en texto, parseamos sus días y ejercicios al catálogo oficial
    if (customReply != null && _hasRoutineProposalContent(customReply)) {
      parsedFromAi = _parseWorkoutPlanFromAiText(
        customReply,
        currentPlan: currentPlan,
        planName: planName,
        goal: focusStr,
        daysCount: effectiveDays,
        profile: effectiveProfile,
      );
    }

    // 2. Si no vino desglose válido de la IA, el Coach Experto genera un split semanal completo y equilibrado
    final newPlan = parsedFromAi ??
        _generateTargetedPlan(
          effectiveProfile,
          currentPlan: currentPlan,
          focusMuscles: focusMuscles,
          daysCount: effectiveDays,
          planName: planName,
          focusStr: focusStr,
          singleMuscleExclusive: singleMuscleExclusive,
        );

    final isNew = currentPlan == null;

    // 3. Construir el resumen exacto a partir de newPlan para que el texto del chat
    // y la tarjeta interactiva "Aplicar" SIEMPRE coincidan al 100% en días, ejercicios, series y repeticiones.
    final daysSummary = newPlan.days.map((day) {
      final exLines = day.exercises
          .map(
            (e) =>
                '  • ${e.name} — ${e.sets} series × ${e.minReps}-${e.maxReps} reps (descanso ${e.restSeconds}s)',
          )
          .join('\n');
      final header = day.title.toLowerCase().contains(day.focus.toLowerCase())
          ? 'Día ${day.dayNumber} · ${day.title}:'
          : 'Día ${day.dayNumber} · ${day.title} (${day.focus}):';
      return '$header\n$exLines';
    }).join('\n\n');

    final priorityNote = (!singleMuscleExclusive &&
            effectiveProfile.priorityMuscles.isNotEmpty)
        ? ' dando prioridad a ${effectiveProfile.priorityMuscles.join(' y ')} dentro de una estructura equilibrada de cuerpo completo'
        : '';

    final replyText =
        'Como tu Coach de entrenamiento, he estructurado un plan de $effectiveDays días (${newPlan.plannedMinutes} min/sesión) enfocado en $focusStr$priorityNote, seleccionando el equipo oficial de Fit Body Gym:\n\n$daysSummary\n\nRevisa la tarjeta inferior (que contiene exactamente estos mismos días y ejercicios) y presiona "Aplicar" para guardarla en Entrenar.';

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

  String _buildLocalCoachingReply(
    String userMessage,
    UserProfileContext userContext,
    WorkoutPlan? activeWorkout,
  ) {
    final norm = userMessage.toLowerCase();
    final name = (userContext.fullName ?? 'atleta').split(' ').first;
    final goal = userContext.goal;
    final days = userContext.daysPerWeek;
    final minutes = userContext.minutesPerSession;

    if (norm.contains('hola') || norm.contains('buenos') || norm.contains('buenas')) {
      return '¡Hola, $name! Tu perfil está configurado para "$goal" ($days días/semana, $minutes min por sesión). ¿Quieres que te arme una rutina distribuida para la semana o que ajustemos algún grupo muscular en específico?';
    }

    if (activeWorkout != null) {
      final dayTitles = activeWorkout.days
          .map((d) => 'Día ${d.dayNumber}: ${d.title} (${d.focus})')
          .join(', ');
      return 'Para tu objetivo de "$goal" ($days días/semana), actualmente tienes activa la rutina "${activeWorkout.name}" distribuida en: $dayTitles.\n\nSi quieres modificar algún día, cambiar el enfoque muscular (por ejemplo: más pecho, piernas, espalda o glúteos) o generar una nueva distribución semanal, dímelo y te preparo la propuesta con el botón para aplicarla.';
    }

    return 'Para tu objetivo de "$goal" ($days días/semana, $minutes min/sesión), puedo generarte una rutina completa con las máquinas y pesas de Fit Body Gym. Escribe por ejemplo "necesito una rutina para la semana" o indica qué músculos quieres priorizar y te daré la propuesta lista para aplicar.';
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
      final singleMuscleExclusive = _isExclusiveSingleMuscleRequest(text);
      final previousUserTexts = messages
          .take(messages.length - 1)
          .where((m) => m.fromUser)
          .map((m) => m.text)
          .toList();
      final focusMuscles = _extractRequestedFocus(
        text,
        previousUserTexts,
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

      late AiChatResponse reply;
      try {
        reply = await aiChatService.reply(
          message: text,
          history: history,
          trainingProfile: userContext.toMergedMap(),
          activeWorkout: activeWorkout?.toJson(),
        );
      } catch (error) {
        // En caso de error de red, saldo o Edge Function desactualizada:
        // Si pidió crear/cambiar la rutina o mencionó músculos, generamos la propuesta localmente
        if (isChangeRequest || focusMuscles.isNotEmpty) {
          final requestedDays = _extractRequestedDays(text);
          reply = _createFocusProposal(
            userContext: userContext,
            currentPlan: activeWorkout,
            focusMuscles: focusMuscles,
            requestedDays: requestedDays,
            singleMuscleExclusive: singleMuscleExclusive,
          );
        } else if (error is FunctionException && error.status == 403) {
          // Si el usuario ya tiene acceso autorizado en la app pero la Edge Function
          // en la nube aún no se ha redesplegado con authorized_access, respondemos localmente
          reply = AiChatResponse(
            reply: _buildLocalCoachingReply(text, userContext, activeWorkout),
            action: const AiWorkoutAction(type: AiActionType.answer),
          );
        } else {
          rethrow;
        }
      }

      // Convertimos en propuesta interactiva cuando la IA entregó una rutina estructurada
      // o cuando el usuario solicitó explícitamente crear/cambiar su rutina.
      final shouldAttachProposal =
          _hasRoutineProposalContent(reply.reply) || isChangeRequest;

      if (shouldAttachProposal && !reply.action.isProposal) {
        final requestedDays =
            _extractRequestedDays(text) ?? _extractRequestedDays(reply.reply);
        reply = _createFocusProposal(
          userContext: userContext,
          currentPlan: activeWorkout,
          focusMuscles: focusMuscles,
          requestedDays: requestedDays,
          customReply: reply.reply,
          singleMuscleExclusive: singleMuscleExclusive,
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
