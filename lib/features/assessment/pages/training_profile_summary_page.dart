import 'package:flutter/material.dart';

import '../models/training_profile.dart';

class TrainingProfileSummaryPage extends StatelessWidget {
  const TrainingProfileSummaryPage({
    super.key,
    required this.profile,
    required this.onOpenAiChat,
  });

  final TrainingProfile profile;
  final VoidCallback onOpenAiChat;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      (
        'Peso',
        profile.weightUnit == 'lb'
            ? '${(profile.weightKg * 2.2046226218).toStringAsFixed(1)} lb'
            : '${profile.weightKg.toStringAsFixed(1)} kg',
      ),
      ('Altura', '${profile.heightCm.toStringAsFixed(0)} cm'),
      ('Edad', '${profile.age} años'),
      ('Objetivo', profile.goal),
      ('Experiencia', profile.experience),
      (
        'Disponibilidad',
        '${profile.daysPerWeek} días, ${profile.minutesPerSession} min',
      ),
      (
        'Preferencias',
        profile.preferences.isEmpty ? 'Sin preferencias' : profile.preferences,
      ),
      ('Limitaciones', profile.limitations),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar evaluación')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Tu perfil de entrenamiento',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Confirma que la información sea correcta antes de preparar tu rutina.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: rows
                    .map(
                      (row) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                row.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(child: Text(row.$2)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'La rutina usa el catálogo local de ejercicios. Debe validarse con el equipo real del gimnasio antes de publicarse.',
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onOpenAiChat();
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Continuar en el Chat IA'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Editar evaluación'),
          ),
        ],
      ),
    );
  }
}
