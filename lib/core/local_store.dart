import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'message_model.dart';

class LocalStore {
  static const String messageBox = 'messages';
  static const _secureStorage = FlutterSecureStorage();
  static final _cipher = AesGcm.with256bits();
  static const _uuid = Uuid();
  static final Map<String, Future<SecretKey>> _historyKeys = {};

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(messageBox);
  }

  static Box get _box => Hive.box(messageBox);

  static Future<void> saveChatMessage({
    required String localUserId,
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final message = ChatHistoryMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    final key = await _historyKey(localUserId);
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(message.toJson())),
      secretKey: key,
      aad: utf8.encode('$localUserId|$conversationId'),
    );
    await _box.put(message.id, {
      'ownerId': localUserId,
      'conversationId': conversationId,
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  static Future<List<ChatHistoryMessage>> loadChatMessages({
    required String localUserId,
    required String conversationId,
  }) async {
    final key = await _historyKey(localUserId);
    final results = <ChatHistoryMessage>[];
    for (final raw in _box.values) {
      if (raw is! Map) continue;
      final record = Map<String, dynamic>.from(raw);
      if (record['ownerId'] != localUserId ||
          record['conversationId'] != conversationId) {
        continue;
      }
      final plaintext = await _cipher.decrypt(
        SecretBox(
          base64Decode(record['cipherText'] as String),
          nonce: base64Decode(record['nonce'] as String),
          mac: Mac(base64Decode(record['mac'] as String)),
        ),
        secretKey: key,
        aad: utf8.encode('$localUserId|$conversationId'),
      );
      results.add(ChatHistoryMessage.fromJson(
        jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>,
      ));
    }
    results.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return results;
  }

  static Future<SecretKey> _historyKey(String localUserId) =>
      _historyKeys.putIfAbsent(localUserId, () => _loadOrCreateHistoryKey(localUserId));

  static Future<SecretKey> _loadOrCreateHistoryKey(String localUserId) async {
    final storageKey = 'chat-history-key:$localUserId';
    final encoded = await _secureStorage.read(key: storageKey);
    if (encoded != null) {
      return SecretKey(base64Decode(encoded));
    }
    final key = await _cipher.newSecretKey();
    await _secureStorage.write(
      key: storageKey,
      value: base64Encode(await key.extractBytes()),
    );
    return key;
  }
}
