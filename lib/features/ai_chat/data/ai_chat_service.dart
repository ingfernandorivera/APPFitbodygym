import 'package:supabase_flutter/supabase_flutter.dart';
import '../../training/data/exercise_catalog.dart';
import '../models/ai_chat_response.dart';

class AiChatService {
  AiChatService({this._client});
  final SupabaseClient? _client;
  Future<AiChatResponse> reply({
    required String message,
    required List<Map<String, String>> history,
    Map<String, dynamic>? trainingProfile,
    Map<String, dynamic>? activeWorkout,
  }) async {
    final response = await (_client ?? Supabase.instance.client).functions
        .invoke(
          'ai-chat',
          body: {
            'message': message,
            'history': history,
            'trainingProfile': trainingProfile,
            'activeWorkout': activeWorkout,
            'catalog': ExerciseCatalog.exercises
                .map((e) => e.toJson())
                .toList(),
          },
        );
    return AiChatResponse.parse(response.data);
  }
}
