import 'package:shared_preferences/shared_preferences.dart';
import '../../assessment/data/training_profile_store.dart';

class UserStorage {
  UserStorage({String? storageUserId, this.writeString})
    : userId = TrainingProfileStore(storageUserId: storageUserId).userId;
  final String? userId;
  final Future<bool> Function(SharedPreferences, String, String)? writeString;
  static final _pending = <String, Future<void>>{};
  Future<T> serialized<T>(
    String namespace,
    Future<T> Function() operation,
  ) async {
    final target = key(namespace);
    final previous = _pending[target] ?? Future<void>.value();
    final next = previous.then((_) => operation());
    final settled = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending[target] = settled;
    try {
      return await next;
    } finally {
      if (identical(_pending[target], settled)) _pending.remove(target);
    }
  }

  String key(String namespace) {
    if (userId == null || userId!.isEmpty) {
      throw StateError('Se necesita una sesión para guardar los datos.');
    }
    return '$namespace:${Uri.encodeComponent(userId!)}';
  }

  Future<String?> read(String namespace, {String? legacyKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final current = prefs.getString(key(namespace));
    if (current != null) return current;
    if (legacyKey != null &&
        userId != 'preview' &&
        prefs.getString('${legacyKey}_owner') == userId) {
      return prefs.getString(legacyKey);
    }
    return null;
  }

  Future<bool> hasUnclaimedLegacy(String namespace, String legacyKey) async {
    if (userId == null || userId!.isEmpty || userId == 'preview') return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getString(key(namespace)) != null) return false;
    return prefs.getString(legacyKey) != null &&
        prefs.getString('${legacyKey}_owner') == null;
  }

  Future<void> claimLegacy(String namespace, String legacyKey) async {
    if (userId == null || userId!.isEmpty) {
      throw StateError('Se necesita una sesión para guardar los datos.');
    }
    if (userId == 'preview') {
      throw StateError('La vista previa no puede importar datos anteriores.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final value = prefs.getString(legacyKey);
    if (value == null) {
      throw StateError('No hay datos anteriores para importar.');
    }
    final ownerKey = '${legacyKey}_owner';
    final owner = prefs.getString(ownerKey);
    if (owner != null && owner != userId) {
      throw StateError('Los datos anteriores pertenecen a otra cuenta.');
    }
    await write(namespace, value);
    if (!await prefs.setString(ownerKey, userId!)) {
      throw StateError('No se pudo confirmar la importación.');
    }
    await prefs.reload();
    if (prefs.getString(ownerKey) != userId) {
      throw StateError('No se pudo verificar la importación.');
    }
  }

  Future<void> write(String namespace, String value) async {
    final target = key(namespace);
    final prefs = await SharedPreferences.getInstance();
    if (!await (writeString?.call(prefs, target, value) ??
        prefs.setString(target, value))) {
      throw StateError('No se pudieron guardar los datos.');
    }
    await prefs.reload();
    if (prefs.getString(target) != value) {
      throw StateError('No se pudo verificar el guardado.');
    }
  }
}
