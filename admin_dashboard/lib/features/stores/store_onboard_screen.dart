// ignore_for_file: avoid_web_libraries_in_flutter
// dart:html and dart:ui_web are only available on Flutter Web
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_sidebar.dart';
import '../../core/providers/stores_provider.dart';
import '../../core/constants/app_routes.dart';

class StoreOnboardScreen extends StatefulWidget {
  const StoreOnboardScreen({super.key});

  @override
  State<StoreOnboardScreen> createState() => _StoreOnboardScreenState();
}

class _StoreOnboardScreenState extends State<StoreOnboardScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _storeName = TextEditingController();
  final _area = TextEditingController();
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _address = TextEditingController();
  final _latCtrl = TextEditingController(text: '18.5204');
  final _lngCtrl = TextEditingController(text: '73.8567');

  double _lat = 18.5204;
  double _lng = 73.8567;
  bool _saving = false;
  bool _showPassword = false;
  bool _mapReady = false;
  late html.EventListener _messageListener;
  String _mapViewId = '';

  @override
  void initState() {
    super.initState();
    _mapViewId = 'store-map-picker-${DateTime.now().millisecondsSinceEpoch}';
    _registerMap();

    // Listen for postMessage from the Leaflet iframe
    _messageListener = (html.Event event) {
      if (event is html.MessageEvent) {
        try {
          final data = event.data;
          if (data is Map && data['type'] == 'map_pick') {
            final newLat = (data['lat'] as num).toDouble();
            final newLng = (data['lng'] as num).toDouble();
            setState(() {
              _lat = newLat;
              _lng = newLng;
              _latCtrl.text = newLat.toStringAsFixed(6);
              _lngCtrl.text = newLng.toStringAsFixed(6);
            });
          }
        } catch (_) {}
      }
    };
    html.window.addEventListener('message', _messageListener);
  }

  void _registerMap() {
    final htmlContent = _buildMapHtml(_lat, _lng);
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);

    ui.platformViewRegistry.registerViewFactory(
      _mapViewId,
      (int viewId) => html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'geolocation',
    );

    setState(() => _mapReady = true);
  }

  String _buildMapHtml(double lat, double lng) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { height: 100%; background: #1A1F2E; }
    #map { height: 100vh; width: 100%; }
    #coords-bar {
      position: absolute;
      bottom: 12px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(26,31,46,0.92);
      color: #F97316;
      padding: 6px 16px;
      border-radius: 20px;
      font-family: sans-serif;
      font-size: 12px;
      z-index: 1000;
      pointer-events: none;
      border: 1px solid rgba(249,115,22,0.3);
    }
    #hint {
      position: absolute;
      top: 12px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(26,31,46,0.88);
      color: #94A3B8;
      padding: 6px 14px;
      border-radius: 8px;
      font-family: sans-serif;
      font-size: 11px;
      z-index: 1000;
      pointer-events: none;
    }
  </style>
</head>
<body>
  <div id="map"></div>
  <div id="hint">📍 Click anywhere or drag the marker to set store location</div>
  <div id="coords-bar" id="coords">Lat: $lat, Lng: $lng</div>
  <script>
    var lat = $lat, lng = $lng;
    var map = L.map('map').setView([lat, lng], 14);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
    }).addTo(map);

    var icon = L.icon({
      iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
      iconSize: [25, 41],
      iconAnchor: [12, 41],
      popupAnchor: [0, -41]
    });

    var marker = L.marker([lat, lng], {draggable: true, icon: icon}).addTo(map);
    marker.bindPopup('<b>Store Location</b><br>Drag to adjust').openPopup();

    function notifyParent(lt, ln) {
      document.getElementById('coords-bar').textContent = 'Lat: ' + lt.toFixed(6) + ', Lng: ' + ln.toFixed(6);
      window.parent.postMessage({type: 'map_pick', lat: lt, lng: ln}, '*');
    }

    marker.on('dragend', function(e) {
      var pos = e.target.getLatLng();
      notifyParent(pos.lat, pos.lng);
    });

    map.on('click', function(e) {
      marker.setLatLng(e.latlng);
      notifyParent(e.latlng.lat, e.latlng.lng);
    });
  </script>
