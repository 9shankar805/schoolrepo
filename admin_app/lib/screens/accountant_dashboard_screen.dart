import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'vouchers_screen.dart';
import 'student_fees_screen.dart';
import 'finance_screen.dart';
import 'inventory_assets_screen.dart';

class AccountantDashboardScreen extends StatefulWidget {
  const AccountantDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AccountantDashboardScreen> createState() => _AccountantDashboardScreenState();
}

class _AccountantDashboardScreenState extends State<AccountantDashboardScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() => _isLoading = true);
    final res = await _api.getAccountantDashboard();
    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        _dashboardData = res.data;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final summary = _dashboardData?['summary'] ?? {};
    final methods = (_dashboardData?['payment_methods'] as Map<String, dynamic>?) ?? {};
    final cashiers = (_dashboardData?['cashiers_today'] as List<dynamic>?) ?? [];
    final recentReceipts = (_dashboardData?['recent_receipts'] as List<dynamic>?) ?? [];
    final recentVouchers = (_dashboardData?['recent_vouchers'] as List<dynamic>?) ?? [];

    final todayTotal = (summary['today_total'] ?? 0).toDouble();
    final monthTotal = (summary['month_total'] ?? 0).toDouble();
    final totalDues = (summary['total_dues'] ?? 0).toDouble();
    final defaultersCount = summary['defaulters_count'] ?? 0;
    final pendingVouchersCount = summary['pending_vouchers_count'] ?? 0;
    final pendingVouchersAmount = (summary['pending_vouchers_amount'] ?? 0).toDouble();
    final pendingProofsCount = summary['pending_proofs_count'] ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finance & Accounts Desk',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${auth.adminName} • Cash Intake Focus',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboard,
            tooltip: 'Refresh Ledger & Intake',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Primary Highlight: Today's Cash Intake
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.point_of_sale, color: AppTheme.emerald, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "TODAY'S CASH INTAKE",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Live Counter',
                                  style: TextStyle(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'NPR ${todayTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white24, height: 16),
                          // Payment Methods Row
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: methods.entries.map((e) {
                              final val = (e.value as num).toDouble();
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${e.key}: ',
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                  Text(
                                    'NPR ${val.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. Pending Actions Alert Cards (Vouchers & Proofs)
                    Row(
                      children: [
                        // Pending Vouchers
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const VouchersScreen()),
                              ).then((_) => _fetchDashboard());
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: pendingVouchersCount > 0 ? AppTheme.gold.withOpacity(0.12) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: pendingVouchersCount > 0 ? AppTheme.gold : AppTheme.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Icon(Icons.receipt_long, color: AppTheme.gold, size: 20),
                                      if (pendingVouchersCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(10)),
                                          child: Text('$pendingVouchersCount', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$pendingVouchersCount Vouchers',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'NPR ${pendingVouchersAmount.toStringAsFixed(0)} claims',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Pending Payment Proofs
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const StudentFeesScreen(initialTab: 1)),
                              ).then((_) => _fetchDashboard());
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: pendingProofsCount > 0 ? Colors.indigo.withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: pendingProofsCount > 0 ? Colors.indigo : AppTheme.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Icon(Icons.document_scanner, color: Colors.indigo, size: 20),
                                      if (pendingProofsCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(10)),
                                          child: Text('$pendingProofsCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$pendingProofsCount Online Slips',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const Text(
                                    'Awaiting verification',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 3. MTD Revenue & Outstanding Dues Summary
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.calendar_month, color: AppTheme.royalBlue, size: 16),
                                    SizedBox(width: 6),
                                    Text('MTD REVENUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'NPR ${monthTotal.toStringAsFixed(0)}',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.royalBlue),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This Month Intake',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 16),
                                    SizedBox(width: 6),
                                    Text('TOTAL DUES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'NPR ${totalDues.toStringAsFixed(0)}',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.crimson),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$defaultersCount Students with Dues',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 4. Quick Actions Grid for Accountants
                    Text(
                      'Accountant Operations',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildActionTile(
                          icon: Icons.add_shopping_cart,
                          label: 'Collect Fee (POS)',
                          color: AppTheme.emerald,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StudentFeesScreen(initialTab: 0)),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        _buildActionTile(
                          icon: Icons.receipt,
                          label: 'Expense Voucher',
                          color: AppTheme.gold,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const VouchersScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        _buildActionTile(
                          icon: Icons.inventory_2,
                          label: 'Inventory & Assets',
                          color: AppTheme.royalBlue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const InventoryAssetsScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        _buildActionTile(
                          icon: Icons.notifications_active,
                          label: 'Fee Reminders',
                          color: AppTheme.crimson,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FinanceScreen()),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 5. Cashier Counter Performance Today
                    if (cashiers.isNotEmpty) ...[
                      Text(
                        'Cashier Desks Today',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          children: cashiers.map((c) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppTheme.primaryLight,
                                        child: Icon(Icons.person, size: 16, color: AppTheme.royalBlue),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(c['cashier_name'] ?? 'Desk', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  Text(
                                    'NPR ${(c['amount'] as num).toDouble().toStringAsFixed(2)} (${c['receipts']} bills)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 13),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 6. Recent Receipts Stream
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Fee Receipts', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen()));
                          },
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    if (recentReceipts.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No fee receipts recorded yet today.')))
                    else
                      ...recentReceipts.map((r) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            dense: true,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFECFDF5),
                              child: Icon(Icons.check, color: AppTheme.emerald, size: 18),
                            ),
                            title: Text(r['student_name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${r['receipt_no']} • ${r['payment_method']} • ${r['created_at']}'),
                            trailing: Text(
                              'NPR ${(r['amount'] as num).toDouble().toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 14),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
