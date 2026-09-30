import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../assessment/data/training_profile_store.dart';
import '../../assessment/models/training_profile.dart';
import '../../assessment/pages/training_assessment_page.dart';
import '../../profile/data/app_user_profile_store.dart';
import '../../profile/models/app_user_profile.dart';
import '../../training/data/demo_workout_generator.dart';
import '../../training/data/exercise_catalog.dart';
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
      final restored = saved
          .map(
            (m) => _ChatMessage(
              m['text'] as String,
              fromUser: m['fromUser'] as bool? ?? false,
              status: m['status'] as String? ?? 'pending',
              response: m['response'] == null
                  ? null
                  : AiChatResponse.parse(m['response']),
            ),
          )
          .toList();
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
      final plan = DemoWorkoutGenerator()
          .generate(profile)
          .copyWith(id: current?.id, version: (current?.version ?? 0) + 1);
      final response = AiChatResponse(
        reply:
            'Propuesta de rutina adaptada a tu evaluación. Revisa los días y ejercicios antes de aplicar.',
        action: AiWorkoutAction(
          type: AiActionType.proposeWorkout,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message.text),
        const SizedBox(height: 8),
        Text(
          'Propuesta: versión ${action.expectedVersion} → ${plan.version}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(plan.changeReason),
        Text(
          '${plan.days.length} días · hasta ${plan.plannedMinutes} min por sesión',
        ),
        ...plan.days.map(
          (d) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Día ${d.dayNumber}: ${d.exercises.map((e) => '${e.name} (${e.sets} × ${e.minReps}–${e.maxReps}, RIR ${e.targetRir}, ${e.restSeconds} s)').join(' · ')}',
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (message.status == 'pending')
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: working ? null : () => changeProposal(message, true),
                child: const Text('Aplicar'),
              ),
              TextButton(
                onPressed: working
                    ? null
                    : () => changeProposal(message, false),
                child: const Text('Cancelar'),
              ),
            ],
          )
        else
          Text(
            message.status == 'applied'
                ? 'Aplicada'
                : message.status == 'invalid'
                ? 'Propuesta inválida; no se puede aplicar.'
                : 'Cancelada',
            style: const TextStyle(fontWeight: FontWeight.bold),
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
    const triggers = [
      'cambiar mi rutina',
      'modificar mi rutina',
      'cambiar rutina',
      'modificar rutina',
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
      'reorganizar mi rutina',
      'reorganizar la rutina',
      'adaptar mi rutina',
      'rutina enfocada',
      'rutina de pecho',
      'rutina para piernas',
      'cambiar ejercicios',
      'poner mas pecho',
      'poner más pecho',
      'poner mas piernas',
      'poner más piernas',
      'poner mas brazos',
      'poner más brazos',
      'poner mas espalda',
      'poner más espalda',
    ];
    return triggers.any((t) => norm.contains(t));
  }

  List<String> _extractRequestedFocus(String text) {
    final norm = text.toLowerCase();
    final result = <String>[];
    if (norm.contains('pecho') || norm.contains('pectoral')) result.add('Pecho');
    if (norm.contains('pierna') ||
        norm.contains('cuadriceps') ||
        norm.contains('cuádriceps') ||
        norm.contains('isquio') ||
        norm.contains('femoral')) {
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

  AiChatResponse _createFocusProposal({
    required UserProfileContext userContext,
    required WorkoutPlan? currentPlan,
    required List<String> focusMuscles,
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

    final effectiveProfile = baseProfile.copyWith(
      priorityMuscles: focusMuscles.isNotEmpty
          ? focusMuscles
          : (baseProfile.priorityMuscles.isNotEmpty
              ? baseProfile.priorityMuscles
              : const ['Pecho', 'Piernas']),
    );

    final generator = DemoWorkoutGenerator();
    final generatedPlan = generator.generate(effectiveProfile);
    final focusStr = focusMuscles.isNotEmpty
        ? focusMuscles.join(' y ')
        : effectiveProfile.goal;

    final newPlan = generatedPlan.copyWith(
      id: currentPlan?.id,
      version: (currentPlan?.version ?? 0) + 1,
      name: focusMuscles.isNotEmpty
          ? 'Rutina con énfasis en $focusStr'
          : (currentPlan?.name ?? 'Rutina adaptada'),
      changeReason: focusMuscles.isNotEmpty
          ? 'Reorganización con mayor énfasis en $focusStr según tu solicitud'
          : 'Ajuste de rutina según tus preferencias',
    );

    return AiChatResponse(
      reply:
          '¡Por supuesto! He reorganizado tu rutina dando mayor énfasis a $focusStr, respetando tus ${effectiveProfile.daysPerWeek} días por semana y tus ${effectiveProfile.minutesPerSession} min por sesión. Revisa la propuesta abajo y pulsa "Aplicar" para guardarla en tu entrenamiento.',
      action: AiWorkoutAction(
        type: AiActionType.modifyWorkout,
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
      final focusMuscles = _extractRequestedFocus(text);

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
          reply = _createFocusProposal(
            userContext: userContext,
            currentPlan: activeWorkout,
            focusMuscles: focusMuscles,
          );
        } else {
          rethrow;
        }
      }

      // Si el usuario pidió cambiar la rutina pero la respuesta de la IA remota no devolvió propuesta (sino solo texto o preguntas),
      // generamos directamente la propuesta adaptada para que no quede con preguntas redundantes.
      if (isChangeRequest && !reply.action.isProposal) {
        reply = _createFocusProposal(
          userContext: userContext,
          currentPlan: activeWorkout,
          focusMuscles: focusMuscles,
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
                      : Text(message.text),
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
