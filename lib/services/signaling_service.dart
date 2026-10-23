import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/app_config.dart';

class SignalingService {
  WebSocketChannel? _channel;
  bool _connected = false;
  String? _roomId;
  String? _userId;
  String? _sessionId;
  Function(String type, dynamic payload)? _onMessage;
  Timer? _retryTimer;
  int _retrySeconds = 1;
  int _generation = 0;

  void connect({
    required String roomId,
    required String userId,
    required Function(String type, dynamic payload) onMessage,
  }) {
    _roomId = roomId;
    _userId = userId;
    _sessionId = null;
    _onMessage = onMessage;
    _open();
  }

  void _open() {
    final generation = ++_generation;
    try {
      final channel =
          WebSocketChannel.connect(Uri.parse(AppConfig.signalingServer));
      _channel = channel;
      _connected = true;
      channel.stream.listen(
        (message) {
          final data = jsonDecode(message);
          final payload = data['payload'];
          if (data['type'] == 'ready' || data['type'] == 'peer_left') {
            _onMessage?.call(data['type'], payload);
          } else if (payload is Map) {
            _onMessage?.call(data['type'], {
              ...Map<String, dynamic>.from(payload),
              '__sessionId': data['sessionId'],
            });
          } else {
            _onMessage?.call(data['type'], payload);
          }
        },
        onError: (e) {
          debugPrint("❌ Signaling error: $e");
          if (generation == _generation) {
            _connected = false;
            _scheduleReconnect();
          }
        },
        onDone: () {
          if (generation != _generation) return;
          _connected = false;
          debugPrint("🔌 Signaling socket closed");
          _scheduleReconnect();
        },
      );

      _send({
        'type': 'join',
        'roomId': _roomId,
        'userId': _userId,
      });
    } catch (error) {
      _connected = false;
      debugPrint('❌ Signaling connection failed: $error');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_retryTimer != null || _roomId == null) return;
    _retryTimer = Timer(Duration(seconds: _retrySeconds), () {
      _retryTimer = null;
      _retrySeconds = (_retrySeconds * 2).clamp(1, 30).toInt();
      _open();
    });
  }

  void reconnectNow({bool force = false}) {
    if (_roomId == null || (_connected && !force)) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retrySeconds = 1;
    _generation++;
    _channel?.sink.close();
    _connected = false;
    _open();
  }

  void setSessionId(String? sessionId) => _sessionId = sessionId;

  void send(String type, String roomId, dynamic payload) {
    if (!_connected) return;

    _send({
      'type': type,
      'roomId': roomId,
      'payload': payload,
      if (_sessionId != null) 'sessionId': _sessionId,
    });
  }

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  void dispose() {
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_connected) {
      _channel?.sink.close();
      _connected = false;
    }
    _roomId = null;
    _userId = null;
    _sessionId = null;
    _onMessage = null;
  }
}
