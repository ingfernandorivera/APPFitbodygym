import 'dart:convert';
import '../../training/data/user_storage.dart';

class ChatCacheStore {
  ChatCacheStore({String? storageUserId, UserStorage? storage})
    : storage = storage ?? UserStorage(storageUserId: storageUserId);
  final UserStorage storage;
  Future<List<Map<String, dynamic>>> load() async {
    final raw = await storage.read('ai_chat_v2');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
  }

  Future<void> save(List<Map<String, dynamic>> messages) async {
    final bounded = messages
        .skip(messages.length > 60 ? messages.length - 60 : 0)
        .toList();
    while (utf8.encode(jsonEncode(bounded)).length > 300000 &&
        bounded.length > 1) {
      bounded.removeAt(0);
    }
    if (utf8.encode(jsonEncode(bounded)).length > 300000) {
      throw StateError('La conversación supera el límite local.');
    }
    await storage.write('ai_chat_v2', jsonEncode(bounded));
  }
}
