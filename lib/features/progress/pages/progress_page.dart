import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../training/data/workout_history_store.dart';
import '../../training/data/workout_plan_store.dart';
import '../../training/models/workout_plan.dart';
import '../../training/models/workout_session.dart';
import '../models/progress_metrics.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({
    super.key,
    this.historyStore,
    this.planStore,
    this.storageUserId,
  });
  final WorkoutHistoryStore? historyStore;
  final WorkoutPlanStore? planStore;
  final String? storageUserId;

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late final historyStore =
      widget.historyStore ??
      WorkoutHistoryStore(storageUserId: widget.storageUserId);
  late final planStore =
      widget.planStore ?? WorkoutPlanStore(storageUserId: widget.storageUserId);
  late Future<(List<WorkoutSession>, WorkoutPlan?, ProgressMetrics)> future;

  Future<(List<WorkoutSession>, WorkoutPlan?, ProgressMetrics)> load() async {
    final history = await historyStore.load();
    final plan = await planStore.load();
    return (history, plan, ProgressMetrics(history, plan: plan));
  }

  @override
  void initState() {
    super.initState();
    future = load();
    WorkoutHistoryStore.changes.addListener(reload);
    WorkoutPlanStore.changes.addListener(reload);
  }

  void reload() {
    if (mounted) setState(() => future = load());
  }

  @override
  void dispose() {
    WorkoutHistoryStore.changes.removeListener(reload);
    WorkoutPlanStore.changes.removeListener(reload);
    super.dispose();
  }

  String series(SetResult? s) =>
      s == null ? 'Sin datos' : '${s.weightKg} kg × ${s.repetitions}';

  Set<int> _trainedWeekdaysThisWeek(List<WorkoutSession> history) {
    final today = DateTime.now().toLocal();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final end = start.add(const Duration(days: 7));
    final days = <int>{};
    for (final s in history) {
      final dt = s.completedAt.toLocal();
      if (!dt.isBefore(start) && dt.isBefore(end)) {
        days.add(dt.weekday);
      }
    }
    return days;
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<(List<WorkoutSession>, WorkoutPlan?, ProgressMetrics)>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: reload,
                child: const Text('No se pudo cargar el progreso. Reintentar'),
              ),
            );
          }
          final (history, plan, m) = snapshot.data!;
          final trainedWeekdays = _trainedWeekdaysThisWeek(history);
          final todayWeekday = DateTime.now().toLocal().weekday;
          final adherencePct = m.adherence == null
              ? 0.0
              : m.adherence!.clamp(0.0, 1.0);
          final totalMinutes = (m.durationSeconds / 60).floor();

          return RefreshIndicator(
            onRefresh: () async {
              reload();
              await future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              children: [
                // Encabezado del Dashboard
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tu progreso',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Panel de rendimiento, cargas y constancia semanal',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 15,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${history.length} sesiones',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Bloque Hero: Adherencia Semanal + Actividad por Día
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.surfaceHigh,
                        AppColors.surface,
                        const Color(0xFF140507),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              color: AppColors.brand,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'META SEMANAL',
                                  style: TextStyle(
                                    color: AppColors.brand,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m.adherence == null
                                      ? 'Adherencia: sin plan activo'
                                      : 'Adherencia semanal: ${(m.adherence! * 100).round()} % de días del plan',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.outline.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              plan == null
                                  ? '${m.sessionsThisWeek} sem.'
                                  : '${m.sessionsThisWeek}/${plan.days.length} días',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: adherencePct,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            adherencePct >= 1.0
                                ? const Color(0xFF4CAF50)
                                : AppColors.brand,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tira de días de la semana (L a D)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (index) {
                          const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                          final dayNum = index + 1;
                          final trained = trainedWeekdays.contains(dayNum);
                          final isToday = dayNum == todayWeekday;
                          return _WeekDayBadge(
                            label: labels[index],
                            trained: trained,
                            isToday: isToday,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Grid 2x2 de Bloques KPI (Dashboard Bento)
                Row(
                  children: [
                    Expanded(
                      child: _DashboardMetricTile(
                        icon: Icons.event_available_rounded,
                        label: 'Sesiones esta semana',
                        value: '${m.sessionsThisWeek}',
                        unit: 'sesiones',
                        subtitle: 'Sesiones esta semana: ${m.sessionsThisWeek}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DashboardMetricTile(
                        icon: Icons.fitness_center_rounded,
                        label: 'Volumen movilizado',
                        value: m.totalVolume.toStringAsFixed(1),
                        unit: 'kg·reps',
                        subtitle:
                            'Volumen total: ${m.totalVolume.toStringAsFixed(1)} kg·reps',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DashboardMetricTile(
                        icon: Icons.timer_outlined,
                        label: 'Tiempo entrenado',
                        value: '$totalMinutes',
                        unit: 'min',
                        subtitle: 'Tiempo entrenado: $totalMinutes min',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DashboardMetricTile(
                        icon: Icons.fact_check_outlined,
                        label: 'Ejercicios y series omitidos',
                        value: '${m.skippedExercises}',
                        unit: 'ej · ${m.skippedSets} series',
                        subtitle:
                            'Omitidos: ${m.skippedExercises} ejercicios · ${m.skippedSets} series',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Nota informativa compacta de cálculo
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171314),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'El tiempo no registrado en sesiones antiguas cuenta como 0. La mejor serie prioriza carga y después repeticiones; excluye calentamiento.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Sección de Récords y Evolución por Ejercicio
                if (m.exercises.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: AppColors.brand,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Progreso por ejercicio',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${m.exercises.length}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...m.exercises.values.map(
                    (e) => _ExerciseProgressCard(
                      exercise: e,
                      seriesFormatter: series,
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                // Encabezado Historial Reciente
                Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Historial reciente',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (history.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181214),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.outline.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: AppColors.brand,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Completa un entrenamiento para comenzar a medir tu progreso.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Al finalizar tus sesiones en la pestaña Entrenar, aquí aparecerán tus récords de peso, evolución por ejercicio y bitácora.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...history.take(20).map((s) => _SessionHistoryCard(session: s)),
              ],
            ),
          );
        },
      );
}

class _WeekDayBadge extends StatelessWidget {
  const _WeekDayBadge({
    required this.label,
    required this.trained,
    required this.isToday,
  });

  final String label;
  final bool trained;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isToday ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: trained
                ? AppColors.brand
                : Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: trained
                  ? AppColors.brand
                  : isToday
                  ? AppColors.brand.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.1),
              width: isToday && !trained ? 1.5 : 1,
            ),
          ),
          child: Icon(
            trained ? Icons.check_rounded : Icons.remove_rounded,
            size: 16,
            color: trained
                ? Colors.white
                : isToday
                ? AppColors.brand
                : Colors.white24,
          ),
        ),
      ],
    );
  }
}

