import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';

/// Blocking screen shown after login. Forces the user to grant the
/// permissions DHAV needs to deliver order alerts reliably:
///   1. POST_NOTIFICATIONS (Android 13+)
///   2. Full-screen intent (Android 14+, Uber-style auto-popup)
///   3. Ignore battery optimizations (so FCM is delivered when app is killed)
///
/// Pass the route name to navigate to once everything is granted.
class PermissionGateScreen extends StatefulWidget {
  final String nextRoute;
  const PermissionGateScreen({super.key, required this.nextRoute});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen>
    with WidgetsBindingObserver {
  bool _notifGranted = false;
  bool _fsiGranted = false;
  bool _batteryIgnored = false;
  bool _overlayGranted = false;
  bool _checking = true;

  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permissions whenever the user returns from system settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);

    final notifStatus = await Permission.notification.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    final overlayStatus = await Permission.systemAlertWindow.status;

    // There's no direct check for full-screen intent, so we rely on the
    // request method's return value cached in shared state. Best-effort:
    // re-request silently — if already granted, returns true without UI.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final fsi = await android?.canScheduleExactNotifications() ?? false;
    // canScheduleExactNotifications is the closest proxy available on the
    // plugin; for FSI we'll mark as granted if user has tapped the button
    // and the system returned true. Track via SharedPreferences if needed.

    setState(() {
      _notifGranted = notifStatus.isGranted;
      _batteryIgnored = batteryStatus.isGranted;
      _overlayGranted = overlayStatus.isGranted;
      _fsiGranted = fsi || _fsiGranted; // sticky once granted in-session
      _checking = false;
    });

    if (_allGranted) {
      _proceed();
    }
  }

  bool get _allGranted =>
      _notifGranted && _fsiGranted && _batteryIgnored && _overlayGranted;

  void _proceed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed(widget.nextRoute);
    });
  }

  Future<void> _requestNotifications() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    await _check();
  }

  Future<void> _requestFullScreenIntent() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestFullScreenIntentPermission() ?? false;
    setState(() => _fsiGranted = granted);
    if (!granted) {
      // System didn't auto-grant — open the settings page.
      await openAppSettings();
    }
    await _check();
  }

  Future<void> _requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (!status.isGranted) {
      await openAppSettings();
    }
    await _check();
  }

  Future<void> _requestOverlay() async {
    final status = await Permission.systemAlertWindow.request();
    if (!status.isGranted) {
      await openAppSettings();
    }
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allGranted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_allGranted) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: _checking
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.notifications_active_rounded,
                          size: 64, color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Enable Order Alerts',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'DHAV needs these permissions to ring you instantly when a new order comes in. Without them, you will MISS orders.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textGrey,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _PermissionCard(
                        icon: Icons.notifications_rounded,
                        title: 'Notifications',
                        subtitle:
                            'Show order alerts in your notification tray.',
                        granted: _notifGranted,
                        onTap: _requestNotifications,
                      ),
                      const SizedBox(height: 12),
                      _PermissionCard(
                        icon: Icons.phonelink_ring_rounded,
                        title: 'Full-Screen Alerts',
                        subtitle:
                            'Pop up the order screen instantly — even when the phone is locked (like Uber).',
                        granted: _fsiGranted,
                        onTap: _requestFullScreenIntent,
                      ),
                      const SizedBox(height: 12),
                      _PermissionCard(
                        icon: Icons.battery_charging_full_rounded,
                        title: 'Ignore Battery Saver',
                        subtitle:
                            'Allows the app to receive orders even when your phone is in power-saving mode.',
                        granted: _batteryIgnored,
                        onTap: _requestBatteryOptimization,
                      ),
                      const SizedBox(height: 12),
                      _PermissionCard(
                        icon: Icons.layers_rounded,
                        title: 'Display Over Other Apps',
                        subtitle:
                            'Allows the order popup to appear over any app you are using — even while the screen is on.',
                        granted: _overlayGranted,
                        onTap: _requestOverlay,
                      ),
                      const SizedBox(height: 28),
                      if (_allGranted)
                        ElevatedButton(
                          onPressed: _proceed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'CONTINUE',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tap each card above and grant permission to continue.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: granted ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: granted
                ? AppColors.green.withValues(alpha: 0.08)
                : AppColors.surfaceGrey,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: granted
                  ? AppColors.green.withValues(alpha: 0.4)
                  : AppColors.border,
              width: granted ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (granted ? AppColors.green : AppColors.primary)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: granted ? AppColors.green : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textGrey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (granted)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.green, size: 24)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ENABLE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
