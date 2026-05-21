import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/models/saved_address.dart';
import '../../core/providers/address_provider.dart';
import '../../core/theme/app_colors.dart';
import 'add_address_map_screen.dart';

class AddressSelectionSheet extends StatefulWidget {
  final VoidCallback? onAddressSelected;

  const AddressSelectionSheet({super.key, this.onAddressSelected});

  static Future<void> show(BuildContext context,
      {VoidCallback? onAddressSelected}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => AddressSelectionSheet(onAddressSelected: onAddressSelected),
    );
  }

  @override
  State<AddressSelectionSheet> createState() => _AddressSelectionSheetState();
}

class _AddressSelectionSheetState extends State<AddressSelectionSheet> {
  String _currentLocationText = 'Detecting location...';
  double? _currentLat;
  double? _currentLng;
  bool _detectingLocation = true;

  @override
  void initState() {
    super.initState();
    _detectCurrentLocation();
  }

  Future<void> _detectCurrentLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _currentLocationText = 'Location access denied';
            _detectingLocation = false;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      final area = await _reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _currentLocationText = area;
          _detectingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentLocationText = 'Unable to detect location';
          _detectingLocation = false;
        });
      }
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=$lat&lon=$lng&zoom=15&addressdetails=1');
      final resp = await http.get(uri, headers: {
        'User-Agent': 'DHAVApp/1.0 (harshadsalunke2002@gmail.com)',
      }).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final area = addr['suburb'] ??
            addr['neighbourhood'] ??
            addr['village'] ??
            addr['town'] ??
            addr['city'] ??
            'Pune';
        final city =
            addr['city'] ?? addr['town'] ?? addr['state_district'] ?? '';
        return city.isNotEmpty && city != area
            ? '$area, $city'
            : area.toString();
      }
    } catch (_) {}
    return 'Pune';
  }

  void _selectCurrentLocation() {
    if (_currentLat == null || _currentLng == null) return;
    final addr = SavedAddress(
      label: 'Current Location',
      flatBuilding: '',
      area: _currentLocationText,
      lat: _currentLat!,
      lng: _currentLng!,
    );
    context.read<AddressProvider>().selectAddress(addr);
    Navigator.pop(context);
    widget.onAddressSelected?.call();
  }

  void _openAddAddressMap() async {
    Navigator.pop(context);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressMapScreen(
          initialLat: _currentLat,
          initialLng: _currentLng,
        ),
      ),
    );
    if (result == true) {
      widget.onAddressSelected?.call();
    }
  }

  IconData _labelIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'work':
        return Icons.work_outline_rounded;
      case 'hotel':
        return Icons.hotel_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final addrProvider = context.watch<AddressProvider>();
    final savedAddresses = addrProvider.addresses;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
              child: Row(
                children: [
                  Text(
                    'Select delivery location',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
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
            // Search bar (tappable — opens map)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: _openAddAddressMap,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Icon(Icons.search_rounded,
                          color: AppColors.textHint, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Search for area, street name...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                children: [
                  // Use current location
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.my_location_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    title: Text(
                      'Use current location',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    subtitle: _detectingLocation
                        ? Text('Detecting...',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary))
                        : Text(
                            _currentLocationText,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                            maxLines: 2,
                          ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textHint),
                    onTap: _selectCurrentLocation,
                  ),
                  const Divider(
                      height: 1,
                      color: AppColors.divider,
                      indent: 16,
                      endIndent: 16),
                  // Add new address
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    title: Text(
                      'Add new address',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textHint),
                    onTap: _openAddAddressMap,
                  ),
                  if (savedAddresses.isNotEmpty) ...[
                    const Divider(height: 1, color: AppColors.divider),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Text(
                        'YOUR SAVED ADDRESSES',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHint,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    ...savedAddresses.asMap().entries.map((e) {
                      final i = e.key;
                      final addr = e.value;
                      final isSelected = addrProvider.selected != null &&
                          addrProvider.selected!.lat == addr.lat &&
                          addrProvider.selected!.lng == addr.lng &&
                          addrProvider.selected!.flatBuilding ==
                              addr.flatBuilding;
                      return _SavedAddressTile(
                        address: addr,
                        isSelected: isSelected,
                        icon: _labelIcon(addr.label),
                        onTap: () {
                          addrProvider.selectAddress(addr);
                          Navigator.pop(context);
                          widget.onAddressSelected?.call();
                        },
                        onDelete: () => addrProvider.deleteAddress(i),
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  final SavedAddress address;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SavedAddressTile({
    required this.address,
    required this.isSelected,
    required this.icon,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Icon(icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 20),
          ),
          title: Row(
            children: [
              Text(
                address.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Selected',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            address.fullAddress,
            style:
                GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.textHint, size: 20),
            onPressed: onDelete,
          ),
          onTap: onTap,
        ),
        const Divider(
            height: 1,
            color: AppColors.divider,
            indent: 16,
            endIndent: 16),
      ],
    );
  }
}
