import 'package:flutter/material.dart';
import '../../training/data/workout_history_store.dart';
import '../../training/data/workout_plan_store.dart';
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
  late Future<(List<WorkoutSession>, ProgressMetrics)> future;
  Future<(List<WorkoutSession>, ProgressMetrics)> load() async {
    final history = await historyStore.load();
    final plan = await planStore.load();
    return (history, ProgressMetrics(history, plan: plan));
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
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(List<WorkoutSession>, ProgressMetrics)>(
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
      final (history, m) = snapshot.data!;
      return RefreshIndicator(
        onRefresh: () async {
          reload();
          await future;
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tu progreso',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sesiones esta semana: ${m.sessionsThisWeek}'),
                    Text(
                      m.adherence == null
                          ? 'Adherencia: sin plan activo'
                          : 'Adherencia semanal: ${(m.adherence! * 100).round()} % de días del plan',
                    ),
                    Text(
                      'Volumen total: ${m.totalVolume.toStringAsFixed(1)} kg·reps',
                    ),
                    Text(
                      'Tiempo entrenado: ${(m.durationSeconds / 60).floor()} min',
                    ),
                    Text(
                      'Omitidos: ${m.skippedExercises} ejercicios · ${m.skippedSets} series',
                    ),
                    const Text(
                      'El tiempo no registrado en sesiones antiguas cuenta como 0. La mejor serie prioriza carga y después repeticiones; excluye calentamiento.',
                    ),
                  ],
                ),
              ),
            ),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  'Completa un entrenamiento para comenzar a medir tu progreso.',
                ),
              ),
            ...m.exercises.values.map(
              (e) => Card(
                child: ListTile(
                  title: Text(e.name),
                  subtitle: Text(
                    'Mejor: ${series(e.best)}\nEvolución: ${series(e.first)} → ${series(e.latest)}',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Historial reciente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...history
                .take(20)
                .map(
                  (s) => Card(
                    child: ListTile(
                      title: Text('Día ${s.dayNumber}: ${s.dayTitle}'),
                      subtitle: Text(
                        '${s.completedExercises} de ${s.results.length} ejercicios · ${s.completedAt.toLocal().toString().substring(0, 16)}',
                      ),
                    ),
                  ),
                ),
          ],
        ),
      );
    },
  );
}
