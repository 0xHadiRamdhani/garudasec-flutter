import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/security_service.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String otherUserId;
  final String otherPublicKey;
  final String chatName;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.otherUserId,
    required this.otherPublicKey,
    required this.chatName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _dbService = DatabaseService();
  final _securityService = SecurityService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  String? _myPublicKey;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyKeys();
  }

  Future<void> _loadMyKeys() async {
    _myPublicKey = await _securityService.getPublicKey();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _myPublicKey == null || _currentUser == null) return;

    _messageController.clear();

    try {
      // Encrypt for BOTH me and the recipient
      final encryptedData = await _securityService.encryptMessage(
        text,
        _currentUser.uid,
        _myPublicKey!,
        widget.otherUserId,
        widget.otherPublicKey,
      );

      await _dbService.sendMessage(
        widget.roomId,
        _currentUser.uid,
        encryptedData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              CupertinoIcons.padlock_solid,
              size: 16,
              color: Colors.redAccent,
              shadows: [Shadow(color: Colors.red, blurRadius: 10)],
            ),
            const SizedBox(width: 8),
            Text(widget.chatName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms/${widget.roomId}/messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['sender_id'] == _currentUser?.uid;

                    return ChatBubble(messageData: data, isMe: isMe);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a secure message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.redAccent,
                      shadows: [Shadow(color: Colors.red, blurRadius: 10)],
                    ),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
