import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/models/saved_address.dart';
import '../../core/providers/address_provider.dart';
import '../../core/theme/app_colors.dart';

class AddAddressDetailScreen extends StatefulWidget {
  final double lat;
  final double lng;
  final String detectedArea;
  final SavedAddress? existingAddress;
  final int? editIndex;

  const AddAddressDetailScreen({
    super.key,
    required this.lat,
    required this.lng,
    required this.detectedArea,
    this.existingAddress,
    this.editIndex,
  });

  @override
  State<AddAddressDetailScreen> createState() =>
      _AddAddressDetailScreenState();
}

class _AddAddressDetailScreenState extends State<AddAddressDetailScreen> {
  final _flatCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  String _label = 'Home';
  bool _saving = false;

  static const _labels = ['Home', 'Work', 'Hotel', 'Other'];
  static const _labelIcons = <String, IconData>{
    'Home': Icons.home_outlined,
    'Work': Icons.work_outline_rounded,
    'Hotel': Icons.hotel_outlined,
    'Other': Icons.location_on_outlined,
  };

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAddress;
    if (existing != null) {
      _flatCtrl.text = existing.flatBuilding;
      _floorCtrl.text = existing.floor ?? '';
      _areaCtrl.text = existing.area;
      _landmarkCtrl.text = existing.landmark ?? '';
      _label = existing.label;
    } else {
      _areaCtrl.text = widget.detectedArea;
    }
  }

  @override
  void dispose() {
    _flatCtrl.dispose();
    _floorCtrl.dispose();
    _areaCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_flatCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter flat / house number')),
      );
      return;
    }
    if (_areaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter area name')),
      );
      return;
    }

    setState(() => _saving = true);

    final address = SavedAddress(
      label: _label,
      flatBuilding: _flatCtrl.text.trim(),
      floor: _floorCtrl.text.trim().isEmpty ? null : _floorCtrl.text.trim(),
      area: _areaCtrl.text.trim(),
      landmark:
          _landmarkCtrl.text.trim().isEmpty ? null : _landmarkCtrl.text.trim(),
      lat: widget.lat,
      lng: widget.lng,
    );

    final addrProvider = context.read<AddressProvider>();
    final bool success;
    if (widget.editIndex != null) {
      success = await addrProvider.editAddress(widget.editIndex!, address);
    } else {
      success = await addrProvider.addAddress(address);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to save address. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editIndex != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit address' : 'Enter complete address',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Save address as
                    Text(
                      'Save address as *',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _labels.map((l) {
                        final selected = _label == l;
                        final isLast = l == _labels.last;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _label = l),
                            child: Container(
                              margin: EdgeInsets.only(right: isLast ? 0 : 8),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primaryLight
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _labelIcons[l]!,
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    l,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    _InputField(
                      controller: _flatCtrl,
                      label: 'Flat / House no / Building name *',
                      hint: 'e.g. 101, Sunshine Apartments',
                    ),
                    const SizedBox(height: 16),

                    _InputField(
                      controller: _floorCtrl,
                      label: 'Floor (optional)',
                      hint: 'e.g. Ground floor, 2nd floor',
                    ),
                    const SizedBox(height: 16),

                    _InputField(
                      controller: _areaCtrl,
                      label: 'Area / Sector / Locality *',
                      hint: 'e.g. Hinjawadi Phase 1',
                    ),
                    const SizedBox(height: 16),

                    _InputField(
                      controller: _landmarkCtrl,
                      label: 'Nearby landmark (optional)',
                      hint: 'e.g. Near City Hospital',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter your details for seamless delivery experience',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // Save button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom + 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isEdit ? 'Update address' : 'Save address',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textHint),
          ),
        ),
      ],
    );
  }
}
