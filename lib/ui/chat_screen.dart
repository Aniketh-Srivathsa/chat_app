import 'package:flutter/material.dart';

import '../services/network_service.dart';
import '../services/secure_session_service.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

class ChatScreen extends StatefulWidget {
  final String localUserId;
  final String peerUserId;
  final String conversationId;

  const ChatScreen({
    super.key,
    required this.localUserId,
    required this.peerUserId,
    required this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<String> messages = [];
  final List<String> _outgoingQueue = [];
  final signaling = SignalingService();
  late final NetworkService networkService;
  late WebRTCService webrtc;
  SecureSessionService? secureSession;
  String? _sessionId;
  String? _safetyCode;
  bool channelReady = false;
  bool _peerPresent = false;
  bool _networkWasDisconnected = false;

  bool get _isCaller => widget.localUserId.compareTo(widget.peerUserId) < 0;
  bool get _secureAndVerified =>
      secureSession?.hasSession == true && secureSession?.peerTrusted == true;

  @override
  void initState() {
    super.initState();
    webrtc = _createWebRtc();
    networkService = NetworkService()
      ..startListening(
        onDisconnected: () {
          _networkWasDisconnected = true;
          _markDisconnected();
        },
        onConnected: () {
          if (_networkWasDisconnected) {
            _networkWasDisconnected = false;
            _rejoinRoom();
          }
        },
      );
    signaling.connect(
      roomId: widget.conversationId,
      userId: widget.localUserId,
      onMessage: _handleSignal,
    );
  }

  WebRTCService _createWebRtc() => WebRTCService(
        signaling: signaling,
        roomId: widget.conversationId,
        onMessage: _receiveCiphertext,
        onChannelReady: (ready) {
          if (!mounted) return;
          setState(() => channelReady = ready);
          _tryFlushQueue();
        },
      );

  Future<void> _handleSignal(String type, dynamic payload) async {
    if (type == 'ready') {
      final nextSession = payload['sessionId'] as String?;
      if (nextSession == null || nextSession == _sessionId) {
        return;
      }
      _sessionId = nextSession;
      signaling.setSessionId(nextSession);
      _peerPresent = true;
      _safetyCode = null;
      secureSession = SecureSessionService(
        conversationId: widget.conversationId,
        sessionId: nextSession,
        localUserId: widget.localUserId,
        peerUserId: widget.peerUserId,
      );
      await secureSession!.initialize();
      signaling.send('key_hello', widget.conversationId, {
        'sessionId': nextSession,
        'hello': await secureSession!.createHello(),
      });
      if (_isCaller) {
        await webrtc.restart(true);
      } else {
        await webrtc.restart(false);
      }
      if (mounted) setState(() {});
      return;
    }

    if (type == 'peer_left') {
      _peerPresent = false;
      _markDisconnected();
      return;
    }
    if (type == 'key_hello') {
      if (payload['__sessionId'] != _sessionId ||
          payload['sessionId'] != _sessionId ||
          secureSession == null) {
        return;
      }
      try {
        final code = await secureSession!.acceptHello(
          Map<String, dynamic>.from(payload['hello'] as Map),
        );
        if (!mounted) return;
        setState(() {
          _safetyCode = code;
        });
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Secure setup failed: $error')),
        );
      }
      return;
    }
    if (_sessionId == null ||
        payload is! Map ||
        payload['__sessionId'] != _sessionId) {
      return;
    }
    switch (type) {
      case 'offer':
        await webrtc.init(false);
        await webrtc.handleOffer(Map<String, dynamic>.from(payload));
        break;
      case 'answer':
        await webrtc.handleAnswer(Map<String, dynamic>.from(payload));
        break;
      case 'ice':
        webrtc.handleIce(Map<String, dynamic>.from(payload));
        break;
    }
  }

  Future<void> _receiveCiphertext(String ciphertext) async {
    try {
      final plaintext = await secureSession!.decrypt(ciphertext);
      if (!mounted) return;
      setState(() => messages.add('Peer: $plaintext'));
    } catch (error) {
      debugPrint('Rejected chat frame: $error');
    }
  }

  void _markDisconnected() {
    if (!mounted) return;
    signaling.setSessionId(null);
    setState(() {
      channelReady = false;
      secureSession = null;
      _safetyCode = null;
    });
  }

  void _rejoinRoom() {
    if (!mounted) return;
    signaling.reconnectNow(force: true);
  }

  Future<void> _verifyPeer() async {
    final session = secureSession;
    if (session == null || _safetyCode == null) return;
    await session.trustPeer();
    if (!mounted) return;
    _tryFlushQueue();
  }

  Future<void> _sendOrQueue(String plaintext) async {
    if (_secureAndVerified && webrtc.isConnected && channelReady) {
      final ciphertext = await secureSession!.encrypt(plaintext);
      webrtc.sendMessage(ciphertext);
    } else {
      _outgoingQueue.add(plaintext);
    }
    if (mounted) setState(() => messages.add('Me: $plaintext'));
  }

  Future<void> _tryFlushQueue() async {
    if (!_secureAndVerified || !webrtc.isConnected || !channelReady) return;
    while (_outgoingQueue.isNotEmpty) {
      final plaintext = _outgoingQueue.removeAt(0);
      webrtc.sendMessage(await secureSession!.encrypt(plaintext));
    }
  }

  @override
  void dispose() {
    networkService.dispose();
    _controller.dispose();
    signaling.dispose();
    webrtc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('${widget.localUserId} ↔ ${widget.peerUserId}'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_secureAndVerified
                  ? (channelReady ? 'Verified secure session' : 'Reconnecting')
                  : (_peerPresent
                      ? 'Verifying secure session…'
                      : 'Waiting for peer')),
            ),
          ),
        ),
        body: Column(children: [
          if (_safetyCode != null && !_secureAndVerified)
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  const Text(
                      'Compare this safety code with your peer in person or over a trusted channel.'),
                  const SizedBox(height: 8),
                  SelectableText(_safetyCode!.replaceAllMapped(
                    RegExp(r'.{4}'),
                    (match) => '${match.group(0)} ',
                  )),
                  TextButton(
                      onPressed: _verifyPeer,
                      child: const Text('Codes match — verify peer')),
                ]),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (context, index) => Align(
                alignment: messages[index].startsWith('Me:')
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: messages[index].startsWith('Me:')
                        ? Colors.blue.shade100
                        : Colors.pink.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(messages[index]),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Row(children: [
              Expanded(
                  child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Type a message…'),
              )),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isEmpty) return;
                  _controller.clear();
                  _sendOrQueue(text);
                },
              ),
            ]),
          ),
        ]),
      );
}
