import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/api_client.dart';
import '../../core/widgets/admin_sidebar.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _customers = [];
  bool _loading = false;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get('/admin/customers', query: {'limit': '100'});
      setState(() {
        _customers = (data['customers'] as List)
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _customers
        .where((c) =>
            (c['name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase()) ||
            (c['email'] ?? '').toString().toLowerCase().contains(_search.toLowerCase()))
        .toList();

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
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customers',
                              style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          Text('${_customers.length} registered',
                              style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 240,
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: GoogleFonts.inter(
                              color: AppColors.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search by name or email...',
                            prefixIcon: Icon(Icons.search_rounded,
                                color: AppColors.textMuted, size: 16),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppColors.textSecondary),
                        onPressed: _load,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.orange))
                      : _error != null
                          ? Center(
                              child: Text(_error!,
                                  style: GoogleFonts.inter(
                                      color: AppColors.red)))
                          : filtered.isEmpty
                              ? Center(
                                  child: Text('No customers found',
                                      style: GoogleFonts.inter(
                                          color: AppColors.textMuted,
                                          fontSize: 14)))
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: _CustomersTable(
                                      customers: filtered),
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomersTable extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  const _CustomersTable({required this.customers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: const [
                Expanded(
                    flex: 3,
                    child: Text('NAME',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 3,
                    child: Text('EMAIL',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 2,
                    child: Text('PHONE',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text('ORDERS',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          ...customers.map((c) => _CustomerRow(customer: c)),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _CustomerRow({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        AppColors.orange.withValues(alpha: 0.15),
                    child: Text(
                      (customer['name'] ?? '?')
                          .toString()
                          .substring(0, 1)
                          .toUpperCase(),
                      style: GoogleFonts.inter(
                          color: AppColors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(customer['name'] ?? '—',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(customer['email'] ?? '—',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            Expanded(
              flex: 2,
              child: Text(customer['phone'] ?? '—',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            Expanded(
              child: Text(
                  (customer['total_orders'] ?? 0).toString(),
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
