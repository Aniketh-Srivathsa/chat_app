import 'package:flutter/material.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const String roomId = "love-room-1";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Couple Chat'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Development Mode',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose how to open the app',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),

            /// Open as Caller
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatScreen(
                      isCaller: true,
                      roomId: roomId,
                    ),
                  ),
                );
              },
              child: const Text('Open as Me'),
            ),

            const SizedBox(height: 16),

            /// Open as Receiver
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatScreen(
                      isCaller: false,
                      roomId: roomId,
                    ),
                  ),
                );
              },
              child: const Text('Open as Her'),
            ),
          ],
        ),
      ),
    );
  }
}
