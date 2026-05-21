import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'type': 'order',
      'title': 'New Order Received',
      'body': 'Order #OD-9929 — 3 items worth ₹420. Accept within 45s.',
      'time': '2 min ago',
      'read': false,
      'icon': Icons.shopping_bag_rounded,
      'color': AppColors.primary,
    },
    {
      'type': 'earnings',
      'title': 'Weekly Settlement',
      'body': 'Your week of May 6–12 settlement of ₹6,240 is processed.',
      'time': '1 hour ago',
      'read': false,
      'icon': Icons.account_balance_wallet_rounded,
      'color': AppColors.green,
    },
    {
      'type': 'order',
      'title': 'Order Delivered',
      'body': 'Order #OD-9928 delivered successfully by Ramesh Kumar.',
      'time': '3 hours ago',
      'read': true,
      'icon': Icons.check_circle_rounded,
      'color': AppColors.green,
    },
    {
      'type': 'warning',
      'title': 'Missed Order Alert',
      'body': 'You missed Order #OD-9924. 1 of 3 strikes recorded.',
      'time': 'Yesterday',
      'read': true,
      'icon': Icons.warning_rounded,
      'color': AppColors.red,
    },
    {
      'type': 'system',
      'title': 'Store Status Changed',
      'body': 'Your store was auto-closed at 10:00 PM as per your schedule.',
      'time': 'Yesterday',
      'read': true,
      'icon': Icons.store_rounded,
      'color': AppColors.primary,
    },
    {
      'type': 'earnings',
      'title': 'Platform Fee Due',
      'body': 'Platform fee of ₹330 is due by Monday, 20 May 2026.',
      'time': '2 days ago',
      'read': true,
      'icon': Icons.receipt_rounded,
      'color': AppColors.primary,
    },
    {
      'type': 'system',
      'title': 'App Update Available',
      'body': 'DHAV Store v2.1 is available with new delivery tracking features.',
      'time': '3 days ago',
      'read': true,
      'icon': Icons.system_update_rounded,
      'color': Colors.blue,
    },
  ];

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n['read'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unread = _notifications.where((n) => n['read'] == false).length;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: 0.5),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 64, color: c.textHint),
                  const SizedBox(height: 16),
                  Text('No notifications', style: GoogleFonts.inter(fontSize: 16, color: c.textHint)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = _notifications[i];
                return _NotificationCard(
                  notification: n,
                  c: c,
                  onTap: () => setState(() => n['read'] = true),
                );
              },
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final DhavColors c;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = notification['read'] as bool;
    final color = notification['color'] as Color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? c.card : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? c.divider : color.withValues(alpha: 0.3),
            width: isRead ? 0.5 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(notification['icon'] as IconData, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['body'] as String,
                    style: GoogleFonts.inter(fontSize: 12, color: c.textHint, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification['time'] as String,
                    style: GoogleFonts.inter(fontSize: 11, color: c.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
