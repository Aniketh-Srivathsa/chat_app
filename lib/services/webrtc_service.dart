import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/webrtc_config.dart';
import '../core/encryption.dart';
import 'signaling_service.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;

  bool _channelOpen = false;
  bool _initialized = false;
  bool isConnected = false;
  bool _isReconnecting = false;
  bool _reconnectScheduled = false; // ✅ REQUIRED


  bool? _lastIsCaller;
  final SignalingService signaling;
  final String roomId;
  final Function(String message) onMessage;
  final Function(bool ready) onChannelReady;

  WebRTCService({
    required this.signaling,
    required this.roomId,
    required this.onMessage,
    required this.onChannelReady,
  });

  // ================= INIT =================

  Future<void> init(bool isCaller) async {
    if (_initialized) return;

    _initialized = true;
    _lastIsCaller = isCaller;

    debugPrint("🚀 Initializing WebRTC");

    _peerConnection = await createPeerConnection(rtcConfiguration);

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        signaling.send('ice', roomId, candidate.toMap());
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      debugPrint("🌐 ICE STATE: $state");

      if (state ==
              RTCIceConnectionState
                  .RTCIceConnectionStateDisconnected ||
          state ==
              RTCIceConnectionState
                  .RTCIceConnectionStateFailed) {
        _handleIceFailure();
      }

      if (state ==
              RTCIceConnectionState
                  .RTCIceConnectionStateConnected ||
          state ==
              RTCIceConnectionState
                  .RTCIceConnectionStateCompleted) {
        debugPrint("✅ Connection RESTORED");
        isConnected = true;
      }
    };

    if (isCaller) {
      _dataChannel = await _peerConnection!.createDataChannel(
        'chat',
        RTCDataChannelInit()..ordered = true,
      );
      _registerDataChannel();
    } else {
      _peerConnection!.onDataChannel = (channel) {
        _dataChannel = channel;
        _registerDataChannel();
      };
    }
  }

  // ================= DATA CHANNEL =================

  void _registerDataChannel() {
    if (_dataChannel == null) return;

    _dataChannel!.onDataChannelState = (state) {
      debugPrint("📡 DataChannel STATE: $state");

      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _channelOpen = true;
        isConnected = true;
        debugPrint("✅ DataChannel OPEN");
        onChannelReady(true);
      }

      if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _handleIceFailure();
      }
    };

    _dataChannel!.onMessage = (message) {
      final decrypted =
          EncryptionHelper.decryptText(message.text);
      onMessage(decrypted);
    };
  }

  // ================= SIGNALING =================

  Future<void> createOffer() async {
    if (_peerConnection == null) return;

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    signaling.send('offer', roomId, offer.toMap());
  }

  Future<void> handleOffer(Map<String, dynamic> offer) async {
    if (_peerConnection == null) return;

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    signaling.send('answer', roomId, answer.toMap());
  }

  Future<void> handleAnswer(Map<String, dynamic> answer) async {
    if (_peerConnection == null) return;

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answer['sdp'], answer['type']),
    );
  }

  void handleIce(Map<String, dynamic> ice) {
    if (_peerConnection == null) return;

    _peerConnection!.addCandidate(
      RTCIceCandidate(
        ice['candidate'],
        ice['sdpMid'],
        ice['sdpMLineIndex'],
      ),
    );
  }

  // ================= SEND MESSAGE =================

  void sendMessage(String message) {
    if (!_channelOpen || _dataChannel == null) {
      debugPrint("⏳ DataChannel not open yet");
      return;
    }

    final encrypted =
        EncryptionHelper.encryptText(message);
    _dataChannel!.send(RTCDataChannelMessage(encrypted));
  }

  // ================= 🔥 ICE FAILURE HANDLING =================

  void _handleIceFailure() {
    if (_isReconnecting) return;

    debugPrint("❌ ICE FAILED — FORCING FULL RECONNECT");

    isConnected = false;
    _channelOpen = false;

    attemptReconnect();
  }

 Future<void> attemptReconnect() async {
  if (_isReconnecting || _reconnectScheduled) {
    debugPrint("⏸ Reconnect already in progress — skipping");
    return;
  }

  _reconnectScheduled = true;

  // debounce window
  await Future.delayed(const Duration(seconds: 2));

  _reconnectScheduled = false;

  if (_isReconnecting) return;

  _isReconnecting = true;
  debugPrint("🔄 FULL WebRTC reconnect started");

  try {
    // 🔥 Prevent crash if init() never ran
    if (_lastIsCaller == null) {
      debugPrint("⚠️ Reconnect skipped: role not initialized");
      _isReconnecting = false;
      return;
    }

    dispose();

    await init(_lastIsCaller!);

    // 🔥 ONLY CALLER CREATES OFFER
    if (_lastIsCaller!) {
      await createOffer();
    }
  } catch (e) {
    debugPrint("❌ Reconnect error: $e");
  }

  _isReconnecting = false;
}


  // ================= CLEANUP =================

  void dispose() {
    debugPrint("❌ Disposing WebRTC");

    _initialized = false;
    isConnected = false;
    _channelOpen = false;

    _dataChannel?.close();
    _peerConnection?.close();

    _dataChannel = null;
    _peerConnection = null;
  }
}
