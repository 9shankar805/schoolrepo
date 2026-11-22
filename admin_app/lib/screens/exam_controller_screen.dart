import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ExamControllerScreen extends StatefulWidget {
  const ExamControllerScreen({Key? key}) : super(key: key);

  @override
  State<ExamControllerScreen> createState() => _ExamControllerScreenState();
}

class _ExamControllerScreenState extends State<ExamControllerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;

  // Tab 1: Marks Progress
  List<dynamic> _marksProgressList = [];
  Map<String, dynamic> _marksCounts = {};
  int? _selectedClassId;
  bool _marksWindowOpen = false;

  // Tab 2: Admit Cards
  List<dynamic> _admitCardsList = [];
  Map<String, dynamic> _admitCardCounts = {};
  String _admitSearchQuery = '';
  String _admitFilter = 'all'; // all, cleared, dues, locked

  // Tab 3: Results & Analytics
  bool _resultsPublished = false;
  Map<String, dynamic> _gradeDistribution = {};
  int _totalGradedSample = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchDashboard(),
      _fetchMarksProgress(),
      _fetchAdmitCards(),
      _fetchGradeDistribution(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDashboard() async {
    final res = await _api.getExamDashboard();
    if (res.success && res.data != null) {
      final summary = res.data!['summary'] ?? {};
      _dashboardData = res.data;
      _marksWindowOpen = summary['marks_window_open'] == true;
      _resultsPublished = summary['results_published'] == true;
    }
  }

  Future<void> _fetchMarksProgress() async {
    final res = await _api.getExamMarksProgress(classId: _selectedClassId);
    if (res.success && res.data != null) {
      _marksProgressList = res.data!['data'] ?? [];
      _marksCounts = res.data!['counts'] ?? {};
    }
  }

  Future<void> _fetchAdmitCards() async {
    final res = await _api.getExamAdmitCards(
      classId: _selectedClassId,
      search: _admitSearchQuery,
    );
    if (res.success && res.data != null) {
      _admitCardsList = res.data!['data'] ?? [];
      _admitCardCounts = res.data!['counts'] ?? {};
    }
  }

  Future<void> _fetchGradeDistribution() async {
    final res = await _api.getExamGradeDistribution();
    if (res.success && res.data != null) {
      _gradeDistribution = res.data!['distribution'] ?? {};
      _totalGradedSample = res.data!['total_sample'] ?? 0;
    }
  }

  // --- ACTIONS ---

  Future<void> _toggleMarksWindow(bool newStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          newStatus ? 'Open Marks Submission?' : 'Lock Marks Submission?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          newStatus
              ? 'Opening the submission window allows all subject teachers to enter and alter marks in their gradebooks.'
              : 'Locking will immediately freeze gradebooks. Teachers will no longer be able to modify student scores.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppTheme.royalBlue : AppTheme.crimson,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newStatus ? 'Open Window' : 'Freeze Marks'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _api.toggleExamMarksWindow(newStatus);
    if (res.success) {
      setState(() => _marksWindowOpen = newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: newStatus ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _toggleResultsPublication(bool newStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          newStatus ? 'Publish Results to Parents & Students?' : 'Withhold Terminal Results?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          newStatus
              ? 'This makes report cards, marks, and ranks instantly visible on the Parent and Student mobile applications.'
              : 'Results will be hidden from Parents and Students. Only administrative staff and teachers will have access.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppTheme.emerald : AppTheme.crimson,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newStatus ? 'Publish Live' : 'Withhold View'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _api.toggleExamResults(newStatus);
    if (res.success) {
      setState(() => _resultsPublished = newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: newStatus ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _sendNudge({int? teacherId, int? courseId, String? teacherName, String? courseName, String? message}) async {
    final controller = TextEditingController(
      text: message ?? 'Notice from Exam Controller: Marks for ${courseName ?? "pending subjects"} are pending submission. Please finalize your gradebook today.',
    );

    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Send Urgent Nudge',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipient: ${teacherName ?? "Subject Teacher"}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                labelText: 'Message Body',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dispatch Alert'),
          ),
        ],
      ),
    );

    if (send != true) return;

    final res = await _api.sendExamMarkReminder(
      teacherId: teacherId,
      courseId: courseId,
      message: controller.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
      ),
    );
  }

  Future<void> _toggleAdmitLock(Map<String, dynamic> student) async {
    final bool currentLock = student['is_locked'] == true;
    final int studentId = student['student_id'] ?? 0;
    final String name = student['name'] ?? 'Student';

    String? reason;
    if (!currentLock) {
      // Prompt for lock reason
      final reasonCtrl = TextEditingController(text: 'Administrative withholding / Fee dues pending');
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Withhold Admit Card for $name?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Lock Reason'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
              onPressed: () {
                reason = reasonCtrl.text;
                Navigator.pop(ctx, true);
              },
              child: const Text('Withhold Card'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final res = await _api.toggleAdmitCardLock(studentId, reason: reason);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: currentLock ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
      _fetchAdmitCards();
      _fetchDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  void _showAdmitCardPreview(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isLocked = student['is_locked'] == true;
        final feeCleared = student['fee_status'] == 'CLEARED';

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(
                'OFFICIAL ADMIT CARD & HALL PASS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppTheme.royalBlue,
                ),
              ),
              Text(
                _dashboardData?['summary']?['latest_exam_name'] ?? 'Terminal Examination 2026',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),

              // Digital Pass Ticket Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLocked ? AppTheme.roseLight : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLocked ? AppTheme.crimson.withOpacity(0.5) : AppTheme.borderLight,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: isLocked ? AppTheme.crimson : AppTheme.royalBlue,
                          child: Text(
                            (student['name'] ?? 'S')[0],
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'] ?? 'Student Name',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${student['class_name']} • Section ${student['section_name']} • Roll #${student['roll_number']}',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: feeCleared ? AppTheme.emeraldLight : AppTheme.amberLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      feeCleared ? 'FEE CLEARED' : 'PENDING DUES: NPR ${(student['due_balance'] ?? 0)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: feeCleared ? AppTheme.emerald : AppTheme.amber,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isLocked ? AppTheme.roseLight : AppTheme.emeraldLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isLocked ? 'WITHHELD' : 'AUTHORIZED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isLocked ? AppTheme.crimson : AppTheme.emerald,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isLocked) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Hall Entry Prohibited: ${student['lock_reason'] ?? "Cleared clearance required"}',
                          style: const TextStyle(color: AppTheme.crimson, fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const Divider(height: 28),
                    // Security Barcode & Seal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BARCODE AUTH', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              '||| || |||| | ||||| ${student['student_id']}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            Text('CONTROLLER OF EXAMINATIONS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                            Text('DIGITALLY SIGNED & VERIFIED', style: TextStyle(fontSize: 8, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(isLocked ? Icons.lock_open : Icons.block, size: 18),
                      label: Text(isLocked ? 'Grant Exception' : 'Withhold Pass'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isLocked ? AppTheme.emerald : AppTheme.crimson,
                        side: BorderSide(color: isLocked ? AppTheme.emerald : AppTheme.crimson),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _toggleAdmitLock(student);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Share PDF Pass'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Admit Card generated for ${student['name']}.'),
                            backgroundColor: AppTheme.royalBlue,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final summary = _dashboardData?['summary'] ?? {};
    final globalPct = (summary['global_progress_pct'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exam Controller Hub',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${auth.adminName} • ${summary['latest_exam_name'] ?? "Terminal Examination"}',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
            tooltip: 'Sync Examination Records',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.fact_check_outlined, size: 18), text: 'Marks Tracker'),
            Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Admit Cards'),
            Tab(icon: Icon(Icons.publish_outlined, size: 18), text: 'Results Release'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMarksProgressTab(globalPct),
                _buildAdmitCardsTab(),
                _buildResultsReleaseTab(),
              ],
            ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: MARKS SUBMISSION TRACKER
  // -------------------------------------------------------------
  Widget _buildMarksProgressTab(double globalPct) {
    final completed = _marksCounts['completed'] ?? 0;
    final inProgress = _marksCounts['in_progress'] ?? 0;
    final pending = _marksCounts['pending'] ?? 0;
    final total = _marksCounts['total'] ?? _marksProgressList.length;

    return RefreshIndicator(
      onRefresh: _fetchMarksProgress,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master Marks Submission Window Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _marksWindowOpen ? AppTheme.emerald.withOpacity(0.3) : AppTheme.crimson.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _marksWindowOpen ? AppTheme.emeraldLight : AppTheme.roseLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _marksWindowOpen ? Icons.lock_open : Icons.lock,
                    color: _marksWindowOpen ? AppTheme.emerald : AppTheme.crimson,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _marksWindowOpen ? 'Teacher Submission Window: OPEN' : 'Teacher Submission Window: LOCKED',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _marksWindowOpen ? AppTheme.emerald : AppTheme.crimson,
                        ),
                      ),
                      Text(
                        _marksWindowOpen
                            ? 'Teachers can freely input & edit student gradebooks.'
                            : 'Marks entry is frozen. Scores are locked against alteration.',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _marksWindowOpen,
                  activeColor: AppTheme.emerald,
                  onChanged: (val) => _toggleMarksWindow(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Global Marks Intake Pulse
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Terminal Marks Entry Status',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$globalPct% Done',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.royalBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (globalPct / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      globalPct >= 80 ? AppTheme.emerald : (globalPct >= 40 ? AppTheme.royalBlue : AppTheme.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildMiniCounter('Completed', '$completed', AppTheme.emerald, AppTheme.emeraldLight),
                    const SizedBox(width: 8),
                    _buildMiniCounter('In Progress', '$inProgress', AppTheme.amber, AppTheme.amberLight),
                    const SizedBox(width: 8),
                    _buildMiniCounter('Pending', '$pending', AppTheme.crimson, AppTheme.roseLight),
                    const SizedBox(width: 8),
                    _buildMiniCounter('Total Subjects', '$total', AppTheme.royalBlue, AppTheme.primaryLight),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Subject-wise Roster
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subject-wise Progress ($total)',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Nudge All Pending', style: TextStyle(fontSize: 12)),
                onPressed: pending > 0
                    ? () => _sendNudge(
                          message: 'Notice from Exam Controller: Please finalize marks entry immediately.',
                        )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_marksProgressList.isEmpty)
            _buildEmptyState('No assigned subjects found for this examination.')
          else
            ..._marksProgressList.map((item) {
              final pct = (item['progress_pct'] ?? 0).toDouble();
              final isDone = item['status'] == 'completed';
              final isProgress = item['status'] == 'in_progress';
              final teacherPhone = item['teacher_phone'];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['class_name']} • ${item['course_name']}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 13, color: AppTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    item['teacher_name'] ?? 'Unassigned',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                  if (teacherPhone != null && teacherPhone.toString().isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => launchUrl(Uri.parse('tel:$teacherPhone')),
                                      child: const Icon(Icons.phone_outlined, size: 13, color: AppTheme.royalBlue),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppTheme.emeraldLight
                                : (isProgress ? AppTheme.amberLight : AppTheme.roseLight),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isDone ? 'COMPLETED' : (isProgress ? 'IN PROGRESS' : 'NOT STARTED'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDone
                                  ? AppTheme.emerald
                                  : (isProgress ? AppTheme.amber : AppTheme.crimson),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item['marks_entered']} / ${item['total_students']} Students Graded',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDone ? AppTheme.emerald : AppTheme.textMain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDone ? AppTheme.emerald : (isProgress ? AppTheme.amber : AppTheme.crimson),
                        ),
                      ),
                    ),
                    if (!isDone) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            side: const BorderSide(color: AppTheme.royalBlue),
                          ),
                          icon: const Icon(Icons.send_outlined, size: 12, color: AppTheme.royalBlue),
                          label: const Text('Send Reminder Nudge', style: TextStyle(fontSize: 11, color: AppTheme.royalBlue)),
                          onPressed: () => _sendNudge(
                            teacherId: item['teacher_id'],
                            courseId: item['course_id'],
                            teacherName: item['teacher_name'],
                            courseName: '${item['class_name']} ${item['course_name']}',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: ADMIT CARDS & HALL PASS GATE
  // -------------------------------------------------------------
  Widget _buildAdmitCardsTab() {
    final total = _admitCardCounts['total'] ?? _admitCardsList.length;
    final cleared = _admitCardCounts['cleared'] ?? 0;
    final pendingDues = _admitCardCounts['pending_dues'] ?? 0;
    final locked = _admitCardCounts['locked'] ?? 0;

    List<dynamic> filtered = _admitCardsList;
    if (_admitFilter == 'cleared') {
      filtered = filtered.where((s) => s['fee_status'] == 'CLEARED').toList();
    } else if (_admitFilter == 'dues') {
      filtered = filtered.where((s) => s['fee_status'] == 'PENDING_DUES').toList();
    } else if (_admitFilter == 'locked') {
      filtered = filtered.where((s) => s['is_locked'] == true).toList();
    }

    return Column(
      children: [
        // Search & Filters Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by student name or roll number...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _admitSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() => _admitSearchQuery = '');
                            _fetchAdmitCards();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (val) {
                  setState(() => _admitSearchQuery = val);
                  _fetchAdmitCards();
                },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill('All Students ($total)', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Fee Cleared ($cleared)', 'cleared'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Pending Dues ($pendingDues)', 'dues'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Withheld / Locked ($locked)', 'locked'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Hall Pass Clearance List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAdmitCards,
            child: filtered.isEmpty
                ? _buildEmptyState('No students match the selected admit card criteria.')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final s = filtered[idx];
                      final isLocked = s['is_locked'] == true;
                      final isCleared = s['fee_status'] == 'CLEARED';
                      final dueBal = (s['due_balance'] ?? 0).toDouble();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isLocked ? AppTheme.crimson.withOpacity(0.4) : AppTheme.borderLight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isLocked ? AppTheme.roseLight : AppTheme.primaryLight,
                                  child: Text(
                                    (s['name'] ?? 'S')[0],
                                    style: TextStyle(
                                      color: isLocked ? AppTheme.crimson : AppTheme.royalBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['name'] ?? 'Student Name',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${s['class_name']} • Sec ${s['section_name']} • Roll #${s['roll_number']}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isCleared ? AppTheme.emeraldLight : AppTheme.amberLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isCleared ? 'CLEARED' : 'DUES: NPR ${dueBal.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isCleared ? AppTheme.emerald : AppTheme.amber,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isLocked ? 'WITHHELD' : 'AUTHORIZED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isLocked ? AppTheme.crimson : AppTheme.emerald,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (isLocked && s['lock_reason'] != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.roseLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Reason: ${s['lock_reason']}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.crimson),
                                ),
                              ),
                            ],
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                                  label: const Text('Preview Pass', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showAdmitCardPreview(s),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: isLocked ? AppTheme.emerald : AppTheme.crimson,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  icon: Icon(isLocked ? Icons.lock_open : Icons.block, size: 14),
                                  label: Text(
                                    isLocked ? 'Grant Pass' : 'Withhold',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => _toggleAdmitLock(s),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 3: RESULTS RELEASE & GRADE ANALYTICS
  // -------------------------------------------------------------
  Widget _buildResultsReleaseTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDashboard();
        await _fetchGradeDistribution();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master Results Visibility Switch Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _resultsPublished
                    ? [const Color(0xFF047857), const Color(0xFF065F46)]
                    : [const Color(0xFF991B1B), const Color(0xFF7F1D1D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_resultsPublished ? AppTheme.emerald : AppTheme.crimson).withOpacity(0.3),
                  blurRadius: 12,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _resultsPublished ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _resultsPublished ? 'RESULTS ARE LIVE' : 'RESULTS WITHHELD',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _resultsPublished,
                      activeColor: Colors.white,
                      activeTrackColor: AppTheme.emeraldLight,
                      inactiveTrackColor: Colors.black26,
                      onChanged: (val) => _toggleResultsPublication(val),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _resultsPublished
                      ? 'Terminal Results Published'
                      : 'Terminal Results Hidden from Parents',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _resultsPublished
                      ? 'Student report cards, marks, and GPA rankings are currently accessible on Parent and Student mobile apps.'
                      : 'Results are securely locked. Parents and students will not see any terminal grades until you release them.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Grade Distribution Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grade Distribution Analytics',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Text(
                'Sample: $_totalGradedSample marks',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Visual Histogram Curve
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score Brackets Frequency',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildGradeBar('A+', _gradeDistribution['A+'] ?? 0, AppTheme.emerald),
                    _buildGradeBar('A', _gradeDistribution['A'] ?? 0, const Color(0xFF10B981)),
                    _buildGradeBar('B+', _gradeDistribution['B+'] ?? 0, AppTheme.royalBlue),
                    _buildGradeBar('B', _gradeDistribution['B'] ?? 0, const Color(0xFF60A5FA)),
                    _buildGradeBar('C+', _gradeDistribution['C+'] ?? 0, AppTheme.amber),
                    _buildGradeBar('C', _gradeDistribution['C'] ?? 0, const Color(0xFFFBBF24)),
                    _buildGradeBar('D', _gradeDistribution['D'] ?? 0, const Color(0xFFFB923C)),
                    _buildGradeBar('F', _gradeDistribution['F'] ?? 0, AppTheme.crimson),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Grade Breakdown Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              _buildGradeStatCard('A+ (90-100%)', '${_gradeDistribution['A+'] ?? 0}', AppTheme.emerald),
              _buildGradeStatCard('A (80-89%)', '${_gradeDistribution['A'] ?? 0}', const Color(0xFF10B981)),
              _buildGradeStatCard('B+ (70-79%)', '${_gradeDistribution['B+'] ?? 0}', AppTheme.royalBlue),
              _buildGradeStatCard('B (60-69%)', '${_gradeDistribution['B'] ?? 0}', const Color(0xFF60A5FA)),
              _buildGradeStatCard('C+ (50-59%)', '${_gradeDistribution['C+'] ?? 0}', AppTheme.amber),
              _buildGradeStatCard('C (40-49%)', '${_gradeDistribution['C'] ?? 0}', const Color(0xFFFBBF24)),
              _buildGradeStatCard('D (35-39%)', '${_gradeDistribution['D'] ?? 0}', const Color(0xFFFB923C)),
              _buildGradeStatCard('F (<35%)', '${_gradeDistribution['F'] ?? 0}', AppTheme.crimson),
            ],
          ),
        ],
      ),
    );
  }

  // --- SUB WIDGET HELPERS ---

  Widget _buildMiniCounter(String label, String value, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, String value) {
    final isSelected = _admitFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _admitFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.royalBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildGradeBar(String grade, int count, Color color) {
    final maxSample = _totalGradedSample > 0 ? _totalGradedSample : 1;
    final pct = (count / maxSample).clamp(0.0, 1.0);
    final barHeight = 20.0 + (pct * 80.0);

    return Column(
      children: [
        Text(
          '$count',
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          grade,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildGradeStatCard(String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
