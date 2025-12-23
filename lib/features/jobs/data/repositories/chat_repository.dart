import 'package:buhay_link/features/home/presentation/pages/chat_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


class ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Dependency Injection
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
  

  // 2. SEND MESSAGE
  Future<void> sendMessage(String chatRoomId, String receiverId, String text) async {
    final String senderId = _auth.currentUser?.uid ?? "";
    if (senderId.isEmpty || text.trim().isEmpty) return;

    final messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Add to sub-collection
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    // Update summary for the list view
    await _firestore.collection('chats').doc(chatRoomId).set({
      'lastMessage': text.trim(),
      'lastTimestamp': FieldValue.serverTimestamp(),
      'users': [senderId, receiverId], // Critical for the query!
    }, SetOptions(merge: true));
  }

  // 3. GET ALL CHAT ROOMS (For Messages Page)
  Stream<QuerySnapshot> getAllChatRoomsStream() {
    final String uid = _auth.currentUser?.uid ?? "";
    if (uid.isEmpty) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('users', arrayContains: uid)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }

  // 4. GET USER STATUS (For the Green Circle)
  Stream<DocumentSnapshot> getUserStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // 5. START CHAT (Navigates & Ensures Doc Exists)
  Future<void> startChat(BuildContext context, String receiverId, String receiverName) async {
    final String currentUserId = _auth.currentUser?.uid ?? "";
    if (currentUserId.isEmpty) return;

    List<String> ids = [currentUserId, receiverId];
    ids.sort(); // Ensure consistent ID generation
    String chatRoomId = ids.join("_");

    // Check if chat exists, if not create it immediately so it appears in lists
    final chatDoc = await _firestore.collection('chats').doc(chatRoomId).get();
    if (!chatDoc.exists) {
      await _firestore.collection('chats').doc(chatRoomId).set({
        'users': ids, 
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastMessage': 'Started a conversation',
        'createdBy': currentUserId,
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
  // SOLID: SRP - Handles fetching user profile data for the UI
  Stream<DocumentSnapshot> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}