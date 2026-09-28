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

  String _letterForDay(int dayNumber) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    if (dayNumber >= 1 && dayNumber <= letters.length) {
      return letters[dayNumber - 1];
    }
    return '$dayNumber';
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
        return Material(
          color: Colors.transparent,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
            // Encabezado tipo Smart Fit (Screenshot 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rutinas',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF33333A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseLibraryPage(
                            repository: widget.repository,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.menu_book_outlined, size: 16),
                      label: const Text(
                        'Biblioteca',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Pestañas / Tabs Smart | Explorar | Guardados (Screenshot 1)
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Smart',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 44,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ExerciseLibraryPage(repository: widget.repository),
                    ),
                  ),
                  child: const Text(
                    'Explorar',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (plan != null) ...[
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkoutResultPage(plan: plan),
                      ),
                    ),
                    child: const Text(
                      'Guardados',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            // Descripción de la anamnesis (Screenshot 1)
            const Text(
              'Entrenamiento prescrito por FitBody Gym, de acuerdo con lo identificado en tu anamnesis y evaluación.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            if (catalogResult != null &&
                catalogResult!.source != CatalogSource.remote)
              ListTile(
                title: Text(catalogResult!.message ?? 'Catálogo local'),
                trailing: TextButton(
                  onPressed: reload,
                  child: const Text('Reintentar'),
                ),
              ),
            // Tarjeta de recuperación legacy segura (Hermes)
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
            const SizedBox(height: 14),
            if (plan == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 52,
                      color: Color(0xFFFFB800),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Aún no tienes una rutina activa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Créala desde el botón principal de Inicio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            else ...[
              // Listado de rutinas catalogadas por día (Screenshot 1)
              ...plan.days.map((day) {
                final isCurrentDay = day.dayNumber == 1;
                final durationMin = day.exercises.length * 4 + 10;
                final letter = _letterForDay(day.dayNumber);
                final titleText = day.focus.isNotEmpty ? day.focus : day.title;

                return InkWell(
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
                          content: Text('Entrenamiento guardado en Progreso.'),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2B2B32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Etiqueta "En curso" para la rutina activa (Screenshot 1)
                        if (isCurrentDay) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB800),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'En curso',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        Row(
                          children: [
                            // Badge con letra A, B, C... en dorado (Screenshot 1)
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC89314),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Título de grupos musculares y duración
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$durationMin min · ${day.exercises.length} ejercicios',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF7E7E88),
                              size: 24,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              // Enlace discreto para ver ficha técnica de la rutina completa
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutResultPage(plan: plan),
                    ),
                  ),
                  icon: const Icon(
                    Icons.assignment_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  label: Text(
                    '${plan.name} (${plan.days.length} días · ${plan.goal})',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      );
    },
  );
  }
}
