import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';// Run 'flutter pub add intl' if you get an error

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listen for notifications sent to THIS user
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("No notifications yet", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = snapshot.data!.docs[index];
              final data = notification.data() as Map<String, dynamic>;
              final bool isRead = data['read'] ?? false;

              return ListTile(
                tileColor: isRead ? Colors.white : Colors.blue[50], // Blue background if unread
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF2E7EFF),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(data['message'] ?? "New Notification", style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(_formatTimestamp(data['timestamp'])),
                onTap: () {
                  // Mark as read when clicked
                  notification.reference.update({'read': true});
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    return DateFormat.yMMMd().add_jm().format(date);
  }
}