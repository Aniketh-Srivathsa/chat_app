import 'package:flutter/material.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> messages = [];

  bool channelReady = false;

  late final SignalingService signaling;
  late final WebRTCService webrtc;

  @override
  void initState() {
    super.initState();

    // 1️⃣ Initialize signaling service
    signaling = SignalingService();

    // 2️⃣ Initialize WebRTC service
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
      },
    );

    // 3️⃣ Connect to signaling server ONCE
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

  @override
  void dispose() {
    _controller.dispose();
    signaling.dispose(); // 🔥 CRITICAL
    webrtc.dispose();    // 🔥 CRITICAL
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          channelReady ? "Couple Chat (Connected)" : "Connecting…",
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 📨 Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Align(
                  alignment: messages[index].startsWith("Me:")
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: messages[index].startsWith("Me:")
                          ? Colors.blue.shade100
                          : Colors.pink.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(messages[index]),
                  ),
                );
              },
            ),
          ),

          // ✏️ Input box
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: channelReady,
                    decoration: const InputDecoration(
                      hintText: "Type a message…",
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: channelReady ? Colors.blue : Colors.grey,
                  onPressed: channelReady
                      ? () {
                          final text = _controller.text.trim();
                          if (text.isEmpty) return;

                          webrtc.sendMessage(text);

                          setState(() {
                            messages.add("Me: $text");
                          });

                          _controller.clear();
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
