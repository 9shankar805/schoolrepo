import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'routine_maker_screen.dart';
import 'student_promotion_screen.dart';

class AcademicsScreen extends StatefulWidget {
  const AcademicsScreen({Key? key}) : super(key: key);

  @override
  State<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends State<AcademicsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isLoadingRoutines = false;

  List<dynamic> _classes = [];
  List<dynamic> _routines = [];
  List<dynamic> _exams = [];
  bool _resultsPublished = true;
  bool _isToggling = false;

  // Timetable filter states
  int? _selectedRoutineClassId;
  int? _selectedRoutineSectionId;
  int _selectedRoutineWeekday = 1; // 1 = Monday

  static const List<Map<String, dynamic>> _weekdays = [
    {'id': 1, 'name': 'Monday', 'short': 'Mon'},
    {'id': 2, 'name': 'Tuesday', 'short': 'Tue'},
    {'id': 3, 'name': 'Wednesday', 'short': 'Wed'},
    {'id': 4, 'name': 'Thursday', 'short': 'Thu'},
    {'id': 5, 'name': 'Friday', 'short': 'Fri'},
    {'id': 6, 'name': 'Saturday', 'short': 'Sat'},
    {'id': 7, 'name': 'Sunday', 'short': 'Sun'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getClasses(),
      _api.getRoutines(weekday: 1),
      _api.getExams(),
    ]);

    setState(() {
      _isLoading = false;
      if (results[0].success) {
        _classes = results[0].data as List<dynamic>;
        if (_classes.isNotEmpty) {
          _selectedRoutineClassId = _classes.first['id'] as int?;
          final sections = (_classes.first['sections'] as List<dynamic>?) ?? [];
          if (sections.isNotEmpty) {
            _selectedRoutineSectionId = sections.first['id'] as int?;
          }
        }
      }
      if (results[1].success) _routines = results[1].data as List<dynamic>;
      if (results[2].success) {
        final examData = results[2].data as Map<String, dynamic>;
        _exams = examData['data'] ?? [];
        _resultsPublished = examData['results_published'] ?? true;
      }
    });

