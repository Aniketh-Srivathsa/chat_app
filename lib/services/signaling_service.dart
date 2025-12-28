import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SignalingService {
  late WebSocketChannel _channel;
  bool _connected = false;

  void connect({
    required String roomId,
    required Function(String type, dynamic payload) onMessage,
  }) {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.29.113:9090'),
    );

    _connected = true;

    _channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        onMessage(data['type'], data['payload']);
      },
      onError: (e) {
        print("❌ Signaling error: $e");
      },
      onDone: () {
        _connected = false;
        print("🔌 Signaling socket closed");
      },
    );

    _send({
      'type': 'join',
      'roomId': roomId,
    });
  }

  void send(String type, String roomId, dynamic payload) {
    if (!_connected) return;

    _send({
      'type': type,
      'roomId': roomId,
      'payload': payload,
    });
  }

  void _send(Map<String, dynamic> data) {
    _channel.sink.add(jsonEncode(data));
  }

  void dispose() {
    if (_connected) {
      _channel.sink.close();
      _connected = false;
    }
  }
}
