import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

/// Add Product Screen — Store owner requests a new catalog item.
/// The request goes to admin for review. If approved, the item appears
/// in the master catalog and the store can enable it in their inventory.
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nameHindiCtrl = TextEditingController();
  final _nameMarathiCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _category = 'Grains';
  String _unit = 'kg';
  bool _submitting = false;
  bool _submitted = false;

  static const List<String> _categories = [
    'Grains',
    'Oil & Ghee',
    'Dairy',
    'Snacks',
    'Personal Care',
    'Cleaning',
    'Baby Care',
    'Beverages',
    'Spices',
    'Other',
  ];

  static const List<String> _units = [
    'kg',
    'g',
    'litre',
    'ml',
    'piece',
    'pack',
    'dozen',
    'bottle',
    'box',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameHindiCtrl.dispose();
    _nameMarathiCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      await ApiClient().post('/stores/me/custom-items', body: {
        'name': _nameCtrl.text.trim(),
        'name_hindi': _nameHindiCtrl.text.trim(),
        'name_marathi': _nameMarathiCtrl.text.trim(),
        'category': _category,
        'unit': _unit,
        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
        'notes': _notesCtrl.text.trim(),
      });
      setState(() => _submitted = true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: AppColors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request New Product',
          style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.textPrimary),
        ),
      ),
      body: _submitted ? _buildSuccessState(c) : _buildForm(c),
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────

  Widget _buildSuccessState(DhavColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 52),
            ),
            const SizedBox(height: 24),
            Text('Request Submitted!',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary)),
            const SizedBox(height: 12),
            Text(
              'Your product request has been sent to the DHAV team for review. '
              'Once approved, the item will appear in your inventory within 24 hours.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: c.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Back to Inventory',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _submitted = false;
                _nameCtrl.clear();
                _nameHindiCtrl.clear();
                _nameMarathiCtrl.clear();
                _priceCtrl.clear();
                _notesCtrl.clear();
                _category = 'Grains';
                _unit = 'kg';
              }),
              child: Text('Submit Another Request',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form ───────────────────────────────────────────────────────────────────

  Widget _buildForm(DhavColors c) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Can\'t find a product in your inventory? Request it here. '
                      'DHAV team reviews requests within 24 hours.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Product name (English) — required
            _sectionLabel('PRODUCT DETAILS', c),
            _buildCard(c, [
              _buildField(
                controller: _nameCtrl,
                label: 'Product Name (English)*',
                hint: 'e.g. Basmati Rice 5kg',
                c: c,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                textInputAction: TextInputAction.next,
              ),
              _Divider(c),
              _buildField(
                controller: _nameHindiCtrl,
                label: 'Name in Hindi',
                hint: 'e.g. बासमती चावल',
                c: c,
                textInputAction: TextInputAction.next,
              ),
              _Divider(c),
              _buildField(
                controller: _nameMarathiCtrl,
                label: 'Name in Marathi',
                hint: 'e.g. बासमती तांदूळ',
                c: c,
                textInputAction: TextInputAction.next,
              ),
            ]),
            const SizedBox(height: 16),

            // Category & Unit
            _sectionLabel('CATEGORY & UNIT', c),
            _buildCard(c, [
              _buildDropdown(
                label: 'Category',
                value: _category,
                items: _categories,
                c: c,
                onChanged: (v) => setState(() => _category = v!),
              ),
              _Divider(c),
              _buildDropdown(
                label: 'Unit',
                value: _unit,
                items: _units,
                c: c,
                onChanged: (v) => setState(() => _unit = v!),
              ),
            ]),
            const SizedBox(height: 16),

            // Price
            _sectionLabel('PRICING', c),
            _buildCard(c, [
              _buildField(
                controller: _priceCtrl,
                label: 'Typical Selling Price (₹)',
                hint: 'e.g. 450',
                c: c,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  final n = double.tryParse(v.trim());
                  if (n == null || n < 0) return 'Enter a valid price';
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 16),

            // Notes
            _sectionLabel('ADDITIONAL NOTES', c),
            _buildCard(c, [
              _buildField(
                controller: _notesCtrl,
                label: 'Notes for the DHAV team',
                hint: 'Brand name, variant, why customers need it…',
                c: c,
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
            ]),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Submit Request',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, DhavColors c) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.textHint,
              letterSpacing: 1.5)),
    );
  }

  Widget _buildCard(DhavColors c, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required DhavColors c,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction textInputAction = TextInputAction.next,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            maxLines: maxLines,
            validator: validator,
            style: GoogleFonts.inter(fontSize: 14, color: c.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  GoogleFonts.inter(fontSize: 13, color: c.textHint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              errorStyle: GoogleFonts.inter(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required DhavColors c,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary)),
          const Spacer(),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            dropdownColor: c.card,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary),
            icon: Icon(Icons.expand_more_rounded,
                color: c.textHint, size: 20),
            items: items
                .map((it) => DropdownMenuItem(
                      value: it,
                      child: Text(it,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: c.textPrimary)),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final DhavColors c;
  const _Divider(this.c);

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: c.divider, indent: 16, endIndent: 0);
}
