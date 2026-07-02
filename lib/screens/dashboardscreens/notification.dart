import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final Color primaryTeal = const Color(0xFF008080);
  List notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('id');

    try {
      final response = await http.get(Uri.parse(
          "http://localhost/school_api/api.php?action=get-notifications&user_id=$userId"));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            notifications = data['data'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint("Error fetching notifications: $e");
    }
  }

  Future<void> markAsRead(String id, int index) async {
    try {
      await http.get(Uri.parse("http://localhost/school_api/api.php?action=mark-read&id=$id"));
      setState(() {
        notifications[index]['is_read'] = 1; // Mark as read locally
      });
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> deleteNotification(String id, int index) async {
    final removedItem = notifications[index];
    setState(() => notifications.removeAt(index));

    try {
      final response = await http.get(Uri.parse("http://localhost/school_api/api.php?action=delete-notification&id=$id"));
      final data = json.decode(response.body);

      if (!data['success']) {
        setState(() => notifications.insert(index, removedItem));
      }
    } catch (e) {
      setState(() => notifications.insert(index, removedItem));
    }
  }

  String formatTimeAgo(String dateStr) {
    try {
      DateTime dateTime = DateTime.parse(dateStr).toLocal();
      final difference = DateTime.now().difference(dateTime);
      if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
      if (difference.inHours < 24) return "${difference.inHours}h ago";
      return DateFormat('dd MMM').format(dateTime);
    } catch (e) {
      return "Just now";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handling both String "0" and int 0 from DB
    int unreadCount = notifications.where((n) => n["is_read"].toString() == "0").length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchNotifications,
          color: primaryTeal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Notifications",
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    if (unreadCount > 0) _buildBadge(unreadCount),
                  ],
                ),
                const SizedBox(height: 25),
                Expanded(
                  child: isLoading
                      ? Center(child: CircularProgressIndicator(color: primaryTeal))
                      : notifications.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    itemCount: notifications.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return Dismissible(
                        key: Key(item['id'].toString()),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) => deleteNotification(item['id'].toString(), index),
                        background: _buildDeleteBackground(),
                        child: _buildNotificationItem(item, index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: primaryTeal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text("$count New", style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildNotificationItem(dynamic notif, int index) {
    IconData icon;
    Color iconColor;
    bool isRead = notif["is_read"].toString() == "1";

    // Logic for Icons based on API types
    switch (notif["type"]) {
      case 'assignment':
        icon = Icons.assignment_outlined;
        iconColor = primaryTeal;
        break;
      case 'submission':
        icon = Icons.file_upload_outlined;
        iconColor = Colors.blue;
        break;
      case 'alert': // FOR DOUBT REPLIES
        icon = Icons.question_answer_rounded;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.notifications_none_rounded;
        iconColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () => markAsRead(notif['id'].toString(), index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isRead ? null : Border.all(color: primaryTeal.withOpacity(0.2), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                if (!isRead)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      height: 12,
                      width: 12,
                      decoration: BoxDecoration(
                        color: primaryTeal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif["title"] ?? "Notification",
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        formatTimeAgo(notif["created_at"]),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif["message"] ?? "",
                    style: TextStyle(
                      color: isRead ? Colors.grey.shade600 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No notifications yet", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}