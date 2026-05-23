import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart' show fcmService;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showEmail = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  Future<void> _onGoogleTap() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      _routeAfterLogin(auth);
    } else if (auth.error != null) {
      _toast(auth.error!);
    }
  }

  Future<void> _onEmailSubmit() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      _routeAfterLogin(auth);
    } else if (auth.error != null) {
      _toast(auth.error!);
    }
  }

  void _routeAfterLogin(AuthProvider auth) {
    final user = auth.user!;
    if (user.isStoreOwner) {
      fcmService.syncTokenToBackend();
      fcmService.listenForTokenRefresh();
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.permissionGate,
        arguments: AppRoutes.dashboard,
      );
    } else if (user.isDeliveryBoy) {
      fcmService.syncDeliveryTokenToBackend();
      fcmService.listenForDeliveryTokenRefresh();
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.permissionGate,
        arguments: AppRoutes.deliveryHome,
      );
    } else {
      // First-time user — route to self-onboarding flow.
      Navigator.pushReplacementNamed(context, AppRoutes.registerStore);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              color: AppColors.bgDark,
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _DiagonalLinesPainter())),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 4),
                            ],
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 20),
                        Text('KIRANA PARTNER',
                            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textWhite, letterSpacing: 4)),
                        const SizedBox(height: 6),
                        Text('LOGISTICS & HYPERLOCAL EXCELLENCE',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textGrey, letterSpacing: 2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 24),
                    Text('Welcome, Partner',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Text('Access your delivery terminal and earnings\ndashboard.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium, height: 1.5)),
                    const SizedBox(height: 32),
                    if (auth.busy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      )
                    else ...[
                      _LoginButton(
                        onTap: _onGoogleTap,
                        filled: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _GoogleIcon(),
                            const SizedBox(width: 12),
                            Text('Continue with Google',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LoginButton(
                        onTap: () => setState(() => _showEmail = !_showEmail),
                        filled: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.email_outlined, size: 20, color: AppColors.textDark),
                            const SizedBox(width: 12),
                            Text(_showEmail ? 'Hide Email Login' : 'Login with Email',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          ],
                        ),
                      ),
                      if (_showEmail) _buildEmailForm(),
                    ],
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(24)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.headset_mic_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('Call DHAV Support',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium),
                        children: [
                          const TextSpan(text: 'New store? '),
                          TextSpan(
                            text: 'Sign in',
                            style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                            recognizer: TapGestureRecognizer()..onTap = _onGoogleTap,
                          ),
                          const TextSpan(text: ' and we’ll walk you through onboarding.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onEmailSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Sign In'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final bool filled;

  const _LoginButton({required this.onTap, required this.child, required this.filled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: filled ? AppColors.surfaceGrey : Colors.transparent,
          border: filled ? null : Border.all(color: AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text('G', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

class _DiagonalLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    for (double i = -size.height; i < size.width + size.height; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
