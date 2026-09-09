import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/training_profile.dart';

class TrainingProfileStore {
  static const _key = 'training_profile_v1';

  Future<TrainingProfile?> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    if (value == null) return null;
    return TrainingProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> save(TrainingProfile profile) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(profile.toJson()),
    );
  }
}
