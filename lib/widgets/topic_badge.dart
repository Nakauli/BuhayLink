import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TopicBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final List<String> filterTypes;

  const TopicBadge({
    super.key,
    required this.icon,
    required this.filterTypes,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Icon(icon, color: color);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', whereIn: [uid, 'all'])
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;

        if (snapshot.hasData) {
          count = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? '';
            final posterId = data['posterId']; // Get the creator's ID

            // 1. Must be the right type (e.g. 'new_post')
            bool isCorrectType = filterTypes.contains(type);

            // 2. Must NOT be my own post (The Fix)
            bool isNotMyOwnPost = posterId != uid;

            return isCorrectType && isNotMyOwnPost;
          }).length;
        }

        return Badge(
          isLabelVisible: count > 0,
          label: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          backgroundColor: Colors.red,
          child: Icon(icon, color: color),
        );
      },
    );
  }
}
