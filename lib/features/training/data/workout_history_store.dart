import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/workout_session.dart';
import 'user_storage.dart';

class WorkoutHistoryStore {
  WorkoutHistoryStore({String? storageUserId, UserStorage? storage})
    : storage = storage ?? UserStorage(storageUserId: storageUserId);
  final UserStorage storage;
  static const legacyKey = 'workout_history_v1';
  static const namespace = 'workout_history_v2';
  static final changes = ValueNotifier<int>(0);
  Future<List<WorkoutSession>> load() => storage.serialized(namespace, _load);
  Future<bool> hasUnclaimedLegacy() =>
      storage.hasUnclaimedLegacy(namespace, legacyKey);
  Future<void> importLegacy() => storage.serialized(namespace, () async {
    await storage.claimLegacy(namespace, legacyKey);
    if ((await _load()).isEmpty) {
      throw StateError('No se pudo recuperar el historial anterior.');
    }
    changes.value++;
  });
  Future<List<WorkoutSession>> _load() async {
    final value = await storage.read(namespace, legacyKey: legacyKey);
    if (value == null) return [];
    final items =
        (jsonDecode(value) as List)
            .map(
              (item) => WorkoutSession.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    // Migración validada; el global original se conserva intacto.
    if (await storage.read(namespace) == null) {
      await storage.write(
        namespace,
        jsonEncode(items.map((s) => s.toJson()).toList()),
      );
    }
    return items;
  }

  Future<void> add(WorkoutSession session) =>
      storage.serialized(namespace, () => _add(session));
  Future<void> _add(WorkoutSession session) async {
    if (!session.results.any((r) => r.completed)) {
      throw StateError('Completa al menos una serie.');
    }
    final history = await _load();
    await storage.write(
      namespace,
      jsonEncode([session, ...history].map((s) => s.toJson()).toList()),
    );
    changes.value++;
  }
}
