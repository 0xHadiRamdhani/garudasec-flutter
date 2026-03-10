import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ... (existing methods)

  // Update User Profile
  Future<void> updateUserProfile(
    String uid, {
    String? username,
    String? photoUrl,
  }) async {
    final Map<String, dynamic> data = {};
    if (username != null) data['username'] = username;
    if (photoUrl != null) data['photo_url'] = photoUrl;

    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).update(data);
    }
  }

  // Upload Profile Image
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    final ref = _storage.ref().child('user_profiles').child('$uid.jpg');
    final uploadTask = ref.putFile(imageFile);
    final snapshot = await uploadTask;

    return await snapshot.ref.getDownloadURL();
  }

  // Save user profile with Public Key
  Future<void> saveUser(
    String uid,
    String email,
    String username,
    String publicKey,
  ) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'username': username,
      'public_key': publicKey,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // Get user's Public Key
  Future<String?> getUserPublicKey(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!['public_key'] as String?;
    }
    return null;
  }

  // Get user by email (for searching)
  Future<QuerySnapshot> searchUser(String email) {
    return _db.collection('users').where('email', isEqualTo: email).get();
  }

  // Create Chat Room
  Future<String> createChatRoom(
    String currentUserId,
    String otherUserId,
  ) async {
    // Check if room exists (naive approach: check both combinations)
    // For production, use a consistent ID generation like hash(uid1, uid2) where uid1 < uid2
    List<String> members = [currentUserId, otherUserId];
    members.sort(); // consistent order
    String roomId = members.join('_');

    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    if (!roomDoc.exists) {
      await _db.collection('rooms').doc(roomId).set({
        'room_id': roomId,
        'members': members,
        'created_at': FieldValue.serverTimestamp(),
        'last_message': '',
        'last_timestamp': FieldValue.serverTimestamp(),
      });
    }
    return roomId;
  }

  // Send Message
  Future<void> sendMessage(
    String roomId,
    String senderId,
    Map<String, dynamic> encryptedData,
  ) async {
    await _db.collection('rooms').doc(roomId).collection('messages').add({
      'sender_id': senderId,
      'content': encryptedData['content'], // Encrypted Content (AES-Base64)
      'iv': encryptedData['iv'], // IV for AES
      'keys': encryptedData['keys'], // Map<UserId, EncryptedAESKey>
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update last message in room
    await _db.collection('rooms').doc(roomId).update({
      'last_message': '🔒 Encrypted Message',
      'last_timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get Chats Stream
  Stream<QuerySnapshot> getChats(String userId) {
    return _db
        .collection('rooms')
        .where('members', arrayContains: userId)
        .orderBy('last_timestamp', descending: true)
        .snapshots();
  }
}