</body>
</html>''';
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _messageListener);
    _storeName.dispose();
    _area.dispose();
    _ownerName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _address.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _onLatLngManualChange() {
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    if (lat != null && lng != null) {
      setState(() {
        _lat = lat;
        _lng = lng;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          const AdminSidebar(),
          const VerticalDivider(color: AppColors.border, width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                  decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: AppColors.border))),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.textSecondary, size: 20),
                        onPressed: () => Navigator.pushReplacementNamed(
                            context, AppRoutes.stores),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Onboard New Store',
                              style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              'Create store + owner account. Owner logs in with email & password.',
                              style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Map picker
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 0, 8),
                              child: Text('Store Location',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(24, 0, 0, 24),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _mapReady
                                        ? HtmlElementView(
                                            viewType: _mapViewId)
                                        : const Center(
                                            child: CircularProgressIndicator(
                                                color: AppColors.orange)),
                                  ),
                                ),
                              ),
                            ),
                            // Manual lat/lng entry
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 0, 0, 24),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ManualCoordField(
                                      label: 'Latitude',
                                      controller: _latCtrl,
                                      onChanged: (_) =>
                                          _onLatLngManualChange(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ManualCoordField(
                                      label: 'Longitude',
                                      controller: _lngCtrl,
                                      onChanged: (_) =>
                                          _onLatLngManualChange(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.orange
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.orange
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded,
                                            color: AppColors.orange, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
                                          style: GoogleFonts.inter(
                                              color: AppColors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(
                          color: AppColors.border, width: 1),
                      // Right: Form
                      SizedBox(
                        width: 360,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionLabel('Store Details'),
                                const SizedBox(height: 12),
                                _FormField(
                                    label: 'Store Name *',
                                    controller: _storeName,
                                    hint: 'e.g. Rahul Kirana',
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null),
                                const SizedBox(height: 12),
                                _FormField(
                                    label: 'Area / Locality *',
                                    controller: _area,
                                    hint: 'e.g. Kothrud, Pune',
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null),
                                const SizedBox(height: 12),
                                _FormField(
                                    label: 'Full Address',
                                    controller: _address,
                                    hint: 'Shop No., Street, Landmark',
                                    maxLines: 2),
                                const SizedBox(height: 20),
                                _SectionLabel('Owner Details'),
                                const SizedBox(height: 12),
                                _FormField(
                                    label: 'Owner Name *',
                                    controller: _ownerName,
                                    hint: 'Full name',
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null),
                                const SizedBox(height: 12),
                                _FormField(
                                    label: 'Phone Number *',
                                    controller: _phone,
                                    hint: '+91 9876543210',
                                    keyboardType: TextInputType.phone,
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null),
                                const SizedBox(height: 20),
                                _SectionLabel('Login Credentials'),
                                const SizedBox(height: 4),
                                Text(
                                    'The store owner will use these to log in.',
                                    style: GoogleFonts.inter(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                                const SizedBox(height: 12),
                                _FormField(
                                    label: 'Email *',
                                    controller: _email,
                                    hint: 'owner@email.com',
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v!.isEmpty) return 'Required';
                                      if (!v.contains('@')) return 'Invalid email';
                                      return null;
                                    }),
                                const SizedBox(height: 12),
                                // Password field with show/hide
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Password *',
                                        style: GoogleFonts.inter(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _password,
                                      obscureText: !_showPassword,
                                      validator: (v) {
                                        if (v!.isEmpty) return 'Required';
                                        if (v.length < 6) {
                                          return 'Min 6 characters';
                                        }
                                        return null;
                                      },
                                      style: GoogleFonts.inter(
                                          color: AppColors.textPrimary,
                                          fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Min 6 characters',
                                        hintStyle: GoogleFonts.inter(
                                            color: AppColors.textMuted,
                                            fontSize: 12),
                                        filled: true,
                                        fillColor: AppColors.card,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _showPassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: AppColors.textMuted,
                                            size: 18,
                                          ),
                                          onPressed: () => setState(() =>
                                              _showPassword = !_showPassword),
                                        ),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: AppColors.border)),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: AppColors.border)),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: AppColors.orange)),
                                        errorBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: AppColors.red)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                // Submit
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    child: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : Text('Onboard Store',
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14)),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider = context.read<StoresProvider>();
    final result = await provider.onboardStore({
      'name': _storeName.text.trim(),
      'area': _area.text.trim(),
      'owner_name': _ownerName.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
      'address': _address.text.trim(),
      'lat': _lat,
      'lng': _lng,
    });

    if (mounted) {
      setState(() => _saving = false);
      if (result != null) {
        _showSuccessDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to onboard store',
                style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.green, size: 24),
            const SizedBox(width: 8),
            Text('Store Onboarded!',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The store and owner account have been created.',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            _CredRow('Store ID', result['store_id'] ?? ''),
            _CredRow('Email', result['email'] ?? ''),
            _CredRow('Password', _password.text),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.2)),
              ),
              child: Text(
                  '⚠️ Share these credentials with the store owner securely. The store needs to be verified before it can receive orders.',
                  style: GoogleFonts.inter(
                      color: AppColors.orange, fontSize: 11)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, AppRoutes.stores);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white),
            child: const Text('Go to Stores'),
          ),
        ],
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: SelectableText(value,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
            color: AppColors.orange,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5));
  }
}

class _ManualCoordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _ManualCoordField(
      {required this.label,
      required this.controller,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: GoogleFonts.inter(
              color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.orange)),
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style:
              GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 12),
            filled: true,
            fillColor: AppColors.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.orange)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.red)),
          ),
        ),
      ],
    );
  }
}
