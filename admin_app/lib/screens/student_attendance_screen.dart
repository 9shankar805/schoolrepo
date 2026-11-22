import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/common_widgets.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final int? initialClassId;
  final int? initialSectionId;
  final String? initialClassName;
  final String? initialSectionName;

  const StudentAttendanceScreen({
    super.key,
    this.initialClassId,
    this.initialSectionId,
    this.initialClassName,
    this.initialSectionName,
  });

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  // Date state
  DateTime _selectedDate = DateTime.now();

  // View state: 0 = Campus Overview, 1 = Class Roll Call
  int _activeTab = 0;

  // Overview data
  bool _loadingOverview = false;
  Map<String, dynamic>? _overviewKpis;
  List<Map<String, dynamic>> _overviewClasses = [];

  // Sheet (Roll Call) data
  bool _loadingSheet = false;
  bool _isSaving = false;
  int? _selectedClassId;
  int? _selectedSectionId;
  String _selectedClassName = '';
  String _selectedSectionName = '';
  String? _recordedBy;
  String? _takenTime;
  bool _isMarked = false;

  // Local student attendance state
  List<Map<String, dynamic>> _students = [];
  String _statusFilter = 'all'; // all, present, late, absent, unmarked
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialClassId != null && widget.initialSectionId != null) {
      _selectedClassId = widget.initialClassId;
      _selectedSectionId = widget.initialSectionId;
      _selectedClassName = widget.initialClassName ?? 'Class';
      _selectedSectionName = widget.initialSectionName ?? 'Section';
      _activeTab = 1;
      _loadSheet();
    } else {
      _loadOverview();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _displayDate => DateFormat('EEE, MMM d, yyyy').format(_selectedDate);

  // ---------------------------------------------------------------------------
  // API LOADERS
  // ---------------------------------------------------------------------------

  Future<void> _loadOverview() async {
    setState(() => _loadingOverview = true);
    final res = await _api.getAttendanceOverview(date: _formattedDate);
    if (!mounted) return;

    if (res.success && res.data != null) {
      final kpis = res.data!['kpis'] is Map
          ? Map<String, dynamic>.from(res.data!['kpis'] as Map)
          : <String, dynamic>{};
      final rawClasses = (res.data!['classes'] as List<dynamic>? ?? [])
          .map((c) => c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{})
          .toList();

      setState(() {
        _overviewKpis = kpis;
        _overviewClasses = rawClasses;
        _loadingOverview = false;

        // Auto-select first class & section if none selected
        if (_selectedClassId == null && rawClasses.isNotEmpty) {
          final firstCls = rawClasses.first;
          final sections = (firstCls['sections'] as List<dynamic>? ?? []);
          if (sections.isNotEmpty) {
            _selectedClassId = firstCls['class_id'];
            _selectedClassName = firstCls['class_name'] ?? 'Class';
            _selectedSectionId = sections.first['section_id'];
            _selectedSectionName = sections.first['section_name'] ?? 'A';
          }
        }
      });
    } else {
      setState(() => _loadingOverview = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _loadSheet() async {
    if (_selectedClassId == null || _selectedSectionId == null) return;
    setState(() => _loadingSheet = true);

    final res = await _api.getAttendanceSheet(
      classId: _selectedClassId!,
      sectionId: _selectedSectionId!,
      date: _formattedDate,
    );
    if (!mounted) return;

    if (res.success && res.data != null) {
      final data = res.data!;
      final rawStudents = (data['students'] as List<dynamic>? ?? [])
          .map((s) => s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{})
          .toList();

      setState(() {
        _students = rawStudents;
        _recordedBy = data['recorded_by'];
        _takenTime = data['taken_time'];
        _isMarked = data['is_marked'] == true;
        _loadingSheet = false;
      });
    } else {
      setState(() => _loadingSheet = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIONS: MARKING & SAVING
  // ---------------------------------------------------------------------------

  void _updateStudentStatus(int studentId, String status, {int? lateMinutes}) {
    setState(() {
      for (var s in _students) {
        if (s['id'] == studentId) {
          s['status'] = status;
          if (status == 'late') {
            s['late_minutes'] = lateMinutes ?? (s['late_minutes'] != null && s['late_minutes'] > 0 ? s['late_minutes'] : 15);
          } else {
            s['late_minutes'] = 0;
          }
          break;
        }
      }
    });
  }

  void _bulkMarkLocal(String status) {
    setState(() {
      for (var s in _students) {
        s['status'] = status;
        if (status != 'late') {
          s['late_minutes'] = 0;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'present'
              ? 'All marked Present. Tap "Save Attendance" to confirm.'
              : 'All marked Absent. Tap "Save Attendance" to confirm.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _quickMarkApi(String status) async {
    if (_selectedClassId == null || _selectedSectionId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Bulk ${status.toUpperCase()}'),
        content: Text(
          'Are you sure you want to instantly record all students in '
          '$_selectedClassName - Section $_selectedSectionName as ${status.toUpperCase()} in the database?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'present' ? AppTheme.emerald : AppTheme.crimson,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Mark All ${status.toUpperCase()}', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    final res = await _api.quickMarkAttendance(
      classId: _selectedClassId!,
      sectionId: _selectedSectionId!,
      date: _formattedDate,
      status: status,
    );
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.emerald,
        ),
      );
      _loadSheet();
      _loadOverview();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedClassId == null || _selectedSectionId == null || _students.isEmpty) return;

    final records = _students.map((s) {
      final status = (s['status'] ?? 'unmarked').toString();
      return {
        'student_id': s['id'],
        'status': status == 'unmarked' ? 'present' : status,
        'late_minutes': s['late_minutes'] ?? 0,
      };
    }).toList();

    setState(() => _isSaving = true);
    final res = await _api.saveAttendance(
      classId: _selectedClassId!,
      sectionId: _selectedSectionId!,
      date: _formattedDate,
      attendance: records,
    );
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isMarked = true;
        _takenTime = DateFormat('hh:mm a').format(DateTime.now());
      });
      _loadOverview();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.crimson,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.royalBlue,
              onPrimary: Colors.white,
              onSurface: AppTheme.dark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      if (_activeTab == 0) {
        _loadOverview();
      } else {
        _loadSheet();
      }
    }
  }

  void _shiftDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    if (_activeTab == 0) {
      _loadOverview();
    } else {
      _loadSheet();
    }
  }

  void _showLateMinutesDialog(Map<String, dynamic> student) {
    int minutes = student['late_minutes'] is int && student['late_minutes'] > 0
        ? student['late_minutes']
        : 15;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.access_time_filled_rounded, color: AppTheme.amber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mark as Late: ${student['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          Text(
                            'Roll #${student['roll_no'] ?? '-'} • Class $_selectedClassName',
                            style: const TextStyle(fontSize: 12, color: AppTheme.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Select Arrival Delay (Minutes):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [5, 10, 15, 20, 30, 45, 60].map((m) {
                    final isSel = minutes == m;
                    return ChoiceChip(
                      label: Text('$m mins'),
                      selected: isSel,
                      selectedColor: AppTheme.amber,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : (isDark ? Colors.white : AppTheme.dark),
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setModalState(() => minutes = m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.amber,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          _updateStudentStatus(student['id'], 'late', lateMinutes: minutes);
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Confirm Late',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD METHOD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, isDark),
            _buildDateBar(isDark),
            _buildViewTabBar(isDark),
            Expanded(
              child: _activeTab == 0
                  ? _buildCampusOverviewView(isDark)
                  : _buildRollCallView(isDark),
            ),
            if (_activeTab == 1 && _students.isNotEmpty)
              _buildFloatingSaveBar(isDark),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR & CONTROLS
  // ---------------------------------------------------------------------------

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 38,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Attendance (हाजिरी)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.dark,
                  ),
                ),
                const Text(
                  'Daily Roll Call & Headcount Tracking',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppTheme.royalBlue,
            onPressed: () {
              if (_activeTab == 0) {
                _loadOverview();
              } else {
                _loadSheet();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateBar(bool isDark) {
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == _formattedDate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: () => _shiftDate(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.royalBlue),
                    const SizedBox(width: 8),
                    Text(
                      _displayDate,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppTheme.dark,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            onPressed: () => _shiftDate(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'Campus Overview',
              icon: Icons.pie_chart_rounded,
              isSelected: _activeTab == 0,
              onTap: () {
                setState(() => _activeTab = 0);
                _loadOverview();
              },
            ),
          ),
          Expanded(
            child: _TabButton(
              title: 'Class Roll Call',
              icon: Icons.checklist_rounded,
              isSelected: _activeTab == 1,
              onTap: () {
                setState(() => _activeTab = 1);
                if (_students.isEmpty && _selectedClassId != null && _selectedSectionId != null) {
                  _loadSheet();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 0: CAMPUS OVERVIEW
  // ---------------------------------------------------------------------------

  Widget _buildCampusOverviewView(bool isDark) {
    if (_loadingOverview && _overviewClasses.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.royalBlue));
    }

    final kpis = _overviewKpis ?? {};
    final total = kpis['total_students'] ?? 0;
    final present = kpis['present'] ?? 0;
    final late = kpis['late'] ?? 0;
    final absent = kpis['absent'] ?? 0;
    final unmarked = kpis['unmarked'] ?? 0;
    final rate = kpis['attendance_rate'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Hero Card
            GradientCard(
              colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              padding: const EdgeInsets.all(18),
              radius: 20,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All Campus Attendance',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$total Enrolled Students',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$rate% Rate',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _kpiItem('Present', '$present', Colors.greenAccent),
                        _kpiDivider(),
                        _kpiItem('Late', '$late', Colors.amberAccent),
                        _kpiDivider(),
                        _kpiItem('Absent', '$absent', Colors.redAccent),
                        _kpiDivider(),
                        _kpiItem('Unmarked', '$unmarked', Colors.white70),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader(title: 'Classes & Sections Breakdown'),
                Text(
                  '${_overviewClasses.length} Grades',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_overviewClasses.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                alignment: Alignment.center,
                child: const Text('No active classes found for this session.', style: TextStyle(color: AppTheme.grey)),
              )
            else
              ..._overviewClasses.map((cls) => _buildClassBreakdownCard(cls, isDark)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _kpiItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _kpiDivider() {
    return Container(width: 1, height: 24, color: Colors.white.withOpacity(0.2));
  }

  Widget _buildClassBreakdownCard(Map<String, dynamic> cls, bool isDark) {
    final className = cls['class_name'] ?? 'Class';
    final classId = cls['class_id'];
    final sections = (cls['sections'] as List<dynamic>? ?? [])
        .map((s) => s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{})
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          className,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: isDark ? Colors.white : AppTheme.dark,
          ),
        ),
        subtitle: Text(
          '${sections.length} Section(s)',
          style: const TextStyle(fontSize: 11, color: AppTheme.grey),
        ),
        children: sections.map((sec) {
          final isMarked = sec['is_marked'] == true;
          final secName = sec['section_name'] ?? 'A';
          final secId = sec['section_id'];
          final total = sec['total'] ?? 0;
          final present = sec['present'] ?? 0;
          final absent = sec['absent'] ?? 0;
          final rate = sec['rate'] ?? 0;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedClassId = classId;
                _selectedClassName = className;
                _selectedSectionId = secId;
                _selectedSectionName = secName;
                _activeTab = 1;
              });
              _loadSheet();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFF3F4F6),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isMarked ? AppTheme.emerald : AppTheme.royalBlue).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      secName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isMarked ? AppTheme.emerald : AppTheme.royalBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Section $secName',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            if (sec['room_no'] != null && sec['room_no'].toString().isNotEmpty)
                              Text(
                                '• Rm ${sec['room_no']}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$present Present • $absent Absent • Total $total',
                          style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMarked
                              ? AppTheme.emerald.withOpacity(0.12)
                              : AppTheme.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isMarked ? 'Taken ($rate%)' : 'Pending',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isMarked ? AppTheme.emerald : AppTheme.amber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Row(
                        children: [
                          Text('Open Sheet', style: TextStyle(fontSize: 10, color: AppTheme.royalBlue, fontWeight: FontWeight.w700)),
                          Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppTheme.royalBlue),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: CLASS ROLL CALL VIEW
  // ---------------------------------------------------------------------------

  Widget _buildRollCallView(bool isDark) {
    return Column(
      children: [
        // Class & Section Selector Pill Bar
        _buildClassSectionSelectorBar(isDark),

        // Quick KPI & Recorder Info
        _buildSheetHeaderInfo(isDark),

        // Quick Bulk Actions Bar & Filters
        _buildQuickActionBar(isDark),

        // Search Bar
        _buildSearchField(isDark),

        // Students Roll Call List
        Expanded(
          child: _loadingSheet
              ? const Center(child: CircularProgressIndicator(color: AppTheme.royalBlue))
              : _buildStudentsList(isDark),
        ),
      ],
    );
  }

  Widget _buildClassSectionSelectorBar(bool isDark) {
    if (_overviewClasses.isEmpty && !_loadingOverview) {
      _loadOverview();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonHideUnderline(
              child: (() {
                final uniqueClasses = <int, Map<String, dynamic>>{};
                for (final cls in _overviewClasses) {
                  final id = cls['class_id'] as int?;
                  if (id != null && !uniqueClasses.containsKey(id)) {
                    uniqueClasses[id] = Map<String, dynamic>.from(cls);
                  }
                }
                final items = uniqueClasses.values.map((cls) {
                  return DropdownMenuItem<int>(
                    value: cls['class_id'],
                    child: Text(
                      cls['class_name'] ?? 'Class',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppTheme.dark,
                      ),
                    ),
                  );
                }).toList();
                final safeValue = uniqueClasses.containsKey(_selectedClassId)
                    ? _selectedClassId
                    : (uniqueClasses.isNotEmpty ? uniqueClasses.keys.first : null);

                return DropdownButton<int>(
                  value: safeValue,
                  isExpanded: true,
                  hint: const Text('Select Class', style: TextStyle(fontSize: 13)),
                  items: items,
                  onChanged: (newClassId) {
                    if (newClassId == null) return;
                    final cls = _overviewClasses.firstWhere((c) => c['class_id'] == newClassId);
                    final sections = (cls['sections'] as List<dynamic>? ?? []);
                    setState(() {
                      _selectedClassId = newClassId;
                      _selectedClassName = cls['class_name'] ?? 'Class';
                      if (sections.isNotEmpty) {
                        _selectedSectionId = sections.first['section_id'];
                        _selectedSectionName = sections.first['section_name'] ?? 'A';
                      } else {
                        _selectedSectionId = null;
                        _selectedSectionName = '';
                      }
                    });
                    _loadSheet();
                  },
                );
              })(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: (() {
                final currentClass = _overviewClasses.firstWhere(
                  (c) => c['class_id'] == _selectedClassId,
                  orElse: () => {'sections': []},
                );
                final rawSections = (currentClass['sections'] as List<dynamic>? ?? []);
                final uniqueSections = <int, Map<String, dynamic>>{};
                for (final s in rawSections) {
                  if (s is Map && s['section_id'] != null) {
                    uniqueSections[s['section_id'] as int] = Map<String, dynamic>.from(s);
                  }
                }
                final items = uniqueSections.values.map((sMap) {
                  return DropdownMenuItem<int>(
                    value: sMap['section_id'],
                    child: Text(
                      'Sec ${sMap['section_name']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppTheme.dark,
                      ),
                    ),
                  );
                }).toList();
                final safeValue = uniqueSections.containsKey(_selectedSectionId)
                    ? _selectedSectionId
                    : (uniqueSections.isNotEmpty ? uniqueSections.keys.first : null);

                return DropdownButton<int>(
                  value: safeValue,
                  isExpanded: true,
                  hint: const Text('Section', style: TextStyle(fontSize: 13)),
                  items: items,
                  onChanged: (newSecId) {
                    if (newSecId == null) return;
                    final cls = _overviewClasses.firstWhere((c) => c['class_id'] == _selectedClassId);
                    final sections = (cls['sections'] as List<dynamic>? ?? []);
                    final target = sections.firstWhere((s) => s['section_id'] == newSecId, orElse: () => {});
                    setState(() {
                      _selectedSectionId = newSecId;
                      _selectedSectionName = target['section_name'] ?? 'A';
                    });
                    _loadSheet();
                  },
                );
              })(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHeaderInfo(bool isDark) {
    final total = _students.length;
    final present = _students.where((s) => s['status'] == 'present' || s['status'] == 'late').length;
    final late = _students.where((s) => s['status'] == 'late').length;
    final absent = _students.where((s) => s['status'] == 'absent').length;
    final unmarked = _students.where((s) => s['status'] == 'unmarked').length;
    final rate = total > 0 ? ((present / total) * 100).toStringAsFixed(1) : '0';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isMarked ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    color: _isMarked ? AppTheme.emerald : AppTheme.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isMarked
                        ? 'Recorded: ${_takenTime ?? 'Today'}${_recordedBy != null ? ' by $_recordedBy' : ''}'
                        : 'Unsaved / Ready to Take Roll Call',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _isMarked ? AppTheme.emerald : AppTheme.amber,
                    ),
                  ),
                ],
              ),
              Text(
                '$rate% Rate',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.royalBlue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statChip('Total', '$total', AppTheme.royalBlue),
              _statChip('Present', '$present', AppTheme.emerald),
              _statChip('Late', '$late', AppTheme.amber),
              _statChip('Absent', '$absent', AppTheme.crimson),
              _statChip('Unmarked', '$unmarked', AppTheme.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildQuickActionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // Bulk Mark Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('All Present', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _bulkMarkLocal('present'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.crimson),
                  label: const Text('All Absent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.crimson)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.crimson),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _bulkMarkLocal('absent'),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppTheme.royalBlue),
                tooltip: 'Server Bulk Mark',
                onSelected: (val) {
                  if (val == 'instant_present') _quickMarkApi('present');
                  if (val == 'instant_absent') _quickMarkApi('absent');
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'instant_present',
                    child: Text('Instant Server Mark: All Present', style: TextStyle(fontSize: 12)),
                  ),
                  const PopupMenuItem(
                    value: 'instant_absent',
                    child: Text('Instant Server Mark: All Absent', style: TextStyle(fontSize: 12, color: AppTheme.crimson)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'All (${_students.length})'),
                _filterChip('present', 'Present (${_students.where((s) => s['status'] == 'present').length})'),
                _filterChip('late', 'Late (${_students.where((s) => s['status'] == 'late').length})'),
                _filterChip('absent', 'Absent (${_students.where((s) => s['status'] == 'absent').length})'),
                _filterChip('unmarked', 'Unmarked (${_students.where((s) => s['status'] == 'unmarked').length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _statusFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.royalBlue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.grey,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _statusFilter = filterKey),
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 38,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search by student name or roll number...',
          hintStyle: const TextStyle(fontSize: 12, color: AppTheme.grey),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsList(bool isDark) {
    final filtered = _students.where((s) {
      if (_statusFilter != 'all') {
        if (_statusFilter == 'present' && s['status'] != 'present') return false;
        if (_statusFilter == 'late' && s['status'] != 'late') return false;
        if (_statusFilter == 'absent' && s['status'] != 'absent') return false;
        if (_statusFilter == 'unmarked' && s['status'] != 'unmarked') return false;
      }
      if (_searchQuery.isNotEmpty) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final roll = (s['roll_no'] ?? '').toString().toLowerCase();
        final adm = (s['admission_no'] ?? '').toString().toLowerCase();
        if (!name.contains(_searchQuery) && !roll.contains(_searchQuery) && !adm.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.grey),
            const SizedBox(height: 12),
            Text(
              _students.isEmpty ? 'No enrolled students found.' : 'No students match filter.',
              style: const TextStyle(color: AppTheme.grey, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (ctx, idx) {
        final s = filtered[idx];
        return _buildStudentRollCard(s, isDark);
      },
    );
  }

  Widget _buildStudentRollCard(Map<String, dynamic> s, bool isDark) {
    final studentId = s['id'];
    final status = s['status'] ?? 'unmarked';
    final rollNo = s['roll_no'] ?? '-';
    final name = s['name'] ?? 'Student';
    final admissionNo = s['admission_no'] ?? '-';
    final lateMins = s['late_minutes'] ?? 0;
    final photoUrl = s['photo_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColorForStatus(status, isDark),
          width: status == 'unmarked' ? 1 : 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Roll No Badge & Photo
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.royalBlue.withOpacity(0.12),
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.royalBlue,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.royalBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$rollNo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppTheme.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Adm #$admissionNo ${s['phone'] != null ? '• ${s['phone']}' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                    ),
                  ],
                ),
              ),

              // Current Status Pill
              if (status == 'late')
                GestureDetector(
                  onTap: () => _showLateMinutesDialog(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.amber),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled, size: 12, color: AppTheme.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${lateMins}m Late',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Status Action Buttons
          Row(
            children: [
              Expanded(
                child: _statusButton(
                  label: 'Present',
                  symbol: 'P',
                  isSelected: status == 'present',
                  activeColor: AppTheme.emerald,
                  onTap: () => _updateStudentStatus(studentId, 'present'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statusButton(
                  label: 'Late',
                  symbol: 'L',
                  isSelected: status == 'late',
                  activeColor: AppTheme.amber,
                  onTap: () => _showLateMinutesDialog(s),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statusButton(
                  label: 'Absent',
                  symbol: 'A',
                  isSelected: status == 'absent',
                  activeColor: AppTheme.crimson,
                  onTap: () => _updateStudentStatus(studentId, 'absent'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statusButton(
                  label: 'Leave',
                  symbol: 'H',
                  isSelected: status == 'half_day' || status == 'leave',
                  activeColor: AppTheme.purple,
                  onTap: () => _updateStudentStatus(studentId, 'half_day'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _borderColorForStatus(String status, bool isDark) {
    switch (status) {
      case 'present':
        return AppTheme.emerald.withOpacity(0.4);
      case 'late':
        return AppTheme.amber.withOpacity(0.5);
      case 'absent':
        return AppTheme.crimson.withOpacity(0.5);
      case 'half_day':
      case 'leave':
        return AppTheme.purple.withOpacity(0.4);
      default:
        return isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7);
    }
  }

  Widget _statusButton({
    required String label,
    required String symbol,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : activeColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : activeColor.withOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              symbol,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: isSelected ? Colors.white : activeColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                color: isSelected ? Colors.white : activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingSaveBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_selectedClassName - Sec $_selectedSectionName',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Text(
                    '${_students.length} Total Students',
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Attendance',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              onPressed: _isSaving ? null : _saveAttendance,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.royalBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.grey,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppTheme.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
