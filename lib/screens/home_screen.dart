import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  final _dbService = DatabaseService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  void _startChat(BuildContext context) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Chat'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Enter Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;

              Navigator.pop(context); // Close dialog

              // 1. Find user
              final snapshot = await _dbService.searchUser(email);
              if (snapshot.docs.isNotEmpty) {
                final otherUserFn = snapshot.docs.first;
                final otherUid = otherUserFn['uid'];

                if (otherUid == _currentUser?.uid) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Can't chat with yourself")),
                    );
                  }
                  return;
                }

                // 2. Create/Get Chat Room
                final roomId = await _dbService.createChatRoom(
                  _currentUser!.uid,
                  otherUid,
                );
                final otherPublicKey = otherUserFn['public_key'];

                // 3. Navigate
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        roomId: roomId,
                        otherUserId: otherUid,
                        otherPublicKey: otherPublicKey,
                        chatName: otherUserFn['username'] ?? email,
                      ),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User not found')),
                  );
                }
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user == null) {
      return const Center(child: Text('Not Authenticated'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('GarudaSec Chats'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getChats(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No chats yet. Start one!'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final chat = docs[index].data() as Map<String, dynamic>;
              final members = chat['members'] as List<dynamic>;
              final otherUid = members.firstWhere(
                (uid) => uid != user.uid,
                orElse: () => '',
              );
              final roomId = chat['room_id'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUid)
                    .get(),
                builder: (context, userSnapshot) {
                  String name = 'Loading...';
                  String? publicKey;
                  if (userSnapshot.hasData && userSnapshot.data != null) {
                    name = userSnapshot.data!['username'] ?? 'Unknown';
                    publicKey = userSnapshot.data!['public_key'];
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                      child: const Icon(
                        CupertinoIcons.person_fill,
                        color: Colors.redAccent,
                        shadows: [Shadow(color: Colors.red, blurRadius: 5)],
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      chat['last_message'] ?? '',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    trailing: Text(
                      chat['last_timestamp'] != null
                          ? (chat['last_timestamp'] as Timestamp)
                                .toDate()
                                .toString()
                                .substring(11, 16)
                          : '',
                    ),
                    onTap: () {
                      if (publicKey != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              roomId: roomId,
                              otherUserId: otherUid,
                              otherPublicKey: publicKey!,
                              chatName: name,
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startChat(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