class _DashboardMetricTile extends StatelessWidget {
  const _DashboardMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1113),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppColors.brand,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 5,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ExerciseProgressCard extends StatelessWidget {
  const _ExerciseProgressCard({
    required this.exercise,
    required this.seriesFormatter,
  });

  final ExerciseProgress exercise;
  final String Function(SetResult?) seriesFormatter;

  @override
  Widget build(BuildContext context) {
    final diffKg = (exercise.latest != null && exercise.first != null)
        ? exercise.latest!.weightKg - exercise.first!.weightKg
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1214),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (diffKg != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: diffKg > 0
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.16)
                        : Colors.orange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${diffKg > 0 ? '+' : ''}${diffKg.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      color: diffKg > 0
                          ? const Color(0xFF66BB6A)
                          : Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Mejor: ${seriesFormatter(exercise.best)}',
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Evolución: ${seriesFormatter(exercise.first)} → ${seriesFormatter(exercise.latest)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionHistoryCard extends StatelessWidget {
  const _SessionHistoryCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final minutes = (session.durationSeconds / 60).floor();
    final dateStr = session.completedAt.toLocal().toString().substring(0, 16);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1214),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'D${session.dayNumber}',
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Día ${session.dayNumber}: ${session.dayTitle}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.completedExercises} de ${session.results.length} ejercicios · $dateStr',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (minutes > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$minutes min',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
