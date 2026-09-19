import 'dart:convert';
import '../../assessment/models/training_profile.dart';
import '../../training/data/training_rules.dart';
import '../../training/data/workout_plan_store.dart';
import '../../training/models/workout_plan.dart';
import '../models/ai_chat_response.dart';

class WorkoutProposalValidator {
  WorkoutProposalValidator(this.catalog);
  final List<WorkoutExercise> catalog;
  List<PlanIssue> validate(
    AiWorkoutAction action, {
    WorkoutPlan? current,
    TrainingProfile? profile,
  }) {
    if (!action.isProposal || action.plan == null) {
      return [
        const PlanIssue(
          'action',
          'propuesta',
          'No hay una propuesta aplicable.',
        ),
      ];
    }
    final issues = WorkoutPlanValidator(
      catalog,
    ).validate(action.plan!, profile: profile);
    if (action.expectedVersion != (current?.version ?? 0) ||
        current != null && action.expectedPlanId != current.id) {
      issues.add(
        const PlanIssue(
          'stale',
          'propuesta',
          'La versión activa cambió. Solicita una nueva propuesta.',
        ),
      );
    }
    if (action.plan!.version != (current?.version ?? 0) + 1) {
      issues.add(
        const PlanIssue(
          'version',
          'propuesta',
          'La nueva versión debe ser consecutiva.',
        ),
      );
    }
    if (current != null && action.plan!.id != current.id) {
      issues.add(
        const PlanIssue(
          'identity',
          'propuesta',
          'La propuesta debe conservar el ID del plan.',
        ),
      );
    }
    if (current == null && action.type != AiActionType.proposeWorkout) {
      issues.add(
        const PlanIssue(
          'missing_plan',
          'propuesta',
          'No existe un plan para modificar.',
        ),
      );
    }
    if (action.type == AiActionType.replaceExercise && current != null) {
      final before = current.days
          .where((d) => d.dayNumber == action.dayNumber)
          .firstOrNull;
      final after = action.plan!.days
          .where((d) => d.dayNumber == action.dayNumber)
          .firstOrNull;
      final index =
          before?.exercises.indexWhere(
            (e) => e.stableId == action.exerciseId,
          ) ??
          -1;
      bool valid =
          index >= 0 &&
          after != null &&
          before!.exercises.length == after.exercises.length &&
          current.days.length == action.plan!.days.length;
      if (valid) {
        for (final day in current.days) {
          final proposed = action.plan!.days
              .where((d) => d.dayNumber == day.dayNumber)
              .firstOrNull;
          if (proposed == null) {
            valid = false;
            break;
          }
          if (day.dayNumber != action.dayNumber) {
            if (jsonEncode(day.toJson()) != jsonEncode(proposed.toJson())) {
              valid = false;
            }
          } else {
            for (var i = 0; i < day.exercises.length; i++) {
              if (i != index &&
                  jsonEncode(day.exercises[i].toJson()) !=
                      jsonEncode(proposed.exercises[i].toJson())) {
                valid = false;
              }
            }
          }
        }
      }
      if (!valid) {
        issues.add(
          const PlanIssue(
            'replacement',
            'propuesta',
            'La sustitución debe cambiar solo el ejercicio indicado.',
          ),
        );
      }
    }
    return issues;
  }

  Future<WorkoutPlan> apply(
    AiWorkoutAction action, {
    required bool confirmed,
    required WorkoutPlanStore store,
    TrainingProfile? profile,
  }) async {
    if (!confirmed) throw StateError('Confirma la propuesta antes de aplicar.');
    final current = await store.load();
    final issues = validate(action, current: current, profile: profile);
    if (issues.isNotEmpty) throw StateError(issues.join('\n'));
    return store.save(
      action.plan!,
      expectedVersion: action.expectedVersion,
      expectedPlanId: action.expectedPlanId,
    );
  }
}
