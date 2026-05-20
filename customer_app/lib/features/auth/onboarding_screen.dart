import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/first_launch_service.dart';
import '../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Data model for each onboarding page
// ---------------------------------------------------------------------------
class _OnboardingData {
  final String imagePath;   // asset path — drop PNG in assets/images/
  final String tag;         // small label above title
  final String title;
  final String subtitle;
  final Color bgColor;      // image section background (fallback when image loads)

  const _OnboardingData({
    required this.imagePath,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.bgColor,
  });
}

const _pages = [
  // 1 — Welcome
  _OnboardingData(
    imagePath: 'assets/images/onboarding_welcome.png',
    tag: 'Welcome to DHAV',
    title: 'Your Kirana Store,\nNow at Your Door',
    subtitle:
        'Order groceries from trusted local kirana stores in your neighbourhood. Fresh stock, familiar faces.',
    bgColor: Color(0xFFFFF3E8),
  ),
  // 2 — Live Tracking (Onboarding 3 in Figma)
  _OnboardingData(
    imagePath: 'assets/images/onboarding_tracking.png',
    tag: 'Real-time Updates',
    title: 'Track Your Order\nin Real Time',
    subtitle:
        'Watch your delivery boy ride to your door live on the map — just like Uber, but for kirana.',
    bgColor: Color(0xFFE8F4FD),
  ),
  // 3 — How It Works (Onboarding 2 in Figma)
  _OnboardingData(
    imagePath: 'assets/images/onboarding_how_it_works.png',
    tag: 'Simple Process',
    title: 'Order in\n3 Easy Steps',
    subtitle:
        'Place your order → Nearby stores get alerted → First store to accept delivers using their own delivery boy.',
    bgColor: Color(0xFFEDF7EE),
  ),
  // 4 — Payment
  _OnboardingData(
    imagePath: 'assets/images/onboarding_payment.png',
    tag: 'Hassle-free Payment',
    title: 'Cash on\nDelivery, Always',
    subtitle:
        'Pay the delivery boy directly. No digital wallet, no prepayment hassle. Simple and trusted.',
    bgColor: Color(0xFFFFF8E1),
  ),
];

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _goToLogin() async {
    await FirstLaunchService.markOnboardingCompleted();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _next() {
    if (_isLastPage) {
      _goToLogin();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final imageAreaHeight = size.height * 0.54;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Full-page PageView
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              return _OnboardingPage(
                data: _pages[index],
                imageAreaHeight: imageAreaHeight,
              );
            },
          ),

          // Bottom controls panel — sits on top of PageView
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              currentPage: _currentPage,
              totalPages: _pages.length,
              isLastPage: _isLastPage,
              onNext: _next,
              onSkip: _goToLogin,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single onboarding page
// ---------------------------------------------------------------------------
class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final double imageAreaHeight;

  const _OnboardingPage({
    required this.data,
    required this.imageAreaHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Image / illustration area
        Container(
          height: imageAreaHeight,
          width: double.infinity,
          color: data.bgColor,
          child: Stack(
            children: [
              // Background decorative circles
              Positioned(
                top: -30,
                right: -30,
                child: _decorCircle(160, data.bgColor.withValues(alpha: 0.6)),
              ),
              Positioned(
                bottom: 20,
                left: -20,
                child: _decorCircle(100, data.bgColor.withValues(alpha: 0.5)),
              ),
              // Main illustration
              Center(
                child: Image.asset(
                  data.imagePath,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: imageAreaHeight * 0.82,
                  errorBuilder: (_, __, ___) => _Placeholder(bgColor: data.bgColor),
                ),
              ),
            ],
          ),
        ),

        // Text content area (fills remaining space)
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.tag,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  data.title,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  data.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _decorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom panel (dots + buttons) — floats over the PageView
// ---------------------------------------------------------------------------
class _BottomPanel extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLastPage;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _BottomPanel({
    required this.currentPage,
    required this.totalPages,
    required this.isLastPage,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalPages,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == currentPage ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == currentPage
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Next / Get Started button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isLastPage ? 'Get Started' : 'Next',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          // Skip / Login link
          if (!isLastPage) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onSkip,
              child: Text(
                'Skip',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onSkip,
              child: RichText(
                text: TextSpan(
                  text: 'Already have an account? ',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  children: [
                    TextSpan(
                      text: 'Login',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder shown when image asset is missing
// ---------------------------------------------------------------------------
class _Placeholder extends StatelessWidget {
  final Color bgColor;
  const _Placeholder({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Add image to\nassets/images/',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
