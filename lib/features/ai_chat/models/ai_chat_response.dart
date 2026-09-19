import 'dart:convert';
import '../../training/models/workout_plan.dart';

enum AiActionType {
  answer,
  proposeWorkout,
  modifyWorkout,
  replaceExercise,
  requestMoreInformation,
}

class AiWorkoutAction {
  const AiWorkoutAction({
    required this.type,
    this.plan,
    this.expectedVersion,
    this.expectedPlanId,
    this.dayNumber,
    this.exerciseId,
  });
  final AiActionType type;
  final WorkoutPlan? plan;
  final int? expectedVersion, dayNumber;
  final String? expectedPlanId, exerciseId;
  bool get isProposal => [
    AiActionType.proposeWorkout,
    AiActionType.modifyWorkout,
    AiActionType.replaceExercise,
  ].contains(type);
  String get wireType => switch (type) {
    AiActionType.answer => 'answer',
    AiActionType.proposeWorkout => 'propose_workout',
    AiActionType.modifyWorkout => 'modify_workout',
    AiActionType.replaceExercise => 'replace_exercise',
    AiActionType.requestMoreInformation => 'request_more_information',
  };
  Map<String, dynamic> toJson() => {
    'type': wireType,
    if (isProposal)
      'payload': {
        'plan': plan!.toJson(),
        'expectedVersion': expectedVersion,
        'expectedPlanId': expectedPlanId,
        if (dayNumber != null) 'dayNumber': dayNumber,
        if (exerciseId != null) 'exerciseId': exerciseId,
      },
  };
}

class AiChatResponse {
  const AiChatResponse({required this.reply, required this.action});
  final String reply;
  final AiWorkoutAction action;
  Map<String, dynamic> toJson() => {'reply': reply, ...action.toJson()};
  factory AiChatResponse.parse(dynamic value) {
    if (value is String) {
      final text = value.trim();
      if (text.startsWith('{') || text.startsWith('[')) {
        return AiChatResponse.parse(jsonDecode(text));
      }
      if (text.isEmpty) throw const FormatException('Respuesta vacía.');
      return AiChatResponse(
        reply: text,
        action: const AiWorkoutAction(type: AiActionType.answer),
      );
    }
    if (value is! Map ||
        value['reply'] is! String ||
        (value['reply'] as String).trim().isEmpty) {
      throw const FormatException('Respuesta inválida.');
    }
    final type = switch (value['type']) {
      null || 'answer' => AiActionType.answer,
      'propose_workout' => AiActionType.proposeWorkout,
      'modify_workout' => AiActionType.modifyWorkout,
      'replace_exercise' => AiActionType.replaceExercise,
      'request_more_information' => AiActionType.requestMoreInformation,
      _ => throw const FormatException('Acción desconocida.'),
    };
    if (type == AiActionType.answer ||
        type == AiActionType.requestMoreInformation) {
      if (value['payload'] != null) {
        throw const FormatException(
          'Respuesta sin acción contiene un payload.',
        );
      }
      return AiChatResponse(
        reply: value['reply'] as String,
        action: AiWorkoutAction(type: type),
      );
    }
    final p = value['payload'];
    if (p is! Map ||
        p['expectedVersion'] is! int ||
        p['expectedVersion'] < 0 ||
        p['plan'] is! Map ||
        p['expectedVersion'] > 0 && p['expectedPlanId'] is! String) {
      throw const FormatException('Propuesta incompleta.');
    }
    final plan = Map<String, dynamic>.from(p['plan'] as Map);
    for (final field in [
      'name',
      'goal',
      'createdAt',
      'id',
      'source',
      'changeReason',
    ]) {
      if (plan[field] is! String || (plan[field] as String).isEmpty) {
        throw FormatException('Falta el campo $field');
      }
    }
    for (final field in ['version', 'plannedMinutes', 'block', 'week']) {
      if (plan[field] is! int) throw FormatException('Falta el campo $field');
    }
    if (plan['days'] is! List) throw const FormatException('Faltan días.');
    for (final day in plan['days'] as List) {
      if (day is! Map ||
          day['dayNumber'] is! int ||
          day['exercises'] is! List) {
        throw const FormatException('Día inválido.');
      }
      for (final e in day['exercises'] as List) {
        if (e is! Map ||
            e['id'] is! String ||
            e['sets'] is! int ||
            e['restSeconds'] is! int ||
            e['targetMin'] is! int ||
            e['targetMax'] is! int ||
            e['targetRir'] is! int) {
          throw const FormatException('Prescripción incompleta.');
        }
      }
    }
    if (type == AiActionType.replaceExercise &&
        (p['dayNumber'] is! int || p['exerciseId'] is! String)) {
      throw const FormatException('Sustitución incompleta.');
    }
    return AiChatResponse(
      reply: value['reply'] as String,
      action: AiWorkoutAction(
        type: type,
        plan: WorkoutPlan.fromJson(plan),
        expectedVersion: p['expectedVersion'] as int,
        expectedPlanId: p['expectedPlanId'] as String?,
        dayNumber: p['dayNumber'] as int?,
        exerciseId: p['exerciseId'] as String?,
      ),
    );
  }
}
