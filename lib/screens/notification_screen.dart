import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late Future<List<AppNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notificationsFuture = NotificationService.getNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationService.markAllAsRead();
              _loadNotifications();
            },
            child: const Text(
              'Mark as read',
              style: TextStyle(color: Color(0xFF84BD00), fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E20),
                  title: const Text('Clear all notifications?', style: TextStyle(color: Colors.white)),
                  content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Clear All', style: TextStyle(color: Color(0xFFE74C3C))),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await NotificationService.clearAll();
                _loadNotifications();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadNotifications();
            },
            color: const Color(0xFF84BD00),
            backgroundColor: const Color(0xFF1E1E20),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.transaction:
        icon = Icons.swap_horiz;
        iconColor = const Color(0xFF84BD00);
        break;
      case NotificationType.security:
        icon = Icons.security;
        iconColor = const Color(0xFFE74C3C);
        break;
      case NotificationType.price:
        icon = Icons.trending_up;
        iconColor = const Color(0xFFF7931A);
        break;
      case NotificationType.info:
      default:
        icon = Icons.info_outline;
        iconColor = const Color(0xFF627EEA);
        break;
    }

    return GestureDetector(
      onTap: () async {
        if (!notification.isRead) {
          await NotificationService.markAsRead(notification.id);
          _loadNotifications();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? const Color(0xFF1E1E20) : const Color(0xFF252528),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead ? Colors.white.withOpacity(0.1) : const Color(0xFF84BD00).withOpacity(0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      color: Color(0xFF6C7278),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              notification.relativeTime,
              style: const TextStyle(
                color: Color(0xFF6C7278),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
