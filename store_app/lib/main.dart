import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/orders/incoming_order_screen.dart';
import 'features/orders/active_order_screen.dart';
import 'features/orders/order_list_screen.dart';
import 'features/orders/missed_order_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/earnings/earnings_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/help/help_support_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/store/store_profile_screen.dart';
import 'features/team/store_team_screen.dart';
import 'features/delivery/delivery_home_screen.dart';
import 'features/delivery/delivery_assignment_screen.dart';
import 'features/delivery/delivery_history_screen.dart';
import 'features/delivery/delivery_completion_screen.dart';
import 'features/delivery/delivery_incoming_assignment_screen.dart';
import 'features/delivery/delivery_assignment_screen.dart';
import 'features/delivery/delivery_history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const DhavStoreApp(),
    ),
  );
}

class DhavStoreApp extends StatelessWidget {
  const DhavStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: themeProvider.isDark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp(
      title: 'DHAV Store Partner',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.splash:
            return _pageRoute(const SplashScreen());
          case AppRoutes.login:
            return _pageRoute(const LoginScreen());
          case AppRoutes.dashboard:
            return _pageRoute(const DashboardScreen());
          case AppRoutes.incomingOrder:
            return PageRouteBuilder(
              pageBuilder: (_, _, _) => const IncomingOrderScreen(),
              transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
            );
          case AppRoutes.activeOrder:
            return _pageRoute(const ActiveOrderScreen());
          case AppRoutes.orderList:
            return _pageRoute(const OrderListScreen());
          case AppRoutes.orderDetail:
            return _pageRoute(const OrderDetailScreen());
          case AppRoutes.inventory:
            return _pageRoute(const InventoryScreen());
          case AppRoutes.earnings:
            return _pageRoute(const EarningsScreen());
          case AppRoutes.profile:
            return _pageRoute(const ProfileScreen());
          case AppRoutes.storeProfile:
            return _pageRoute(const StoreProfileScreen());
          case AppRoutes.storeTeam:
            return _pageRoute(const StoreTeamScreen());
          case AppRoutes.notifications:
            return _pageRoute(const NotificationsScreen());
          case AppRoutes.helpSupport:
            return _pageRoute(const HelpSupportScreen());
          case AppRoutes.settings:
            return _pageRoute(const SettingsScreen());
          case AppRoutes.deliveryHome:
            return _pageRoute(const DeliveryHomeScreen());
          case AppRoutes.deliveryAssignment:
            return _pageRoute(const DeliveryAssignmentScreen());
          case AppRoutes.deliveryHistory:
            return _pageRoute(const DeliveryHistoryScreen());
          case AppRoutes.deliveryCompletion:
            return _pageRoute(const DeliveryCompletionScreen());
          case AppRoutes.deliveryIncomingAssignment:
            return _pageRoute(const DeliveryIncomingAssignmentScreen());
          case AppRoutes.missedOrderWarning:
            return _pageRoute(const MissedOrderScreen());
          default:
            return _pageRoute(const SplashScreen());
        }
      },
    );
  }

  PageRoute _pageRoute(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }
}
