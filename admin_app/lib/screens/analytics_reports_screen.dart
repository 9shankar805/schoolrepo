import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoadingOverview = true;
  bool _isLoadingReport = false;

  // Overview Data
  Map<String, dynamic>? _overviewData;

  // Report Generator Filter States
  String _selectedReportType = 'student_attendance'; // student_attendance, staff_attendance, finance, academics
  String _datePreset = 'this_month'; // today, this_week, this_month, custom
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();

  int? _selectedClassId;
  int? _selectedSectionId;
  int? _selectedExamId;
  String _selectedPaymentMethod = 'all';

  // Options
  List<dynamic> _classes = [];
  List<dynamic> _exams = [];
  List<dynamic> _paymentMethods = [];

  // Active Report Result
  Map<String, dynamic>? _reportResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOverviewAndOptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOverviewAndOptions() async {
    setState(() => _isLoadingOverview = true);
    final results = await Future.wait([
      _api.getAnalyticsOverview(),
      _api.getReportOptions(),
    ]);

    if (!mounted) return;

    final ovRes = results[0];
    final optRes = results[1];

    setState(() {
      _isLoadingOverview = false;
      if (ovRes.success && ovRes.data != null) {
        _overviewData = ovRes.data;
      }
      if (optRes.success && optRes.data != null) {
        _classes = (optRes.data!['classes'] as List<dynamic>?) ?? [];
        _exams = (optRes.data!['exams'] as List<dynamic>?) ?? [];
        _paymentMethods = (optRes.data!['payment_methods'] as List<dynamic>?) ?? [];
      }
    });

    // Run default report
    _runReportQuery();
  }

  Future<void> _runReportQuery() async {
    setState(() => _isLoadingReport = true);
    final dateFromStr = _dateFrom.toIso8601String().substring(0, 10);
    final dateToStr = _dateTo.toIso8601String().substring(0, 10);

    ApiResponse<Map<String, dynamic>> res;

    if (_selectedReportType == 'student_attendance') {
      res = await _api.getAttendanceReport(
        dateFrom: dateFromStr,
        dateTo: dateToStr,
        classId: _selectedClassId,
        sectionId: _selectedSectionId,
        type: 'students',
      );
    } else if (_selectedReportType == 'staff_attendance') {
      res = await _api.getAttendanceReport(
        dateFrom: dateFromStr,
        dateTo: dateToStr,
        type: 'staff',
      );
    } else if (_selectedReportType == 'finance') {
      res = await _api.getFinanceReport(
        dateFrom: dateFromStr,
        dateTo: dateToStr,
        paymentMethod: _selectedPaymentMethod,
      );
    } else {
      res = await _api.getAcademicsReport(
        examId: _selectedExamId,
        classId: _selectedClassId,
        sectionId: _selectedSectionId,
      );
    }

    if (!mounted) return;

    setState(() {
      _isLoadingReport = false;
      if (res.success && res.data != null) {
        _reportResult = res.data;
      } else {
        _reportResult = null;
      }
    });
  }

  Future<void> _exportActiveReport() async {
    final res = await _api.exportReport({
      'report_type': _selectedReportType,
      'date_from': _dateFrom.toIso8601String().substring(0, 10),
      'date_to': _dateTo.toIso8601String().substring(0, 10),
      'class_id': _selectedClassId,
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.royalBlue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.print_rounded, color: AppTheme.royalBlue),
              ),
              const SizedBox(width: 12),
              Text(
                'Report Export Ready',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Official summary statement prepared for "${res.data?['export_title'] ?? 'Institutional Report'}".',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Institution', res.data?['institution'] ?? 'School Hub'),
                    _buildModalRow('IEMIS Code', res.data?['iemis_code'] ?? '-'),
                    _buildModalRow('Generated At', res.data?['generated_at'] ?? ''),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Share Summary'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Executive summary statement copied to clipboard.')),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted)),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
    );

    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
        _datePreset = 'custom';
      });
      _runReportQuery();
    }
  }

  void _setDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _datePreset = preset;
      if (preset == 'today') {
        _dateFrom = DateTime(now.year, now.month, now.day);
        _dateTo = now;
      } else if (preset == 'this_week') {
        _dateFrom = now.subtract(Duration(days: now.weekday - 1));
        _dateTo = now;
      } else if (preset == 'this_month') {
        _dateFrom = DateTime(now.year, now.month, 1);
        _dateTo = now;
      }
    });
    _runReportQuery();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Analytics & Reports Studio',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.royalBlue),
            tooltip: 'Refresh Analytics',
            onPressed: _loadOverviewAndOptions,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Executive Insights'),
            Tab(text: 'Report Query Studio'),
            Tab(text: 'Rankings & Standing'),
          ],
        ),
      ),
      body: _isLoadingOverview
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildReportStudioTab(),
                _buildRankingsTab(),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Executive Overview & Visual Insights
  // ---------------------------------------------------------------------------
  Widget _buildOverviewTab() {
    final data = _overviewData;
    if (data == null) {
      return const Center(child: Text('No analytics data available.'));
    }

    final students = data['students'] as Map<String, dynamic>? ?? {};
    final staff = data['staff'] as Map<String, dynamic>? ?? {};
    final attendance = data['attendance'] as Map<String, dynamic>? ?? {};
    final finance = data['finance'] as Map<String, dynamic>? ?? {};
    final academics = data['academics'] as Map<String, dynamic>? ?? {};
    final weeklyTrend = (attendance['weekly_trend'] as List<dynamic>?) ?? [];
    final classAttendance = (attendance['by_class'] as List<dynamic>?) ?? [];
    final paymentMethods = (finance['payment_methods'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadOverviewAndOptions,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: High Level Velocity Cards
            _buildVelocityRow(students, staff, attendance, finance),
            const SizedBox(height: 16),

            // 7-Day Attendance Trend Chart
            _buildAttendanceTrendCard(weeklyTrend),
            const SizedBox(height: 16),

            // Financial & Collection Progress
            _buildFinanceOverviewCard(finance, paymentMethods),
            const SizedBox(height: 16),

            // Academic Grade Standing
            _buildAcademicOverviewCard(academics),
            const SizedBox(height: 16),

            // Today's Class-wise Attendance
            _buildClassAttendanceList(classAttendance),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVelocityRow(
    Map<String, dynamic> students,
    Map<String, dynamic> staff,
    Map<String, dynamic> attendance,
    Map<String, dynamic> finance,
  ) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final itemWidth = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildMetricCard(
            title: 'Today Student Attendance',
            value: '${attendance['today_pct'] ?? 0}%',
            subtitle: '${attendance['present'] ?? 0} Present • ${attendance['absent'] ?? 0} Absent',
            icon: Icons.how_to_reg_rounded,
            color: AppTheme.emerald,
            width: itemWidth,
          ),
          _buildMetricCard(
            title: 'Staff On Duty Today',
            value: '${staff['attendance_pct_today'] ?? 0}%',
            subtitle: '${staff['on_leave_today'] ?? 0} On Leave • ${staff['teachers'] ?? 0} Faculty',
            icon: Icons.badge_rounded,
            color: AppTheme.purple,
            width: itemWidth,
          ),
          _buildMetricCard(
            title: 'YTD Fee Collections',
            value: 'Rs. ${(finance['ytd_collected'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
            subtitle: '${finance['collection_rate'] ?? 0}% Collection Efficiency',
            icon: Icons.account_balance_wallet_rounded,
            color: AppTheme.royalBlue,
            width: itemWidth,
          ),
          _buildMetricCard(
            title: 'Active Enrollment',
            value: '${students['total'] ?? 0}',
            subtitle: '${students['male'] ?? 0} Boys • ${students['female'] ?? 0} Girls',
            icon: Icons.school_rounded,
            color: AppTheme.amber,
            width: itemWidth,
          ),
        ],
      );
    });
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTrendCard(List<dynamic> trend) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '7-Day Attendance Velocity',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendDot(AppTheme.royalBlue, 'Students'),
                  const SizedBox(width: 8),
                  _buildLegendDot(AppTheme.purple, 'Staff'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (trend.isEmpty)
            const Center(child: Text('No attendance trend records'))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: trend.map((t) {
                final sPct = (t['student_pct'] as num?)?.toDouble() ?? 0.0;
                final stPct = (t['staff_pct'] as num?)?.toDouble() ?? 0.0;
                final day = t['day'] ?? '';

                return Column(
                  children: [
                    Text(
                      '${sPct.toInt()}%',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.royalBlue),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Student Bar
                        Container(
                          width: 14,
                          height: (sPct * 0.9).clamp(6.0, 90.0),
                          decoration: BoxDecoration(
                            color: AppTheme.royalBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Staff Bar
                        Container(
                          width: 14,
                          height: (stPct * 0.9).clamp(6.0, 90.0),
                          decoration: BoxDecoration(
                            color: AppTheme.purple,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      day,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildFinanceOverviewCard(Map<String, dynamic> finance, List<dynamic> paymentMethods) {
    final dues = (finance['outstanding_dues'] as num?)?.toDouble() ?? 0.0;
    final collected = (finance['ytd_collected'] as num?)?.toDouble() ?? 0.0;
    final rate = (finance['collection_rate'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Financial Performance & Collections',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.royalBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Fiscal YTD',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.royalBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Collection Efficiency Target', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted)),
              Text('$rate%', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.emerald)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Collected', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        'Rs. ${collected.toInt()}',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.emerald),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outstanding Dues', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        'Rs. ${dues.toInt()}',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.crimson),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (paymentMethods.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Payment Gateways Breakdown', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: paymentMethods.map((pm) {
                return Chip(
                  backgroundColor: AppTheme.background,
                  padding: const EdgeInsets.all(4),
                  label: Text(
                    '${pm['method']}: Rs. ${(pm['amount'] as num?)?.toInt() ?? 0}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcademicOverviewCard(Map<String, dynamic> academics) {
    final avgMarks = (academics['average_marks'] as num?)?.toDouble() ?? 0.0;
    final grade = academics['grade'] ?? '—';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.royalBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                grade,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: AppTheme.royalBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Institutional Academic Standing',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Average score across all marked classes: $avgMarks%',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassAttendanceList(List<dynamic> classAttendance) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Class-wise Attendance",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (classAttendance.isEmpty)
            const Text('No class records available.')
          else
            ...classAttendance.take(6).map((c) {
              final rate = (c['rate'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        c['class_name'] ?? 'Class',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (rate / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            rate > 80 ? AppTheme.emerald : (rate > 60 ? AppTheme.amber : AppTheme.crimson),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${rate.toInt()}%',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: Interactive Report Query Studio
  // ---------------------------------------------------------------------------
  Widget _buildReportStudioTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Query Control Hub Card
          _buildQueryControlCard(),
          const SizedBox(height: 16),

          // Report Results Section
          if (_isLoadingReport)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_reportResult == null)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: const Center(child: Text('No report data returned for these parameters.')),
            )
          else
            _buildReportResultsView(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildQueryControlCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Report Query Parameters',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              IconButton(
                icon: const Icon(Icons.print_rounded, color: AppTheme.royalBlue),
                tooltip: 'Export Report',
                onPressed: _exportActiveReport,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Report Type Selector
          Text('Report Domain', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedReportType,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: 'student_attendance', child: Text('Student Attendance & Truancy')),
              DropdownMenuItem(value: 'staff_attendance',   child: Text('Staff & Faculty Attendance')),
              DropdownMenuItem(value: 'finance',            child: Text('Fee Collection & Outstanding Dues')),
              DropdownMenuItem(value: 'academics',          child: Text('Exam Performance & Marks Standing')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedReportType = val);
                _runReportQuery();
              }
            },
          ),
          const SizedBox(height: 14),

          // Date presets
          Text('Timeline Scope', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip('today', 'Today'),
                const SizedBox(width: 6),
                _buildPresetChip('this_week', 'This Week'),
                const SizedBox(width: 6),
                _buildPresetChip('this_month', 'This Month'),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_rounded, size: 14),
                  label: const Text('Custom'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _datePreset == 'custom' ? AppTheme.royalBlue : AppTheme.textMuted,
                    side: BorderSide(color: _datePreset == 'custom' ? AppTheme.royalBlue : AppTheme.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: _pickDateRange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Class filter (when applicable)
          if (_selectedReportType != 'staff_attendance') ...[
            Text('Grade / Class Filter', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            (() {
              final uniqueClasses = <int, Map<String, dynamic>>{};
              for (final c in _classes) {
                if (c is Map && c['id'] != null) {
                  uniqueClasses[c['id'] as int] = Map<String, dynamic>.from(c);
                }
              }
              final items = [
                const DropdownMenuItem<int?>(value: null, child: Text('All Classes (Whole School)')),
                ...uniqueClasses.values.map<DropdownMenuItem<int?>>((c) {
                  return DropdownMenuItem<int?>(
                    value: c['id'] as int?,
                    child: Text(c['class_name'] ?? 'Class'),
                  );
                }),
              ];
              final safeVal = uniqueClasses.containsKey(_selectedClassId) ? _selectedClassId : null;

              return DropdownButtonFormField<int?>(
                value: safeVal,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: items,
                onChanged: (val) {
                  setState(() => _selectedClassId = val);
                  _runReportQuery();
                },
              );
            })(),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetChip(String key, String label) {
    final active = _datePreset == key;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (val) {
        if (val) _setDatePreset(key);
      },
      selectedColor: AppTheme.royalBlue,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        color: active ? Colors.white : AppTheme.textPrimary,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: active ? AppTheme.royalBlue : AppTheme.glassBorder),
      ),
    );
  }

  Widget _buildReportResultsView() {
    final res = _reportResult!;
    final summary = res['summary'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary KPI Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.royalBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.royalBlue.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      summary['report_type'] ?? 'Report Summary',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.royalBlue),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${summary['date_from'] ?? ''}  →  ${summary['date_to'] ?? ''}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Divider(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: summary.entries
                    .where((e) => !['report_type', 'date_from', 'date_to'].contains(e.key))
                    .map((e) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ucwords(e.key.replaceAll('_', ' ')),
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      Text(
                        '${e.value}',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Domain specific details
        if (_selectedReportType == 'student_attendance' || _selectedReportType == 'staff_attendance')
          _buildAttendanceDetailReport(res)
        else if (_selectedReportType == 'finance')
          _buildFinanceDetailReport(res)
        else
          _buildAcademicsDetailReport(res),
      ],
    );
  }

  Widget _buildAttendanceDetailReport(Map<String, dynamic> res) {
    final chronic = (res['chronic_absentees'] as List<dynamic>?) ?? [];
    final byClass = (res['by_class'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chronic.isNotEmpty) ...[
          Text('Chronic Absentee Radar (≥2 Absences)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          ...chronic.take(5).map((ca) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.crimson.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ca['student_name'] ?? ca['name'] ?? 'Person', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('${ca['class_name'] ?? 'Class'} • ${ca['absent_count']} days missed', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
        ],

        if (byClass.isNotEmpty) ...[
          Text('Class Aggregates in Selected Scope', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          ...byClass.map((bc) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bc['class_name'] ?? 'Class',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${bc['rate']}% (${bc['present']} / ${bc['total']})', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.royalBlue, fontSize: 12)),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildFinanceDetailReport(Map<String, dynamic> res) {
    final outstanding = (res['outstanding_invoices'] as List<dynamic>?) ?? [];
    final transactions = (res['transactions'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (outstanding.isNotEmpty) ...[
          Text('Highest Outstanding Dues', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          ...outstanding.take(6).map((inv) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.crimson.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv['student_name'] ?? 'Student',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${inv['title']} • Due: ${inv['due_date']}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rs. ${(inv['amount'] as num?)?.toInt() ?? 0}',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.crimson),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
        ],

        if (transactions.isNotEmpty) ...[
          Text('Recent Payment Receipts', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          ...transactions.take(8).map((tx) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx['student_name'] ?? 'Student',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${tx['receipt_no']} • ${tx['payment_method']}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Rs. ${(tx['amount'] as num?)?.toInt() ?? 0}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.emerald, fontSize: 13)),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildAcademicsDetailReport(Map<String, dynamic> res) {
    final grades = res['grades'] as Map<String, dynamic>? ?? {};
    final topRankers = (res['top_rankers'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grade Frequency Distribution', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: grades.entries.map((g) {
              return Column(
                children: [
                  Text(g.key, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.royalBlue)),
                  const SizedBox(height: 4),
                  Text('${g.value}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        if (topRankers.isNotEmpty) ...[
          Text('Academic Honor Roll (Top Performers)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          ...topRankers.take(5).map((tr) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(color: AppTheme.amber, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        '${topRankers.indexOf(tr) + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr['student_name'] ?? 'Student', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('${tr['class_name']} • Roll #${tr['roll_no']}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  Text(
                    '${tr['average']}% (${tr['grade']})',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.royalBlue),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Performance Rankings & Institutional Standing
  // ---------------------------------------------------------------------------
  Widget _buildRankingsTab() {
    final data = _overviewData;
    if (data == null) {
      return const Center(child: Text('No ranking data available.'));
    }

    final academics = data['academics'] as Map<String, dynamic>? ?? {};
    final classPerf = (academics['class_performance'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Class Academic Leaderboard',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.emoji_events_rounded, color: AppTheme.amber),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ranked by average percentage across all marked exam subjects.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                if (classPerf.isEmpty)
                  const Text('No class marks evaluated yet.')
                else
                  ...classPerf.map((cp) {
                    final rank = classPerf.indexOf(cp) + 1;
                    Color badgeColor;
                    if (rank == 1) badgeColor = const Color(0xFFFFD700);
                    else if (rank == 2) badgeColor = const Color(0xFFC0C0C0);
                    else if (rank == 3) badgeColor = const Color(0xFFCD7F32);
                    else badgeColor = AppTheme.royalBlue.withOpacity(0.15);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                '$rank',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  color: rank <= 3 ? Colors.white : AppTheme.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              cp['class_name'] ?? 'Class',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                          Text(
                            '${cp['avg_marks']}% Avg',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.royalBlue, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Institutional Health & Capacity
          _buildHealthCapacityCard(data),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHealthCapacityCard(Map<String, dynamic> data) {
    final students = data['students'] as Map<String, dynamic>? ?? {};
    final staff = data['staff'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Faculty-Student Ratio & Staffing',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Teacher-Student Ratio', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text('1 : ${students['student_teacher_ratio'] ?? '0'}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.royalBlue)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Admissions (Month)', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text('+${students['new_this_month'] ?? '0'} students', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.emerald)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String ucwords(String str) {
    return str.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }
}
