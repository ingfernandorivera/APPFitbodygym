import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/training_profile.dart';

class TrainingProfileStore {
  TrainingProfileStore({String? storageUserId})
    : userId = storageUserId ?? _currentUserId();

  final String? userId;
  static final changes = ValueNotifier<int>(0);
  static const legacyKey = 'training_profile_v1';

  static String? _currentUserId() {
    if (const bool.fromEnvironment('PREVIEW_MODE')) return 'preview';
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String get _key {
    if (userId == null || userId!.isEmpty) {
      throw StateError('Se necesita una sesión para guardar la evaluación.');
    }
    return 'training_profile_v2:${Uri.encodeComponent(userId!)}';
  }

  String get _draftKey => '$_key:draft';

  Future<TrainingProfile?> load() async {
    final key = _key;
    final prefs = await SharedPreferences.getInstance();
    var value = prefs.getString(key);
    // El legado global no demuestra a qué cuenta pertenece. Nunca lo reclamamos
    // solo porque sea la primera cuenta que inicia sesión en este dispositivo.
    if (value == null &&
        userId != 'preview' &&
        prefs.getString('${legacyKey}_owner') == userId) {
      value = prefs.getString(legacyKey);
      if (value != null) {
        final migrated = TrainingProfile.fromJson(
          jsonDecode(value) as Map<String, dynamic>,
        );
        await _checked(prefs.setString(key, jsonEncode(migrated.toJson())));
      }
    }
    if (value == null) return null;
    return TrainingProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> save(TrainingProfile profile) async {
    final key = _key;
    final prefs = await SharedPreferences.getInstance();
    await _checked(prefs.setString(key, jsonEncode(profile.toJson())));
    await _checked(prefs.remove(_draftKey));
    changes.value++;
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    final key = _draftKey;
    final value = (await SharedPreferences.getInstance()).getString(key);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  Future<void> saveDraft(Map<String, dynamic> draft) async {
    final key = _draftKey;
    await _checked(
      (await SharedPreferences.getInstance()).setString(key, jsonEncode(draft)),
    );
    changes.value++;
  }

  Future<void> _checked(Future<bool> operation) async {
    if (!await operation) throw StateError('No se pudieron guardar los datos.');
  }
}
