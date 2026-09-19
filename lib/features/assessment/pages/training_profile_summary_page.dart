import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/assessment_rules.dart';
import '../models/assessment_step.dart';
import '../models/training_profile.dart';

class TrainingProfileSummaryPage extends StatelessWidget {
  const TrainingProfileSummaryPage({
    super.key,
    required this.profile,
    this.onOpenAiChat,
    this.onOpenInfo,
    this.membershipActive = false,
  });

  final TrainingProfile profile;
  final VoidCallback? onOpenAiChat;
  final VoidCallback? onOpenInfo;
  final bool membershipActive;

  String weight(double value) =>
      '${weightFromKg(value, profile.weightUnit).toStringAsFixed(1)} ${profile.weightUnit}';

  int _stepFor(String key) {
    final idx = assessmentSteps.indexWhere((s) => s.key == key);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tu evaluación'), centerTitle: false),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // Hero Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.brand,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'EVALUACIÓN GUARDADA',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ya tienes un punto de partida',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tu objetivo es ${profile.goal.toLowerCase()}. Has elegido dedicar '
                        '${profile.daysPerWeek * profile.minutesPerSession} minutos por semana. '
                        'Puedes ajustar este compromiso a medida que descubras qué funciona para ti.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Quick highlight metric chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetricChip(
                            icon: Icons.flag_rounded,
                            label: profile.goal,
                          ),
                          _MetricChip(
                            icon: Icons.calendar_today_rounded,
                            label: '${profile.daysPerWeek} días/sem',
                          ),
                          _MetricChip(
                            icon: Icons.timer_outlined,
                            label: '${profile.minutesPerSession} min/sesión',
                          ),
                          _MetricChip(
                            icon: Icons.place_outlined,
                            label: profile.trainingLocation,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 1: Objetivo y Motivación
                _SummarySectionCard(
                  title: 'Objetivo y Motivación',
                  icon: Icons.track_changes_rounded,
                  onEdit: () => Navigator.pop(context, _stepFor('goal')),
                  items: [
                    _SummaryItem('Objetivo principal', profile.goal),
                    _SummaryItem('Nivel de experiencia', profile.experience),
                    _SummaryItem(
                      'Motivaciones',
                      profile.motivations.isEmpty
                          ? 'Sin indicar'
                          : profile.motivations.join(', '),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 2: Disponibilidad y Rutina
                _SummarySectionCard(
                  title: 'Disponibilidad y Horarios',
                  icon: Icons.schedule_rounded,
                  onEdit: () => Navigator.pop(context, _stepFor('daysPerWeek')),
                  items: [
                    _SummaryItem(
                      'Frecuencia semanal',
                      '${profile.daysPerWeek} días por semana',
                    ),
                    _SummaryItem(
                      'Duración por sesión',
                      '${profile.minutesPerSession} min por sesión',
                    ),
                    _SummaryItem('Momento preferido', profile.schedule),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 3: Lugar y Equipamiento
                _SummarySectionCard(
                  title: 'Lugar y Equipamiento',
                  icon: Icons.fitness_center_rounded,
                  onEdit: () =>
                      Navigator.pop(context, _stepFor('trainingLocation')),
                  items: [
                    _SummaryItem('Dónde entrenarás', profile.trainingLocation),
                    _SummaryItem('Equipamiento disponible', profile.equipment),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 4: Físico y Silueta
                _SummarySectionCard(
                  title: 'Enfoque Físico y Zonas',
                  icon: Icons.accessibility_new_rounded,
                  onEdit: () =>
                      Navigator.pop(context, _stepFor('priorityMuscles')),
                  items: [
                    _SummaryItem(
                      'Zonas prioritarias',
                      profile.priorityMuscles.isEmpty
                          ? 'Sin zonas prioritarias'
                          : profile.priorityMuscles.join(', '),
                    ),
                    _SummaryItem('Forma autoseleccionada', profile.bodyShape),
                    if (profile.bodyFatEstimate != null)
                      _SummaryItem(
                        'Estimación visual personal',
                        '${visualFatRange(profile.bodyFatEstimate!)} · orientativa, no médica',
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 5: Medidas y Hábitos
                _SummarySectionCard(
                  title: 'Medidas y Hábitos de Vida',
                  icon: Icons.monitor_heart_outlined,
                  onEdit: () => Navigator.pop(context, _stepFor('weight')),
                  items: [
                    _SummaryItem(
                      'Edad y Altura',
                      '${profile.age} años · ${profile.heightCm.toStringAsFixed(0)} cm',
                    ),
                    _SummaryItem('Peso actual', weight(profile.weightKg)),
                    _SummaryItem(
                      'Peso objetivo',
                      profile.targetWeightKg == null
                          ? 'Sin objetivo de peso'
                          : weight(profile.targetWeightKg!),
                    ),
                    _SummaryItem('Actividad cotidiana', profile.dailyActivity),
                    _SummaryItem(
                      'Sueño',
                      profile.sleepHours == null
                          ? 'Sin indicar'
                          : '${profile.sleepHours} horas por noche',
                    ),
                    _SummaryItem(
                      'Agua',
                      profile.hydrationLiters == null
                          ? 'Sin indicar'
                          : '${profile.hydrationLiters} L al día',
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 6: Seguridad y Preferencias
                _SummarySectionCard(
                  title: 'Seguridad y Preferencias',
                  icon: Icons.health_and_safety_rounded,
                  onEdit: () => Navigator.pop(context, _stepFor('limitations')),
                  items: [
                    _SummaryItem(
                      'Molestias',
                      profile.limitations.isEmpty
                          ? 'Sin molestias registradas'
                          : profile.limitations,
                    ),
                    if (profile.preferences.isNotEmpty)
                      _SummaryItem('Preferencias', profile.preferences),
                  ],
                ),
                const SizedBox(height: 24),

                // Next Step Card & Membership Status
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: membershipActive
                          ? AppColors.brand.withValues(alpha: 0.3)
                          : Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            membershipActive
                                ? Icons.verified_rounded
                                : Icons.info_outline_rounded,
                            color: membershipActive
                                ? AppColors.brand
                                : Colors.amber,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tu próximo paso',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        membershipActive
                            ? 'Revisa tus respuestas y prepara tu rutina con el asistente. Si tienes molestias, consulta con un profesional antes de realizar movimientos que las agraven.'
                            : 'Tu evaluación ya está guardada. Consulta en recepción cómo vincular o renovar tu membresía para acceder a entrenamiento, Chat IA y progreso. Puedes seguir editando tu evaluación.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Este resumen recoge tus respuestas. No es una valoración médica ni predice cambios físicos o fechas de resultados.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          if (membershipActive) {
                            onOpenAiChat?.call();
                          } else {
                            onOpenInfo?.call();
                          }
                        },
                        icon: Icon(
                          membershipActive
                              ? Icons.chat_bubble_outline
                              : Icons.info_outline,
                        ),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            membershipActive
                                ? 'Preparar mi rutina en Chat IA'
                                : 'Consultar información del gimnasio',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Editar evaluación'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brand),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value);
  final String label;
  final String value;
}

class _SummarySectionCard extends StatelessWidget {
  const _SummarySectionCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.onEdit,
  });

  final String title;
  final IconData icon;
  final List<_SummaryItem> items;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Edit button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Editar',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 16, color: Colors.white10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
