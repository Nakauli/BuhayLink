import 'package:buhay_link/features/jobs/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// SOLID: Dependency Inversion - UI depends on the Repository

import 'chat_detail_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final ChatRepository _chatRepository = ChatRepository();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Messages", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _currentUserId.isEmpty
          ? const Center(child: Text("Please login to see messages"))
          : StreamBuilder<QuerySnapshot>(
              stream: _chatRepository.getAllChatRoomsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text("No conversations yet", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final chatRooms = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: chatRooms.length,
                  itemBuilder: (context, index) {
                    final chatData = chatRooms[index].data() as Map<String, dynamic>;
                    final List users = chatData['users'] ?? [];
                    
                    // Identify the other person in the chat
                    final String receiverId = users.firstWhere((id) => id != _currentUserId, orElse: () => "");

                    if (receiverId.isEmpty) return const SizedBox.shrink();

                    return _buildChatTile(chatData, receiverId);
                  },
                );
              },
            ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chatData, String receiverId) {
    // We fetch the receiver's name from the users collection for accuracy
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(receiverId).snapshots(),
      builder: (context, userSnapshot) {
        String name = "User";
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          name = userData['fullName'] ?? userData['firstName'] ?? "User";
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue[50],
            child: Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF2E7EFF), fontWeight: FontWeight.bold)),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            chatData['lastMessage'] ?? "No messages yet",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600]),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailPage(
                  receiverId: receiverId,
                  receiverName: name,
                ),
              ),
            );
          },
        );
      },
    );
  }
}