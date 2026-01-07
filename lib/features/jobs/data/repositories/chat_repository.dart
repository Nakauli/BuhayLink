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

  Stream<QuerySnapshot> getMessagesStream(String chatRoomId) {
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 2. SEND MESSAGE (UPDATED FOR RED DOT)
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

    // [CRITICAL UPDATE] Update Main Chat Doc for Dashboard Notification
    // 'participants' must arrayContains me for the query to work
    // 'lastSenderId' tells the receiver "this wasn't you"
    // 'isRead': false triggers the red dot
    await _firestore.collection('chats').doc(chatRoomId).set({
      'lastMessage': text.trim(),
      'lastMessageTime':
          FieldValue.serverTimestamp(), // Fixed field name for sorting
      'participants': [
        senderId,
        receiverId,
      ], // Renamed 'users' to 'participants' to match Dashboard query
      'lastSenderId': senderId, // Crucial for "unread" logic
      'isRead': false, // Crucial for red dot
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getAllChatRoomsStream() {
    final String uid = _auth.currentUser?.uid ?? "";
    if (uid.isEmpty) return const Stream.empty();

    // Updated to match the 'sendMessage' field 'participants'
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot> getUserStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

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
        'participants': ids, // Consistent field name
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessage': 'Started a conversation',
        'createdBy': currentUser.uid,
        'isRead': true, // Start as read
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
