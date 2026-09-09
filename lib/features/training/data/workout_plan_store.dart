import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_plan.dart';

class WorkoutPlanStore {
  static const _key = 'active_workout_plan_v1';

  Future<WorkoutPlan?> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    if (value == null) return null;
    return WorkoutPlan.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> save(WorkoutPlan plan) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(plan.toJson()),
    );
  }
}
