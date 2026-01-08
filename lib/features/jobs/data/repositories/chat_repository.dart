import 'package:buhay_link/features/home/presentation/pages/chat_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // 1. GET MESSAGES (Real-time)
  Stream<QuerySnapshot> getMessagesStream(String chatRoomId) {
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 2. SEND MESSAGE (Updated to support Types: text, image, file, location)
  Future<void> sendMessage(
    String chatRoomId,
    String receiverId,
    String content, {
    String type = 'text', // Added named parameter
  }) async {
    final String senderId = _auth.currentUser?.uid ?? "";
    if (senderId.isEmpty || content.trim().isEmpty) return;

    final messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': content.trim(), // Changed key to 'message' to match UI
      'type': type, // Save the type
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    // Add to sub-collection
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    // Determine Preview Text for the Chat List
    String previewText = content.trim();
    if (type == 'image')
      previewText = "📷 Image";
    else if (type == 'file')
      previewText = "📎 Attachment";
    else if (type == 'location')
      previewText = "📍 Location";

    // Update Chat Room Metadata
    await _firestore.collection('chats').doc(chatRoomId).set({
      'lastMessage': previewText, // Shows "📷 Image" instead of URL
      'lastTimestamp': FieldValue.serverTimestamp(),
      'users': [senderId, receiverId],
      'lastSenderId': senderId,
      'isRead': false,
    }, SetOptions(merge: true));
  }

  // 3. GET ALL CHAT ROOMS
  Stream<QuerySnapshot> getAllChatRoomsStream() {
    final String uid = _auth.currentUser?.uid ?? "";
    if (uid.isEmpty) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('users', arrayContains: uid)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }

  // 4. GET USER STATUS
  Stream<DocumentSnapshot> getUserStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // 5. START CHAT
  Future<void> startChat(
    BuildContext context,
    String receiverId,
    String receiverName,
    String? receiverPhoto,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    List<String> ids = [currentUser.uid, receiverId];
    ids.sort();
    String chatRoomId = ids.join("_");

    final chatDoc = await _firestore.collection('chats').doc(chatRoomId).get();
    if (!chatDoc.exists) {
      await _firestore.collection('chats').doc(chatRoomId).set({
        'users': ids,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastMessage': 'Started a conversation',
        'createdBy': currentUser.uid,
        'isRead': true,
        'lastSenderId': currentUser.uid,
      });
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            receiverId: receiverId,
            receiverName: receiverName,
          ),
        ),
      );
    }
  }

  // 6. MARK MESSAGES AS READ (New Method for UI)
  Future<void> markMessagesAsRead(String receiverId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    List<String> ids = [currentUser.uid, receiverId];
    ids.sort();
    String chatRoomId = ids.join("_");

    // Update Room Status
    await _firestore.collection('chats').doc(chatRoomId).update({
      'isRead': true,
    });
  }

  Stream<DocumentSnapshot> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
