import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class StudentFeesScreen extends StatefulWidget {
  final int initialTab;
  const StudentFeesScreen({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends State<StudentFeesScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  // Student Ledger Search State
  final _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Map<String, dynamic>? _selectedStudent;
  List<dynamic> _invoices = [];
  List<dynamic> _ledgerEntries = [];
  bool _isLoadingLedger = false;

  // Payment Proofs State
  bool _isLoadingProofs = true;
  String _proofsFilter = 'pending'; // pending, approved, rejected, all
  List<dynamic> _proofs = [];
  Map<String, dynamic> _proofsCounts = {'pending': 0, 'approved': 0, 'rejected': 0};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _fetchPaymentProofs();
    // Default search for student ID 7 (demo defaulter)
    _loadStudentLedger(7);
  }

  Future<void> _fetchPaymentProofs() async {
    setState(() => _isLoadingProofs = true);
    final res = await _api.getAccountantPaymentProofs(status: _proofsFilter);
    setState(() {
      _isLoadingProofs = false;
      if (res.success && res.data != null) {
        _proofs = res.data!['data'] ?? [];
        _proofsCounts = res.data!['counts'] ?? {};
      }
    });
  }

  Future<void> _loadStudentLedger(int studentId) async {
    setState(() => _isLoadingLedger = true);
    final res = await _api.getStudentLedger(studentId);
    setState(() {
      _isLoadingLedger = false;
      if (res.success && res.data != null) {
        _selectedStudent = res.data!['student'];
        _invoices = res.data!['invoices'] ?? [];
        _ledgerEntries = res.data!['ledger'] ?? [];
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Action: Collect Fee (Counter POS)
  // ---------------------------------------------------------------------------
  void _showCollectFeeModal() {
    if (_selectedStudent == null) return;

    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMethod = 'Cash';
    int? selectedInvoiceId;

    // Pick first unpaid invoice if available
    final unpaidInvs = _invoices.where((i) => i['dues'] > 0).toList();
    if (unpaidInvs.isNotEmpty) {
      selectedInvoiceId = unpaidInvs.first['id'];
      amountCtrl.text = unpaidInvs.first['dues'].toString();
    }

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
                        Text('Collect Student Fee (POS)', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: AppTheme.royalBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedStudent!['name']} (${_selectedStudent!['class_name']})',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (unpaidInvs.isNotEmpty) ...[
                      (() {
                        final uniqueInvs = <int, Map<String, dynamic>>{};
                        for (final i in unpaidInvs) {
                          if (i is Map && i['id'] != null) {
                            uniqueInvs[i['id'] as int] = Map<String, dynamic>.from(i);
                          }
                        }
                        final items = uniqueInvs.values.map<DropdownMenuItem<int>>((i) {
                          return DropdownMenuItem<int>(
                            value: i['id'] as int,
                            child: Text('${i['title']} (Due: NPR ${i['dues']})'),
                          );
                        }).toList();
                        final safeVal = uniqueInvs.containsKey(selectedInvoiceId) ? selectedInvoiceId : (uniqueInvs.isNotEmpty ? uniqueInvs.keys.first : null);

                        return DropdownButtonFormField<int>(
                          value: safeVal,
                          decoration: const InputDecoration(labelText: 'Target Bill / Invoice'),
                          items: items,
                          onChanged: (val) {
                            setModalState(() {
                              selectedInvoiceId = val;
                              final inv = uniqueInvs[val];
                              if (inv != null && inv['dues'] != null) amountCtrl.text = inv['dues'].toString();
                            });
                          },
                        );
                      })(),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount to Collect (NPR) *', prefixIcon: Icon(Icons.payments)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(labelText: 'Payment Method', prefixIcon: Icon(Icons.account_balance_wallet)),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash at Counter')),
                        DropdownMenuItem(value: 'Fonepay', child: Text('Fonepay / QR')),
                        DropdownMenuItem(value: 'eSewa', child: Text('eSewa Wallet')),
                        DropdownMenuItem(value: 'Khalti', child: Text('Khalti Wallet')),
                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Direct Bank Deposit')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => paymentMethod = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(labelText: 'Transaction Reference / Bank Slip # (Optional)', prefixIcon: Icon(Icons.tag)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Confirm & Issue Official Receipt'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                          if (amount <= 0) return;

                          Navigator.pop(ctx);
                          final res = await _api.collectFee(
                            studentId: _selectedStudent!['id'],
                            amount: amount,
                            paymentMethod: paymentMethod,
                            invoiceId: selectedInvoiceId,
                            reference: refCtrl.text.trim(),
                            notes: notesCtrl.text.trim(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message), backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson),
                            );
                            if (res.success) _loadStudentLedger(_selectedStudent!['id']);
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

  // ---------------------------------------------------------------------------
  // Action: Approve Online Payment Proof
  // ---------------------------------------------------------------------------
  Future<void> _approveProof(int id) async {
    final res = await _api.approveAccountantPaymentProof(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson),
      );
      if (res.success) {
        _fetchPaymentProofs();
        if (_selectedStudent != null) _loadStudentLedger(_selectedStudent!['id']);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Action: Reject Online Payment Proof
  // ---------------------------------------------------------------------------
  void _promptRejectProof(int id) {
    final reasonCtrl = TextEditingController(text: 'Transaction ID not verified in school bank statement.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payment Slip?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter rejection reason for guardian:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.rejectAccountantPaymentProof(id, reason: reasonCtrl.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res.message), backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson),
                );
                if (res.success) _fetchPaymentProofs();
              }
            },
            child: const Text('Reject Proof'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Student Fees & Verification',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: [
            const Tab(text: 'Dues & Ledger'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Payment Proofs'),
                  if ((_proofsCounts['pending'] ?? 0) > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.crimson, borderRadius: BorderRadius.circular(10)),
                      child: Text('${_proofsCounts['pending']}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDuesAndLedgerTab(),
          _buildPaymentProofsTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Dues & Ledger
  // ---------------------------------------------------------------------------
  Widget _buildDuesAndLedgerTab() {
    return Column(
      children: [
        // Search Student Bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search student by name or roll number...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                  filled: true,
                  fillColor: AppTheme.background,
                ),
                onChanged: (val) async {
                  if (val.trim().length >= 2) {
                    setState(() => _isSearching = true);
                    final res = await _api.searchStudents(val.trim());
                    setState(() {
                      _isSearching = false;
                      if (res.success && res.data != null) {
                        _searchResults = res.data ?? [];
                      }
                    });
                  }
                },
              ),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(border: Border.all(color: AppTheme.borderLight), borderRadius: BorderRadius.circular(8)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (c, i) {
                      final s = _searchResults[i];
                      return ListTile(
                        dense: true,
                        title: Text(s['name'] ?? 'Student'),
                        subtitle: Text('${s['class_name']} • Roll #${s['roll_number']}'),
                        onTap: () {
                          setState(() {
                            _searchResults = [];
                            _searchCtrl.clear();
                          });
                          _loadStudentLedger(s['id']);
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        // Selected Student Header & Ledger
        Expanded(
          child: _isLoadingLedger
              ? const Center(child: CircularProgressIndicator())
              : _selectedStudent == null
                  ? const Center(child: Text('Search and select a student to inspect dues and ledger.'))
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        // Student Profile & Dues Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppTheme.royalBlue,
                                    child: Text(
                                      (_selectedStudent!['name'] ?? 'S')[0],
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedStudent!['name'] ?? 'Student',
                                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          'Class ${_selectedStudent!['class_name']} (${_selectedStudent!['section']}) • Phone: ${_selectedStudent!['phone'] ?? 'N/A'}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Divider(color: Colors.white24, height: 1),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('OUTSTANDING BALANCE', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'NPR ${(_selectedStudent!['total_dues'] as num).toDouble().toStringAsFixed(2)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: (_selectedStudent!['total_dues'] as num) > 0 ? AppTheme.gold : AppTheme.emerald,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                                    label: const Text('Collect Fee (POS)'),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                                    onPressed: _showCollectFeeModal,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Invoices Breakdown
                        if (_invoices.isNotEmpty) ...[
                          Text('Active Invoices & Fees', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ..._invoices.map((inv) {
                            final dues = (inv['dues'] as num).toDouble();
                            final isPaid = inv['status'] == 'paid';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                dense: true,
                                title: Text(inv['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Total: NPR ${inv['total_amount']} • Paid: NPR ${inv['paid_amount']}'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPaid ? AppTheme.emerald.withOpacity(0.12) : AppTheme.crimson.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isPaid ? 'PAID' : 'DUE: NPR ${dues.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isPaid ? AppTheme.emerald : AppTheme.crimson,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // Ledger Chronological Statement
                        Text('Chronological Financial Ledger', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_ledgerEntries.isEmpty)
                          const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No historical ledger transactions found.')))
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _ledgerEntries.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final row = _ledgerEntries[idx];
                                final isPayment = row['type'] == 'payment' || (row['credit'] as num? ?? 0) > 0;
                                final credit = (row['credit'] as num? ?? 0).toDouble();
                                final debit = (row['debit'] as num? ?? 0).toDouble();

                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isPayment ? AppTheme.emerald : AppTheme.crimson,
                                    size: 18,
                                  ),
                                  title: Text(row['description'] ?? 'Transaction', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text('${row['entry_date']} • Running Bal: NPR ${row['balance']}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  trailing: Text(
                                    isPayment ? '- NPR ${credit.toStringAsFixed(0)}' : '+ NPR ${debit.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isPayment ? AppTheme.emerald : AppTheme.crimson,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Payment Proofs (Online Slip Verifier)
  // ---------------------------------------------------------------------------
  Widget _buildPaymentProofsTab() {
    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              _buildProofFilterChip('pending', 'Pending Review (${_proofsCounts['pending'] ?? 0})', isAlert: (_proofsCounts['pending'] ?? 0) > 0),
              const SizedBox(width: 8),
              _buildProofFilterChip('approved', 'Verified (${_proofsCounts['approved'] ?? 0})'),
              const SizedBox(width: 8),
              _buildProofFilterChip('rejected', 'Rejected (${_proofsCounts['rejected'] ?? 0})'),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingProofs
              ? const Center(child: CircularProgressIndicator())
              : _proofs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 52, color: AppTheme.emerald),
                          const SizedBox(height: 12),
                          Text('No online payment slips in this queue.', style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _proofs.length,
                      itemBuilder: (ctx, idx) {
                        final p = _proofs[idx];
                        final isPending = p['status'] == 'pending';
                        final amount = (p['amount'] as num).toDouble();

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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['student_name'] ?? 'Student',
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          '${p['class_name']} • Slip #${p['id']}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPending ? Colors.indigo.withOpacity(0.12) : (p['status'] == 'approved' ? AppTheme.emerald.withOpacity(0.12) : AppTheme.crimson.withOpacity(0.12)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        (p['status'] ?? 'pending').toString().toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          color: isPending ? Colors.indigo : (p['status'] == 'approved' ? AppTheme.emerald : AppTheme.crimson),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Gateway: ${p['gateway']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                          Text('Txn: ${p['transaction_id']}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                        ],
                                      ),
                                      if (p['notes'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text('Note: ${p['notes']}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                      ],
                                    ],
                                  ),
                                ),
                                const Divider(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'NPR ${amount.toStringAsFixed(2)}',
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.textMain),
                                    ),
                                    if (isPending)
                                      Row(
                                        children: [
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.crimson,
                                              side: const BorderSide(color: AppTheme.crimson),
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                            ),
                                            onPressed: () => _promptRejectProof(p['id']),
                                            child: const Text('Reject Slip', style: TextStyle(fontSize: 12)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.check, size: 14),
                                            label: const Text('Verify & Credit', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, padding: const EdgeInsets.symmetric(horizontal: 12)),
                                            onPressed: () => _approveProof(p['id']),
                                          ),
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
    );
  }

  Widget _buildProofFilterChip(String key, String label, {bool isAlert = false}) {
    final isSelected = _proofsFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() => _proofsFilter = key);
        _fetchPaymentProofs();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.royalBlue : (isAlert ? Colors.indigo.withOpacity(0.12) : AppTheme.borderLight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isAlert ? Colors.indigo : AppTheme.textMain),
          ),
        ),
      ),
    );
  }
}
