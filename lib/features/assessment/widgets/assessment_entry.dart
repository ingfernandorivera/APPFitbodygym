import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/training_profile_store.dart';
import '../models/training_profile.dart';
import '../pages/training_assessment_page.dart';
import '../pages/training_profile_summary_page.dart';

class AssessmentEntry extends StatefulWidget {
  const AssessmentEntry({
    super.key,
    required this.store,
    required this.membershipActive,
    this.onOpenAiChat,
    this.onOpenInfo,
    this.openAutomatically = false,
  });
  final TrainingProfileStore store;
  final bool membershipActive;
  final VoidCallback? onOpenAiChat;
  final VoidCallback? onOpenInfo;
  final bool openAutomatically;

  @override
  State<AssessmentEntry> createState() => _AssessmentEntryState();
}

class _AssessmentEntryState extends State<AssessmentEntry> {
  TrainingProfile? profile;
  bool hasDraft = false;
  bool loading = true;
  bool opening = false;
  bool automaticChecked = false;
  String? error;

  @override
  void initState() {
    super.initState();
    TrainingProfileStore.changes.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    TrainingProfileStore.changes.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final saved = await widget.store.load();
      final draft = await widget.store.loadDraft();
      if (!mounted) return;
      setState(() {
        profile = saved;
        hasDraft = draft != null;
        error = null;
        loading = false;
      });
      if (!automaticChecked && widget.openAutomatically) {
        automaticChecked = true;
        if (saved == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) open(edit: true);
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'No se pudo leer tu evaluación.';
          loading = false;
        });
      }
    }
  }

  Future<void> open({bool edit = false, int? initialStep}) async {
    if (opening || loading) return;
    opening = true;
    try {
      var current = await widget.store.load();
      if (!mounted) return;
      var shouldEdit = edit || current == null || hasDraft;
      int? targetStep = initialStep;
      while (mounted) {
        if (shouldEdit) {
          if (!mounted) break;
          final saved = await Navigator.push<TrainingProfile>(
            context,
            MaterialPageRoute(
              builder: (_) => TrainingAssessmentPage(
                initialProfile: current,
                store: widget.store,
                initialStep: targetStep,
              ),
            ),
          );
          if (!mounted || saved == null) break;
          current = saved;
          targetStep = null;
        }
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
            builder: (_) => TrainingProfileSummaryPage(
              profile: current!,
              membershipActive: widget.membershipActive,
              onOpenAiChat: widget.onOpenAiChat,
              onOpenInfo: widget.onOpenInfo,
            ),
          ),
        );
        if (result == null || (result is bool && !result)) break;
        shouldEdit = true;
        if (result is int) {
          targetStep = result;
        } else {
          targetStep = null;
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudo abrir tu evaluación. Reintenta.');
      }
    } finally {
      opening = false;
      if (mounted) reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasDraft
              ? Colors.amber.withValues(alpha: 0.4)
              : profile != null
              ? AppColors.brand.withValues(alpha: 0.3)
              : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status row with athletic icon and badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (hasDraft
                                ? Colors.amber
                                : profile != null
                                ? AppColors.brand
                                : AppColors.brand)
                            .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasDraft
                        ? Icons.edit_note_rounded
                        : profile != null
                        ? Icons.verified_rounded
                        : Icons.fitness_center_rounded,
                    size: 26,
                    color: hasDraft
                        ? Colors.amber
                        : profile != null
                        ? AppColors.brand
                        : AppColors.brand,
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
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (hasDraft
                                      ? Colors.amber
                                      : profile != null
                                      ? AppColors.brand
                                      : Colors.white24)
                                  .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasDraft
                              ? 'PROGRESO GUARDADO'
                              : profile != null
                              ? 'EVALUACIÓN LISTA'
                              : 'PASO 1 DE TU RUTA',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: hasDraft
                                ? Colors.amber
                                : profile != null
                                ? AppColors.brand
                                : AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        profile == null
                            ? 'Empieza por conocerte'
                            : 'Tu punto de partida',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              profile == null
                  ? 'Cuéntanos tus objetivos y tu ritmo. Puedes completar esta evaluación con o sin membresía activa.'
                  : 'Revisa tus respuestas y ajústalas cuando lo necesites.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            if (profile != null && !hasDraft) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      size: 16,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${profile!.goal} · ${profile!.daysPerWeek} días/sem · ${profile!.minutesPerSession} min',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (error != null) ...[
              Text(error!),
              TextButton(onPressed: reload, child: const Text('Reintentar')),
            ] else
              FilledButton.icon(
                onPressed: loading ? null : () => open(),
                icon: Icon(
                  hasDraft ? Icons.play_arrow : Icons.assignment_outlined,
                ),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    loading
                        ? 'Cargando evaluación…'
                        : hasDraft
                        ? 'Reanudar evaluación'
                        : profile == null
                        ? 'Comenzar evaluación'
                        : 'Ver mi evaluación',
                  ),
                ),
              ),
            if (profile != null && !hasDraft && error == null)
              TextButton.icon(
                onPressed: () => open(edit: true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar evaluación'),
              ),
          ],
        ),
      ),
    );
  }
}
