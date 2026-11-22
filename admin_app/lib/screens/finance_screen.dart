import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({Key? key}) : super(key: key);

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  // Overview
  bool _isLoadingOverview = true;
  Map<String, dynamic>? _overviewData;
  bool _isSendingReminder = false;

  // Fee Structures
  bool _isLoadingStructures = false;
  Map<String, dynamic>? _structuresData;
  List<dynamic> _classes = [];

  // Payroll
  bool _isLoadingPayroll = false;
  Map<String, dynamic>? _payrollOverview;
  List<dynamic> _payrollSlips = [];
  String _payrollStatus = 'all';
  int _payrollMonth = DateTime.now().month;
  int _payrollYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 1 && _structuresData == null) {
          _fetchFeeStructures();
        } else if (_tabController.index == 2 && _payrollOverview == null) {
          _fetchPayroll();
        }
      }
    });
    _fetchOverview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data fetching ────────────────────────────────────────────────────────────

  Future<void> _fetchOverview() async {
    setState(() => _isLoadingOverview = true);
    final res = await _api.getFinanceOverview();
    setState(() {
      _isLoadingOverview = false;
      if (res.success) _overviewData = res.data;
    });
  }

  Future<void> _fetchFeeStructures() async {
    setState(() => _isLoadingStructures = true);
    final results = await Future.wait([
      _api.getFeeStructures(),
      _api.getStudentClasses(),
    ]);
    setState(() {
      _isLoadingStructures = false;
      if (results[0].success) _structuresData = results[0].data as Map<String, dynamic>?;
      if (results[1].success) _classes = results[1].data as List<dynamic>;
    });
  }

  Future<void> _fetchPayroll() async {
    setState(() => _isLoadingPayroll = true);
    final results = await Future.wait([
      _api.getPayrollOverview(month: _payrollMonth, year: _payrollYear),
      _api.getPayrollSlips(
          month: _payrollMonth,
          year: _payrollYear,
          status: _payrollStatus != 'all' ? _payrollStatus : null),
    ]);
    setState(() {
      _isLoadingPayroll = false;
      if (results[0].success) _payrollOverview = results[0].data as Map<String, dynamic>?;
      if (results[1].success) _payrollSlips = results[1].data as List<dynamic>;
    });
  }

  Future<void> _sendBulkReminder() async {
    setState(() => _isSendingReminder = true);
    final res = await _api.sendFeeReminder(
      message:
          'Dear Parent, this is a gentle reminder to clear outstanding school fees at your earliest convenience.',
    );
    setState(() => _isSendingReminder = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
      ));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Finance & Cash Counter',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final idx = _tabController.index;
              if (idx == 0) _fetchOverview();
              if (idx == 1) _fetchFeeStructures();
              if (idx == 2) _fetchPayroll();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Fee Structures'),
            Tab(text: 'Payroll'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildFeeStructuresTab(),
          _buildPayrollTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Overview ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    if (_isLoadingOverview && _overviewData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = _overviewData?['summary'] ?? {};
    final recent =
        (_overviewData?['recent_payments'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _fetchOverview,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary banner
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
                  const Text('Total Month Collections',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    'NPR ${(summary['month_total'] ?? 0).toInt()}',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800),
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Today's Intake",
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            'NPR ${(summary['today_total'] ?? 0).toInt()}',
                            style: const TextStyle(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total Outstanding Dues',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            'NPR ${(summary['total_dues'] ?? 0).toInt()}',
                            style: const TextStyle(
                                color: Color(0xFFF87171),
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Remind button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSendingReminder ? null : _sendBulkReminder,
                icon: _isSendingReminder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.notifications_active, size: 18),
                label: const Text(
                    'Send Dues Reminders to Parents (Push/SMS)'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.crimson,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 24),

            // Recent transactions
            Text('Recent Fee Transactions',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              const Text('No recent receipts recorded.')
            else
              ...recent.map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle,
                            color: AppTheme.emerald, size: 20),
                      ),
                      title: Text(p['student_name'] ?? 'Student',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                          '${p['payment_method']} • ${p['created_at']}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                      trailing: Text(
                        '+ NPR ${(p['amount'] as num).toInt()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.emerald),
                      ),
                    ),
                  )),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ── Tab 2: Fee Structures ────────────────────────────────────────────────────

  Widget _buildFeeStructuresTab() {
    if (_isLoadingStructures) {
      return const Center(child: CircularProgressIndicator());
    }

    final structures =
        ((_structuresData?['data'] ?? _structuresData?['structures'])
                as List<dynamic>?) ??
            [];

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.royalBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Structure',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showCreateStructureSheet,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFeeStructures,
        child: structures.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.request_quote_outlined,
                            size: 56, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        Text('No fee structures defined yet.',
                            style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textMuted, fontSize: 15)),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap + New Structure to create tuition, transport, or hostel fee plans.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: structures.length,
                itemBuilder: (ctx, idx) {
                  final s = structures[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.royalBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: AppTheme.royalBlue, size: 20),
                      ),
                      title: Text(s['name'] ?? 'Fee Structure',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        '${s['fee_type'] ?? s['type'] ?? 'General'} • ${s['class_name'] ?? 'All Classes'}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'NPR ${(s['amount'] as num?)?.toInt() ?? 0}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.emerald),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded,
                                size: 18, color: AppTheme.crimson),
                            onPressed: () =>
                                _confirmDeleteStructure(s['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showCreateStructureSheet() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String feeType = 'Tuition';
    int? selectedClassId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: AppTheme.iosHandle()),
              const SizedBox(height: 16),
              Text('Create Fee Structure',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Structure Name',
                    hintText: 'e.g. Annual Tuition Fee Grade 10'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Amount (NPR)',
                    hintText: 'e.g. 45000'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: feeType,
                decoration: const InputDecoration(labelText: 'Fee Type'),
                items: ['Tuition', 'Transport', 'Hostel', 'Exam', 'Other']
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setS(() => feeType = val!),
              ),
              const SizedBox(height: 14),
              if (_classes.isNotEmpty)
                (() {
                  final uniqueClasses = <int, Map<String, dynamic>>{};
                  for (final c in _classes) {
                    if (c is Map && c['id'] != null) {
                      uniqueClasses[c['id'] as int] = Map<String, dynamic>.from(c);
                    }
                  }
                  final items = [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('All Classes')),
                    ...uniqueClasses.values.map((c) => DropdownMenuItem<int?>(
                          value: c['id'] as int?,
                          child: Text(c['class_name'] ?? 'Class'),
                        )),
                  ];
                  final safeVal = uniqueClasses.containsKey(selectedClassId) ? selectedClassId : null;

                  return DropdownButtonFormField<int?>(
                    value: safeVal,
                    decoration: const InputDecoration(
                        labelText: 'Applicable Class (optional)'),
                    items: items,
                    onChanged: (val) => setS(() => selectedClassId = val),
                  );
                })(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final amount =
                        double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (name.isEmpty || amount <= 0) return;
                    Navigator.pop(ctx);
                    final res = await _api.createFeeStructure({
                      'name': name,
                      'amount': amount,
                      'fee_type': feeType,
                      if (selectedClassId != null)
                        'class_id': selectedClassId,
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(res.message),
                        backgroundColor: res.success
                            ? AppTheme.emerald
                            : AppTheme.crimson,
                      ));
                      if (res.success) _fetchFeeStructures();
                    }
                  },
                  child: const Text('Create Fee Structure'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteStructure(dynamic id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Structure'),
        content: const Text(
            'Are you sure you want to delete this fee structure? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.deleteFeeStructure(id as int);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res.message),
                  backgroundColor:
                      res.success ? AppTheme.emerald : AppTheme.crimson,
                ));
                if (res.success) _fetchFeeStructures();
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Payroll ───────────────────────────────────────────────────────────

  Widget _buildPayrollTab() {
    if (_isLoadingPayroll) {
      return const Center(child: CircularProgressIndicator());
    }

    final overview = _payrollOverview ?? {};
    final slips = _payrollSlips;

    return RefreshIndicator(
      onRefresh: _fetchPayroll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Month / Year selector
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _payrollMonth,
                      isExpanded: true,
                      items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text([
                                'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                              ][i]))),
                      onChanged: (val) {
                        setState(() => _payrollMonth = val!);
                        _fetchPayroll();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _payrollYear,
                      isExpanded: true,
                      items: List.generate(
                          5,
                          (i) => DropdownMenuItem(
                              value: DateTime.now().year - 2 + i,
                              child: Text(
                                  '${DateTime.now().year - 2 + i}'))),
                      onChanged: (val) {
                        setState(() => _payrollYear = val!);
                        _fetchPayroll();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payroll overview card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.greenGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.emerald.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PayrollStat(
                  label: 'Total Payable',
                  value:
                      'NPR ${(overview['total_payable'] ?? 0).toInt()}',
                  color: Colors.white,
                ),
                Container(
                    width: 1, height: 40, color: Colors.white24),
                _PayrollStat(
                  label: 'Paid This Month',
                  value:
                      'NPR ${(overview['total_paid'] ?? 0).toInt()}',
                  color: const Color(0xFFBEF0DB),
                ),
                Container(
                    width: 1, height: 40, color: Colors.white24),
                _PayrollStat(
                  label: 'Pending',
                  value:
                      '${overview['pending_count'] ?? slips.where((s) => s['status'] == 'pending').length}',
                  color: AppTheme.gold,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Status filter
          Row(
            children: ['all', 'pending', 'paid'].map((s) {
              final selected = _payrollStatus == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s[0].toUpperCase() + s.substring(1)),
                  selected: selected,
                  selectedColor: AppTheme.royalBlue.withOpacity(0.15),
                  onSelected: (_) {
                    setState(() => _payrollStatus = s);
                    _fetchPayroll();
                  },
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.royalBlue : AppTheme.textMuted,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Salary slips list
          if (slips.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                  child: Text('No salary slips for the selected period.',
                      style: TextStyle(color: AppTheme.textMuted))),
            )
          else
            ...slips.map((slip) {
              final isPaid = slip['status'] == 'paid';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
                        child: Text(
                          (slip['name'] as String? ?? 'T')[0].toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.royalBlue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slip['name'] ?? 'Staff Member',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              slip['designation'] ?? slip['role'] ?? 'Teacher',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'NPR ${(slip['net_salary'] ?? slip['amount'] ?? 0).toInt()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textMain),
                          ),
                          const SizedBox(height: 4),
                          if (isPaid)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppTheme.emeraldLight,
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Text('PAID',
                                  style: TextStyle(
                                      color: AppTheme.emerald,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                            )
                          else
                            GestureDetector(
                              onTap: () =>
                                  _markSlipPaid(slip['id'], slip['type'] ?? 'teacher'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: AppTheme.goldLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: AppTheme.gold.withOpacity(0.4))),
                                child: const Text('MARK PAID',
                                    style: TextStyle(
                                        color: AppTheme.gold,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _markSlipPaid(dynamic id, String type) async {
    final res = await _api.markPayrollPaid(id as int, type,
        paymentMethod: 'cash',
        paymentDate: DateTime.now().toIso8601String().substring(0, 10));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
      ));
      if (res.success) _fetchPayroll();
    }
  }
}

class _PayrollStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PayrollStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}
