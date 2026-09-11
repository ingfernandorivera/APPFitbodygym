import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class AiChatService {
  AiChatService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> reply({
    required String message,
    required List<Map<String, String>> history,
    Map<String, dynamic>? trainingProfile,
    Map<String, dynamic>? activeWorkout,
  }) async {
    final contextualHistory = <Map<String, String>>[
      ...history,
      if (trainingProfile != null)
        {
          'role': 'user',
          'content':
              'Contexto de mi perfil de entrenamiento ya completado: '
              '${jsonEncode(trainingProfile)}. Usa estos datos y no vuelvas a '
              'preguntarme información que ya aparece aquí.',
        },
      if (activeWorkout != null)
        {
          'role': 'user',
          'content':
              'Contexto de mi rutina activa actual: '
              '${jsonEncode(_workoutSummary(activeWorkout))}. '
              'No la reemplaces ni afirmes haber '
              'guardado cambios sin pedirme confirmación.',
        },
    ];
    final body = {
      'message': message,
      'history': contextualHistory,
      'trainingProfile': trainingProfile,
      'activeWorkout': activeWorkout,
    };

    dynamic response;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        response = await _client.functions.invoke('ai-chat', body: body);
        break;
      } on FunctionException catch (error) {
        if (attempt == 0 && _isEmptyReplyError(error.details)) continue;
        rethrow;
      }
    }

    final data = response.data;
    if (data is Map && data['reply'] is String) {
      final reply = (data['reply'] as String).trim();
      if (reply.isNotEmpty) return reply;
    }
    throw const FormatException('La respuesta del asistente no es valida.');
  }

  bool _isEmptyReplyError(dynamic details) =>
      details is Map &&
      details['error'] is String &&
      (details['error'] as String).contains('respuesta vacía');

  Map<String, dynamic> _workoutSummary(Map<String, dynamic> workout) {
    final days = workout['days'];
    return {
      'name': workout['name'],
      'goal': workout['goal'],
      'days': days is List
          ? days
                .whereType<Map>()
                .map(
                  (day) => {
                    'dayNumber': day['dayNumber'],
                    'title': day['title'],
                    'focus': day['focus'],
                  },
                )
                .toList()
          : const [],
    };
  }
}
