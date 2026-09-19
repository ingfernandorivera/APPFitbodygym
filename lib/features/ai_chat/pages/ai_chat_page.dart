import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../assessment/data/training_profile_store.dart';
import '../../assessment/models/training_profile.dart';
import '../../assessment/pages/training_assessment_page.dart';
import '../../training/data/workout_plan_store.dart';
import '../data/ai_chat_service.dart';
import '../data/chat_cache_store.dart';
import '../data/workout_proposal_validator.dart';
import '../models/ai_chat_response.dart';
import '../../training/data/exercise_catalog.dart';
import '../../training/data/demo_workout_generator.dart';

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
  late final planStore =
      widget.planStore ?? WorkoutPlanStore(storageUserId: profileStore.userId);
  late final cacheStore =
      widget.cacheStore ?? ChatCacheStore(storageUserId: profileStore.userId);
  String? cacheError;
  bool loading = true;
  late final profileStore =
      widget.profileStore ??
      TrainingProfileStore(storageUserId: widget.storageUserId);
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final messages = <_ChatMessage>[
    _ChatMessage(
      'Hola. Puedo ayudarte a crear tu rutina, revisar tu evaluacion y explicarte como usar la app. ¿Que necesitas?',
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
            'Propuesta local según tu evaluación. Revisa los días y ejercicios antes de aplicar.',
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

  Future<void> sendMessage([String? suggested]) async {
    final text = (suggested ?? controller.text).trim();
    if (text.isEmpty || working || loading) return;
    controller.clear();
    addMessage(text, fromUser: true);
    setState(() => working = true);
    try {
      await persist();
      final profile = await profileStore.load();
      final activeWorkout = await planStore.load();
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
      final reply = await aiChatService.reply(
        message: text,
        history: history,
        trainingProfile: profile?.toJson(),
        activeWorkout: activeWorkout?.toJson(),
      );
      if (mounted) {
        final issues = reply.action.isProposal
            ? WorkoutProposalValidator(
                ExerciseCatalog.exercises,
              ).validate(reply.action, current: activeWorkout, profile: profile)
            : [];
        setState(
          () => messages.add(
            _ChatMessage(
              reply.reply,
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
      avatar: Icon(icon, size: 18),
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
