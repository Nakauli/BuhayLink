import 'package:buhay_link/features/jobs/data/repositories/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'notification_badge.dart';
import '../features/home/presentation/pages/notifications_page.dart';

class HomeAnimatedHeader extends StatefulWidget {
  final DashboardRepository repository;
  final bool showMyPosts;
  final Function(List<String>) onMarkRead;

  const HomeAnimatedHeader({
    super.key,
    required this.repository,
    required this.showMyPosts,
    required this.onMarkRead,
  });

  @override
  State<HomeAnimatedHeader> createState() => _HomeAnimatedHeaderState();
}

class _HomeAnimatedHeaderState extends State<HomeAnimatedHeader> {
  List<Color> _gradientColors = [
    const Color(0xFF2E7EFF),
    const Color(0xFF9C27B0),
  ];
  Alignment _beginAlignment = Alignment.topLeft;
  Alignment _endAlignment = Alignment.bottomRight;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Animates the gradient every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          if (_beginAlignment == Alignment.topLeft) {
            _beginAlignment = Alignment.topRight;
            _endAlignment = Alignment.bottomLeft;
            _gradientColors = [
              const Color(0xFF9C27B0),
              const Color(0xFF2E7EFF),
            ];
          } else {
            _beginAlignment = Alignment.topLeft;
            _endAlignment = Alignment.bottomRight;
            _gradientColors = [
              const Color(0xFF2E7EFF),
              const Color(0xFF9C27B0),
            ];
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final emailName = user?.email?.split('@')[0] ?? "Guest";

    return AnimatedContainer(
      duration: const Duration(seconds: 3),
      padding: const EdgeInsets.only(top: 50, left: 24, right: 24, bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: _beginAlignment,
          end: _endAlignment,
          colors: _gradientColors,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7EFF).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Welcome back,",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (uid != null)
                StreamBuilder<DocumentSnapshot>(
                  stream: widget.repository.getUserStatsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final String realName =
                          data?['name'] ?? data?['fullName'] ?? emailName;
                      return Text(
                        realName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }
                    return Text(
                      emailName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                )
              else
                const Text(
                  "Guest",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          GestureDetector(
            onTap: () {
              if (widget.showMyPosts) {
                widget.onMarkRead(['application']);
              } else {
                widget.onMarkRead([
                  'new_post',
                  'post',
                  'job_post',
                  'created',
                  'hired',
                  'rejected',
                ]);
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      NotificationsPage(isEmployerMode: widget.showMyPosts),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: NotificationBadge(
                icon: Icons.notifications,
                color: Colors.white,
                isEmployerMode: widget.showMyPosts,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
