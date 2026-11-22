import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'staff_leave_management_screen.dart';

class StaffHrPayrollScreen extends StatefulWidget {
  const StaffHrPayrollScreen({Key? key}) : super(key: key);

  @override
  State<StaffHrPayrollScreen> createState() => _StaffHrPayrollScreenState();
}

class _StaffHrPayrollScreenState extends State<StaffHrPayrollScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  // Tab 1: Payroll State
  bool _payrollLoading = true;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _payrollStatus = 'all'; // 'all', 'paid', 'pending'
  String _payrollType = 'all';   // 'all', 'teacher', 'staff'
  final TextEditingController _payrollSearchCtrl = TextEditingController();

  Map<String, dynamic> _payrollKpis = {
    'total_gross': 0.0,
    'total_net': 0.0,
    'total_paid': 0.0,
    'total_pending': 0.0,
    'total_tds': 0.0,
    'total_deductions': 0.0,
    'total_staff_count': 0,
    'paid_count': 0,
    'pending_count': 0,
    'disbursed_percent': 0,
    'currency': 'NPR',
  };
  List<dynamic> _payrollSlips = [];

  // Tab 2: Contracts State
  bool _contractsLoading = true;
  String _contractStatus = 'all'; // 'all', 'expiring', 'probation', 'active', 'expired'
  final TextEditingController _contractSearchCtrl = TextEditingController();
  Map<String, dynamic> _contractAlerts = {
    'expiring_soon': 0,
    'in_probation': 0,
  };
  List<dynamic> _contracts = [];

  // Tab 3: Trainings State
  bool _trainingsLoading = true;
  final TextEditingController _trainingSearchCtrl = TextEditingController();
  Map<String, dynamic> _trainingSummary = {
    'total_trainings': 0,
    'completed': 0,
    'total_hours': 0,
  };
  List<dynamic> _trainings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadPayroll();
    _loadContracts();
    _loadTrainings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _payrollSearchCtrl.dispose();
    _contractSearchCtrl.dispose();
    _trainingSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPayroll() async {
    setState(() => _payrollLoading = true);
    final overviewRes = await _api.getPayrollOverview(month: _selectedMonth, year: _selectedYear);
    final slipsRes = await _api.getPayrollSlips(
      month: _selectedMonth,
      year: _selectedYear,
      status: _payrollStatus == 'all' ? null : _payrollStatus,
      type: _payrollType == 'all' ? null : _payrollType,
      search: _payrollSearchCtrl.text.trim().isEmpty ? null : _payrollSearchCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _payrollLoading = false;
        if (overviewRes.success && overviewRes.data != null) {
          _payrollKpis = (overviewRes.data!['kpis'] as Map<String, dynamic>?) ?? _payrollKpis;
        }
        if (slipsRes.success && slipsRes.data != null) {
          _payrollSlips = slipsRes.data ?? [];
        }
      });
    }
  }

  Future<void> _loadContracts() async {
    setState(() => _contractsLoading = true);
    final res = await _api.getStaffContracts(
      status: _contractStatus == 'all' ? null : _contractStatus,
      search: _contractSearchCtrl.text.trim().isEmpty ? null : _contractSearchCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _contractsLoading = false;
        if (res.success && res.data != null) {
          _contractAlerts = (res.data!['alerts'] as Map<String, dynamic>?) ?? _contractAlerts;
          _contracts = (res.data!['data'] as List<dynamic>?) ?? [];
        }
      });
    }
  }

  Future<void> _loadTrainings() async {
    setState(() => _trainingsLoading = true);
    final res = await _api.getStaffTrainings(
      search: _trainingSearchCtrl.text.trim().isEmpty ? null : _trainingSearchCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _trainingsLoading = false;
        if (res.success && res.data != null) {
          _trainingSummary = (res.data!['summary'] as Map<String, dynamic>?) ?? _trainingSummary;
          _trainings = (res.data!['data'] as List<dynamic>?) ?? [];
        }
      });
    }
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiringCount = (_contractAlerts['expiring_soon'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Staff HR & Payroll Overview',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.dark),
            ),
            Text(
              'Disbursement, Contracts, Probation & Training',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_busy_rounded, color: AppTheme.purple),
            tooltip: 'Staff Leave Center',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffLeaveManagementScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: () {
              _loadPayroll();
              _loadContracts();
              _loadTrainings();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            const Tab(text: 'Payroll & Slips'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Contracts & Alerts'),
                  if (expiringCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppTheme.crimson, borderRadius: BorderRadius.circular(10)),
                      child: Text('$expiringCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Training & Certs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPayrollTab(),
          _buildContractsTab(),
          _buildTrainingsTab(),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    if (_tabController.index == 1) {
      return FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.assignment_add, color: Colors.white),
        label: Text('New Contract', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
        onPressed: _showAddContractSheet,
      );
    } else if (_tabController.index == 2) {
      return FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.secondary,
        icon: const Icon(Icons.school_rounded, color: Colors.white),
        label: Text('Log Workshop', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
        onPressed: _showAddTrainingSheet,
      );
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: PAYROLL DISBURSEMENT & SLIPS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPayrollTab() {
    final double netTotal = (_payrollKpis['total_net'] as num?)?.toDouble() ?? 0.0;
    final double paidTotal = (_payrollKpis['total_paid'] as num?)?.toDouble() ?? 0.0;
    final double pendingTotal = (_payrollKpis['total_pending'] as num?)?.toDouble() ?? 0.0;
    final double tdsTotal = (_payrollKpis['total_tds'] as num?)?.toDouble() ?? 0.0;
    final int disbursedPercent = (_payrollKpis['disbursed_percent'] as int?) ?? 0;
    final int paidCount = (_payrollKpis['paid_count'] as int?) ?? 0;
    final int totalCount = (_payrollKpis['total_staff_count'] as int?) ?? 0;

    return RefreshIndicator(
      onRefresh: _loadPayroll,
      child: CustomScrollView(
        slivers: [
          // Month Selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                      onPressed: () {
                        setState(() {
                          if (_selectedMonth == 1) {
                            _selectedMonth = 12;
                            _selectedYear--;
                          } else {
                            _selectedMonth--;
                          }
                        });
                        _loadPayroll();
                      },
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth)),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.dark),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onPressed: () {
                        setState(() {
                          if (_selectedMonth == 12) {
                            _selectedMonth = 1;
                            _selectedYear++;
                          } else {
                            _selectedMonth++;
                          }
                        });
                        _loadPayroll();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Disbursement Telemetry Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E86DE), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF1E3A8A).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Monthly Net Payroll', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white70)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text('$paidCount of $totalCount Staff Paid', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'NPR ${NumberFormat('#,##,###').format(netTotal)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalCount > 0 ? (paidCount / totalCount) : 0.0,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.green),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPayrollMiniStat('Disbursed', 'NPR ${NumberFormat('#,##,###').format(paidTotal)}', AppTheme.green),
                        _buildPayrollMiniStat('Pending', 'NPR ${NumberFormat('#,##,###').format(pendingTotal)}', AppTheme.gold),
                        _buildPayrollMiniStat('TDS Withheld', 'NPR ${NumberFormat('#,##,###').format(tdsTotal)}', Colors.white70),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filters & Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                children: [
                  // Search
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: TextField(
                      controller: _payrollSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search staff name or account number...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.grey),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.grey, size: 20),
                        suffixIcon: _payrollSearchCtrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _payrollSearchCtrl.clear(); _loadPayroll(); })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _loadPayroll(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChoiceChip('All Slips', 'all', _payrollStatus, (v) { setState(() => _payrollStatus = v); _loadPayroll(); }),
                        const SizedBox(width: 6),
                        _buildChoiceChip('Pending Disbursement', 'pending', _payrollStatus, (v) { setState(() => _payrollStatus = v); _loadPayroll(); }),
                        const SizedBox(width: 6),
                        _buildChoiceChip('Paid', 'paid', _payrollStatus, (v) { setState(() => _payrollStatus = v); _loadPayroll(); }),
                        const SizedBox(width: 12),
                        const Text('|', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 12),
                        _buildChoiceChip('Teachers Only', 'teacher', _payrollType, (v) { setState(() => _payrollType = v); _loadPayroll(); }),
                        const SizedBox(width: 6),
                        _buildChoiceChip('Staff Only', 'staff', _payrollType, (v) { setState(() => _payrollType = v); _loadPayroll(); }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Slips List
          if (_payrollLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_payrollSlips.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 56, color: AppTheme.grey.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No Payroll Slips Found', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('No salary slip records generated for this period.', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _payrollSlips[index];
                    return _buildSalarySlipCard(item);
                  },
                  childCount: _payrollSlips.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPayrollMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildSalarySlipCard(dynamic item) {
    final int id = item['id'] ?? 0;
    final String type = item['type'] ?? 'staff';
    final String name = item['name'] ?? 'Staff Member';
    final String role = item['role_label'] ?? 'Employee';
    final String department = item['department'] ?? 'General';
    final double basic = (item['basic_salary'] as num?)?.toDouble() ?? 0.0;
    final double allowances = (item['allowances'] as num?)?.toDouble() ?? 0.0;
    final double gross = (item['gross_salary'] as num?)?.toDouble() ?? 0.0;
    final double tds = (item['tds_withheld'] as num?)?.toDouble() ?? 0.0;
    final double deductions = (item['total_deductions'] as num?)?.toDouble() ?? 0.0;
    final double net = (item['net_salary'] as num?)?.toDouble() ?? 0.0;
    final bool isPaid = (item['status'] ?? '').toString().toLowerCase() == 'paid';
    final String? phone = item['phone'];
    final String? pDate = item['payment_date'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.primary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.dark)),
                      Text('$role • $department', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? AppTheme.emerald.withOpacity(0.12) : AppTheme.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPaid ? 'PAID' : 'PENDING',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isPaid ? AppTheme.emerald : AppTheme.amber),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Basic: NPR ${NumberFormat('#,##,###').format(basic)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
                    Text('Allowances: NPR ${NumberFormat('#,##,###').format(allowances)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TDS Tax: NPR ${NumberFormat('#,##,###').format(tds)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.crimson)),
                    Text('Total Deductions: NPR ${NumberFormat('#,##,###').format(deductions)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.crimson)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Net Payout: ', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.dark)),
                    Text('NPR ${NumberFormat('#,##,###').format(net)}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                    const Spacer(),
                    if (!isPaid)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 14),
                        label: Text('Disburse', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700)),
                        onPressed: () => _confirmMarkPaid(id, type, name, net),
                      )
                    else if (pDate != null)
                      Text('Disbursed $pDate', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                    if (phone != null && phone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 18, color: AppTheme.primary),
                        onPressed: () => _makePhoneCall(phone),
                        tooltip: 'Call Employee',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmMarkPaid(int id, String type, String name, double amount) {
    String paymentMethod = 'bank_transfer';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Disburse Salary Slip', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm salary disbursement for $name:', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
              const SizedBox(height: 6),
              Text('Amount: NPR ${NumberFormat('#,##,###').format(amount)}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primary)),
              const SizedBox(height: 14),
              Text('Payment Channel:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                items: const [
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Direct Bank Transfer')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash Counter')),
                  DropdownMenuItem(value: 'cheque', child: Text('Bank Cheque')),
                  DropdownMenuItem(value: 'esewa', child: Text('eSewa Wallet')),
                  DropdownMenuItem(value: 'khalti', child: Text('Khalti Wallet')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => paymentMethod = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.markPayrollPaid(id, type, paymentMethod: paymentMethod);
                if (res.success) {
                  _loadPayroll();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salary disbursement confirmed!')));
                }
              },
              child: const Text('Confirm Disburse'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: STAFF CONTRACTS & PROBATION ALERTS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContractsTab() {
    final expiringSoon = (_contractAlerts['expiring_soon'] as int?) ?? 0;
    final inProbation = (_contractAlerts['in_probation'] as int?) ?? 0;

    return RefreshIndicator(
      onRefresh: _loadContracts,
      child: CustomScrollView(
        slivers: [
          // Expiry Alerts Banner
          if (expiringSoon > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.crimson.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$expiringSoon Contract(s) Expiring Within 30 Days',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.crimson),
                            ),
                            Text(
                              'Review staff employment terms or prepare contract renewals.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.dark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Filters & Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: TextField(
                      controller: _contractSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search staff name or position...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.grey),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.grey, size: 20),
                        suffixIcon: _contractSearchCtrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _contractSearchCtrl.clear(); _loadContracts(); })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _loadContracts(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChoiceChip('All Contracts', 'all', _contractStatus, (v) { setState(() => _contractStatus = v); _loadContracts(); }),
                        const SizedBox(width: 6),
                        _buildChoiceChip('Expiring Soon', 'expiring', _contractStatus, (v) { setState(() => _contractStatus = v); _loadContracts(); }, badge: expiringSoon > 0 ? '$expiringSoon' : null),
                        const SizedBox(width: 6),
                        _buildChoiceChip('In Probation', 'probation', _contractStatus, (v) { setState(() => _contractStatus = v); _loadContracts(); }, badge: inProbation > 0 ? '$inProbation' : null),
                        const SizedBox(width: 6),
                        _buildChoiceChip('Active', 'active', _contractStatus, (v) { setState(() => _contractStatus = v); _loadContracts(); }),
                        const SizedBox(width: 6),
                        _buildChoiceChip('Expired', 'expired', _contractStatus, (v) { setState(() => _contractStatus = v); _loadContracts(); }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contracts List
          if (_contractsLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_contracts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 56, color: AppTheme.grey.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No Contracts Found', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Tap "+ New Contract" to register a contract.', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _contracts[index];
                    return _buildContractCard(item);
                  },
                  childCount: _contracts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContractCard(dynamic item) {
    final String name = item['name'] ?? 'Employee';
    final String role = item['role_label'] ?? 'Staff';
    final String position = item['position'] ?? 'Position';
    final String contractType = item['contract_type'] ?? 'Permanent';
    final double salary = (item['salary'] as num?)?.toDouble() ?? 0.0;
    final String startDate = item['start_date'] ?? 'N/A';
    final String endDate = item['end_date'] ?? 'Indefinite';
    final bool isExpiring = (item['is_expiring'] as bool?) ?? false;
    final bool isExpired = (item['is_expired'] as bool?) ?? false;
    final bool isProbation = (item['is_probation'] as bool?) ?? false;
    final int? daysLeft = item['days_left'] as int?;
    final String? phone = item['phone'];

    Color statusColor = AppTheme.emerald;
    String statusTag = 'ACTIVE';
    if (isExpired) {
      statusColor = AppTheme.crimson;
      statusTag = 'EXPIRED';
    } else if (isExpiring) {
      statusColor = AppTheme.amber;
      statusTag = 'EXPIRES IN $daysLeft DAYS';
    } else if (isProbation) {
      statusColor = AppTheme.blue;
      statusTag = 'PROBATION';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpiring || isExpired ? statusColor.withOpacity(0.4) : Colors.grey.shade200, width: isExpiring ? 1.5 : 1.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'E', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: statusColor)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.dark)),
                      Text('$position • $role', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusTag, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Type & Salary', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.grey)),
                    Text('$contractType • NPR ${NumberFormat('#,##,###').format(salary)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.dark)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Contract Period', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.grey)),
                    Text('$startDate - $endDate', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.dark)),
                  ]),
                ],
              ),
            ),
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 14, color: AppTheme.primary),
                  label: Text('Contact Employee', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  onPressed: () => _makePhoneCall(phone),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3: STAFF TRAINING & CERTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTrainingsTab() {
    final int totalTrainings = (_trainingSummary['total_trainings'] as int?) ?? 0;
    final int completed = (_trainingSummary['completed'] as int?) ?? 0;
    final int hours = (_trainingSummary['total_hours'] as int?) ?? 0;

    return RefreshIndicator(
      onRefresh: _loadTrainings,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Workshops Logged', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                        Text('$totalTrainings', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Total PD Hours', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                        Text('$hours hrs', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.secondary)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_trainingsLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_trainings.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium_outlined, size: 56, color: AppTheme.grey.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No Faculty Workshops Logged', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Track professional development sessions by tapping "Log Workshop".', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _trainings[index];
                    return _buildTrainingCard(item);
                  },
                  childCount: _trainings.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrainingCard(dynamic item) {
    final String staffName = item['staff_name'] ?? 'Faculty';
    final String title = item['title'] ?? 'Training';
    final String type = item['type'] ?? 'Workshop';
    final String provider = item['provider'] ?? 'Education Board';
    final int hours = item['duration_hours'] ?? 8;
    final String startDate = item['start_date'] ?? 'N/A';
    final bool isCompleted = (item['is_completed'] as bool?) ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.dark)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.emerald.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(isCompleted ? 'COMPLETED' : 'IN PROGRESS', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.emerald)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Attendee: $staffName • Type: $type', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.apartment_rounded, size: 13, color: AppTheme.grey),
                const SizedBox(width: 4),
                Text(provider, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                const Spacer(),
                Text('$hours Hours • $startDate', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add Contract Sheet
  void _showAddContractSheet() {
    int? selectedUserId;
    String? selectedUserName;
    String contractType = 'Permanent';
    final TextEditingController positionCtrl = TextEditingController(text: 'Senior Faculty');
    final TextEditingController salaryCtrl = TextEditingController(text: '35000');
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 365));
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('New Staff Employment Contract', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                // Teacher / Staff picker via Search
                Text('Employee User ID *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: 'Enter staff/teacher user ID (e.g. 1, 2, 5)...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => selectedUserId = int.tryParse(val),
                ),
                const SizedBox(height: 12),
                Text('Contract Type', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: contractType,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  items: const [
                    DropdownMenuItem(value: 'Permanent', child: Text('Permanent')),
                    DropdownMenuItem(value: 'Probation', child: Text('Probation (3-6 Months)')),
                    DropdownMenuItem(value: 'Contract', child: Text('Annual Contract')),
                    DropdownMenuItem(value: 'Visiting', child: Text('Visiting Faculty')),
                  ],
                  onChanged: (v) { if (v != null) setModalState(() => contractType = v); },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Position / Title', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(controller: positionCtrl, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Salary (NPR)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(controller: salaryCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isSaving ? null : () async {
                      if (selectedUserId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an employee ID')));
                        return;
                      }
                      setModalState(() => isSaving = true);
                      final res = await _api.createStaffContract({
                        'user_id': selectedUserId,
                        'contract_type': contractType,
                        'position': positionCtrl.text.trim(),
                        'salary': double.tryParse(salaryCtrl.text) ?? 30000,
                        'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                        'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                      });
                      setModalState(() => isSaving = false);
                      if (res.success) {
                        Navigator.pop(ctx);
                        _loadContracts();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract registered successfully!')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                      }
                    },
                    child: Text(isSaving ? 'Registering...' : 'Register Contract', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add Training Sheet
  void _showAddTrainingSheet() {
    int? selectedUserId;
    final TextEditingController titleCtrl = TextEditingController();
    String type = 'Workshop';
    final TextEditingController providerCtrl = TextEditingController(text: 'Education Board Nepal');
    final TextEditingController hoursCtrl = TextEditingController(text: '8');
    DateTime startDate = DateTime.now();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Log Professional Development Workshop', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Text('Faculty / Staff User ID *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextFormField(
                  decoration: InputDecoration(hintText: 'Enter staff/teacher user ID (e.g. 1, 2, 5)...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => selectedUserId = int.tryParse(val),
                ),
                const SizedBox(height: 12),
                Text('Workshop Title *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(controller: titleCtrl, decoration: InputDecoration(hintText: 'e.g. Modern Pedagogy & STEM Integration', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Provider', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(controller: providerCtrl, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Duration (Hours)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(controller: hoursCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isSaving ? null : () async {
                      if (selectedUserId == null || titleCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete required fields')));
                        return;
                      }
                      setModalState(() => isSaving = true);
                      final res = await _api.createStaffTraining({
                        'user_id': selectedUserId,
                        'title': titleCtrl.text.trim(),
                        'type': type,
                        'provider': providerCtrl.text.trim(),
                        'duration_hours': int.tryParse(hoursCtrl.text) ?? 8,
                        'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                        'is_completed': true,
                      });
                      setModalState(() => isSaving = false);
                      if (res.success) {
                        Navigator.pop(ctx);
                        _loadTrainings();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Training workshop logged!')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                      }
                    },
                    child: Text(isSaving ? 'Logging...' : 'Log Workshop Record', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value, String selectedValue, ValueChanged<String> onSelected, {String? badge}) {
    final isSel = selectedValue == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badge != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: isSel ? Colors.white : AppTheme.crimson, borderRadius: BorderRadius.circular(8)),
              child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isSel ? AppTheme.primary : Colors.white)),
            ),
          ],
        ],
      ),
      selected: isSel,
      selectedColor: AppTheme.primary,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.dark),
      onSelected: (_) => onSelected(value),
    );
  }
}
