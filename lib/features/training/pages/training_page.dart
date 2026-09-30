import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../data/exercise_catalog_repository.dart';
import '../data/workout_history_store.dart';
import '../data/workout_plan_store.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import 'exercise_library_page.dart';
import 'workout_result_page.dart';
import 'workout_session_page.dart';

class _TrainingPageStateData {
  const _TrainingPageStateData({
    required this.plan,
    required this.history,
    this.manualAdvanceTimestamp,
    this.cycleResetTimestamp,
  });

  final WorkoutPlan? plan;
  final List<WorkoutSession> history;
  final DateTime? manualAdvanceTimestamp;
  final DateTime? cycleResetTimestamp;
}

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
  late Future<_TrainingPageStateData> pageDataFuture;
  late final store =
      widget.planStore ?? WorkoutPlanStore(storageUserId: widget.storageUserId);
  late final historyStore =
      widget.historyStore ??
      WorkoutHistoryStore(storageUserId: widget.storageUserId);
  CatalogResult? catalogResult;
  bool hasUnclaimedLegacy = false;
  bool importingLegacy = false;

  Future<_TrainingPageStateData> load() async {
    catalogResult = await widget.repository.loadResult();
    await _checkLegacy();
    final plan = await store.load();
    final history = await historyStore.load();

    DateTime? manualAdvance;
    DateTime? cycleReset;
    try {
      final prefs = await SharedPreferences.getInstance();
      final advanceStr = prefs.getString(
        'plan_week_advance_${plan?.id}_${store.storage.userId}',
      );
      if (advanceStr != null) {
        manualAdvance = DateTime.tryParse(advanceStr);
      }
      final resetStr = prefs.getString(
        'plan_cycle_reset_${plan?.id}_${store.storage.userId}',
      );
      if (resetStr != null) {
        cycleReset = DateTime.tryParse(resetStr);
      }
    } catch (_) {}

    if (plan == null) {
      return _TrainingPageStateData(
        plan: null,
        history: history,
        manualAdvanceTimestamp: manualAdvance,
        cycleResetTimestamp: cycleReset,
      );
    }
    final media = {for (final e in catalogResult!.exercises) e.stableId: e};
    final enrichedPlan = plan.copyWith(
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

    return _TrainingPageStateData(
      plan: enrichedPlan,
      history: history,
      manualAdvanceTimestamp: manualAdvance,
      cycleResetTimestamp: cycleReset,
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
    pageDataFuture = load();
    WorkoutPlanStore.changes.addListener(reload);
    WorkoutHistoryStore.changes.addListener(reload);
  }

  void reload() {
    if (mounted) {
      setState(() {
        pageDataFuture = load();
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

  String _formatCompletion(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (isToday) {
      return 'Hoy · $timeStr';
    } else if (isYesterday) {
      return 'Ayer · $timeStr';
    } else {
      const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final dayName = days[dt.weekday - 1];
      return '$dayName · $timeStr';
    }
  }

  Future<void> _advanceWeek(WorkoutPlan plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'plan_week_advance_${plan.id}_${store.storage.userId}',
        DateTime.now().toIso8601String(),
      );
      reload();
    } catch (_) {}
  }

  Future<void> _resetPlanCycles(WorkoutPlan plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('plan_week_advance_${plan.id}_${store.storage.userId}');
      await prefs.setString(
        'plan_cycle_reset_${plan.id}_${store.storage.userId}',
        DateTime.now().toIso8601String(),
      );
      reload();
    } catch (_) {}
  }

  Widget _buildRoutineCard({
    required WorkoutPlan plan,
    required WorkoutDay day,
    required bool isCompleted,
    required bool isCurrentDay,
    WorkoutSession? session,
  }) {
    final durationMin = day.exercises.length * 4 + 10;
    final letter = _letterForDay(day.dayNumber);
    final titleText = day.focus.isNotEmpty ? day.focus : day.title;

    final cardBg = isCompleted
        ? const Color(0xFF141417)
        : const Color(0xFF1B1B1E);
    final borderColor = isCompleted
        ? const Color(0xFF222228)
        : (isCurrentDay
            ? AppColors.brand.withValues(alpha: 0.5)
            : const Color(0xFF2B2B32));

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
        if (completed == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entrenamiento guardado en Progreso.'),
            ),
          );
          reload();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge para la rutina en curso (pendiente activa)
            if (isCurrentDay && !isCompleted) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'En curso',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            // Badge verde para la rutina terminada esta semana
            if (isCompleted && session != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF132A1C),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF235336)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 13,
                      color: Color(0xFF2ECC71),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Terminada esta semana · ${_formatCompletion(session.completedAt)}',
                      style: const TextStyle(
                        color: Color(0xFF2ECC71),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                // Badge con letra A, B, C...
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF25252B)
                        : AppColors.brand,
                    borderRadius: BorderRadius.circular(10),
                    border: isCompleted
                        ? Border.all(
                            color: const Color(0xFF2ECC71).withValues(alpha: 0.6),
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: isCompleted
                            ? const Color(0xFF2ECC71)
                            : Colors.white,
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
                        style: TextStyle(
                          color: isCompleted ? Colors.white70 : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted
                            ? '$durationMin min · ${day.exercises.length} ejercicios · Realizada'
                            : '$durationMin min · ${day.exercises.length} ejercicios',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isCompleted ? Icons.check_circle_outline : Icons.chevron_right,
                  color: isCompleted
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFF7E7E88),
                  size: 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TrainingPageStateData>(
      future: pageDataFuture,
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
        final data = snapshot.data;
        final plan = data?.plan;

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
                          color: AppColors.brand,
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
                        builder: (_) => ExerciseLibraryPage(
                          repository: widget.repository,
                        ),
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
              // Tarjeta de recuperación legacy segura
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
                        const Icon(
                          Icons.history_rounded,
                          color: AppColors.brand,
                        ),
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
                          onPressed:
                              importingLegacy ? null : _promptRecoverLegacy,
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
                        color: AppColors.brand,
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
                // CÁLCULO DE CICLOS, SEMANAS Y ESTADO DE RUTINAS
                () {
                  final history = data?.history ?? const [];
                  final cycleReset = data?.cycleResetTimestamp;

                  final relevantHistory = cycleReset == null
                      ? history
                      : history
                          .where((s) => s.completedAt.isAfter(cycleReset))
                          .toList();

                  final now = DateTime.now();
                  final currentMonday = DateTime(now.year, now.month, now.day)
                      .subtract(Duration(days: now.weekday - 1));

                  DateTime weekStart = currentMonday;
                  if (data?.manualAdvanceTimestamp != null &&
                      data!.manualAdvanceTimestamp!.isAfter(currentMonday)) {
                    weekStart = data.manualAdvanceTimestamp!;
                  }

                  final planSessions = relevantHistory.where((s) {
                    final match = s.planId == plan.id ||
                        (s.planId == null && s.planName == plan.name);
                    return match && s.completedExercises > 0;
                  }).toList();

                  final sessionsThisWeek = planSessions
                      .where((s) => s.completedAt.isAfter(weekStart))
                      .toList();

                  final completedDaysThisWeek = <int, WorkoutSession>{};
                  for (final s in sessionsThisWeek) {
                    final existing = completedDaysThisWeek[s.dayNumber];
                    if (existing == null ||
                        s.completedAt.isAfter(existing.completedAt)) {
                      completedDaysThisWeek[s.dayNumber] = s;
                    }
                  }

                  final pendingDays = plan.days
                      .where(
                        (d) => !completedDaysThisWeek.containsKey(d.dayNumber),
                      )
                      .toList();
                  final completedDays = plan.days
                      .where(
                        (d) => completedDaysThisWeek.containsKey(d.dayNumber),
                      )
                      .toList();

                  final nextActiveDayNumber = pendingDays.isNotEmpty
                      ? pendingDays.first.dayNumber
                      : null;

                  final daysCount = plan.days.isEmpty ? 1 : plan.days.length;
                  final totalCompletedSessions = planSessions.length;
                  final completedCycles = totalCompletedSessions ~/ daysCount;
                  final isWeekCompleted =
                      pendingDays.isEmpty && plan.days.isNotEmpty;
                  final isPlanFullyCompleted =
                      completedCycles >= plan.totalWeeks && isWeekCompleted;
                  final currentWeek = isWeekCompleted
                      ? (completedCycles > 0 ? completedCycles : 1)
                          .clamp(1, plan.totalWeeks)
                      : (completedCycles + 1).clamp(1, plan.totalWeeks);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // MARCADOR DE SEMANAS Y PROGRESO DEL PLAN
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E1E22), Color(0xFF151518)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2C2C34)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          AppColors.brand.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 13,
                                        color: AppColors.brand,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Semana $currentWeek de ${plan.totalWeeks}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${completedDays.length}/${plan.days.length} completadas',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: plan.days.isEmpty
                                    ? 0.0
                                    : (completedDays.length / plan.days.length)
                                        .clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: const Color(0xFF282830),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isWeekCompleted
                                      ? const Color(0xFF2ECC71)
                                      : AppColors.brand,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (isPlanFullyCompleted) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.emoji_events_rounded,
                                    size: 18,
                                    color: Color(0xFF2ECC71),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '¡Felicidades! Has completado las ${plan.totalWeeks} semanas de tu plan.',
                                      style: const TextStyle(
                                        color: Color(0xFF2ECC71),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Color(0xFF2ECC71),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  onPressed: () => _resetPlanCycles(plan),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                    color: Color(0xFF2ECC71),
                                  ),
                                  label: const Text(
                                    'Reiniciar ciclo del plan',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ] else if (isWeekCompleted) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: Color(0xFF2ECC71),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '¡Semana $currentWeek completada! Todas las rutinas terminadas.',
                                      style: const TextStyle(
                                        color: Color(0xFF2ECC71),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  onPressed: () => _advanceWeek(plan),
                                  icon: const Icon(
                                    Icons.fast_forward_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Comenzar Semana ${currentWeek + 1} ahora',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Completa las rutinas programadas para avanzar en tu plan de ${plan.totalWeeks} semanas.',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // LISTADO DE RUTINAS PENDIENTES
                      if (pendingDays.isNotEmpty) ...[
                        ...pendingDays.map((day) {
                          return _buildRoutineCard(
                            plan: plan,
                            day: day,
                            isCompleted: false,
                            isCurrentDay: day.dayNumber == nextActiveDayNumber,
                          );
                        }),
                      ],

                      // LISTADO DE RUTINAS COMPLETADAS ESTA SEMANA (SE MUEVEN ABAJO)
                      if (completedDays.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF2ECC71),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Completadas esta semana (${completedDays.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...completedDays.map((day) {
                          return _buildRoutineCard(
                            plan: plan,
                            day: day,
                            isCompleted: true,
                            isCurrentDay: false,
                            session: completedDaysThisWeek[day.dayNumber],
                          );
                        }),
                      ],
                    ],
                  );
                }(),
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
