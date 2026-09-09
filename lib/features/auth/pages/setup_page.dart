import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/molecules/auth_header.dart';
import '../../../shared/presentation/atomic_design/templates/centered_form_template.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CenteredFormTemplate(
      padding: EdgeInsets.all(28),
      children: [
        AuthHeader(
          icon: Icons.fitness_center,
          iconSize: 72,
          title: 'FIT BODY GYM',
          titleFontSize: 28,
          subtitle:
              'La app está lista. Falta conectar el proyecto de Supabase para habilitar el acceso de miembros.',
          subtitleColor: Colors.white70,
          iconTitleSpacing: 24,
          titleSubtitleSpacing: 14,
        ),
      ],
    );
  }
}
