import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final bool isEmployerMode;

  const NotificationBadge({
    super.key,
    this.icon = Icons.notifications,
    this.color,
    required this.isEmployerMode,
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
            final posterId = data['posterId'];

            // 1. EMPLOYER MODE (My Posts)
            // Show only when people apply to me
            if (isEmployerMode) {
              return type == 'application';
            }
            // Show New Jobs, Hires, and Rejections
            // 2. APPLICANT MODE (Find Jobs)
            else {
              // CHANGE: I added more possible spellings here to be safe
              bool isRelevant = [
                'new_post',
                'post', // <--- Maybe your DB uses this?
                'job_post', // <--- Or this?
                'created', // <--- Or this?
                'hired',
                'rejected',
              ].contains(type);

              bool isNotMyOwnPost = posterId != uid;

              return isRelevant && isNotMyOwnPost;
            }
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
