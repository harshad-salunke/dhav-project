import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class _OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bgColor;
  final Color iconBgColor;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
    required this.iconBgColor,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardingPage(
      title: 'Your Kirana Store,\nNow at Your Door',
      subtitle:
          'Order groceries from trusted local kirana stores in your neighbourhood. Fresh stock, familiar faces.',
      icon: Icons.storefront_rounded,
      bgColor: Color(0xFFFFF5EC),
      iconBgColor: Color(0xFFFFE0C2),
    ),
    _OnboardingPage(
      title: 'How It Works',
      subtitle:
          'Place your order → Nearby stores get alerted → First store to accept delivers using their own delivery boy.',
      icon: Icons.bolt_rounded,
      bgColor: Color(0xFFF0FDF4),
      iconBgColor: Color(0xFFBBF7D0),
    ),
    _OnboardingPage(
      title: 'Track Live Delivery',
      subtitle:
          'Watch your delivery boy ride to your door in real time on the map — just like Uber, but for kirana.',
      icon: Icons.location_on_rounded,
      bgColor: Color(0xFFEFF6FF),
      iconBgColor: Color(0xFFBFDBFE),
    ),
    _OnboardingPage(
      title: 'Cash on Delivery,\nAlways',
      subtitle:
          'Pay the delivery boy directly. No digital wallet, no prepayment hassle. Simple and trusted.',
      icon: Icons.payments_rounded,
      bgColor: Color(0xFFFFFBEB),
      iconBgColor: Color(0xFFFDE68A),
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    return Scaffold(
      backgroundColor: page.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 24, 0),
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: Text(
                    'Skip',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final p = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Illustration circle
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: p.iconBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(p.icon,
                              size: 90, color: AppColors.primary),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          p.title,
                          style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.25),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p.subtitle,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(
                        _page == _pages.length - 1 ? 'Get Started' : 'Next'),
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
