import 'package:hive_flutter/hive_flutter.dart';
import 'message_model.dart';

class LocalStore {
  static const String messageBox = 'messages';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(messageBox);
  }

  static Box get _box => Hive.box(messageBox);

  static void saveMessage(ChatMessage message) {
    _box.put(message.id, message.toJson());
  }

  static List<ChatMessage> loadMessages() {
    return _box.values
        .map(
          (e) => ChatMessage.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }
}
