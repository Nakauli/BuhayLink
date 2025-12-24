import 'package:buhay_link/features/jobs/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// SOLID: Import the Repository
import 'chat_detail_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  // SOLID: Dependency Inversion - UI depends on the Repository
  final ChatRepository _chatRepository = ChatRepository();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB), // Modern light grey background
      appBar: AppBar(
        title: const Text("Messages", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.white,
        elevation: 0.5,
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
                        Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("No conversations yet", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      ],
                    ),
                  );
                }

                final chatRooms = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: chatRooms.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12), // Spacing between cards
                  itemBuilder: (context, index) {
                    final chatDoc = chatRooms[index];
                    final chatData = chatDoc.data() as Map<String, dynamic>;
                    final List users = chatData['users'] ?? [];
                    
                    // Identify the other person in the chat
                    final String receiverId = users.firstWhere((id) => id != _currentUserId, orElse: () => "");

                    if (receiverId.isEmpty) return const SizedBox.shrink();

                    // Build the modern chat tile
                    return _buildChatTile(chatData, receiverId);
                  },
                );
              },
            ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chatData, String receiverId) {
    // SOLID: Use repository to fetch the other user's profile
    return StreamBuilder<DocumentSnapshot>(
      stream: _chatRepository.getUserProfileStream(receiverId),
      builder: (context, userSnapshot) {
        String name = "User";
        String? profileImageUrl;
        
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          name = userData['fullName'] ?? userData['firstName'] ?? userData['username'] ?? "User";
          profileImageUrl = userData['profileImageUrl'];
        }

        final String lastMessage = chatData['lastMessage'] ?? "No messages yet";
        final Timestamp? lastTimestamp = chatData['lastTimestamp'];
        final String timeString = _formatTimestamp(lastTimestamp);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Avatar with image or initials
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.blue[50],
                      backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                      child: profileImageUrl == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : "?",
                              style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 20),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // Name, Message, and Time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                timeString,
                                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper function to format timestamp into a readable string
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final DateTime date = timestamp.toDate();
    final DateTime now = DateTime.now();

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      // Today: Show time (e.g., 10:30 AM)
      String hour = date.hour > 12 ? (date.hour - 12).toString() : (date.hour == 0 ? "12" : date.hour.toString());
      String minute = date.minute.toString().padLeft(2, '0');
      String period = date.hour < 12 ? "AM" : "PM";
      return "$hour:$minute $period";
    } else if (now.difference(date).inDays < 7) {
      // This week: Show weekday name (e.g., Mon, Tue)
      const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      return weekdays[date.weekday - 1];
    } else {
      // Older: Show date (e.g., 10/25/23)
      return "${date.month}/${date.day}/${date.year.toString().substring(2)}";
    }
  }
}