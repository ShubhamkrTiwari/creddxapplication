import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
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
          Padding(
            padding: const EdgeInsets.only(top: 24, right: 8),
            child: TextButton(
              onPressed: () {
                // Handle mark as read action
              },
              child: const Text(
                'Mark as read',
                style: TextStyle(color: Color(0xFF84BD00), fontSize: 14),
              ),
            ),
          ),
        ],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latest',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildNotificationItem(
              'Transaction Successful',
              'Your deposit of \$500.00 has been completed',
              '2 minutes ago',
              Icons.check_circle,
              const Color(0xFF84BD00),
            ),
            _buildNotificationItem(
              'Price Alert',
              'BTC has reached \$45,000',
              '15 minutes ago',
              Icons.trending_up,
              const Color(0xFFF7931A),
            ),
            const SizedBox(height: 32),
            const Text(
              'Last 7 Days',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildNotificationItem(
              'Security Alert',
              'New login detected from mobile device',
              '2 days ago',
              Icons.security,
              const Color(0xFFE74C3C),
            ),
            _buildNotificationItem(
              'Transaction Failed',
              'Withdrawal of \$200.00 failed',
              '3 days ago',
              Icons.error,
              const Color(0xFFE74C3C),
            ),
            _buildNotificationItem(
              'Weekly Summary',
              'Your weekly profit is \$1,250.00',
              '5 days ago',
              Icons.analytics,
              const Color(0xFF627EEA),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String title, String description, String time, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF6C7278),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFF6C7278),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
