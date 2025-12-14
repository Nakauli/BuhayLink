import 'package:flutter/material.dart';

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
        // Navigate to chat detail later
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
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row (Name + Time + Badge)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(chat['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      
                      // Right Side: Time & Badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(chat['time'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          if (chat['unreadCount'] > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E7EFF), // Brand Blue
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                chat['unreadCount'].toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            )
                          ]
                        ],
                      )
                    ],
                  ),
                  
                  // Message Preview
                  // We use a slight transform to pull the text up if there is no badge, to align nicely
                  Transform.translate(
                    offset: const Offset(0, -5), // Pull up slightly closer to name
                    child: Text(
                      chat['message'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                  
                  const SizedBox(height: 4),

                  // Job Tag (Green Dot + Text)
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        chat['jobTag'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
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