import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../main.dart' show fcmService;

/// Self-onboarding screen for store owners. Captures shop details + a
/// draggable map pin for the store's lat/lng.
class StoreRegistrationScreen extends StatefulWidget {
  const StoreRegistrationScreen({super.key});

  @override
  State<StoreRegistrationScreen> createState() =>
      _StoreRegistrationScreenState();
}

class _StoreRegistrationScreenState extends State<StoreRegistrationScreen> {
  // Default to Pune city center if no GPS available.
  static const LatLng _puneFallback = LatLng(18.5204, 73.8567);

  final _formKey = GlobalKey<FormState>();
  final _shopNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _openCtrl = TextEditingController(text: '09:00');
  final _closeCtrl = TextEditingController(text: '22:00');

  final Completer<GoogleMapController> _mapCompleter = Completer();
  LatLng _pinned = _puneFallback;
  bool _locating = false;
  String? _locError;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _ownerNameCtrl.text = user.displayName;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentLocation());
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled. Please enable GPS.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission denied. Tap the map to set your store location.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final newPin = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _pinned = newPin;
      });
      _animateTo(newPin);
    } catch (e) {
      setState(() => _locError = e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _animateTo(LatLng target) async {
    final controller = await _mapCompleter.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(target, 17),
    );
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.registerStore(
      ownerName: _ownerNameCtrl.text.trim(),
      shopName: _shopNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      lat: _pinned.latitude,
      lng: _pinned.longitude,
      openTime: _openCtrl.text.trim().isEmpty ? null : _openCtrl.text.trim(),
      closeTime: _closeCtrl.text.trim().isEmpty ? null : _closeCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      fcmService.syncTokenToBackend();
      fcmService.listenForTokenRefresh();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Store registered. Awaiting admin verification before you can go live.',
          ),
        ),
      );
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.permissionGate,
        (_) => false,
        arguments: AppRoutes.dashboard,
      );
    } else if (auth.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        title: Text(
          'Register Your Store',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await context.read<AuthProvider>().signOut();
              if (!mounted) return;
              navigator.pushNamedAndRemoveUntil(
                AppRoutes.login,
                (_) => false,
              );
            },
            child: Text(
              'Sign out',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Tell us about your shop',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your store will be reviewed by DHAV before going live. '
                'Pin the exact store location — customers within range will see it.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: c.textHint,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              _label(c, 'Shop name'),
              _field(
                controller: _shopNameCtrl,
                hint: 'e.g. Sai Kirana Stores',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              _label(c, 'Owner name'),
              _field(
                controller: _ownerNameCtrl,
                hint: 'Your full name',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              _label(c, 'Phone'),
              _field(
                controller: _phoneCtrl,
                hint: '10-digit mobile',
                keyboard: TextInputType.phone,
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Required';
                  if (s.length < 10) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _label(c, 'Shop address'),
              _field(
                controller: _addressCtrl,
                hint: 'Full address, area, landmark',
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(c, 'Open time'),
                        _field(controller: _openCtrl, hint: '09:00'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(c, 'Close time'),
                        _field(controller: _closeCtrl, hint: '22:00'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _label(c, 'Pin your store on the map'),
              const SizedBox(height: 8),
              _mapCard(c),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lat ${_pinned.latitude.toStringAsFixed(6)},  '
                      'Lng ${_pinned.longitude.toStringAsFixed(6)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: c.textHint,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text('Use my location'),
                  ),
                ],
              ),
              if (_locError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _locError!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.red,
                    ),
                  ),
                ),
              Text(
                'Drag the orange pin or tap anywhere on the map to fine-tune.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: c.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.busy ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: auth.busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Submit for Verification',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(DhavColors c, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _mapCard(DhavColors c) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: _pinned, zoom: 15),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        markers: {
          Marker(
            markerId: const MarkerId('store'),
            position: _pinned,
            draggable: true,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            onDragEnd: (pos) => setState(() => _pinned = pos),
          ),
        },
        onTap: (pos) => setState(() => _pinned = pos),
        onMapCreated: (controller) {
          if (!_mapCompleter.isCompleted) _mapCompleter.complete(controller);
        },
      ),
    );
  }
}
