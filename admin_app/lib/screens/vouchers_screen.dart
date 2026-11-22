import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({Key? key}) : super(key: key);

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, approved
  List<dynamic> _vouchers = [];
  Map<String, dynamic> _counts = {'total': 0, 'pending': 0, 'approved': 0};

  @override
  void initState() {
    super.initState();
    _fetchVouchers();
  }

  Future<void> _fetchVouchers() async {
    setState(() => _isLoading = true);
    final res = await _api.getAccountantVouchers(status: _selectedFilter);
    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        _vouchers = res.data!['data'] ?? [];
        _counts = res.data!['counts'] ?? {};
      }
    });
  }

  Future<void> _approveVoucher(int id) async {
    final res = await _api.approveAccountantVoucher(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
      if (res.success) _fetchVouchers();
    }
  }

  Future<void> _rejectVoucher(int id) async {
    final res = await _api.rejectAccountantVoucher(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
      if (res.success) _fetchVouchers();
    }
  }

  void _showNewVoucherModal() {
    final titleCtrl = TextEditingController();
    final vendorCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final invNoCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'General Supplies';
    String paymentMethod = 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Create Expense Voucher / Bill', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Expense Title / Description *', prefixIcon: Icon(Icons.description)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Amount (NPR) *', prefixIcon: Icon(Icons.payments)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: category,
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: const [
                              DropdownMenuItem(value: 'General Supplies', child: Text('Supplies')),
                              DropdownMenuItem(value: 'Laboratory', child: Text('Laboratory')),
                              DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                              DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                              DropdownMenuItem(value: 'Hospitality', child: Text('Hospitality')),
                              DropdownMenuItem(value: 'Printing', child: Text('Printing')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => category = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: vendorCtrl,
                            decoration: const InputDecoration(labelText: 'Vendor / Supplier Name', prefixIcon: Icon(Icons.store)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: invNoCtrl,
                            decoration: const InputDecoration(labelText: 'Bill / Invoice #', prefixIcon: Icon(Icons.receipt)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(labelText: 'Disbursement Method', prefixIcon: Icon(Icons.account_balance_wallet)),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash from Drawer')),
                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer / Cheque')),
                        DropdownMenuItem(value: 'Fonepay', child: Text('Fonepay / QR')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => paymentMethod = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Internal Notes / Reason', prefixIcon: Icon(Icons.note)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Submit Voucher Claim'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                          if (title.isEmpty || amount <= 0) return;

                          Navigator.pop(ctx);
                          final res = await _api.createAccountantVoucher(
                            title: title,
                            category: category,
                            amount: amount,
                            vendor: vendorCtrl.text.trim(),
                            vendorInvoiceNo: invNoCtrl.text.trim(),
                            paymentMethod: paymentMethod,
                            notes: notesCtrl.text.trim(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message), backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson),
                            );
                            if (res.success) _fetchVouchers();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Expense Vouchers & Claims',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchVouchers),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${_counts['total'] ?? 0})'),
                const SizedBox(width: 8),
                _buildFilterChip('pending', 'Pending Approval (${_counts['pending'] ?? 0})', isAlert: (_counts['pending'] ?? 0) > 0),
                const SizedBox(width: 8),
                _buildFilterChip('approved', 'Approved (${_counts['approved'] ?? 0})'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _vouchers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 52, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text('No vouchers found in this category.', style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Create New Voucher'),
                              onPressed: _showNewVoucherModal,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _vouchers.length,
                        itemBuilder: (ctx, idx) {
                          final v = _vouchers[idx];
                          final isApproved = v['is_approved'] == true;
                          final amount = (v['amount'] as num).toDouble();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          v['title'] ?? 'Expense Voucher',
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isApproved ? AppTheme.emerald.withOpacity(0.12) : AppTheme.gold.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isApproved ? 'APPROVED' : 'PENDING APPROVAL',
                                          style: TextStyle(
                                            color: isApproved ? AppTheme.emerald : Colors.orange[800],
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Vendor: ${v['vendor']} • ${v['category']} • Date: ${v['expense_date']}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                  if (v['notes'] != null && (v['notes'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Notes: ${v['notes']}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                  ],
                                  const Divider(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'NPR ${amount.toStringAsFixed(2)}',
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textMain),
                                      ),
                                      if (!isApproved)
                                        Row(
                                          children: [
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.crimson,
                                                side: const BorderSide(color: AppTheme.crimson),
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                              ),
                                              onPressed: () => _rejectVoucher(v['id']),
                                              child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.emerald,
                                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                              ),
                                              onPressed: () => _approveVoucher(v['id']),
                                              child: const Text('Approve Bill', style: TextStyle(fontSize: 12)),
                                            ),
                                          ],
                                        )
                                      else
                                        Row(
                                          children: const [
                                            Icon(Icons.check_circle, size: 16, color: AppTheme.emerald),
                                            SizedBox(width: 4),
                                            Text('Signed Off', style: TextStyle(color: AppTheme.emerald, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.royalBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Voucher', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showNewVoucherModal,
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isAlert = false}) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = key);
        _fetchVouchers();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.royalBlue
              : (isAlert ? AppTheme.gold.withOpacity(0.15) : AppTheme.borderLight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isAlert ? Colors.orange[800] : AppTheme.textMain),
          ),
        ),
      ),
    );
  }
}
