import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static void _callSupport() => _launch('tel:+919876543210');
  static void _whatsAppSupport() =>
      _launch('https://wa.me/919876543210?text=Hi%20DHAV%20Support%2C%20I%20need%20help');
  static void _emailSupport() =>
      _launch('mailto:support@dhav.in?subject=Store%20Partner%20Support');

  static const List<Map<String, dynamic>> _faqs = [
    {
      'q': 'How do I accept an incoming order?',
      'a': 'When a new order arrives, you will see an incoming order popup with a 45-second timer. Tap "Quick Accept" to accept, or "View Details" to see the full order before accepting.',
    },
    {
      'q': 'Why was my store auto-closed?',
      'a': 'Stores are auto-closed at your configured closing time. You can override this by toggling your store status to Open in the Dashboard. Check your store hours in Profile > Store Details.',
    },
    {
      'q': 'How do I add or mark items unavailable?',
      'a': 'Go to the Inventory tab. Use the toggle switch on any item to mark it available or unavailable. Tap the + icon in the top right to add a new custom item.',
    },
    {
      'q': 'When do I receive my weekly settlement?',
      'a': 'Settlements are processed every Monday for the previous week (Mon–Sun). Funds are credited to your registered bank account within 2 business days after you clear the platform fee via UPI.',
    },
    {
      'q': 'What happens if I get 3 strikes?',
      'a': 'Three missed orders in a week will temporarily suspend your store from receiving new orders for 24 hours. Contact support to have strikes reviewed if they were due to technical issues.',
    },
    {
      'q': 'How do I assign a delivery partner?',
      'a': 'On the Active Order screen, tap "Assign Delivery Boy" and select an available partner from your team. Partners marked "On Delivery" are currently busy and cannot be assigned.',
    },
    {
      'q': 'How do I add a delivery partner to my team?',
      'a': 'Go to Profile > Delivery Team and tap "+ ADD". Fill in the partner\'s name, phone number and vehicle type. They will receive an invite on the DHAV Delivery app.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
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
                  label: 'Call Support',
                  sub: '9AM – 9PM',
                  color: AppColors.green,
                  onTap: _callSupport,
                  c: c,
                ),
                const SizedBox(width: 12),
                _ContactCard(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  sub: 'Quick reply',
                  color: const Color(0xFF25D366),
                  onTap: _whatsAppSupport,
                  c: c,
                ),
                const SizedBox(width: 12),
                _ContactCard(
                  icon: Icons.email_rounded,
                  label: 'Email Us',
                  sub: 'support@dhav.in',
                  color: AppColors.primary,
                  onTap: _emailSupport,
                  c: c,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: _faqs.asMap().entries.map((e) {
                  final isLast = e.key == _faqs.length - 1;
                  return _FaqTile(
                    faq: e.value,
                    isLast: isLast,
                    c: c,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            // Report issue
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REPORT AN ISSUE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Text(
                    'Facing a technical issue or a problem with an order? Let us know and we\'ll resolve it within 2 hours.',
                    style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _emailSupport,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Report Issue',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
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
  final DhavColors c;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
    required this.c,
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
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textPrimary), textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text(sub, style: GoogleFonts.inter(fontSize: 10, color: c.textHint), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final Map<String, dynamic> faq;
  final bool isLast;
  final DhavColors c;

  const _FaqTile({required this.faq, required this.isLast, required this.c});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.faq['q'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
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
              widget.faq['a'] as String,
              style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary, height: 1.6),
            ),
          ),
        if (!widget.isLast)
          Divider(height: 1, color: c.divider, indent: 18, endIndent: 18),
      ],
    );
  }
}
