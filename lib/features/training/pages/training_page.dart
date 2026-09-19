import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/exercise_catalog_repository.dart';
import '../data/workout_history_store.dart';
import '../data/workout_plan_store.dart';
import '../models/workout_plan.dart';
import 'exercise_library_page.dart';
import 'workout_result_page.dart';
import 'workout_session_page.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({
    super.key,
    this.planStore,
    this.historyStore,
    this.storageUserId,
    this.repository = const ExerciseCatalogRepository(),
  });
  final WorkoutPlanStore? planStore;
  final WorkoutHistoryStore? historyStore;
  final String? storageUserId;
  final ExerciseCatalogRepository repository;

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  late Future<WorkoutPlan?> planFuture;
  late final store =
      widget.planStore ?? WorkoutPlanStore(storageUserId: widget.storageUserId);
  late final historyStore =
      widget.historyStore ??
      WorkoutHistoryStore(storageUserId: widget.storageUserId);
  CatalogResult? catalogResult;
  bool hasUnclaimedLegacy = false;
  bool importingLegacy = false;

  Future<WorkoutPlan?> load() async {
    catalogResult = await widget.repository.loadResult();
    await _checkLegacy();
    final plan = await store.load();
    if (plan == null) return null;
    final media = {for (final e in catalogResult!.exercises) e.stableId: e};
    return plan.copyWith(
      days: plan.days
          .map(
            (d) => WorkoutDay(
              dayNumber: d.dayNumber,
              title: d.title,
              focus: d.focus,
              exercises: d.exercises
                  .map(
                    (e) => e.copyWith(
                      mediaUrl: media[e.stableId]?.mediaUrl,
                      mediaStatus: media[e.stableId]?.mediaStatus,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  Future<void> _checkLegacy() async {
    try {
      final p = await store.hasUnclaimedLegacy();
      final h = await historyStore.hasUnclaimedLegacy();
      if (mounted) {
        setState(() {
          hasUnclaimedLegacy = p || h;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          hasUnclaimedLegacy = false;
        });
      }
    }
  }

  Future<void> _promptRecoverLegacy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar datos anteriores'),
        content: const Text(
          'Se encontraron datos de una versión anterior en este dispositivo.\n\n'
          'Solo debes continuar si estos datos te pertenecen. Tras confirmar, '
          'se importarán a tu cuenta actual y ninguna otra cuenta podrá reclamarlos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar importación'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _executeRecoverLegacy();
    }
  }

  Future<void> _executeRecoverLegacy() async {
    setState(() => importingLegacy = true);
    var planSuccess = true;
    var historySuccess = true;
    String? planError;
    String? historyError;

    final hasPlan = await store.hasUnclaimedLegacy();
    final hasHistory = await historyStore.hasUnclaimedLegacy();

    if (hasPlan) {
      try {
        await store.importLegacy();
      } catch (e) {
        planSuccess = false;
        planError = e.toString();
      }
    }

    if (hasHistory) {
      try {
        await historyStore.importLegacy();
      } catch (e) {
        historySuccess = false;
        historyError = e.toString();
      }
    }

    // Comprobar lectura de vuelta para garantizar que está escrito y verificado
    final verifiedPlan = hasPlan && planSuccess ? await store.load() : null;
    final verifiedHistory = hasHistory && historySuccess
        ? await historyStore.load()
        : null;

    final planVerified = !hasPlan || (planSuccess && verifiedPlan != null);
    final historyVerified =
        !hasHistory || (historySuccess && verifiedHistory != null);

    if (!mounted) return;
    setState(() => importingLegacy = false);

    if (planVerified && historyVerified && (hasPlan || hasHistory)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos anteriores recuperados con éxito.'),
        ),
      );
    } else if (planVerified || historyVerified) {
      final detail = planError ?? historyError ?? 'error de verificación';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recuperación parcial: algunos datos no se pudieron importar ($detail). Puedes reintentar.',
          ),
        ),
      );
    } else {
      final detail = planError ?? historyError ?? 'error desconocido';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron recuperar los datos anteriores ($detail). Puedes reintentar.',
          ),
        ),
      );
    }
    reload();
  }

  @override
  void initState() {
    super.initState();
    planFuture = load();
    WorkoutPlanStore.changes.addListener(reload);
    WorkoutHistoryStore.changes.addListener(reload);
  }

  void reload() {
    if (mounted) {
      setState(() {
        planFuture = load();
      });
    }
  }

  @override
  void dispose() {
    WorkoutPlanStore.changes.removeListener(reload);
    WorkoutHistoryStore.changes.removeListener(reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkoutPlan?>(
      future: planFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: reload,
              child: const Text('No se pudo cargar la rutina. Reintentar'),
            ),
          );
        }
        final plan = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Entrenamiento',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Biblioteca de ejercicios',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ExerciseLibraryPage(repository: widget.repository),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                ),
              ],
            ),
            if (catalogResult != null &&
                catalogResult!.source != CatalogSource.remote)
              ListTile(
                title: Text(catalogResult!.message ?? 'Catálogo local'),
                trailing: TextButton(
                  onPressed: reload,
                  child: const Text('Reintentar'),
                ),
              ),
            if (hasUnclaimedLegacy) ...[
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppColors.brand),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Datos de una versión anterior',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Se encontraron entrenamientos guardados en este dispositivo.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: importingLegacy
                            ? null
                            : _promptRecoverLegacy,
                        child: importingLegacy
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Recuperar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (plan == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.fitness_center, size: 52),
                    SizedBox(height: 16),
                    Text(
                      'Aún no tienes una rutina activa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Créala desde el botón principal de Inicio.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    child: Icon(Icons.assignment_outlined),
                  ),
                  title: Text(plan.name),
                  subtitle: Text(
                    '${plan.days.length} días por semana · ${plan.goal}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutResultPage(plan: plan),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Entrenamiento del día',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ...plan.days.map(
                (day) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(child: Text('${day.dayNumber}')),
                    title: Text(day.title),
                    subtitle: Text(
                      '${day.focus}\n${day.exercises.length} ejercicios',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () async {
                      final completed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkoutSessionPage(
                            planName: plan.name,
                            day: day,
                            planId: plan.id,
                            planVersion: plan.version,
                            storageUserId: store.storage.userId,
                            historyStore: historyStore,
                          ),
                        ),
                      );
                      if (completed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Entrenamiento guardado en Progreso.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
