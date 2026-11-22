import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

enum TimetableViewMode { classRoutine, teacherRoutine }

class RoutineMakerScreen extends StatefulWidget {
  final int? initialClassId;
  final int? initialSectionId;

  const RoutineMakerScreen({
    Key? key,
    this.initialClassId,
    this.initialSectionId,
  }) : super(key: key);

  @override
  State<RoutineMakerScreen> createState() => _RoutineMakerScreenState();
}

class _RoutineMakerScreenState extends State<RoutineMakerScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;

  TimetableViewMode _viewMode = TimetableViewMode.classRoutine;

  // Configuration data from backend
  List<dynamic> _classes = [];
  List<dynamic> _teachers = [];
  List<dynamic> _teacherMappings = [];
  List<dynamic> _cloneableSections = [];

  // Active selections
  int? _selectedClassId;
  int? _selectedSectionId;
  int? _selectedWeekday; // null = All Days, 1..7 = Monday..Sunday
  int? _selectedTeacherId; // for teacher workload perspective

  // Routines data
  List<dynamic> _routines = [];
  Map<String, dynamic>? _teacherTimetableData;

  static const List<Map<String, dynamic>> _weekdays = [
    {'id': 1, 'name': 'Monday', 'short': 'Mon'},
    {'id': 2, 'name': 'Tuesday', 'short': 'Tue'},
    {'id': 3, 'name': 'Wednesday', 'short': 'Wed'},
    {'id': 4, 'name': 'Thursday', 'short': 'Thu'},
    {'id': 5, 'name': 'Friday', 'short': 'Fri'},
    {'id': 6, 'name': 'Saturday', 'short': 'Sat'},
    {'id': 7, 'name': 'Sunday', 'short': 'Sun'},
  ];

  static const List<Map<String, dynamic>> _palette = [
    {'name': 'Indigo', 'hex': '#4F46E5', 'color': Color(0xFF4F46E5)},
    {'name': 'Emerald', 'hex': '#059669', 'color': Color(0xFF059669)},
    {'name': 'Amber', 'hex': '#D97706', 'color': Color(0xFFD97706)},
    {'name': 'Crimson', 'hex': '#DC2626', 'color': Color(0xFFDC2626)},
    {'name': 'Purple', 'hex': '#7C3AED', 'color': Color(0xFF7C3AED)},
    {'name': 'Sky', 'hex': '#0284C7', 'color': Color(0xFF0284C7)},
    {'name': 'Rose', 'hex': '#DB2777', 'color': Color(0xFFDB2777)},
    {'name': 'Teal', 'hex': '#0D9488', 'color': Color(0xFF0D9488)},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialConfig();
  }

  Future<void> _loadInitialConfig() async {
    setState(() => _isLoading = true);
    final configRes = await _api.getRoutineConfig();

    if (configRes.success && configRes.data != null) {
      final data = configRes.data!;
      _classes = (data['classes'] as List<dynamic>?) ?? [];
      _teachers = (data['teachers'] as List<dynamic>?) ?? [];
      _teacherMappings = (data['teacher_mappings'] as List<dynamic>?) ?? [];
      _cloneableSections = (data['cloneable_sections'] as List<dynamic>?) ?? [];

      // Auto-select Class & Section
      if (widget.initialClassId != null) {
        _selectedClassId = widget.initialClassId;
      } else if (_classes.isNotEmpty) {
        _selectedClassId = _classes.first['id'] as int?;
      }

      final currentClass = _getSelectedClass();
      final sections = (currentClass?['sections'] as List<dynamic>?) ?? [];

      if (widget.initialSectionId != null) {
        _selectedSectionId = widget.initialSectionId;
      } else if (sections.isNotEmpty) {
        _selectedSectionId = sections.first['id'] as int?;
      }

      if (_teachers.isNotEmpty) {
        _selectedTeacherId = _teachers.first['id'] as int?;
      }
    }

    await _fetchRoutines();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchRoutines() async {
    if (_viewMode == TimetableViewMode.classRoutine) {
      if (_selectedClassId == null || _selectedSectionId == null) {
        setState(() => _routines = []);
        return;
      }

      final res = await _api.getRoutines(
        classId: _selectedClassId,
        sectionId: _selectedSectionId,
        weekday: _selectedWeekday,
      );

      if (res.success && res.data != null) {
        setState(() => _routines = res.data!);
      } else {
        setState(() => _routines = []);
      }
    } else {
      if (_selectedTeacherId == null) return;
      final res = await _api.getTeacherTimetable(_selectedTeacherId!);
      if (res.success && res.data != null) {
        setState(() {
          _teacherTimetableData = res.data!;
          _routines = (res.data!['slots'] as List<dynamic>?) ?? [];
        });
      } else {
        setState(() {
          _teacherTimetableData = null;
          _routines = [];
        });
      }
    }
  }

  Map<String, dynamic>? _getSelectedClass() {
    if (_selectedClassId == null) return null;
    return _classes.firstWhere(
      (c) => c['id'] == _selectedClassId,
      orElse: () => null,
    );
  }

  Map<String, dynamic>? _getSelectedSection() {
    final currentClass = _getSelectedClass();
    if (currentClass == null || _selectedSectionId == null) return null;
    final sections = (currentClass['sections'] as List<dynamic>?) ?? [];
    return sections.firstWhere(
      (s) => s['id'] == _selectedSectionId,
      orElse: () => null,
    );
  }

  List<dynamic> _getCoursesForSelectedClass() {
    final currentClass = _getSelectedClass();
    if (currentClass == null) return [];
    return (currentClass['courses'] as List<dynamic>?) ?? [];
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
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Routine & Timetable Studio',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.dark,
              ),
            ),
            Text(
              _viewMode == TimetableViewMode.classRoutine
                  ? 'Manage bell schedules & period allocations'
                  : 'Faculty workload & weekly teaching schedules',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.dark),
            tooltip: 'Refresh',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _fetchRoutines();
              setState(() => _isLoading = false);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.dark),
            onSelected: (val) {
              if (val == 'generator') {
                _showBellScheduleGeneratorModal();
              } else if (val == 'clone') {
                _showCloneSectionModal();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'generator',
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high_rounded, size: 18, color: AppTheme.primary),
                    SizedBox(width: 10),
                    Text('Bell Schedule Generator'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clone',
                child: Row(
                  children: [
                    Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.emerald),
                    SizedBox(width: 10),
                    Text('Clone from Section'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Perspective Switcher & Selection Bar
                _buildControlHeader(),

                // 2. Weekday Pill Filter
                _buildWeekdayFilterBar(),

                // 3. Main Routine Slots List / Timeline
                Expanded(
                  child: _routines.isEmpty ? _buildEmptyState() : _buildRoutineTimeline(),
                ),
              ],
            ),
      floatingActionButton: _viewMode == TimetableViewMode.classRoutine
          ? FloatingActionButton.extended(
        heroTag: null,
              onPressed: () => _showAddEditSlotModal(),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Add Period Slot',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Header & Controls
  // ---------------------------------------------------------------------------
  Widget _buildControlHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Column(
        children: [
          // View Mode Selector Segment
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.lightBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_viewMode != TimetableViewMode.classRoutine) {
                        setState(() => _viewMode = TimetableViewMode.classRoutine);
                        _fetchRoutines();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _viewMode == TimetableViewMode.classRoutine
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _viewMode == TimetableViewMode.classRoutine
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 16,
                            color: _viewMode == TimetableViewMode.classRoutine
                                ? AppTheme.primary
                                : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Class Timetable',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: _viewMode == TimetableViewMode.classRoutine
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _viewMode == TimetableViewMode.classRoutine
                                  ? AppTheme.dark
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_viewMode != TimetableViewMode.teacherRoutine) {
                        setState(() => _viewMode = TimetableViewMode.teacherRoutine);
                        _fetchRoutines();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _viewMode == TimetableViewMode.teacherRoutine
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _viewMode == TimetableViewMode.teacherRoutine
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.badge_rounded,
                            size: 16,
                            color: _viewMode == TimetableViewMode.teacherRoutine
                                ? AppTheme.primary
                                : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Teacher Workload',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: _viewMode == TimetableViewMode.teacherRoutine
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _viewMode == TimetableViewMode.teacherRoutine
                                  ? AppTheme.dark
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dropdowns depending on Mode
          if (_viewMode == TimetableViewMode.classRoutine)
            Row(
              children: [
                // Class Selector
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
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
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList();
                      final safeValue = uniqueClasses.containsKey(_selectedClassId)
                          ? _selectedClassId
                          : (uniqueClasses.isNotEmpty ? uniqueClasses.keys.first : null);

                      return DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: safeValue,
                          isExpanded: true,
                          hint: const Text('Select Class', style: TextStyle(fontSize: 13)),
                          items: items,
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              _selectedClassId = val;
                              final currentClass = _classes.firstWhere((c) => c['id'] == val, orElse: () => null);
                              final sections = (currentClass?['sections'] as List<dynamic>?) ?? [];
                              _selectedSectionId = sections.isNotEmpty ? sections.first['id'] as int? : null;
                            });
                            _fetchRoutines();
                          },
                        ),
                      );
                    })(),
                  ),
                ),
                const SizedBox(width: 8),

                // Section Selector
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
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
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList();
                      final safeValue = uniqueSections.containsKey(_selectedSectionId)
                          ? _selectedSectionId
                          : (uniqueSections.isNotEmpty ? uniqueSections.keys.first : null);

                      return DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: safeValue,
                          isExpanded: true,
                          hint: const Text('Section', style: TextStyle(fontSize: 13)),
                          items: items,
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _selectedSectionId = val);
                            _fetchRoutines();
                          },
                        ),
                      );
                    })(),
                  ),
                ),
              ],
            )
          else
            // Teacher Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: (() {
                final uniqueTeachers = <int, Map<String, dynamic>>{};
                for (final t in _teachers) {
                  if (t is Map && t['id'] != null) {
                    uniqueTeachers[t['id'] as int] = Map<String, dynamic>.from(t);
                  }
                }
                final items = uniqueTeachers.values.map<DropdownMenuItem<int>>((t) {
                  return DropdownMenuItem<int>(
                    value: t['id'] as int,
                    child: Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          t['name'] ?? 'Teacher',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
                final safeValue = uniqueTeachers.containsKey(_selectedTeacherId)
                    ? _selectedTeacherId
                    : (uniqueTeachers.isNotEmpty ? uniqueTeachers.keys.first : null);

                return DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: safeValue,
                    isExpanded: true,
                    hint: const Text('Select Faculty Member', style: TextStyle(fontSize: 13)),
                    items: items,
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _selectedTeacherId = val);
                      _fetchRoutines();
                    },
                  ),
                );
              })(),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Weekday Filter Pills
  // ---------------------------------------------------------------------------
  Widget _buildWeekdayFilterBar() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // All Week Pill
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                'All Days (${_routines.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _selectedWeekday == null ? Colors.white : AppTheme.dark,
                ),
              ),
              selected: _selectedWeekday == null,
              selectedColor: AppTheme.primary,
              backgroundColor: Colors.white,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedWeekday = null);
                  _fetchRoutines();
                }
              },
            ),
          ),
          ..._weekdays.map((w) {
            final wId = w['id'] as int;
            final count = _routines.where((r) => r['weekday'] == wId).length;
            final isSelected = _selectedWeekday == wId;

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  '${w['short']} ($count)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.dark,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.primary,
                backgroundColor: Colors.white,
                onSelected: (val) {
                  setState(() => _selectedWeekday = val ? wId : null);
                  _fetchRoutines();
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Main Routine Timeline
  // ---------------------------------------------------------------------------
  Widget _buildRoutineTimeline() {
    // Group routines by weekday for clean presentation
    final Map<int, List<dynamic>> grouped = {};
    for (var r in _routines) {
      final w = (r['weekday'] as int?) ?? 1;
      grouped.putIfAbsent(w, () => []).add(r);
    }

    final sortedDays = grouped.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _fetchRoutines,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
        itemCount: sortedDays.length,
        itemBuilder: (ctx, dIdx) {
          final dayNum = sortedDays[dIdx];
          final daySlots = grouped[dayNum]!;
          daySlots.sort((a, b) => (a['start_time'] ?? '').compareTo(b['start_time'] ?? ''));

          final dayMeta = _weekdays.firstWhere(
            (w) => w['id'] == dayNum,
            orElse: () => {'name': 'Day $dayNum'},
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day Header
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dayMeta['name'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${daySlots.length} Periods Scheduled',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const Spacer(),
                    if (_viewMode == TimetableViewMode.classRoutine)
                      InkWell(
                        onTap: () => _showAddEditSlotModal(prefillWeekday: dayNum),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline_rounded, size: 14, color: AppTheme.primary),
                              SizedBox(width: 4),
                              Text('Add Period', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Slot Cards
              ...daySlots.asMap().entries.map((entry) {
                final slotIndex = entry.key;
                final slot = entry.value;
                return _buildSlotCard(slot, slotIndex + 1);
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSlotCard(dynamic slot, int periodNum) {
    final slotColor = _parseColor(slot['color']);
    final startTime = slot['start_time'] ?? '00:00';
    final endTime = slot['end_time'] ?? '00:00';
    final subject = slot['subject_name'] ?? 'General Subject';
    final teacher = slot['teacher_name'] ?? 'TBA';
    final room = slot['room'] ?? 'N/A';
    final className = slot['class_name'] ?? '';
    final sectionName = slot['section_name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color Bar
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: slotColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Period & Timing Column
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: slotColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'P$periodNum',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: slotColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    startTime,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dark,
                    ),
                  ),
                  Text(
                    endTime,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),
            Container(width: 1, color: AppTheme.borderLight, margin: const EdgeInsets.symmetric(vertical: 10)),
            const SizedBox(width: 12),

            // Subject & Faculty Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      subject,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Teacher line
                    Row(
                      children: [
                        const Icon(Icons.person_rounded, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            teacher,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.dark,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Room & Class chips
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.lightBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.meeting_room_outlined, size: 11, color: AppTheme.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                room,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.dark),
                              ),
                            ],
                          ),
                        ),
                        if (_viewMode == TimetableViewMode.teacherRoutine && className.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$className - $sectionName',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Edit & Delete Action Buttons (Class Routine Mode)
            if (_viewMode == TimetableViewMode.classRoutine)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMuted),
                      tooltip: 'Edit Slot',
                      onPressed: () => _showAddEditSlotModal(slot: slot),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.crimson),
                      tooltip: 'Remove Slot',
                      onPressed: () => _confirmDeleteSlot(slot['id'] as int, subject),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Empty State with Setup Helpers
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Timetable Periods Configured',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _viewMode == TimetableViewMode.classRoutine
                  ? 'Build your class timetable quickly by generating standard period slots, cloning from an existing section, or adding single periods.'
                  : 'No teaching routine periods scheduled for this faculty member in the current academic session.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            if (_viewMode == TimetableViewMode.classRoutine) ...[
              ElevatedButton.icon(
                onPressed: _showBellScheduleGeneratorModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18, color: Colors.white),
                label: Text(
                  'Auto-Generate Bell Schedule',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _showCloneSectionModal,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  side: const BorderSide(color: AppTheme.borderLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.dark),
                label: Text(
                  'Clone from Another Section',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Add / Edit Slot Bottom Sheet Modal
  // ---------------------------------------------------------------------------
  void _showAddEditSlotModal({dynamic slot, int? prefillWeekday}) {
    final isEdit = slot != null;
    final slotId = isEdit ? (slot['id'] as int) : null;

    int currentWeekday = slot != null
        ? (slot['weekday'] as int? ?? 1)
        : (prefillWeekday ?? (_selectedWeekday ?? 1));

    String startTimeStr = slot != null ? (slot['start_time'] ?? '09:00') : '09:00';
    String endTimeStr = slot != null ? (slot['end_time'] ?? '09:45') : '09:45';

    final courses = _getCoursesForSelectedClass();
    int? currentCourseId = slot != null
        ? (slot['course_id'] as int?)
        : (courses.isNotEmpty ? courses.first['id'] as int? : null);

    // Auto-map teacher if mapping exists and teacher is not set
    int? currentTeacherId = slot != null ? (slot['teacher_id'] as int?) : null;
    if (currentTeacherId == null && currentCourseId != null) {
      final mapping = _teacherMappings.firstWhere(
        (m) =>
            m['class_id'] == _selectedClassId &&
            m['section_id'] == _selectedSectionId &&
            m['course_id'] == currentCourseId,
        orElse: () => null,
      );
      if (mapping != null && mapping['teacher_id'] != null) {
        currentTeacherId = mapping['teacher_id'] as int?;
      }
    }

    final roomController = TextEditingController(text: slot != null ? (slot['room'] ?? '') : 'Room 101');
    String selectedHexColor = slot != null ? (slot['color'] ?? '#4F46E5') : '#4F46E5';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Routine Period Slot' : 'Add New Period Slot',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.dark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Day of the Week Picker
                    Text('Day of Week', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: currentWeekday,
                          isExpanded: true,
                          items: _weekdays.map<DropdownMenuItem<int>>((w) {
                            return DropdownMenuItem<int>(
                              value: w['id'] as int,
                              child: Text(w['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => currentWeekday = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Start Time & End Time
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Time (24h)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final parts = startTimeStr.split(':');
                                  final initialTime = TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 9,
                                    minute: int.tryParse(parts[1]) ?? 0,
                                  );
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: initialTime,
                                  );
                                  if (picked != null) {
                                    final h = picked.hour.toString().padLeft(2, '0');
                                    final m = picked.minute.toString().padLeft(2, '0');
                                    setModalState(() => startTimeStr = '$h:$m');
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.borderLight),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(startTimeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Time (24h)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final parts = endTimeStr.split(':');
                                  final initialTime = TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 9,
                                    minute: int.tryParse(parts[1]) ?? 45,
                                  );
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: initialTime,
                                  );
                                  if (picked != null) {
                                    final h = picked.hour.toString().padLeft(2, '0');
                                    final m = picked.minute.toString().padLeft(2, '0');
                                    setModalState(() => endTimeStr = '$h:$m');
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.borderLight),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(endTimeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Subject / Course
                    Text('Subject / Course', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: (() {
                          final uniqueCourses = <int, Map<String, dynamic>>{};
                          for (final co in courses) {
                            if (co is Map && co['id'] != null) {
                              uniqueCourses[co['id'] as int] = Map<String, dynamic>.from(co);
                            }
                          }
                          final items = uniqueCourses.values.map<DropdownMenuItem<int>>((co) {
                            return DropdownMenuItem<int>(
                              value: co['id'] as int,
                              child: Text(co['course_name'] ?? 'Subject', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList();
                          final safeVal = uniqueCourses.containsKey(currentCourseId) ? currentCourseId : null;

                          return DropdownButton<int>(
                            value: safeVal,
                            isExpanded: true,
                            hint: const Text('Choose Subject'),
                            items: items,
                            onChanged: (val) {
                              setModalState(() {
                                currentCourseId = val;
                                // Auto lookup assigned teacher mapping
                                final map = _teacherMappings.firstWhere(
                                  (m) =>
                                      m['class_id'] == _selectedClassId &&
                                      m['section_id'] == _selectedSectionId &&
                                      m['course_id'] == val,
                                  orElse: () => null,
                                );
                                if (map != null && map['teacher_id'] != null) {
                                  currentTeacherId = map['teacher_id'] as int?;
                                }
                              });
                            },
                          );
                        })(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Faculty / Teacher
                    Text('Assigned Teacher / Faculty', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: (() {
                          final uniqueTeachers = <int, Map<String, dynamic>>{};
                          for (final t in _teachers) {
                            if (t is Map && t['id'] != null) {
                              uniqueTeachers[t['id'] as int] = Map<String, dynamic>.from(t);
                            }
                          }
                          final items = [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('To Be Announced (TBA)', style: TextStyle(color: AppTheme.textMuted)),
                            ),
                            ...uniqueTeachers.values.map<DropdownMenuItem<int?>>((t) {
                              return DropdownMenuItem<int?>(
                                value: t['id'] as int?,
                                child: Text(t['name'] ?? 'Teacher', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              );
                            }),
                          ];
                          final safeVal = (currentTeacherId != null && uniqueTeachers.containsKey(currentTeacherId))
                              ? currentTeacherId
                              : null;

                          return DropdownButton<int?>(
                            value: safeVal,
                            isExpanded: true,
                            hint: const Text('Select Teacher (Optional)'),
                            items: items,
                            onChanged: (val) => setModalState(() => currentTeacherId = val),
                          );
                        })(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Room No.
                    Text('Room / Venue', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: roomController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Room 101, Science Lab, Aud A',
                        filled: true,
                        fillColor: AppTheme.lightBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Color Palette Selector
                    Text('Subject Color Tag', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _palette.map((item) {
                        final hex = item['hex'] as String;
                        final color = item['color'] as Color;
                        final isChosen = selectedHexColor.toUpperCase() == hex.toUpperCase();

                        return GestureDetector(
                          onTap: () => setModalState(() => selectedHexColor = hex),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isChosen ? Border.all(color: AppTheme.dark, width: 2.5) : null,
                            ),
                            child: isChosen ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                if (currentCourseId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select a subject.')),
                                  );
                                  return;
                                }

                                final payload = {
                                  'class_id': _selectedClassId,
                                  'section_id': _selectedSectionId,
                                  'course_id': currentCourseId,
                                  'teacher_id': currentTeacherId,
                                  'weekday': currentWeekday,
                                  'start': startTimeStr,
                                  'end': endTimeStr,
                                  'room': roomController.text.trim().isEmpty ? 'Room 101' : roomController.text.trim(),
                                  'color': selectedHexColor,
                                };

                                Navigator.pop(modalCtx);
                                await _executeSaveRoutine(isEdit: isEdit, slotId: slotId, payload: payload);
                              },
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                isEdit ? 'Update Period Slot' : 'Save Period Slot',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
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

  Future<void> _executeSaveRoutine({
    required bool isEdit,
    int? slotId,
    required Map<String, dynamic> payload,
    bool forceOverride = false,
  }) async {
    setState(() => _isSaving = true);

    final res = isEdit
        ? await _api.updateRoutine(slotId!, payload, forceOverride: forceOverride)
        : await _api.createRoutine(payload, forceOverride: forceOverride);

    setState(() => _isSaving = false);

    if (res.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
      _fetchRoutines();
    } else {
      // Check if it was a timetable clash / conflict
      final conflictData = res.data;
      if (conflictData != null && conflictData['conflict'] == true) {
        _showConflictDialog(
          conflictMessage: res.message,
          onOverride: () async {
            await _executeSaveRoutine(
              isEdit: isEdit,
              slotId: slotId,
              payload: payload,
              forceOverride: true,
            );
          },
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message),
              backgroundColor: AppTheme.crimson,
            ),
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 6. Conflict Detection Dialog with Force Override
  // ---------------------------------------------------------------------------
  void _showConflictDialog({
    required String conflictMessage,
    required VoidCallback onOverride,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 28),
              const SizedBox(width: 8),
              Text(
                'Schedule Clash Detected',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.crimson,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conflictMessage,
                style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.dark),
              ),
              const SizedBox(height: 14),
              const Text(
                'Would you like to adjust the period timing or force override the timetable slot?',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Adjust Schedule', style: TextStyle(color: AppTheme.dark, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.crimson,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onOverride();
              },
              child: const Text('Force Override', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Universal Bell Schedule & Period Generator Modal
  // ---------------------------------------------------------------------------
  void _showBellScheduleGeneratorModal() {
    String startTime = '09:00';
    int periodDuration = 45;
    int periodCount = 7;
    int breakAfter = 4;
    int breakDuration = 30;
    bool replaceExisting = false;
    List<int> selectedDays = [1, 2, 3, 4, 5, 6]; // Monday to Saturday

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_fix_high_rounded, color: AppTheme.primary, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Bell Schedule Generator',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.dark,
                              ),
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(modalCtx)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Rapidly establish standard class period slots across your academic week.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),

                    // Working Days Selection
                    Text('Active Weekdays', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: _weekdays.map((w) {
                        final id = w['id'] as int;
                        final isChecked = selectedDays.contains(id);
                        return FilterChip(
                          label: Text(w['short'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isChecked ? Colors.white : AppTheme.dark)),
                          selected: isChecked,
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.lightBg,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                selectedDays.add(id);
                              } else {
                                if (selectedDays.length > 1) selectedDays.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Start Time & Duration
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('School Start Time', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final parts = startTime.split(':');
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0),
                                  );
                                  if (picked != null) {
                                    setModalState(() => startTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.borderLight),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(startTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Period Duration', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderLight),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: periodDuration,
                                    isExpanded: true,
                                    items: [30, 35, 40, 45, 50, 55, 60].map<DropdownMenuItem<int>>((d) {
                                      return DropdownMenuItem<int>(
                                        value: d,
                                        child: Text('$d mins', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => periodDuration = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Number of Periods & Recess Break
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Periods / Day', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderLight),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: periodCount,
                                    isExpanded: true,
                                    items: [4, 5, 6, 7, 8, 9, 10].map<DropdownMenuItem<int>>((cnt) {
                                      return DropdownMenuItem<int>(
                                        value: cnt,
                                        child: Text('$cnt Periods', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => periodCount = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recess Duration', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderLight),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: breakDuration,
                                    isExpanded: true,
                                    items: [15, 20, 25, 30, 40, 45].map<DropdownMenuItem<int>>((b) {
                                      return DropdownMenuItem<int>(
                                        value: b,
                                        child: Text('$b mins', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => breakDuration = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Recess Break After Period
                    Text('Insert Recess Break After Period', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: breakAfter,
                          isExpanded: true,
                          items: [2, 3, 4, 5, 6].map<DropdownMenuItem<int>>((p) {
                            return DropdownMenuItem<int>(
                              value: p,
                              child: Text('After Period $p', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => breakAfter = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Overwrite toggle
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: replaceExisting,
                      activeColor: AppTheme.crimson,
                      title: const Text('Replace existing periods for chosen days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onChanged: (val) => setModalState(() => replaceExisting = val ?? false),
                    ),
                    const SizedBox(height: 20),

                    // Generate Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(modalCtx);
                          setState(() => _isLoading = true);

                          final payload = {
                            'class_id': _selectedClassId,
                            'section_id': _selectedSectionId,
                            'weekdays': selectedDays,
                            'start_time': startTime,
                            'period_duration': periodDuration,
                            'period_count': periodCount,
                            'break_after_period': breakAfter,
                            'break_duration': breakDuration,
                            'replace_existing': replaceExisting,
                          };

                          final res = await _api.generatePeriodSchedule(payload);
                          setState(() => _isLoading = false);

                          if (res.success) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: AppTheme.emerald,
                                ),
                              );
                            }
                            _fetchRoutines();
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: AppTheme.crimson,
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          'Generate Timetable Framework',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
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
  // 8. Clone Routine From Another Section Modal
  // ---------------------------------------------------------------------------
  void _showCloneSectionModal() {
    if (_cloneableSections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other sections with existing routines found to clone.')),
      );
      return;
    }

    int? sourceClassId = _cloneableSections.first['class_id'] as int?;
    int? sourceSectionId = _cloneableSections.first['section_id'] as int?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            return Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.copy_all_rounded, color: AppTheme.emerald, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Clone Section Timetable',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.dark,
                            ),
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(modalCtx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Copy the entire weekly timetable from an existing section into this one in 1 tap.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 18),

                  Text('Source Section', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: '$sourceClassId-$sourceSectionId',
                        isExpanded: true,
                        items: _cloneableSections.map<DropdownMenuItem<String>>((cs) {
                          final cId = cs['class_id'];
                          final sId = cs['section_id'];
                          return DropdownMenuItem<String>(
                            value: '$cId-$sId',
                            child: Text(cs['label'] ?? 'Section', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final parts = val.split('-');
                            setModalState(() {
                              sourceClassId = int.parse(parts[0]);
                              sourceSectionId = int.parse(parts[1]);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (sourceClassId == null || sourceSectionId == null) return;
                        Navigator.pop(modalCtx);
                        setState(() => _isLoading = true);

                        final res = await _api.cloneSectionRoutine(
                          sourceClassId: sourceClassId!,
                          sourceSectionId: sourceSectionId!,
                          targetClassId: _selectedClassId!,
                          targetSectionId: _selectedSectionId!,
                        );

                        setState(() => _isLoading = false);

                        if (res.success) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: AppTheme.emerald,
                              ),
                            );
                          }
                          _fetchRoutines();
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: AppTheme.crimson,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        'Clone Timetable Now',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 9. Confirm Delete Slot
  // ---------------------------------------------------------------------------
  void _confirmDeleteSlot(int slotId, String subjectName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Remove Routine Slot?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: Text(
            'Are you sure you want to remove the "$subjectName" period slot from this timetable?',
            style: const TextStyle(fontSize: 13, color: AppTheme.dark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.crimson,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                final res = await _api.deleteRoutine(slotId);
                setState(() => _isLoading = false);

                if (res.success) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res.message), backgroundColor: AppTheme.emerald),
                    );
                  }
                  _fetchRoutines();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
                    );
                  }
                }
              },
              child: const Text('Delete Slot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
