import 'package:flutter/material.dart';
import 'chat_detail_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _searchController = TextEditingController();

  // Mock Data based on your screenshot
  final List<Map<String, dynamic>> _conversations = [
    {
      "name": "Maria Santos",
      "message": "When can you start the plumbing work?",
      "jobTag": "Kitchen Plumbing Repair",
      "time": "10:30 AM",
      "unreadCount": 2,
      "avatarColor": const Color(0xFF5F60FF), // Blue-ish
    },
    {
      "name": "Juan dela Cruz",
      "message": "Thanks for applying! Can we discuss the timeline?",
      "jobTag": "Custom Furniture",
      "time": "Yesterday",
      "unreadCount": 0,
      "avatarColor": const Color(0xFF9845FF), // Purple-ish
    },
    {
      "name": "Ana Reyes",
      "message": "I sent you the updated requirements",
      "jobTag": "House Painting",
      "time": "2 days ago",
      "unreadCount": 1,
      "avatarColor": const Color(0xFF5F60FF),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // --- 1. HEADER ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text("Messages", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),

            // --- 2. SEARCH BAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search conversations...",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  // Blue border when focused, Grey when not (like screenshot)
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF2E7EFF))),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // --- 3. CONVERSATION LIST ---
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _conversations.length,
                separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                itemBuilder: (context, index) {
                  final chat = _conversations[index];
                  return _buildConversationItem(chat);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildConversationItem(Map<String, dynamic> chat) {
    return InkWell(
      onTap: () {
        // --- NAVIGATION LOGIC ---
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              userName: chat['name'],
              jobTitle: chat['jobTag'],
              budget: "₱5,000", // You can add this to your data map later
              avatarColor: chat['avatarColor'],
              isOnline: true, // We assume they are online for this demo
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [chat['avatarColor'], chat['avatarColor'].withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              // Green Online Dot (Visual only for list)
              child: Stack(
                children: [
                   // (Avatar is background)
                   Positioned(
                     right: 0, bottom: 0,
                     child: Container(
                       width: 14, height: 14,
                       decoration: BoxDecoration(
                         color: Colors.green, 
                         shape: BoxShape.circle,
                         border: Border.all(color: Colors.white, width: 2),
                       ),
                     ),
                   )
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(chat['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(chat['time'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          if (chat['unreadCount'] > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Color(0xFF2E7EFF), shape: BoxShape.circle),
                              child: Text(chat['unreadCount'].toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          ]
                        ],
                      )
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(0, -5),
                    child: Text(chat['message'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(chat['jobTag'], style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}