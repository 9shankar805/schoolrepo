import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class SyllabusHomeworkScreen extends StatefulWidget {
  const SyllabusHomeworkScreen({Key? key}) : super(key: key);

  @override
  State<SyllabusHomeworkScreen> createState() => _SyllabusHomeworkScreenState();
}

class _SyllabusHomeworkScreenState extends State<SyllabusHomeworkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  // Tab 1: Syllabus Progress State
  bool _syllabusLoading = true;
  int? _selectedClassId;
  String _syllabusSearch = '';
  List<dynamic> _syllabusList = [];
  Map<String, dynamic> _syllabusSummary = {};
  List<dynamic> _availableClasses = [];

  // Tab 2: Homework Radar State
  bool _homeworkLoading = true;
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _homeworkList = [];
  Map<String, dynamic> _homeworkSummary = {};
  List<dynamic> _classBreakdown = [];

  // Tab 3: Lesson Plan Verification State
  bool _lessonPlansLoading = true;
  String _lessonPlanStatusFilter = 'all'; // 'all', 'submitted', 'approved', 'needs_revision'
  List<dynamic> _lessonPlansList = [];
  Map<String, dynamic> _lessonPlanSummary = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSyllabusProgress(),
      _loadHomeworkRadar(),
      _loadLessonPlans(),
      _loadClasses(),
    ]);
  }

  Future<void> _loadClasses() async {
    final res = await _api.getClasses();
    if (res.success && res.data != null && mounted) {
      setState(() {
        _availableClasses = res.data!;
      });
    }
  }

  Future<void> _loadSyllabusProgress() async {
    setState(() => _syllabusLoading = true);
    final res = await _api.getSyllabusProgress(classId: _selectedClassId);
    if (mounted) {
      setState(() {
        _syllabusLoading = false;
        if (res.success && res.data != null) {
          _syllabusSummary = (res.data!['summary'] as Map<String, dynamic>?) ?? {};
          _syllabusList = (res.data!['data'] as List<dynamic>?) ?? [];
        } else {
          _syllabusList = [];
        }
      });
    }
  }

  Future<void> _loadHomeworkRadar() async {
    setState(() => _homeworkLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final res = await _api.getHomeworkRadar(date: dateStr);
    if (mounted) {
      setState(() {
        _homeworkLoading = false;
        if (res.success && res.data != null) {
          _homeworkSummary = (res.data!['summary'] as Map<String, dynamic>?) ?? {};
          _classBreakdown = (res.data!['class_breakdown'] as List<dynamic>?) ?? [];
          _homeworkList = (res.data!['data'] as List<dynamic>?) ?? [];
        } else {
          _homeworkList = [];
        }
      });
    }
  }

  Future<void> _loadLessonPlans() async {
    setState(() => _lessonPlansLoading = true);
    final res = await _api.getLessonPlans(status: _lessonPlanStatusFilter);
    if (mounted) {
      setState(() {
        _lessonPlansLoading = false;
        if (res.success && res.data != null) {
          _lessonPlanSummary = (res.data!['summary'] as Map<String, dynamic>?) ?? {};
          _lessonPlansList = (res.data!['data'] as List<dynamic>?) ?? [];
        } else {
          _lessonPlansList = [];
        }
      });
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI BUILD
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Academic Radar & Syllabus',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Data',
            onPressed: () {
              if (_tabController.index == 0) _loadSyllabusProgress();
              if (_tabController.index == 1) _loadHomeworkRadar();
              if (_tabController.index == 2) _loadLessonPlans();
            },
          ),
          if (_tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.add_task_rounded, color: AppTheme.royalBlue),
              tooltip: 'Dispatch Homework',
              onPressed: _showDispatchHomeworkSheet,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            const Tab(text: 'Syllabus Tracker'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Homework Radar'),
                  if ((_homeworkSummary['overload_alerts'] ?? 0) > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.crimson, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '${_homeworkSummary['overload_alerts']}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Lesson Plans'),
                  if ((_lessonPlanSummary['pending_approval'] ?? 0) > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.amber, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '${_lessonPlanSummary['pending_approval']}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
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
          _buildSyllabusTab(),
          _buildHomeworkRadarTab(),
          _buildLessonPlansTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
        heroTag: null,
              onPressed: _showDispatchHomeworkSheet,
              backgroundColor: AppTheme.royalBlue,
              icon: const Icon(Icons.add_task_rounded, color: Colors.white),
              label: Text(
                'Dispatch Homework',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            )
          : null,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: SYLLABUS PROGRESS TRACKER
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSyllabusTab() {
    if (_syllabusLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredList = _syllabusList.where((item) {
      if (_syllabusSearch.isEmpty) return true;
      final q = _syllabusSearch.toLowerCase();
      final cName = (item['course_name'] ?? '').toString().toLowerCase();
      final clsName = (item['class_name'] ?? '').toString().toLowerCase();
      return cName.contains(q) || clsName.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadSyllabusProgress,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI Metric Header
          Container(
            padding: const EdgeInsets.all(16),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Curriculum Coverage Velocity',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'Expected Pace: ${_syllabusSummary['expected_pace'] ?? 75}%',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPaceStat('On Track', '${_syllabusSummary['on_track'] ?? 0}', Colors.lightBlueAccent),
                    _buildPaceStat('Ahead', '${_syllabusSummary['ahead'] ?? 0}', Colors.greenAccent),
                    _buildPaceStat('Behind Pace', '${_syllabusSummary['behind_pace'] ?? 0}', Colors.orangeAccent),
                    _buildPaceStat('Total Subjects', '${_syllabusSummary['total_tracked'] ?? 0}', Colors.white70),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Class Filters & Search Bar
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
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search subject or grade...',
                      icon: Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _syllabusSearch = val.trim()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: DropdownButtonHideUnderline(
                  child: (() {
                    final uniqueClasses = <int, Map<String, dynamic>>{};
                    for (final cls in _availableClasses) {
                      if (cls is Map && cls['id'] != null) {
                        uniqueClasses[cls['id'] as int] = Map<String, dynamic>.from(cls);
                      }
                    }
                    final items = [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Grades', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      ...uniqueClasses.values.map((cls) => DropdownMenuItem<int?>(
                            value: cls['id'] as int?,
                            child: Text(cls['class_name'] ?? 'Class', style: const TextStyle(fontSize: 12)),
                          )),
                    ];
                    final safeVal = uniqueClasses.containsKey(_selectedClassId) ? _selectedClassId : null;

                    return DropdownButton<int?>(
                      value: safeVal,
                      hint: const Text('All Grades', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      items: items,
                      onChanged: (val) {
                        setState(() => _selectedClassId = val);
                        _loadSyllabusProgress();
                      },
                    );
                  })(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Course Syllabus Coverage Cards
          if (filteredList.isEmpty)
            _buildEmptyState('No syllabus records matching filter.')
          else
            ...filteredList.map((item) => _buildSyllabusItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildPaceStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildSyllabusItemCard(dynamic item) {
    final actual = (item['actual_progress'] as num?)?.toInt() ?? 0;
    final expected = (item['expected_pace'] as num?)?.toInt() ?? 75;
    final statusTag = item['status_tag']?.toString() ?? 'on_track';
    final completedUnits = item['completed_units'] ?? 0;
    final totalUnits = item['total_units'] ?? 24;

    Color badgeColor;
    IconData badgeIcon;
    String badgeLabel;

    if (statusTag == 'ahead') {
      badgeColor = AppTheme.emerald;
      badgeIcon = Icons.trending_up_rounded;
      badgeLabel = 'Ahead of Pace';
    } else if (statusTag == 'behind') {
      badgeColor = AppTheme.crimson;
      badgeIcon = Icons.warning_amber_rounded;
      badgeLabel = 'Behind Pace';
    } else {
      badgeColor = AppTheme.royalBlue;
      badgeIcon = Icons.check_circle_outline_rounded;
      badgeLabel = 'On Track';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['course_name'] ?? 'Subject',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Grade: ${item['class_name']} • Units: $completedUnits / $totalUnits Completed',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badgeColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar with Expected Marker
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (actual / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Actual: $actual% completed',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badgeColor),
              ),
              Text(
                'Expected Pace: $expected%',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: HOMEWORK LOAD MONITOR & RADAR
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHomeworkRadarTab() {
    if (_homeworkLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalAssignments = _homeworkSummary['total_assignments'] ?? 0;
    final overloadAlerts = _homeworkSummary['overload_alerts'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadHomeworkRadar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.royalBlue),
                  onPressed: () {
                    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                    _loadHomeworkRadar();
                  },
                ),
                InkWell(
                  onTap: _pickHomeworkDate,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.royalBlue),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.royalBlue),
                  onPressed: () {
                    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                    _loadHomeworkRadar();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Overload Alert Warning Banner
          if (overloadAlerts > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.roseLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.crimson.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.crimson.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.warning_rounded, color: AppTheme.crimson, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Homework Overload Detected!',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.crimson,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$overloadAlerts class has \u2265 3 assignments due on this date. Rebalance homework to prevent student burnout.',
                          style: const TextStyle(fontSize: 11, color: AppTheme.dark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Daily Homework Load Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetricCard(
                  'Total Due',
                  '$totalAssignments',
                  'Assignments today',
                  Icons.assignment_outlined,
                  AppTheme.royalBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMetricCard(
                  'Classes with HW',
                  '${_homeworkSummary['classes_with_hw'] ?? 0}',
                  'Active cohorts',
                  Icons.class_outlined,
                  AppTheme.emerald,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMetricCard(
                  'Overload Risk',
                  '$overloadAlerts',
                  'Heavy burden',
                  Icons.speed_rounded,
                  overloadAlerts > 0 ? AppTheme.crimson : AppTheme.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Class Breakdown Chips
          if (_classBreakdown.isNotEmpty) ...[
            Text(
              'COHORT LOAD BREAKDOWN',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _classBreakdown.map((b) {
                final isOverloaded = b['is_overloaded'] == true;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOverloaded ? AppTheme.roseLight : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isOverloaded ? AppTheme.crimson : AppTheme.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${b['class_section']}: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOverloaded ? AppTheme.crimson : AppTheme.dark,
                        ),
                      ),
                      Text(
                        '${b['count']} HW',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isOverloaded ? AppTheme.crimson : AppTheme.royalBlue,
                        ),
                      ),
                      if (isOverloaded) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.priority_high_rounded, size: 14, color: AppTheme.crimson),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Scheduled Assignments List
          Text(
            'SCHEDULED ASSIGNMENTS (${_homeworkList.length})',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),

          if (_homeworkList.isEmpty)
            _buildEmptyState('No homework assignments due on this date. Safe academic load.')
          else
            ..._homeworkList.map((hw) => _buildHomeworkCard(hw)),
        ],
      ),
    );
  }

  Widget _buildSummaryMetricCard(String title, String val, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            val,
            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.dark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(dynamic hw) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.royalBlue.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  hw['subject_name'] ?? 'General',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.royalBlue),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.emeraldLight, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${hw['total_marks'] ?? 10} Marks',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.emerald),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hw['title'] ?? 'Assignment',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            hw['description'] ?? '',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(hw['class_section'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(hw['teacher_name'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickHomeworkDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadHomeworkRadar();
    }
  }

  void _showDispatchHomeworkSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final marksCtrl = TextEditingController(text: '15');
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));
    int? selectedClass = _availableClasses.isNotEmpty ? _availableClasses.first['id'] as int? : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Dispatch Homework Assignment',
                  style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),

                // Class selector
                (() {
                  final uniqueClasses = <int, Map<String, dynamic>>{};
                  for (final cls in _availableClasses) {
                    if (cls is Map && cls['id'] != null) {
                      uniqueClasses[cls['id'] as int] = Map<String, dynamic>.from(cls);
                    }
                  }
                  final items = uniqueClasses.values.map((cls) {
                    return DropdownMenuItem<int?>(
                      value: cls['id'] as int?,
                      child: Text(cls['class_name'] ?? 'Class'),
                    );
                  }).toList();
                  final safeVal = uniqueClasses.containsKey(selectedClass) ? selectedClass : null;

                  return DropdownButtonFormField<int?>(
                    value: safeVal,
                    hint: const Text('Select Grade / Class'),
                    decoration: const InputDecoration(labelText: 'Target Grade / Class *', isDense: true),
                    items: items,
                    onChanged: (val) => setSheetState(() => selectedClass = val),
                  );
                })(),
                const SizedBox(height: 12),

                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Assignment Title *', hintText: 'e.g. Chapter 4 Numerical Problems'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Instructions & Workbook Pages *', hintText: 'Complete questions 1 to 15 on pages 45-47...'),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: marksCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Total Marks'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (d != null) setSheetState(() => dueDate = d);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Due Date', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              Text(DateFormat('MMM d, yyyy').format(dueDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.royalBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      if (selectedClass == null || titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
                        return;
                      }
                      Navigator.pop(ctx);
                      final res = await _api.createHomework({
                        'class_id': selectedClass,
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
                        'total_marks': int.tryParse(marksCtrl.text.trim()) ?? 15,
                      });

                      if (res.success) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Homework dispatched to student app!')));
                        _loadHomeworkRadar();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                      }
                    },
                    child: const Text('Dispatch Assignment Now', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 3: TEACHER LESSON PLAN VERIFICATION
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildLessonPlansTab() {
    if (_lessonPlansLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendingCount = _lessonPlanSummary['pending_approval'] ?? 0;
    final totalPlans = _lessonPlanSummary['total_plans'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadLessonPlans,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Review Queue Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: pendingCount > 0 ? [const Color(0xFF0D9488), const Color(0xFF0F766E)] : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.verified_rounded, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Faculty Lesson Plan Sign-Off',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pendingCount > 0 ? '$pendingCount weekly plans awaiting verification' : 'All submitted lesson plans verified',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPlanFilterChip('All Plans', 'all'),
                _buildPlanFilterChip('Pending Review', 'submitted'),
                _buildPlanFilterChip('Approved', 'approved'),
                _buildPlanFilterChip('Needs Revision', 'needs_revision'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_lessonPlansList.isEmpty)
            _buildEmptyState('No lesson plans in this category.')
          else
            ..._lessonPlansList.map((plan) => _buildLessonPlanCard(plan)),
        ],
      ),
    );
  }

  Widget _buildPlanFilterChip(String label, String statusKey) {
    final isSelected = _lessonPlanStatusFilter == statusKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : AppTheme.dark,
        ),
        selectedColor: AppTheme.royalBlue,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? AppTheme.royalBlue : AppTheme.borderLight),
        onSelected: (val) {
          setState(() => _lessonPlanStatusFilter = statusKey);
          _loadLessonPlans();
        },
      ),
    );
  }

  Widget _buildLessonPlanCard(dynamic plan) {
    final status = plan['status']?.toString() ?? 'submitted';
    final isPending = status == 'submitted';
    final isApproved = status == 'approved' || status == 'completed';

    Color statusColor;
    String statusLabel;
    if (isApproved) {
      statusColor = AppTheme.emerald;
      statusLabel = 'Approved & Signed';
    } else if (status == 'needs_revision') {
      statusColor = AppTheme.amber;
      statusLabel = 'Needs Revision';
    } else if (status == 'rejected') {
      statusColor = AppTheme.crimson;
      statusLabel = 'Rejected';
    } else {
      statusColor = AppTheme.royalBlue;
      statusLabel = 'Pending Review';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
                    child: const Icon(Icons.person, size: 18, color: AppTheme.royalBlue),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan['teacher_name'] ?? 'Faculty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${plan['subject_name']} • ${plan['class_section']}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ],
          ),
          const Divider(height: 18),

          Text(
            plan['title'] ?? 'Lesson Plan',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),

          if (plan['objectives'] != null && plan['objectives'].toString().isNotEmpty) ...[
            Text(
              'OBJECTIVES: ${plan['objectives']}',
              style: const TextStyle(fontSize: 12, color: AppTheme.dark, height: 1.3),
            ),
            const SizedBox(height: 6),
          ],

          if (plan['teaching_methods'] != null && plan['teaching_methods'].toString().isNotEmpty) ...[
            Text(
              'Methodology: ${plan['teaching_methods']}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Planned: ${plan['planned_date']} (${plan['duration_minutes']}m)',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPending ? AppTheme.royalBlue : Colors.grey.shade100,
                  foregroundColor: isPending ? Colors.white : AppTheme.dark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: Icon(isApproved ? Icons.check : Icons.rate_review_outlined, size: 14),
                label: Text(isPending ? 'Review & Sign' : 'Inspect Plan', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _showReviewPlanModal(plan),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReviewPlanModal(dynamic plan) {
    final remarksCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Executive Lesson Plan Verification',
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${plan['teacher_name']} • ${plan['subject_name']} (${plan['class_section']})',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Topic: ${plan['title']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('Objectives: ${plan['objectives'] ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('Content: ${plan['content'] ?? "N/A"}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Principal / Supervisor Endorsement Remarks',
                  hintText: 'e.g. Approved. Ensure hands-on experiment time.',
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.amber,
                        side: const BorderSide(color: AppTheme.amber),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _submitPlanVerification(plan['id'], 'needs_revision', remarksCtrl.text.trim());
                      },
                      child: const Text('Request Revision', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _submitPlanVerification(plan['id'], 'approved', remarksCtrl.text.trim());
                      },
                      child: const Text('Approve & Sign Off', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitPlanVerification(int planId, String status, String remarks) async {
    final res = await _api.verifyLessonPlan(planId, status: status, notes: remarks.isEmpty ? null : remarks);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
      _loadLessonPlans();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
