import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../assessment/data/training_profile_store.dart';
import '../../assessment/models/training_profile.dart';
import '../../assessment/pages/training_assessment_page.dart';
import '../../training/data/workout_plan_store.dart';
import '../data/ai_chat_service.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key, required this.onOpenTraining});

  final VoidCallback onOpenTraining;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _ChatMessage {
  const _ChatMessage(this.text, {this.fromUser = false});

  final String text;
  final bool fromUser;
}

class _AiChatPageState extends State<AiChatPage> {
  final aiChatService = AiChatService();
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final messages = <_ChatMessage>[
    const _ChatMessage(
      'Hola. Puedo ayudarte a crear tu rutina, revisar tu evaluacion y explicarte como usar la app. ¿Que necesitas?',
    ),
  ];
  var working = false;

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
    final saved = await TrainingProfileStore().load();
    if (!mounted) return;
    final result = await Navigator.push<TrainingProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingAssessmentPage(initialProfile: saved),
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
    if (text.isEmpty || working) return;
    controller.clear();
    addMessage(text, fromUser: true);
    setState(() => working = true);
    try {
      final profile = await TrainingProfileStore().load();
      final activeWorkout = await WorkoutPlanStore().load();
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
      if (mounted) addMessage(reply);
    } on FunctionException catch (error) {
      if (!mounted) return;
      final details = error.details;
      final message = details is Map && details['error'] is String
          ? details['error'] as String
          : 'No pude conectar con el asistente. Intenta nuevamente.';
      addMessage(message);
    } catch (_) {
      if (mounted) {
        addMessage('No pude conectar con el asistente. Intenta nuevamente.');
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget quickAction(String label, IconData icon, VoidCallback onPressed) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: working ? null : onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
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
                  child: Text(message.text),
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
              quickAction(
                'Crear mi rutina',
                Icons.auto_awesome,
                () => sendMessage('Crear mi rutina'),
              ),
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
                    enabled: !working,
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
                  onPressed: working ? null : sendMessage,
                  icon: working
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
