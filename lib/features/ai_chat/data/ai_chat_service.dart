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
    final response = await _client.functions.invoke(
      'ai-chat',
      body: {
        'message': message,
        'history': history,
        'trainingProfile': trainingProfile,
        'activeWorkout': activeWorkout,
      },
    );

    final data = response.data;
    if (data is Map && data['reply'] is String) {
      final reply = (data['reply'] as String).trim();
      if (reply.isNotEmpty) return reply;
    }
    throw const FormatException('La respuesta del asistente no es valida.');
  }
}
