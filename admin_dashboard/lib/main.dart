import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_routes.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/catalog_provider.dart';
import 'core/providers/dashboard_provider.dart';
import 'core/providers/stores_provider.dart';
import 'core/providers/orders_provider.dart';
import 'core/providers/settlements_provider.dart';

import 'features/auth/login_screen.dart';
import 'features/catalog/catalog_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/stores/store_detail_screen.dart';
import 'features/stores/store_onboard_screen.dart';
import 'features/stores/stores_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/settlements/settlements_screen.dart';

// ─── Firebase Web config ───────────────────────────────────────────────────────
// Replace these values with your actual Firebase project's web config.
// In Firebase Console → Project Settings → Your apps → Web app → Config snippet.
const _firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDN0Drq3YtXe4hbrYFd1RhFlKl3xUkXFFY',
  appId: '1:928693290794:web:49d840cc50b5e6801d8053',
  messagingSenderId: '928693290794',
  projectId: 'dhav-quick-commerce',
  authDomain: 'dhav-quick-commerce.firebaseapp.com',
  databaseURL: 'https://dhav-quick-commerce-default-rtdb.firebaseio.com',
  storageBucket: 'dhav-quick-commerce.firebasestorage.app',
  measurementId: 'G-LBTNR16C6F',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _firebaseOptions);
  runApp(const DhavAdminApp());
}

class DhavAdminApp extends StatelessWidget {
  const DhavAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => StoresProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => SettlementsProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
      ],
      child: MaterialApp(
        title: 'DHAV Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: AppRoutes.login,
        onGenerateRoute: (settings) {
          // Handle routes that need arguments
          switch (settings.name) {
            case AppRoutes.storeDetail:
              final storeId = settings.arguments as String? ?? '';
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => _ProtectedRoute(
                  child: StoreDetailScreen(storeId: storeId),
                ),
              );
            default:
              return null;
          }
        },
        routes: {
          AppRoutes.login: (_) => const _AuthGuard(child: LoginScreen()),
          AppRoutes.dashboard: (_) =>
              const _ProtectedRoute(child: DashboardScreen()),
          AppRoutes.stores: (_) =>
              const _ProtectedRoute(child: StoresScreen()),
          AppRoutes.storeOnboard: (_) =>
              const _ProtectedRoute(child: StoreOnboardScreen()),
          AppRoutes.orders: (_) =>
              const _ProtectedRoute(child: OrdersScreen()),
          AppRoutes.customers: (_) =>
              const _ProtectedRoute(child: CustomersScreen()),
          AppRoutes.settlements: (_) =>
              const _ProtectedRoute(child: SettlementsScreen()),
          AppRoutes.catalog: (_) =>
              const _ProtectedRoute(child: CatalogScreen()),
        },
      ),
    );
  }
}

/// Redirects authenticated admins away from login screen.
class _AuthGuard extends StatelessWidget {
  final Widget child;
  const _AuthGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.authenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
          });
        }
        return child;
      },
    );
  }
}

/// Redirects unauthenticated users to login.
class _ProtectedRoute extends StatelessWidget {
  final Widget child;
  const _ProtectedRoute({required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.unknown) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F1117),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)),
            ),
          );
        }
        if (auth.status == AuthStatus.unauthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          });
          return const SizedBox.shrink();
        }
        return child;
      },
    );
  }
}
