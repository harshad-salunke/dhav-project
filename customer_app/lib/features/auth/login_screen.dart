import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedLanguage = 'English';

  Future<void> _signInGoogle() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error!), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0E8), // Warm peach
      body: SafeArea(
        child: Column(
          children: [
            // Top — grocery bag illustration area
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD9B0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.shopping_basket_rounded,
                          size: 100, color: AppColors.primary.withOpacity(0.3)),
                      const Icon(Icons.kitchen_outlined, size: 60, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom white sheet
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                          children: const [
                            TextSpan(text: 'Welcome to '),
                            TextSpan(
                                text: 'DHAV',
                                style: TextStyle(color: AppColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to order from stores near you',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 28),

                      // Google Sign-In
                      _SocialButton(
                        onTap: auth.loading ? null : _signInGoogle,
                        icon: Icons.g_mobiledata_rounded,
                        label: auth.loading
                            ? 'Signing in…'
                            : 'Continue with Google',
                        outlined: true,
                      ),
                      const SizedBox(height: 12),

                      // Email Sign-In
                      _SocialButton(
                        onTap: auth.loading
                            ? null
                            : () => Navigator.pushNamed(context, '/email-signin'),
                        icon: Icons.email_outlined,
                        label: 'Continue with Email',
                        orange: true,
                      ),

                      const SizedBox(height: 20),
                      const _OrDivider(),
                      const SizedBox(height: 20),

                      // Phone number row
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 16),
                              decoration: const BoxDecoration(
                                border: Border(
                                    right: BorderSide(color: AppColors.border)),
                              ),
                              child: Text('+91',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.textPrimary)),
                            ),
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  hintText: 'Enter mobile number',
                                  hintStyle: GoogleFonts.inter(
                                      color: AppColors.textHint, fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Get Started button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: auth.loading
                              ? null
                              : () =>
                                  Navigator.pushNamed(context, '/email-signin'),
                          child: const Text('Get Started'),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Language selector
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LangButton('English', _selectedLanguage, (l) => setState(() => _selectedLanguage = l)),
                            _divider(),
                            _LangButton('हिंदी', _selectedLanguage, (l) => setState(() => _selectedLanguage = l)),
                            _divider(),
                            _LangButton('मराठी', _selectedLanguage, (l) => setState(() => _selectedLanguage = l)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textSecondary),
                            children: [
                              const TextSpan(
                                  text: 'By continuing, you agree to our '),
                              TextSpan(
                                  text: 'Terms of Service',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                              const TextSpan(text: ' & '),
                              TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_outlined,
                                size: 14, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(
                              'SECURE HYPERLOCAL CHECKOUT',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w500),
                            ),
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
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: AppColors.border,
      );
}

class _LangButton extends StatelessWidget {
  final String label;
  final String selected;
  final void Function(String) onTap;

  const _LangButton(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = label == selected;
    return GestureDetector(
      onTap: () => onTap(label),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: active ? AppColors.primary : AppColors.textSecondary,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final bool outlined;
  final bool orange;

  const _SocialButton({
    required this.onTap,
    required this.icon,
    required this.label,
    this.outlined = false,
    this.orange = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: orange ? Colors.white : Colors.white,
          border: Border.all(
            color: orange ? AppColors.primary : AppColors.border,
            width: outlined || orange ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: orange ? AppColors.primary : AppColors.textPrimary, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: orange ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
