import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import '../services/security_service.dart';

class ChatBubble extends StatefulWidget {
  final Map<String, dynamic> messageData;
  final bool isMe;

  const ChatBubble({super.key, required this.messageData, required this.isMe});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  final _securityService = SecurityService();
  late Future<String> _decryptedContentFuture;

  @override
  void initState() {
    super.initState();
    _decryptedContentFuture = _decrypt();
  }

  Future<String> _decrypt() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "⚠ Auth Error";

    try {
      final keys = widget.messageData['keys'];
      final String? myEncryptedKey = keys is Map ? keys[uid] : null;

      if (myEncryptedKey == null) {
        return "⛔ Unreadable (Key missing)";
      }

      final content = widget.messageData['content'];
      final iv = widget.messageData['iv'];

      return await _securityService.decryptMessage(content, myEncryptedKey, iv);
    } catch (e) {
      return "⚠ Decryption Error";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.redAccent.withValues(alpha: 0.2)
              : const Color(0xFF222222),
          border: widget.isMe
              ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5))
              : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: widget.isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: widget.isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: FutureBuilder<String>(
          future: _decryptedContentFuture,
          builder: (context, snapshot) {
            final textStyle = TextStyle(
              color: Colors.white,
              shadows: widget.isMe
                  ? [const Shadow(color: Colors.red, blurRadius: 5)]
                  : null,
            );

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text(
                "🔓 Decrypting...",
                style: textStyle.copyWith(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              );
            }
            if (snapshot.hasError) {
              return Text("Error", style: textStyle);
            }
            return Text(snapshot.data ?? "", style: textStyle);
          },
        ),
      ),
    );
  }
}

// Fix class name mismatch

// Wait, I messed up the class names in the state. Fixing inline.
