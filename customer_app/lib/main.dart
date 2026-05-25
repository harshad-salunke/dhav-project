import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_routes.dart';
import 'core/providers/address_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/catalog_provider.dart';
import 'core/providers/order_provider.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';

import 'features/auth/splash_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/email_signin_screen.dart';
import 'features/auth/profile_setup_screen.dart';
import 'core/widgets/main_shell.dart';
import 'features/cart/cart_screen.dart';
import 'features/orders/broadcasting_screen.dart';
import 'features/orders/order_accepted_screen.dart';
import 'features/orders/order_tracking_screen.dart';
import 'features/orders/order_delivered_screen.dart';
import 'features/orders/order_history_screen.dart';
import 'features/address/saved_addresses_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/search/search_screen.dart';
import 'features/notifications/notifications_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late FcmService fcmService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase
  await Firebase.initializeApp();

  // FCM service
  fcmService = FcmService(navigatorKey: navigatorKey);
  await fcmService.init();

  runApp(const DhavCustomerApp());
}

class DhavCustomerApp extends StatelessWidget {
  const DhavCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        title: 'DHAV',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorKey: navigatorKey,
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashScreen(),
          AppRoutes.onboarding: (_) => const OnboardingScreen(),
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.emailSignIn: (_) => const EmailSignInScreen(),
          AppRoutes.profileSetup: (_) => const ProfileSetupScreen(),
          AppRoutes.home: (_) => const MainShell(),
          AppRoutes.search: (_) => const SearchScreen(),
          AppRoutes.cart: (_) => const CartScreen(),
          AppRoutes.broadcasting: (_) => const BroadcastingScreen(),
          AppRoutes.orderAccepted: (_) => const OrderAcceptedScreen(),
          AppRoutes.orderTracking: (_) => const OrderTrackingScreen(),
          AppRoutes.orderDelivered: (_) => const OrderDeliveredScreen(),
          AppRoutes.orderHistory: (_) => const OrderHistoryScreen(),
          AppRoutes.profile: (_) => const ProfileScreen(),
          AppRoutes.notifications: (_) => const NotificationsScreen(),
          '/saved-addresses': (_) => const SavedAddressesScreen(),
        },
      ),
    );
  }
}
