import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_routes.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/delivery_provider.dart';
import 'core/providers/earnings_provider.dart';
import 'core/providers/inventory_provider.dart';
import 'core/providers/order_provider.dart';
import 'core/providers/store_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/permission_gate_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/store_registration_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/delivery/delivery_assignment_screen.dart';
import 'features/delivery/delivery_completion_screen.dart'
    show DeliveryCompletionScreen, DeliveryCompletionArgs;
import 'features/delivery/delivery_history_screen.dart';
import 'features/delivery/delivery_home_screen.dart';
import 'features/delivery/delivery_incoming_assignment_screen.dart';
import 'features/earnings/earnings_screen.dart';
import 'features/help/help_support_screen.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/orders/active_order_screen.dart';
import 'features/orders/incoming_order_screen.dart';
import 'features/orders/missed_order_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/orders/order_list_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/store/store_profile_screen.dart';
import 'features/team/store_team_screen.dart';
import 'firebase_options.dart';

/// Global navigator key — used by FCM service to push the incoming-order
/// overlay from anywhere (including cold-start from notification).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FcmService fcmService = FcmService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await fcmService.init();

  void navigateToIncomingOrder(String orderId) {
    navigatorKey.currentState?.pushNamed(
      AppRoutes.incomingOrder,
      arguments: orderId,
    );
  }

  // Store owner: new order FCM → push incoming order popup.
  fcmService.onIncomingOrder = (data) {
    final orderId = data['order_id'];
    if (orderId == null) return;
    navigateToIncomingOrder(orderId);
  };

  // Store owner: tapped local notification from tray → push incoming order popup.
  fcmService.onNotificationTap = (orderId) {
    navigateToIncomingOrder(orderId);
  };

  // Delivery boy: assignment alert → push delivery incoming assignment popup.
  fcmService.onDeliveryAssigned = (data) {
    final orderId = data['order_id'];
    if (orderId == null) return;
    navigatorKey.currentState?.pushNamed(
      AppRoutes.deliveryIncomingAssignment,
      arguments: orderId,
    );
  };

  // Native side (DhavMessagingService.kt) force-launches MainActivity when
  // an order arrives while the screen is on. It caches the order_id and
  // signals us here so we can pull-and-navigate as soon as Dart's navigator
  // is ready. We also pull on lifecycle resume below for the
  // backgrounded-but-still-running case.
  Future<void> consumeAndNavigateNative() async {
    final pending = await fcmService.consumePendingNativeOrder();
    if (pending == null) return;
    final orderId = pending['order_id'];
    if (orderId == null) return;
    final type = pending['type'];
    if (type == 'delivery_assigned') {
      navigatorKey.currentState?.pushNamed(
        AppRoutes.deliveryIncomingAssignment,
        arguments: orderId,
      );
    } else {
      navigateToIncomingOrder(orderId);
    }
  }

  fcmService.onNativePendingOrderAvailable(consumeAndNavigateNative);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => EarningsProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
      ],
      child: const DhavStoreApp(),
    ),
  );
}

class DhavStoreApp extends StatefulWidget {
  const DhavStoreApp({super.key});

  @override
  State<DhavStoreApp> createState() => _DhavStoreAppState();
}

class _DhavStoreAppState extends State<DhavStoreApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App was brought to the foreground — most likely by the native
      // force-launch from DhavMessagingService. Pull any pending order
      // and navigate to the popup.
      _drainPendingNativeOrder();
    }
  }

  Future<void> _drainPendingNativeOrder() async {
    final pending = await fcmService.consumePendingNativeOrder();
    if (pending == null) return;
    final orderId = pending['order_id'];
    if (orderId == null) return;
    final type = pending['type'];
    if (type == 'delivery_assigned') {
      navigatorKey.currentState?.pushNamed(
        AppRoutes.deliveryIncomingAssignment,
        arguments: orderId,
      );
    } else {
      navigatorKey.currentState?.pushNamed(
        AppRoutes.incomingOrder,
        arguments: orderId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeProvider.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
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
          case AppRoutes.permissionGate:
            final nextRoute =
                (settings.arguments as String?) ?? AppRoutes.dashboard;
            return _pageRoute(PermissionGateScreen(nextRoute: nextRoute));
          case AppRoutes.login:
            return _pageRoute(const LoginScreen());
          case AppRoutes.registerStore:
            return _pageRoute(const StoreRegistrationScreen());
          case AppRoutes.dashboard:
            return _pageRoute(const DashboardScreen());
          case AppRoutes.incomingOrder:
            final orderId = settings.arguments as String?;
            return PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  IncomingOrderScreen(orderId: orderId),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            );
          case AppRoutes.activeOrder:
            final orderId = settings.arguments as String?;
            return _pageRoute(ActiveOrderScreen(orderId: orderId));
          case AppRoutes.orderList:
            return _pageRoute(const OrderListScreen());
          case AppRoutes.orderDetail:
            final orderId = settings.arguments as String?;
            return _pageRoute(OrderDetailScreen(orderId: orderId));
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
            final orderId = settings.arguments as String?;
            return _pageRoute(DeliveryAssignmentScreen(orderId: orderId));
          case AppRoutes.deliveryHistory:
            return _pageRoute(const DeliveryHistoryScreen());
          case AppRoutes.deliveryCompletion:
            final args = settings.arguments as DeliveryCompletionArgs?;
            return _pageRoute(DeliveryCompletionScreen(args: args));
          case AppRoutes.deliveryIncomingAssignment:
            final orderId = settings.arguments as String?;
            return PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  DeliveryIncomingAssignmentScreen(orderId: orderId),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            );
          case AppRoutes.deliveryMissedOrder:
            return _pageRoute(const MissedOrderScreen());
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
