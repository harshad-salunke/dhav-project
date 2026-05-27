import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'How do I place an order?',
      'a':
          'Browse items on the Home screen or use Search, add items to your cart, and tap "Place Order". We\'ll find the nearest available kirana store and deliver to your address.',
    },
    {
      'q': 'How long does delivery take?',
      'a':
          'Most deliveries arrive in 15-30 minutes depending on your distance from the store. You can track your delivery boy in real-time on the order tracking screen.',
    },
    {
      'q': 'What if no store accepts my order?',
      'a':
          'We broadcast your order to stores in 3 waves (1 km, 2 km, 3 km). If no store accepts within that radius, your order is cancelled and you are notified immediately.',
    },
    {
      'q': 'Can I cancel my order?',
      'a':
          'Orders can be cancelled before a store accepts them. Once accepted, please contact support immediately — we\'ll try our best to help.',
    },
    {
      'q': 'How do I change my delivery address?',
      'a':
          'Go to Profile > Saved Addresses to manage your saved addresses. You can also select a different address in the Cart before placing an order.',
    },
    {
      'q': 'What payment methods are accepted?',
      'a':
          'Currently we support Cash on Delivery (COD). UPI and card payments are coming soon.',
    },
    {
      'q': 'How do I rate my delivery experience?',
      'a':
          'After your order is delivered, you\'ll see a "Rate this delivery" prompt. You can also rate from Order History by tapping the Rate button on any delivered order.',
    },
    {
      'q': 'What if an item is missing from my order?',
      'a':
          'Please contact support via WhatsApp or call us. Share your order ID and we\'ll resolve it within 2 hours.',
    },
  ];

  static Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Help & Support',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact cards
            Row(
              children: [
                _ContactCard(
                  icon: Icons.phone_rounded,
                  label: 'Call Us',
                  sub: '9AM – 9PM',
                  color: AppColors.success,
                  onTap: () => _launch('tel:+919876543210'),
                ),
                const SizedBox(width: 12),
                _ContactCard(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  sub: 'Quick reply',
                  color: const Color(0xFF25D366),
                  onTap: () => _launch(
                      'https://wa.me/919876543210?text=Hi%20DHAV%20Support%2C%20I%20need%20help%20with%20my%20order'),
                ),
                const SizedBox(width: 12),
                _ContactCard(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  sub: 'support@dhav.in',
                  color: AppColors.primary,
                  onTap: () => _launch(
                      'mailto:support@dhav.in?subject=Customer%20Support%20Request'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                children: _faqs.asMap().entries.map((e) {
                  final isLast = e.key == _faqs.length - 1;
                  return _FaqTile(faq: e.value, isLast: isLast);
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Report issue
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REPORT AN ISSUE',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHint,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Text(
                    "Got a problem with your order or delivery? Tell us and we'll resolve it within 2 hours.",
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _launch(
                        'mailto:support@dhav.in?subject=Order%20Issue%20Report'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text('Report Issue',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text(sub,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textHint),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final Map<String, String> faq;
  final bool isLast;

  const _FaqTile({required this.faq, required this.isLast});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.faq['q']!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Text(
              widget.faq['a']!,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6),
            ),
          ),
        if (!widget.isLast)
          const Divider(
              height: 1,
              color: AppColors.divider,
              indent: 18,
              endIndent: 18),
      ],
    );
  }
}
