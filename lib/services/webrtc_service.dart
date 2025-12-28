import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/webrtc_config.dart';
import '../core/encryption.dart';
import 'signaling_service.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;

  bool _channelOpen = false;
  bool _initialized = false; // 🔥 CRITICAL

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

  // ---------------- INIT ----------------

  Future<void> init(bool isCaller) async {
    if (_initialized) {
      debugPrint("⚠️ WebRTC already initialized — skipping init()");
      return;
    }

    _initialized = true;

    _peerConnection = await createPeerConnection(rtcConfiguration);

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        signaling.send('ice', roomId, candidate.toMap());
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

  // ---------------- DATA CHANNEL ----------------

  void _registerDataChannel() {
    if (_dataChannel == null) return;

    _dataChannel!.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _channelOpen = true;
        debugPrint("✅ DataChannel OPEN");
        onChannelReady(true);
      }
    };

    _dataChannel!.onMessage = (message) {
      final decrypted = EncryptionHelper.decryptText(message.text);
      onMessage(decrypted);
    };
  }

  // ---------------- SIGNALING ----------------

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
    if (_peerConnection == null) {
      debugPrint("⚠️ ICE received before PeerConnection ready — ignoring");
      return;
    }

    _peerConnection!.addCandidate(
      RTCIceCandidate(
        ice['candidate'],
        ice['sdpMid'],
        ice['sdpMLineIndex'],
      ),
    );
  }

  // ---------------- SEND MESSAGE ----------------

  void sendMessage(String message) {
    if (!_channelOpen || _dataChannel == null) {
      debugPrint("⏳ DataChannel not open yet");
      return;
    }

    final encrypted = EncryptionHelper.encryptText(message);
    _dataChannel!.send(RTCDataChannelMessage(encrypted));
  }

  // ---------------- CLEANUP ----------------

  void dispose() {
    _channelOpen = false;
    _initialized = false;
    _dataChannel?.close();
    _peerConnection?.close();
    _dataChannel = null;
    _peerConnection = null;
  }
}