    if (_selectedRoutineClassId != null && _selectedRoutineSectionId != null) {
      _fetchFilteredRoutines();
    }
  }

  Future<void> _fetchFilteredRoutines() async {
    setState(() => _isLoadingRoutines = true);
    final res = await _api.getRoutines(
      classId: _selectedRoutineClassId,
      sectionId: _selectedRoutineSectionId,
      weekday: _selectedRoutineWeekday,
    );
    setState(() {
      _isLoadingRoutines = false;
      if (res.success && res.data != null) {
        _routines = res.data!;
      } else {
        _routines = [];
      }
    });
  }

  Future<void> _handleToggleResult(bool val) async {
    setState(() => _isToggling = true);
    final res = await _api.toggleResultLock(val);
    setState(() {
      _isToggling = false;
      if (res.success) {
        _resultsPublished = val;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: val ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
    }
  }

  Map<String, dynamic>? _getSelectedClass() {
    if (_selectedRoutineClassId == null) return null;
    return _classes.firstWhere(
      (c) => c['id'] == _selectedRoutineClassId,
      orElse: () => null,
    );
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFF4F46E5);
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF4F46E5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Academics & Timetables',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_mode_rounded, color: AppTheme.purple),
            tooltip: 'Student Promotion',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentPromotionScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.royalBlue),
            tooltip: 'Routine Studio',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoutineMakerScreen(
                    initialClassId: _selectedRoutineClassId,
                    initialSectionId: _selectedRoutineSectionId,
                  ),
                ),
              ).then((_) => _fetchFilteredRoutines());
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: [
            Tab(text: 'Classes (${_classes.length})'),
            Tab(text: 'Routines (${_routines.length})'),
            Tab(text: 'Exams (${_exams.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Classes & Sections
                _buildClassesTab(),
                // Tab 2: Timetable / Routines
                _buildRoutinesTab(),
                // Tab 3: Exams & Result Publication
                _buildExamsTab(),
              ],
            ),
    );
  }

  Widget _buildClassesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _classes.length,
      itemBuilder: (ctx, idx) {
        final c = _classes[idx];
        final sections = (c['sections'] as List<dynamic>?) ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryLight,
              child: Text(
                '${idx + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
              ),
            ),
            title: Text(
              c['class_name'] ?? 'Class',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Text(
              '${sections.length} Sections • ${c['courses_count'] ?? 0} Subjects',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.emeraldLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${c['student_count'] ?? 0} Enrolled',
                style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            onTap: () {
              // Open routine maker directly for this class
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoutineMakerScreen(
                    initialClassId: c['id'] as int?,
                  ),
                ),
              ).then((_) => _fetchFilteredRoutines());
            },
          ),
        );
      },
    );
  }

  Widget _buildRoutinesTab() {
    return Column(
      children: [
        // 1. Studio Promotion & Shortcut Banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C3CE9), Color(0xFF4A148C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Routine & Timetable Studio',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bell schedules, auto-generation, clash detection & section cloning',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoutineMakerScreen(
                        initialClassId: _selectedRoutineClassId,
                        initialSectionId: _selectedRoutineSectionId,
                      ),
                    ),
                  ).then((_) => _fetchFilteredRoutines());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(
                  'Launch',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Class & Section Selectors
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: (() {
                      final uniqueClasses = <int, Map<String, dynamic>>{};
                      for (final c in _classes) {
                        if (c is Map && c['id'] != null) {
                          uniqueClasses[c['id'] as int] = Map<String, dynamic>.from(c);
                        }
                      }
                      final items = uniqueClasses.values.map<DropdownMenuItem<int>>((c) {
                        return DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(
                            c['class_name'] ?? 'Class',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList();
                      final safeValue = uniqueClasses.containsKey(_selectedRoutineClassId)
                          ? _selectedRoutineClassId
                          : (uniqueClasses.isNotEmpty ? uniqueClasses.keys.first : null);

                      return DropdownButton<int>(
                        value: safeValue,
                        isExpanded: true,
                        hint: const Text('Select Class', style: TextStyle(fontSize: 13)),
                        items: items,
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _selectedRoutineClassId = val;
                            final cls = _classes.firstWhere((c) => c['id'] == val, orElse: () => null);
                            final secs = (cls?['sections'] as List<dynamic>?) ?? [];
                            _selectedRoutineSectionId = secs.isNotEmpty ? secs.first['id'] as int? : null;
                          });
                          _fetchFilteredRoutines();
                        },
                      );
                    })(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: (() {
                      final currentClass = _getSelectedClass();
                      final rawSections = (currentClass?['sections'] as List<dynamic>?) ?? [];
                      final uniqueSections = <int, Map<String, dynamic>>{};
                      for (final s in rawSections) {
                        if (s is Map && s['id'] != null) {
                          uniqueSections[s['id'] as int] = Map<String, dynamic>.from(s);
                        }
                      }
                      final items = uniqueSections.values.map<DropdownMenuItem<int>>((s) {
                        return DropdownMenuItem<int>(
                          value: s['id'] as int,
                          child: Text(
                            s['section_name'] ?? 'Sec',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList();
                      final safeValue = uniqueSections.containsKey(_selectedRoutineSectionId)
                          ? _selectedRoutineSectionId
                          : (uniqueSections.isNotEmpty ? uniqueSections.keys.first : null);

                      return DropdownButton<int>(
                        value: safeValue,
                        isExpanded: true,
                        hint: const Text('Section', style: TextStyle(fontSize: 13)),
                        items: items,
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedRoutineSectionId = val);
                          _fetchFilteredRoutines();
                        },
                      );
                    })(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Weekday Filter Chips
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            itemCount: _weekdays.length,
            itemBuilder: (ctx, idx) {
              final w = _weekdays[idx];
              final id = w['id'] as int;
              final isSelected = _selectedRoutineWeekday == id;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    w['short'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.dark,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.royalBlue,
                  backgroundColor: Colors.white,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedRoutineWeekday = id);
                      _fetchFilteredRoutines();
                    }
                  },
                ),
              );
            },
          ),
        ),

        // 4. Slots List
        Expanded(
          child: _isLoadingRoutines
              ? const Center(child: CircularProgressIndicator())
              : _routines.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_busy_rounded, size: 44, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No routine periods configured for this day.',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Use the Studio to generate bell schedules or add periods.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RoutineMakerScreen(
                                    initialClassId: _selectedRoutineClassId,
                                    initialSectionId: _selectedRoutineSectionId,
                                  ),
                                ),
                              ).then((_) => _fetchFilteredRoutines());
                            },
                            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            label: const Text('Configure in Studio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                      itemCount: _routines.length,
                      itemBuilder: (ctx, idx) {
                        final r = _routines[idx];
                        final color = _parseColor(r['color']);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.borderLight),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Container(
                                  width: 5,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          r['start_time'] ?? '09:00',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                                        ),
                                        const Text('to', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                        Text(
                                          r['end_time'] ?? '09:45',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          r['subject_name'] ?? 'Subject',
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Class: ${r['class_name']} • Room: ${r['room'] ?? 'N/A'}',
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Faculty: ${r['teacher_name'] ?? 'TBA'}',
                                          style: const TextStyle(color: AppTheme.royalBlue, fontWeight: FontWeight.w600, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMuted),
                                  tooltip: 'Open in Studio',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RoutineMakerScreen(
                                          initialClassId: r['class_id'] as int?,
                                          initialSectionId: r['section_id'] as int?,
                                        ),
                                      ),
                                    ).then((_) => _fetchFilteredRoutines());
                                  },
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

  Widget _buildExamsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result Lock Master Switch
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publish Results to Parents',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _resultsPublished
                            ? 'Results are visible on Parent & Student apps.'
                            : 'Results are locked from Parent & Student apps.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _resultsPublished ? AppTheme.emerald : AppTheme.crimson,
                        ),
                      ),
                    ],
                  ),
                ),
                _isToggling
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Switch(
                        value: _resultsPublished,
                        activeColor: AppTheme.emerald,
                        onChanged: (val) => _handleToggleResult(val),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Scheduled Examinations',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_exams.isEmpty)
            const Text('No upcoming exams scheduled.')
          else
            ..._exams.map((e) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.event_note, color: AppTheme.royalBlue),
                  title: Text(
                    e['exam_name'] ?? 'Term Exam',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${e['class_name']} • ${e['subject']}\n${e['start_date']} to ${e['end_date'] ?? 'TBA'}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: e['status'] == 'completed' ? AppTheme.borderLight : AppTheme.emeraldLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (e['status'] as String).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: e['status'] == 'completed' ? AppTheme.textMuted : AppTheme.emerald,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
