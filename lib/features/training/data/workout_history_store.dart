import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_session.dart';

class WorkoutHistoryStore {
  static const _key = 'workout_history_v1';

  Future<List<WorkoutSession>> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    if (value == null) return [];
    final items = jsonDecode(value) as List<dynamic>;
    return items
        .map((item) => WorkoutSession.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  Future<void> add(WorkoutSession session) async {
    final history = await load();
    history.insert(0, session);
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(history.map((item) => item.toJson()).toList()),
    );
  }
}
