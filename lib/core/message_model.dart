import 'message_type.dart';

class ChatHistoryMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final int timestamp;

  const ChatHistoryMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  factory ChatHistoryMessage.fromJson(Map<String, dynamic> json) =>
      ChatHistoryMessage(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        senderId: json['senderId'] as String,
        text: json['text'] as String,
        timestamp: json['timestamp'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'text': text,
        'timestamp': timestamp,
      };
}

class ChatMessage {
  final String id;
  final MessageType type;
  final String senderId;
  final int timestamp;
  final Map<String, dynamic> payload;
  bool delivered;
  bool seen;

  ChatMessage({
    required this.id,
    required this.type,
    required this.senderId,
    required this.timestamp,
    required this.payload,
    this.delivered = false,
    this.seen = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'senderId': senderId,
      'timestamp': timestamp,
      'payload': payload,
      'delivered': delivered,
      'seen': seen,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      senderId: json['senderId'],
      timestamp: json['timestamp'],
      payload: Map<String, dynamic>.from(json['payload']),
      delivered: json['delivered'] ?? false,
      seen: json['seen'] ?? false,
    );
  }
}
