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
        .collection(
          'chats',
        ) // Note: Ensure this matches 'chat_rooms' or 'chats' consistently. Your previous code used 'chats', so I kept it.
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 2. SEND MESSAGE (Updated for Seen & Delete features)
  Future<void> sendMessage(
    String chatRoomId,
    String receiverId,
    String content, {
    String type = 'text',
  }) async {
    final String senderId = _auth.currentUser?.uid ?? "";
    if (senderId.isEmpty || content.trim().isEmpty) return;

    final messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': content.trim(),
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false, // For the chat room indicator
      'isSeen': false, // [NEW] For the double check icon
      'deletedFor': [], // [NEW] List of user IDs who deleted this message
    };

    // Add to sub-collection
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    // Determine Preview Text
    String previewText = content.trim();
    if (type == 'image') {
      previewText = "📷 Image";
    } else if (type == 'file') {
      previewText = "📎 Attachment";
    } else if (type == 'location') {
      previewText = "📍 Location";
    }

    // Update Chat Room Metadata
    await _firestore.collection('chats').doc(chatRoomId).set({
      'lastMessage': previewText,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'users': [senderId, receiverId],
      'lastSenderId': senderId,
      'isRead': false,
    }, SetOptions(merge: true));
  }

  // [NEW] 2.1 DELETE MESSAGE LOGIC
  Future<void> deleteMessage(
    String chatRoomId,
    String messageId, {
    required bool forEveryone,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final docRef = _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    if (forEveryone) {
      // Hard Delete: Remove the document completely
      await docRef.delete();

      // Optional: Update last message in chat room if needed (complex, can skip for now)
    } else {
      // Soft Delete: Add user ID to 'deletedFor' array
      await docRef.update({
        'deletedFor': FieldValue.arrayUnion([currentUserId]),
      });
    }
  }

  // [NEW] 2.2 MARK MESSAGES AS SEEN (Bulk Update)
  Future<void> markMessagesAsSeen(String chatRoomId, String receiverId) async {
    // 1. Mark the room as read for the current user
    await _firestore.collection('chats').doc(chatRoomId).update({
      'isRead': true,
    });

    // 2. Mark individual messages as 'isSeen: true'
    // We only update messages sent BY the other person that are NOT seen yet
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('senderId', isEqualTo: receiverId) // Messages sent BY them
        .where('isSeen', isEqualTo: false) // That are not seen yet
        .get();

    final batch = _firestore.batch();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isSeen': true});
    }

    await batch.commit();
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

  Stream<DocumentSnapshot> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
