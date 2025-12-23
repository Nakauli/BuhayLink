import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // SOLID: SRP - Handles only the data flow for messages
  Stream<QuerySnapshot> getMessagesStream(String chatRoomId) {
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Functional: Sends a message and updates the main chat document
  Future<void> sendMessage(String chatRoomId, String receiverId, String text) async {
    final String senderId = _auth.currentUser?.uid ?? "";
    if (senderId.isEmpty || text.trim().isEmpty) return;

    final messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    // 1. Add message to sub-collection
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    // 2. Update the parent doc for the "Last Message" preview in the list
    await _firestore.collection('chats').doc(chatRoomId).set({
      'lastMessage': text.trim(),
      'lastTimestamp': FieldValue.serverTimestamp(),
      'users': [senderId, receiverId],
    }, SetOptions(merge: true));
  }
  // SOLID: SRP - Handles fetching the list of all active conversations
  Stream<QuerySnapshot> getAllChatRoomsStream() {
    final String uid = _auth.currentUser?.uid ?? "";
    if (uid.isEmpty) return const Stream.empty();

    // Fetches chat rooms where the current user is a participant
    return _firestore
        .collection('chats')
        .where('users', arrayContains: uid)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }
}