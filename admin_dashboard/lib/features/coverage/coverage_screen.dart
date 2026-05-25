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
      _stores = (results[1]['stores'] as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

      _buildMap();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _buildMap() {
    final customersJson = jsonEncode(_customers);
    final storesJson = jsonEncode(_stores);

    final htmlContent = _buildMapHtml(customersJson, storesJson, _radiusM);
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);

    ui.platformViewRegistry.registerViewFactory(
      _mapViewId,
      (int viewId) => html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%',
    );

    setState(() {
      _loading = false;
      _mapReady = true;
    });
  }

  static String _buildMapHtml(
      String customersJson, String storesJson, double radius) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { height: 100%; background: #0F1117; }
    #map { height: 100vh; width: 100%; }

    /* Wave pulse animations */
    @keyframes wave-covered {
      0%   { opacity: 0.85; }
      50%  { opacity: 0.45; }
      100% { opacity: 0.08; }
    }
    @keyframes wave-uncovered {
      0%   { opacity: 0.9; }
      40%  { opacity: 0.5; }
      100% { opacity: 0.08; }
    }

    .wc1 { animation: wave-covered   2.8s ease-in-out infinite 0s; }
    .wc2 { animation: wave-covered   2.8s ease-in-out infinite 0.7s; }
    .wc3 { animation: wave-covered   2.8s ease-in-out infinite 1.4s; }
    .wu1 { animation: wave-uncovered 2.2s ease-in-out infinite 0s; }
    .wu2 { animation: wave-uncovered 2.2s ease-in-out infinite 0.55s; }
    .wu3 { animation: wave-uncovered 2.2s ease-in-out infinite 1.1s; }

    /* Leaflet popup dark theme */
    .leaflet-popup-content-wrapper {
      background: #1E293B;
      color: #F8FAFC;
      border: 1px solid #334155;
      border-radius: 12px !important;
      box-shadow: 0 8px 32px rgba(0,0,0,0.5);
      padding: 0;
    }
    .leaflet-popup-content { margin: 0; }
    .leaflet-popup-tip { background: #1E293B; }
    .leaflet-popup-close-button { color: #94A3B8 !important; top: 8px !important; right: 8px !important; }

    .store-popup {
      font-family: -apple-system, sans-serif;
      padding: 14px 16px;
      min-width: 210px;
    }
    .store-popup h4 {
      color: #F8FAFC;
      font-size: 14px;
      font-weight: 700;
      margin: 0 0 3px;
    }
    .store-popup .area {
      color: #94A3B8;
      font-size: 11px;
      margin-bottom: 8px;
    }
    .store-popup .status-badge {
      font-size: 10px;
      font-weight: 700;
      padding: 2px 8px;
      border-radius: 10px;
      display: inline-block;
      margin-bottom: 10px;
      letter-spacing: 0.3px;
    }
    .badge-online  { background: rgba(34,197,94,0.15); color: #22C55E; }
    .badge-offline { background: rgba(239,68,68,0.15);  color: #EF4444; }
    .store-popup .view-btn {
      display: block;
      width: 100%;
      background: #00897B;
      color: white;
      border: none;
      border-radius: 8px;
      padding: 8px 0;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      font-family: inherit;
      text-align: center;
      transition: background 0.15s;
    }
    .store-popup .view-btn:hover { background: #00695C; }

    .customer-popup {
      font-family: -apple-system, sans-serif;
      padding: 12px 14px;
      min-width: 180px;
    }
    .customer-popup h4 {
      color: #F8FAFC;
      font-size: 13px;
      font-weight: 700;
      margin: 0 0 5px;
    }
    .coverage-tag {
      font-size: 10px;
      font-weight: 700;
      padding: 2px 8px;
      border-radius: 10px;
      display: inline-block;
      margin-bottom: 5px;
      letter-spacing: 0.3px;
    }
    .tag-covered   { background: rgba(34,197,94,0.15); color: #22C55E; }
    .tag-uncovered { background: rgba(239,68,68,0.15);  color: #EF4444; }
    .customer-popup .email { color: #64748B; font-size: 10px; }

    #legend {
      position: absolute;
      bottom: 20px;
      right: 12px;
      background: rgba(15,17,23,0.93);
      border: 1px solid #2D3748;
      border-radius: 12px;
      padding: 12px 16px;
      font-family: -apple-system, sans-serif;
      z-index: 1000;
      min-width: 200px;
    }
    #legend h5 {
      color: #64748B;
      font-size: 9px;
      font-weight: 700;
      letter-spacing: 1px;
      text-transform: uppercase;
      margin: 0 0 10px;
    }
    .leg { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; color: #CBD5E1; font-size: 11px; }
    .leg-dot  { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
    .leg-ring { width: 14px; height: 14px; border-radius: 50%; border: 2px solid; background: transparent; flex-shrink: 0; }
    .leg-sep  { border-top: 1px solid #1E293B; margin: 8px 0; }
    .leg-note { color: #475569; font-size: 10px; }
  </style>
</head>
<body>
  <div id="map"></div>
  <div id="legend">
    <h5>Map Legend</h5>
    <div class="leg"><div class="leg-dot" style="background:#22C55E"></div><span>Customer — shop nearby</span></div>
    <div class="leg"><div class="leg-dot" style="background:#EF4444"></div><span>Customer — no shop</span></div>
    <div class="leg"><div class="leg-ring" style="border-color:#00897B;background:rgba(0,137,123,0.12)"></div><span>Store</span></div>
    <div class="leg-sep"></div>
    <div class="leg leg-note">Coverage radius: 2 km · Click markers for details</div>
  </div>
  <script>
    var CUSTOMERS = $customersJson;
    var STORES    = $storesJson;
    var RADIUS    = $radius;

    var map = L.map('map', { preferCanvas: false }).setView([18.5204, 73.8567], 12);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://openstreetmap.org">OSM</a>',
      maxZoom: 18
    }).addTo(map);

    /* ── Haversine distance (meters) ── */
    function dist(lat1, lng1, lat2, lng2) {
      var R = 6371000, d2r = Math.PI / 180;
      var dLat = (lat2 - lat1) * d2r, dLng = (lng2 - lng1) * d2r;
      var a = Math.sin(dLat/2)*Math.sin(dLat/2) +
              Math.cos(lat1*d2r)*Math.cos(lat2*d2r)*
              Math.sin(dLng/2)*Math.sin(dLng/2);
      return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    /* ── Extract lat/lng from customer (handles multiple API shapes) ── */
    function getCustomerLoc(c) {
      if (c.lat && c.lng) return [+c.lat, +c.lng];
      var loc = c.location || c.address || c.current_address || c.saved_address;
      if (loc && loc.lat && loc.lng) return [+loc.lat, +loc.lng];
      return null;
    }

    /* ── Build store marker ── */
    STORES.forEach(function(s) {
      if (!s.lat || !s.lng) return;
      var sLat = +s.lat, sLng = +s.lng;
      if (isNaN(sLat) || isNaN(sLng)) return;

      var isOnline = s.is_active && !s.is_suspended;
      var bg = isOnline ? '#00897B' : '#475569';

      var icon = L.divIcon({
        className: '',
        html: '<div style="width:34px;height:34px;background:' + bg + ';border-radius:9px;border:2.5px solid white;display:flex;align-items:center;justify-content:center;box-shadow:0 3px 10px rgba(0,0,0,0.45);font-size:17px;line-height:1">🏪</div>',
        iconSize: [34, 34], iconAnchor: [17, 17], popupAnchor: [0, -20]
      });

      var popup =
        '<div class="store-popup">' +
          '<h4>' + (s.name || 'Store') + '</h4>' +
          '<div class="area">📍 ' + (s.area || '—') + ' &nbsp;·&nbsp; ' + (s.phone || '') + '</div>' +
          '<span class="status-badge ' + (isOnline ? 'badge-online' : 'badge-offline') + '">' +
            (isOnline ? '● ONLINE' : '● OFFLINE') +
          '</span>' +
          '<button class="view-btn" onclick="viewStore(\'' + s.store_id + '\')">View Store →</button>' +
        '</div>';

      L.marker([sLat, sLng], { icon: icon, zIndexOffset: 50 })
        .addTo(map)
        .bindPopup(popup, { maxWidth: 260, minWidth: 210 });
    });

    /* ── Build customer circles + markers ── */
    CUSTOMERS.forEach(function(c) {
      var loc = getCustomerLoc(c);
      if (!loc) return;
      var cLat = loc[0], cLng = loc[1];
      if (isNaN(cLat) || isNaN(cLng)) return;

      /* check if any store is within coverage radius */
      var covered = STORES.some(function(s) {
        if (!s.lat || !s.lng) return false;
        var sLat = +s.lat, sLng = +s.lng;
        return !isNaN(sLat) && dist(cLat, cLng, sLat, sLng) <= RADIUS;
      });

      var clr  = covered ? '#22C55E' : '#EF4444';
      var pfx  = covered ? 'wc' : 'wu';

      /* 3 concentric wave circles */
      L.circle([cLat, cLng], {
        radius: RADIUS * 0.33, color: clr, weight: 2.5, opacity: 0.85,
        fillColor: clr, fillOpacity: 0.10, className: pfx + '1'
      }).addTo(map);
      L.circle([cLat, cLng], {
        radius: RADIUS * 0.66, color: clr, weight: 1.5, opacity: 0.55,
        fillColor: clr, fillOpacity: 0.05, className: pfx + '2'
      }).addTo(map);
      L.circle([cLat, cLng], {
        radius: RADIUS,        color: clr, weight: 1,   opacity: 0.30,
        fillColor: clr, fillOpacity: 0.02, className: pfx + '3'
      }).addTo(map);

      /* customer dot marker */
      var dotIcon = L.divIcon({
        className: '',
        html: '<div style="width:22px;height:22px;background:' + clr + ';border-radius:50%;border:3px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.4);display:flex;align-items:center;justify-content:center;font-size:10px;line-height:1">👤</div>',
        iconSize: [22, 22], iconAnchor: [11, 11], popupAnchor: [0, -14]
      });

      var custPopup =
        '<div class="customer-popup">' +
          '<h4>' + (c.name || 'Customer') + '</h4>' +
          '<span class="coverage-tag ' + (covered ? 'tag-covered' : 'tag-uncovered') + '">' +
            (covered ? '✓ Shop in range' : '✗ No shop nearby') +
          '</span>' +
          (c.email ? '<div class="email">' + c.email + '</div>' : '') +
        '</div>';

      L.marker([cLat, cLng], { icon: dotIcon, zIndexOffset: 100 })
        .addTo(map)
        .bindPopup(custPopup, { maxWidth: 220 });
    });

    /* ── Navigate to store detail ── */
    function viewStore(storeId) {
      window.parent.postMessage({ type: 'view_store', store_id: storeId }, '*');
    }
  </script>
</body>
</html>''';
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
