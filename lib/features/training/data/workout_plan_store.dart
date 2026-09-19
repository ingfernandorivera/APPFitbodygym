import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/workout_plan.dart';
import 'user_storage.dart';

class WorkoutPlanStore {
  WorkoutPlanStore({String? storageUserId, UserStorage? storage})
    : storage = storage ?? UserStorage(storageUserId: storageUserId);
  final UserStorage storage;
  static const legacyKey = 'active_workout_plan_v1';
  static const namespace = 'workout_plan_v2';
  static final changes = ValueNotifier<int>(0);
  // Una única escritura contiene la versión activa y su historial.
  Future<List<WorkoutPlan>> versions() =>
      storage.serialized(namespace, _versions);
  Future<List<WorkoutPlan>> _versions() async {
    final raw = await storage.read(namespace, legacyKey: legacyKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    final items = decoded is List ? decoded : [decoded];
    final plans = items
        .map((p) => WorkoutPlan.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    if (decoded is! List) {
      await storage.write(
        namespace,
        jsonEncode(plans.map((p) => p.toJson()).toList()),
      );
    }
    return plans;
  }

  Future<WorkoutPlan?> load() async => (await versions()).firstOrNull;
  Future<bool> hasUnclaimedLegacy() =>
      storage.hasUnclaimedLegacy(namespace, legacyKey);
  Future<void> importLegacy() => storage.serialized(namespace, () async {
    await storage.claimLegacy(namespace, legacyKey);
    if ((await _versions()).isEmpty) {
      throw StateError('No se pudo recuperar la rutina anterior.');
    }
    changes.value++;
  });
  Future<WorkoutPlan> save(
    WorkoutPlan plan, {
    int? expectedVersion,
    String? expectedPlanId,
  }) => storage.serialized(
    namespace,
    () => _save(
      plan,
      expectedVersion: expectedVersion,
      expectedPlanId: expectedPlanId,
    ),
  );
  Future<WorkoutPlan> _save(
    WorkoutPlan plan, {
    int? expectedVersion,
    String? expectedPlanId,
  }) async {
    final history = await _versions();
    final active = history.firstOrNull;
    if (expectedVersion != null && (active?.version ?? 0) != expectedVersion ||
        expectedPlanId != null && active?.id != expectedPlanId) {
      throw StateError('La rutina cambió. Revisa una nueva propuesta.');
    }
    final next = plan.copyWith(
      id: active?.id ?? plan.id,
      version: (active?.version ?? 0) + 1,
    );
    await storage.write(
      namespace,
      jsonEncode([next, ...history.take(19)].map((p) => p.toJson()).toList()),
    );
    final verified = (await _versions()).firstOrNull;
    if (verified == null ||
        jsonEncode(verified.toJson()) != jsonEncode(next.toJson())) {
      throw StateError('No se pudo verificar la rutina guardada.');
    }
    changes.value++;
    return verified;
  }

  Future<WorkoutPlan> restorePrevious() async {
    final history = await versions();
    if (history.length < 2) throw StateError('No hay una versión anterior.');
    return save(
      history[1].copyWith(changeReason: 'Restauración de versión anterior'),
      expectedVersion: history.first.version,
      expectedPlanId: history.first.id,
    );
  }
}
