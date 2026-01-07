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

  // 2. SEND MESSAGE (FIXED: Uses 'lastTimestamp' and 'users')
  Future<void> sendMessage(
    String chatRoomId,
    String receiverId,
    String text,
  ) async {
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

    // [FIXED] Using 'lastTimestamp' to match your existing data
    await _firestore.collection('chats').doc(chatRoomId).set({
      'lastMessage': text.trim(),
      'lastTimestamp':
          FieldValue.serverTimestamp(), // Reverted to lastTimestamp
      'users': [senderId, receiverId], // Reverted to users
      'lastSenderId': senderId,
      'isRead': false,
    }, SetOptions(merge: true));
  }

  // 3. GET ALL CHAT ROOMS (FIXED QUERY)
  Stream<QuerySnapshot> getAllChatRoomsStream() {
    final String uid = _auth.currentUser?.uid ?? "";
    if (uid.isEmpty) return const Stream.empty();

    // [FIXED] Queries 'users' and sorts by 'lastTimestamp' to find old chats
    return _firestore
        .collection('chats')
        .where('users', arrayContains: uid)
        .orderBy('lastTimestamp', descending: true) // Reverted to lastTimestamp
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

  Stream<DocumentSnapshot> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
