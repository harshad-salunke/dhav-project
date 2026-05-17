import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class _NotificationItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String time;
  final bool unread;

  const _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.time,
    this.unread = false,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Mock notifications — in production these come from Firebase/backend
  final _notifications = [
    const _NotificationItem(
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.success,
      title: 'Order Accepted!',
      body: 'Ram Kirana Store accepted your order and is packing it now.',
      time: 'Just now',
      unread: true,
    ),
    const _NotificationItem(
      icon: Icons.delivery_dining_rounded,
      iconColor: AppColors.primary,
      title: 'Out for Delivery',
      body: 'Raju is on the way to deliver your order. ETA: ~12 minutes.',
      time: '5 min ago',
      unread: true,
    ),
    const _NotificationItem(
      icon: Icons.home_rounded,
      iconColor: AppColors.success,
      title: 'Order Delivered!',
      body: 'Your order has been delivered. Thank you for shopping with DHAV!',
      time: '2 days ago',
    ),
    const _NotificationItem(
      icon: Icons.storefront_rounded,
      iconColor: AppColors.warning,
      title: 'Store Searching',
      body: 'We are looking for available stores near you. This usually takes less than a minute.',
      time: '3 days ago',
    ),
    const _NotificationItem(
      icon: Icons.cancel_rounded,
      iconColor: AppColors.error,
      title: 'No Stores Available',
      body: 'Sorry, no stores were available for your last order. Please try again later.',
      time: '1 week ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n.unread).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notifications',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () =>
                  setState(() { /* mark all read */ }),
              child: Text('Mark all read',
                  style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, i) =>
                  _NotificationTile(notification: _notifications[i]),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('No notifications yet',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _NotificationItem notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: notification.unread
          ? AppColors.primaryLight.withOpacity(0.4)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notification.iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(notification.icon,
                color: notification.iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(notification.title,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: notification.unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    Text(notification.time,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textHint)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(notification.body,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4)),
              ],
            ),
          ),
          if (notification.unread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, left: 8),
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
