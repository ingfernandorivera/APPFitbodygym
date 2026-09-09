import 'package:flutter/material.dart';

import '../../training/data/workout_history_store.dart';
import '../../training/models/workout_session.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late Future<List<WorkoutSession>> historyFuture;

  @override
  void initState() {
    super.initState();
    historyFuture = WorkoutHistoryStore().load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorkoutSession>>(
      future: historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final history = snapshot.data ?? [];
        final completedExercises = history.fold<int>(
          0,
          (total, session) => total + session.completedExercises,
        );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tu progreso',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Entrenamientos',
                    value: '${history.length}',
                    icon: Icons.event_available_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Ejercicios',
                    value: '$completedExercises',
                    icon: Icons.fitness_center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Historial reciente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Icon(Icons.show_chart, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Completa un entrenamiento para comenzar a medir tu progreso.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...history
                  .take(20)
                  .map(
                    (session) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.check)),
                        title: Text(
                          'Día ${session.dayNumber}: ${session.dayTitle}',
                        ),
                        subtitle: Text(
                          '${session.completedExercises} de ${session.results.length} ejercicios · ${_date(session.completedAt)}',
                        ),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    );
  }
}
