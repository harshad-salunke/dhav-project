// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_sidebar.dart';
import '../../core/services/api_client.dart';
import '../../core/constants/app_routes.dart';

class CoverageScreen extends StatefulWidget {
  const CoverageScreen({super.key});

  @override
  State<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends State<CoverageScreen> {
  final _api = ApiClient();

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;
  String? _error;

  late html.EventListener _messageListener;
  final String _mapViewId =
      'coverage-map-${DateTime.now().millisecondsSinceEpoch}';
  bool _mapReady = false;
  bool _viewRegistered = false;
  html.IFrameElement? _mapIframe;

  // Coverage radius in meters
  static const double _radiusM = 2000;

  int get _customersWithLocation => _customers.where((c) {
        return c['lat'] != null ||
            (c['location'] is Map &&
                (c['location'] as Map)['lat'] != null) ||
            (c['address'] is Map &&
                (c['address'] as Map)['lat'] != null) ||
            (c['current_address'] is Map &&
                (c['current_address'] as Map)['lat'] != null);
      }).length;

  int get _storesWithLocation =>
      _stores.where((s) => s['lat'] != null).length;

  @override
  void initState() {
    super.initState();
    _messageListener = (html.Event event) {
      if (event is html.MessageEvent) {
        try {
          final data = event.data;
          if (data is Map && data['type'] == 'view_store') {
            final storeId = data['store_id'] as String;
            if (mounted) {
              Navigator.pushNamed(context, AppRoutes.storeDetail,
                  arguments: storeId);
            }
          }
        } catch (_) {}
      }
    };
    html.window.addEventListener('message', _messageListener);
    _loadData();
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _messageListener);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _mapReady = false;
    });
    try {
      final results = await Future.wait([
        _api.get('/admin/customers',
            query: {'limit': '500', 'include_location': 'true'}),
        _api.get('/admin/stores', query: {'limit': '500'}),
      ]);

      _customers = (results[0]['customers'] as List)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();
      _stores = (results[1]['stores'] as List).map((s) {
        final m = Map<String, dynamic>.from(s as Map);
        // Normalize Postgres shape for the Leaflet map JS, which expects
        // top-level lat/lng, store_id, name and area.
        final loc = m['location'] is Map
            ? Map<String, dynamic>.from(m['location'] as Map)
            : const {};
        m['lat'] ??= loc['lat'];
        m['lng'] ??= loc['lng'];
        m['store_id'] = m['store_id'] ?? m['id'];
        final name = m['name'];
        if (name == null || (name is String && name.isEmpty)) {
          m['name'] = m['shop_name'];
        }
        final area = m['area'];
        if (area == null || (area is String && area.isEmpty)) {
          m['area'] = m['address'];
        }
        return m;
      }).toList();

      _buildMap();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _buildMap() {
    // Write data to localStorage BEFORE creating/reloading the iframe.
    // Since the parent app and coverage_map.html share the same origin
    // (dhav-quick-commerce.web.app), the iframe reads it directly on load —
    // no postMessage, no Dart deserialization, no timing race.
    html.window.localStorage['dhav_coverage_data'] = jsonEncode({
      'customers': _customers,
      'stores': _stores,
      'radius': _radiusM,
    });

    // Cache-bust the src so the iframe always reloads fresh data.
    final src =
        '${html.window.location.origin}/coverage_map.html'
        '?t=${DateTime.now().millisecondsSinceEpoch}';

    if (!_viewRegistered) {
      _viewRegistered = true;
      ui.platformViewRegistry.registerViewFactory(
        _mapViewId,
        (int viewId) {
          _mapIframe = html.IFrameElement()
            ..src = src
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';
          return _mapIframe!;
        },
      );
    } else {
      // Refresh: reload the iframe; it will re-read updated localStorage.
      _mapIframe?.src = src;
    }

    setState(() {
      _loading = false;
      _mapReady = true;
    });
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
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coverage Zones',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              Text(
                'Customer locations vs 2 km store coverage',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          if (!_loading && _error == null) ...[
            _StatChip(
              icon: Icons.people_rounded,
              label: 'On Map',
              value: _customersWithLocation.toString(),
              color: AppColors.orange,
            ),
            const SizedBox(width: 8),
            _StatChip(
              icon: Icons.storefront_rounded,
              label: 'Stores',
              value: _storesWithLocation.toString(),
              color: AppColors.green,
            ),
          ],
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.orange));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.red, size: 28),
            ),
            const SizedBox(height: 14),
            Text('Failed to load coverage data',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_error!,
                style:
                    GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }
    if (!_mapReady) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.orange));
    }
    return HtmlElementView(viewType: _mapViewId);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(value,
              style: GoogleFonts.inter(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  color: color.withValues(alpha: 0.7), fontSize: 11)),
        ],
      ),
    );
  }
}
