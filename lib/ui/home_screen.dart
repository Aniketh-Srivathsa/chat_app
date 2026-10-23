import 'package:flutter/material.dart';

import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const users = ['A', 'B', 'C'];
  String currentUser = 'A';

  void _openChat(String peer) {
    final ids = [currentUser, peer]..sort();
    final conversationId = 'direct:${ids.join(':')}';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          localUserId: currentUser,
          peerUserId: peer,
          conversationId: conversationId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Couple Chat'), centerTitle: true),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Three-user prototype',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Choose the local test identity, then open a one-to-one conversation.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: currentUser,
                decoration: const InputDecoration(labelText: 'This device is'),
                items: users
                    .map((id) =>
                        DropdownMenuItem(value: id, child: Text('User $id')))
                    .toList(),
                onChanged: (value) => setState(() => currentUser = value!),
              ),
              const SizedBox(height: 24),
              for (final peer in users.where((id) => id != currentUser))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52)),
                    onPressed: () => _openChat(peer),
                    child: Text('Chat with User $peer'),
                  ),
                ),
              const Spacer(),
              const Text(
                'A, B, and C are prototype IDs, not authenticated accounts. Compare each new safety code out of band before trusting it.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
}
