import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class InventoryAssetsScreen extends StatefulWidget {
  const InventoryAssetsScreen({Key? key}) : super(key: key);

  @override
  State<InventoryAssetsScreen> createState() => _InventoryAssetsScreenState();
}

class _InventoryAssetsScreenState extends State<InventoryAssetsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  List<dynamic> _supplies = [];
  List<dynamic> _assets = [];
  Map<String, dynamic> _summary = {};

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() => _isLoading = true);
    final res = await _api.getAccountantInventory();
    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        _supplies = res.data!['supplies'] ?? [];
        _assets = res.data!['assets'] ?? [];
        _summary = res.data!['summary'] ?? {};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Inventory & Fixed Assets',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchInventory),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Supplies & Consumables'),
                  if ((_summary['low_stock_alerts'] ?? 0) > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.crimson, borderRadius: BorderRadius.circular(10)),
                      child: Text('${_summary['low_stock_alerts']}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Fixed Assets'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Filter items or assets...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSuppliesTab(),
                      _buildAssetsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSuppliesTab() {
    final filtered = _supplies.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final sku = (s['sku'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || sku.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No supplies found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (ctx, idx) {
        final item = filtered[idx];
        final isLow = item['is_low_stock'] == true;
        final qty = item['quantity_in_stock'] ?? 0;
        final reorder = item['reorder_level'] ?? 0;
        final unitPrice = (item['unit_price'] as num).toDouble();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isLow ? AppTheme.crimson.withOpacity(0.12) : AppTheme.emerald.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isLow ? Icons.warning_amber_rounded : Icons.inventory_2,
                    color: isLow ? AppTheme.crimson : AppTheme.emerald,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Item',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${item['sku']} • Loc: ${item['location']}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rate: NPR ${unitPrice.toStringAsFixed(2)} / ${item['unit']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.royalBlue),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$qty ${item['unit']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isLow ? AppTheme.crimson : AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLow ? AppTheme.crimson.withOpacity(0.1) : AppTheme.emerald.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isLow ? 'LOW (Min: $reorder)' : 'IN STOCK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLow ? AppTheme.crimson : AppTheme.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssetsTab() {
    final filtered = _assets.where((a) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      final tag = (a['asset_tag'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || tag.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No fixed assets recorded.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (ctx, idx) {
        final a = filtered[idx];
        final price = (a['purchase_price'] as num).toDouble();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
              child: const Icon(Icons.devices_other, color: AppTheme.royalBlue),
            ),
            title: Text(a['name'] ?? 'Asset', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('Tag: ${a['asset_tag']} • Loc: ${a['location']}\nCondition: ${a['condition']} • Status: ${a['status']}'),
            trailing: Text(
              'NPR ${price.toStringAsFixed(0)}',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.textMain),
            ),
          ),
        );
      },
    );
  }
}
