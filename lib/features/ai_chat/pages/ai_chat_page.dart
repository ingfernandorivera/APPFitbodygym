import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/molecules/feature_list_item.dart';
import '../../../shared/presentation/atomic_design/organisms/feature_placeholder_panel.dart';

class AiChatPage extends StatelessWidget {
  const AiChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPanel(
      icon: Icons.auto_awesome,
      title: 'Chat IA',
      description:
          'Entrada visual reservada para un asistente de entrenamiento. No realiza llamadas a IA todavía.',
      items: [
        FeatureListItem(
          icon: Icons.chat_bubble_outline,
          title: 'Conversación',
          description:
              'El historial y el campo de mensaje se conectarán después.',
        ),
        FeatureListItem(
          icon: Icons.psychology_outlined,
          title: 'Contexto fitness',
          description: 'Preparado para responder sobre objetivos y rutinas.',
        ),
        FeatureListItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Sin integración activa',
          description:
              'Esta pantalla no envía datos ni consulta servicios externos.',
        ),
      ],
    );
  }
}
