import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/widgets/shimmer_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final np = context.watch<StoreNotificationProvider>();
    final notifications = np.notifications;
    final unread = np.unreadCount;

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
          style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
              letterSpacing: 0.5),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  context.read<StoreNotificationProvider>().markAllRead(),
              child: Text(
                'Mark all read',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: np.loading
          ? const NotificationsShimmer()
          : notifications.isEmpty
          ? _buildEmpty(c)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = notifications[i];
                return _NotificationCard(
                  notification: n,
                  c: c,
                  onTap: () {
                    context.read<StoreNotificationProvider>().markRead(n.id);
                    // Navigate to relevant screen if there's an order
                    if (n.orderId != null) {
                      if (n.type == StoreNotificationType.newOrder) {
                        Navigator.pushNamed(context, AppRoutes.incomingOrder,
                            arguments: n.orderId);
                      } else {
                        Navigator.pushNamed(context, AppRoutes.orderDetail,
                            arguments: n.orderId);
                      }
                    }
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmpty(DhavColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_rounded, size: 64, color: c.textHint),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: GoogleFonts.inter(fontSize: 16, color: c.textHint),
          ),
          const SizedBox(height: 6),
          Text(
            'Order alerts and updates will appear here',
            style: GoogleFonts.inter(fontSize: 13, color: c.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final StoreNotification notification;
  final DhavColors c;
  final VoidCallback onTap;

  const _NotificationCard(
      {required this.notification, required this.c, required this.onTap});

  IconData get _icon {
    switch (notification.type) {
      case StoreNotificationType.newOrder:
        return Icons.shopping_bag_rounded;
      case StoreNotificationType.orderDelivered:
        return Icons.check_circle_rounded;
      case StoreNotificationType.settlement:
        return Icons.account_balance_wallet_rounded;
      case StoreNotificationType.strike:
        return Icons.warning_rounded;
      case StoreNotificationType.deliveryAssigned:
        return Icons.delivery_dining_rounded;
      case StoreNotificationType.announcement:
        return Icons.campaign_rounded;
      case StoreNotificationType.offer:
        return Icons.local_offer_rounded;
      case StoreNotificationType.system:
        return Icons.info_outline_rounded;
    }
  }

  Color get _color {
    switch (notification.type) {
      case StoreNotificationType.newOrder:
        return AppColors.primary;
      case StoreNotificationType.orderDelivered:
        return AppColors.green;
      case StoreNotificationType.settlement:
        return AppColors.green;
      case StoreNotificationType.strike:
        return AppColors.red;
      case StoreNotificationType.deliveryAssigned:
        return AppColors.primary;
      case StoreNotificationType.announcement:
        return AppColors.primary;
      case StoreNotificationType.offer:
        return AppColors.green;
      case StoreNotificationType.system:
        return AppColors.primary;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final color = _color;

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
              child: Icon(_icon, color: color, size: 22),
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
                          notification.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: c.textHint, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notification.receivedAt),
                    style:
                        GoogleFonts.inter(fontSize: 11, color: c.textHint),
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
