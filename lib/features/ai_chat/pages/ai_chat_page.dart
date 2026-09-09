import 'package:flutter/material.dart';

import '../../assessment/data/training_profile_store.dart';
import '../../assessment/models/training_profile.dart';
import '../../assessment/pages/training_assessment_page.dart';
import '../../training/data/demo_workout_generator.dart';
import '../../training/data/workout_plan_store.dart';

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

  Future<TrainingProfile?> ensureProfile() async {
    final saved = await TrainingProfileStore().load();
    if (saved != null || !mounted) return saved;
    addMessage(
      'Primero necesito tu evaluacion para preparar una rutina segura. Completa estos datos y regresaras al chat.',
    );
    final profile = await Navigator.push<TrainingProfile>(
      context,
      MaterialPageRoute(builder: (_) => const TrainingAssessmentPage()),
    );
    return profile;
  }

  Future<void> createRoutine() async {
    if (working) return;
    setState(() => working = true);
    try {
      final profile = await ensureProfile();
      if (profile == null) {
        if (mounted) {
          addMessage(
            'No se creo la rutina porque la evaluacion quedo pendiente.',
          );
        }
        return;
      }
      final plan = DemoWorkoutGenerator().generate(profile);
      await WorkoutPlanStore().save(plan);
      if (!mounted) return;
      addMessage(
        'Listo: cree y guarde "${plan.name}" con ${plan.days.length} dias por semana para ${profile.goal.toLowerCase()}. Ya esta disponible en Entrenar.',
      );
    } catch (_) {
      if (mounted) {
        addMessage('No pude guardar la rutina. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
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
    final normalized = text.toLowerCase();
    if (normalized.contains('rutina') ||
        normalized.contains('entrenamiento') ||
        normalized.contains('ejercicio')) {
      await createRoutine();
    } else if (normalized.contains('perfil') ||
        normalized.contains('evaluacion') ||
        normalized.contains('datos')) {
      await reviewProfile();
    } else if (normalized.contains('entrenar') ||
        normalized.contains('guardada')) {
      addMessage('Abriendo tu rutina activa en Entrenar.');
      widget.onOpenTraining();
    } else {
      addMessage(
        'Por ahora puedo crear una rutina, actualizar tu evaluacion o abrir Entrenar. Puedes elegir una opcion de abajo.',
      );
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
                () => sendMessage('Editar mi evaluacion'),
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
