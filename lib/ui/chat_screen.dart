import 'package:flutter/material.dart';

import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/network_service.dart';

class ChatScreen extends StatefulWidget {
  final bool isCaller;
  final String roomId;

  const ChatScreen({
    super.key,
    required this.isCaller,
    required this.roomId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();

  // UI messages
  final List<String> messages = [];

  // 🔥 Outgoing queue (CRITICAL)
  final List<String> _outgoingQueue = [];

  bool channelReady = false;

  late final SignalingService signaling;
  late final WebRTCService webrtc;
  late final NetworkService networkService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1️⃣ Signaling
    signaling = SignalingService();

    // 2️⃣ WebRTC
    webrtc = WebRTCService(
      signaling: signaling,
      roomId: widget.roomId,
      onMessage: (msg) {
        if (!mounted) return;
        setState(() {
          messages.add("Her: $msg");
        });
      },
      onChannelReady: (ready) {
        if (!mounted) return;

        setState(() {
          channelReady = ready;
        });

        // 🔥 Try flushing whenever channel becomes ready
        _tryFlushQueueSafely();
      },
    );

    // 3️⃣ Network detection
    networkService = NetworkService();
    networkService.startListening(
      onDisconnected: () {
        debugPrint("📡 Network disconnected");
      },
      onConnected: () {
        debugPrint("📶 Network connected");

        if (!webrtc.isConnected) {
          debugPrint("🔄 Network restored → reconnecting WebRTC");
          webrtc.attemptReconnect();

          // 🔥 FORCE FLUSH after reconnect delay
          Future.delayed(const Duration(seconds: 2), () {
            _tryFlushQueueSafely();
          });
        }
      },
    );

    // 4️⃣ Signaling server
    signaling.connect(
      roomId: widget.roomId,
      onMessage: (type, payload) async {
        switch (type) {
          case 'ready':
            if (widget.isCaller) {
              await webrtc.init(true);
              await webrtc.createOffer();
            }
            break;

          case 'offer':
            await webrtc.init(false);
            await webrtc.handleOffer(payload);
            break;

          case 'answer':
            await webrtc.handleAnswer(payload);
            break;

          case 'ice':
            webrtc.handleIce(payload);
            break;
        }
      },
    );
  }

  // ================= MESSAGE QUEUE =================

  void _sendOrQueue(String message) {
    if (webrtc.isConnected && channelReady) {
      webrtc.sendMessage(message);
    } else {
      debugPrint("📥 Queued message (offline): $message");
      _outgoingQueue.add(message);
    }
  }

  void _tryFlushQueueSafely() {
    if (!webrtc.isConnected) return;
    if (_outgoingQueue.isEmpty) return;

    debugPrint("📤 Flushing queued messages: ${_outgoingQueue.length}");

    for (final msg in _outgoingQueue) {
      webrtc.sendMessage(msg);
    }

    _outgoingQueue.clear();
  }

  // ================= LIFECYCLE =================

  

  // ================= CLEANUP =================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    networkService.dispose();
    _controller.dispose();
    signaling.dispose();
    webrtc.dispose();

    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          channelReady
              ? "Couple Chat (Connected)"
              : "Reconnecting…",
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final isMe =
                    messages[index].startsWith("Me:");
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.blue.shade100
                          : Colors.pink.shade100,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Text(messages[index]),
                  ),
                );
              },
            ),
          ),

          // Input
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: true, // allow typing anytime
                    decoration: const InputDecoration(
                      hintText: "Type a message…",
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.blue,
                  onPressed: () {
                    final text =
                        _controller.text.trim();
                    if (text.isEmpty) return;

                    _sendOrQueue(text);

                    setState(() {
                      messages.add("Me: $text");
                    });

                    _controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
