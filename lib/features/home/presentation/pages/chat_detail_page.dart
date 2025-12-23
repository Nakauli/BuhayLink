import 'package:buhay_link/features/jobs/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// SOLID: Import the Repository


class ChatDetailPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatDetailPage({super.key, required this.receiverId, required this.receiverName});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ChatRepository _chatRepository = ChatRepository();
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  final ScrollController _scrollController = ScrollController();

  String get _chatRoomId {
    List<String> ids = [_currentUserId, widget.receiverId];
    ids.sort();
    return ids.join("_");
  }

  void _handleSendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _chatRepository.sendMessage(_chatRoomId, widget.receiverId, _messageController.text);
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // List is reversed, so 0 is the bottom
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeOut
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB), // Softer background color
      appBar: _buildModernAppBar(),
      body: Column(
        children: [
          // 1. REAL-TIME MESSAGE LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatRepository.getMessagesStream(_chatRoomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Newest messages at the bottom
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == _currentUserId;
                    
                    // Check if we should show the avatar (only for the receiver)
                    bool showAvatar = !isMe;
                    // Optimization: Only show avatar if previous message was from different user
                    if (index > 0) {
                      final prevData = messages[index - 1].data() as Map<String, dynamic>;
                      if (prevData['senderId'] == data['senderId']) {
                        showAvatar = false;
                      }
                    }

                    return _buildMessageBubble(data['text'] ?? "", isMe, showAvatar);
                  },
                );
              },
            ),
          ),

          // 2. MODERN INPUT BAR
          _buildInputBar(),
        ],
      ),
    );
  }

  // --- UI WIDGETS ---

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.grey.withOpacity(0.1),
      leading: const BackButton(color: Colors.black),
      titleSpacing: 0,
      title: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
        builder: (context, snapshot) {
          String name = widget.receiverName;
          bool isActive = true; // You can hook this to real status later

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['fullName'] ?? data['firstName'] ?? name;
          }

          return Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(name[0].toUpperCase(), style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                  ),
                  if (isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text("Active now", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w400)),
                ],
              ),
            ],
          );
        },
      ),
      actions: [
        IconButton(icon: const Icon(Icons.phone, color: Colors.blue), onPressed: () {}),
        IconButton(icon: const Icon(Icons.info_outline, color: Colors.black54), onPressed: () {}),
      ],
    );
  }

  Widget _buildMessageBubble(String message, bool isMe, bool showAvatar) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4, top: showAvatar ? 8 : 0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar)
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey[300],
                child: Text(widget.receiverName[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
              )
            else
              const SizedBox(width: 28), // Spacer to align text
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // Gradient for sender, solid grey for receiver
                gradient: isMe 
                  ? const LinearGradient(colors: [Color(0xFF2E7EFF), Color(0xFF0052CC)]) 
                  : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.3
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF2E7EFF), size: 28), onPressed: () {}),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleSendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7EFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}