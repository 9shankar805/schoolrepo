import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/common_widgets.dart';

class StudentPromotionScreen extends StatefulWidget {
  final int? initialClassId;
  final int? initialSectionId;

  const StudentPromotionScreen({
    super.key,
    this.initialClassId,
    this.initialSectionId,
  });

  @override
  State<StudentPromotionScreen> createState() => _StudentPromotionScreenState();
}

class _StudentPromotionScreenState extends State<StudentPromotionScreen> {
  final ApiService _api = ApiService();

  bool _isLoadingOptions = true;
  bool _isLoadingSheet = false;
  bool _isExecuting = false;

  // Options
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _classes = [];

  // Source selection
  int? _fromSessionId;
  int? _fromClassId;
  int? _fromSectionId;

  // Target selection
  int? _toSessionId;
  int? _toClassId;
  int? _toSectionId;

  // Students sheet
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() => _isLoadingOptions = true);
    final res = await _api.getPromotionOptions();
    if (!mounted) return;

    if (res.success && res.data != null) {
      final rawSessions = (res.data!['sessions'] as List<dynamic>? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
      final rawClasses = (res.data!['classes'] as List<dynamic>? ?? [])
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();

      final curSess = res.data!['current_session'] as Map<String, dynamic>?;

      setState(() {
        _sessions = rawSessions;
        _classes = rawClasses;

        if (curSess != null) {
          _fromSessionId = curSess['id'];
          // Set target session to newest or next session
          _toSessionId = rawSessions.isNotEmpty ? rawSessions.first['id'] : curSess['id'];
        } else if (rawSessions.isNotEmpty) {
          _fromSessionId = rawSessions.first['id'];
          _toSessionId = rawSessions.first['id'];
        }

        if (widget.initialClassId != null) {
          _fromClassId = widget.initialClassId;
          _fromSectionId = widget.initialSectionId;
        } else if (_classes.isNotEmpty) {
          _fromClassId = _classes.first['id'];
          final secs = (_classes.first['sections'] as List<dynamic>? ?? []);
          _fromSectionId = secs.isNotEmpty ? secs.first['id'] : null;
        }

        _autoMapTargetClass();
        _isLoadingOptions = false;
      });

      if (_fromClassId != null && _fromSessionId != null) {
        _loadSheet();
      }
    } else {
      setState(() => _isLoadingOptions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  void _autoMapTargetClass() {
    if (_fromClassId == null || _classes.isEmpty) return;

    final fromIdx = _classes.indexWhere((c) => c['id'] == _fromClassId);
    if (fromIdx != -1 && fromIdx + 1 < _classes.length) {
      _toClassId = _classes[fromIdx + 1]['id'];
      final secs = (_classes[fromIdx + 1]['sections'] as List<dynamic>? ?? []);
      _toSectionId = secs.isNotEmpty ? secs.first['id'] : null;
    } else {
      _toClassId = _fromClassId;
      final c = _classes.firstWhere((x) => x['id'] == _toClassId, orElse: () => {'sections': []});
      final secs = (c['sections'] as List<dynamic>? ?? []);
      _toSectionId = secs.isNotEmpty ? secs.first['id'] : null;
    }
  }

  Future<void> _loadSheet() async {
    if (_fromSessionId == null || _fromClassId == null) return;
    setState(() => _isLoadingSheet = true);

    final res = await _api.getPromotionSheet(
      sessionId: _fromSessionId!,
      classId: _fromClassId!,
      sectionId: _fromSectionId,
    );
    if (!mounted) return;

    if (res.success && res.data != null) {
      final raw = (res.data!['students'] as List<dynamic>? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

      setState(() {
        _students = raw;
        _isLoadingSheet = false;
      });
    } else {
      setState(() => _isLoadingSheet = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  void _bulkSetAction(String action) {
    setState(() {
      for (var s in _students) {
        s['action'] = action;
      }
    });
  }

  void _autoSequenceRollNumbers() {
    setState(() {
      int roll = 1;
      for (var s in _students) {
        if (s['action'] == 'promote' || s['action'] == 'repeat') {
          s['suggested_roll_no'] = str_pad(roll.toString(), 2, '0');
          roll++;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Target roll numbers sequenced sequentially (01, 02, 03...).')),
    );
  }

  String str_pad(String val, int len, String pad) {
    while (val.length < len) {
      val = pad + val;
    }
    return val;
  }

  Future<void> _executePromotion() async {
    if (_toClassId == null || _toSectionId == null || _toSessionId == null || _students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select target session, class, and section.')),
      );
      return;
    }

    final fromClassName = _classes.firstWhere((c) => c['id'] == _fromClassId, orElse: () => {})['class_name'] ?? 'Class';
    final toClassName = _classes.firstWhere((c) => c['id'] == _toClassId, orElse: () => {})['class_name'] ?? 'Class';

    final promoteCount = _students.where((s) => s['action'] == 'promote').length;
    final repeatCount = _students.where((s) => s['action'] == 'repeat').length;
    final graduateCount = _students.where((s) => s['action'] == 'graduate').length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Annual Progression'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to execute year-end progression for ${_students.length} students?',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text('• From: $fromClassName'),
            Text('• To: $toClassName (Target Year)'),
            const SizedBox(height: 8),
            Text('• $promoteCount student(s) will be Promoted'),
            Text('• $repeatCount student(s) will Repeat'),
            Text('• $graduateCount student(s) will Graduate'),
            const SizedBox(height: 12),
            const Text(
              'This will generate new enrollment records in the target academic year.',
              style: TextStyle(fontSize: 11, color: AppTheme.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Execute', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isExecuting = true);

    final payload = {
      'from_session_id': _fromSessionId,
      'to_session_id': _toSessionId,
      'from_class_id': _fromClassId,
      'to_class_id': _toClassId,
      'from_section_id': _fromSectionId,
      'to_section_id': _toSectionId,
      'students': _students.map((s) {
        return {
          'student_id': s['student_id'],
          'action': s['action'],
          'roll_no': s['suggested_roll_no'],
          'target_class_id': s['action'] == 'repeat' ? _fromClassId : _toClassId,
          'target_section_id': _toSectionId,
        };
      }).toList(),
    };

    final res = await _api.promoteStudents(payload);
    if (!mounted) return;

    setState(() => _isExecuting = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadSheet();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final promoting = _students.where((s) => s['action'] == 'promote').length;
    final repeating = _students.where((s) => s['action'] == 'repeat').length;
    final graduating = _students.where((s) => s['action'] == 'graduate').length;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, isDark),
            _buildProgressionMapperCard(isDark),
            _buildKpiSummaryBar(promoting, repeating, graduating, isDark),
            _buildQuickActionBar(isDark),
            Expanded(
              child: _isLoadingSheet || _isLoadingOptions
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.royalBlue))
                  : _buildStudentsList(isDark),
            ),
            if (_students.isNotEmpty) _buildBottomExecutionButton(promoting, isDark),
          ],
        ),
      ),
    );
  }

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
                  'Student Promotion (कक्षा स्तरोन्नति)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.dark,
                  ),
                ),
                const Text(
                  'Year-End Batch Progression & Class Rollover',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.royalBlue),
            onPressed: () {
              _loadOptions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionMapperCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7),
        ),
      ),
      child: Column(
        children: [
          // Source & Target Grid
          Row(
            children: [
              // FROM (Source)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FROM SOURCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.royalBlue)),
                    const SizedBox(height: 6),
                    // Class Dropdown
                    (() {
                      final uniqueClasses = <int, Map<String, dynamic>>{};
                      for (final c in _classes) {
                        if (c is Map && c['id'] != null) {
                          uniqueClasses[c['id'] as int] = Map<String, dynamic>.from(c);
                        }
                      }
                      final items = uniqueClasses.values.map<DropdownMenuItem<int>>((c) {
                        return DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(c['class_name'] ?? 'Class', style: const TextStyle(fontSize: 12)),
                        );
                      }).toList();
                      final safeVal = uniqueClasses.containsKey(_fromClassId) ? _fromClassId : (uniqueClasses.isNotEmpty ? uniqueClasses.keys.first : null);

                      return DropdownButtonFormField<int>(
                        value: safeVal,
                        isExpanded: true,
                        hint: const Text('Source Class', style: TextStyle(fontSize: 12)),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        items: items,
                        onChanged: (v) {
                          if (v == null) return;
                          final c = uniqueClasses[v];
                          final secs = (c?['sections'] as List<dynamic>? ?? []);
                          setState(() {
                            _fromClassId = v;
                            _fromSectionId = secs.isNotEmpty ? secs.first['id'] as int? : null;
                            _autoMapTargetClass();
                          });
                          _loadSheet();
                        },
                      );
                    })(),
                    const SizedBox(height: 6),
                    // Section Dropdown
                    (() {
                      Map<String, dynamic>? matchingClass;
                      for (final c in _classes) {
                        if (c is Map && c['id'] == _fromClassId) {
                          matchingClass = Map<String, dynamic>.from(c);
                          break;
                        }
                      }
                      final rawSecs = (matchingClass?['sections'] as List<dynamic>? ?? []);
                      final uniqueSecs = <int, Map<String, dynamic>>{};
                      for (final s in rawSecs) {
                        if (s is Map && s['id'] != null) {
                          uniqueSecs[s['id'] as int] = Map<String, dynamic>.from(s);
                        }
                      }
                      final items = [
                        const DropdownMenuItem<int?>(value: null, child: Text('All Sections', style: TextStyle(fontSize: 12))),
                        ...uniqueSecs.values.map((s) => DropdownMenuItem<int?>(
                              value: s['id'] as int?,
                              child: Text('Sec ${s['section_name']}', style: const TextStyle(fontSize: 12)),
                            )),
                      ];
                      final safeVal = uniqueSecs.containsKey(_fromSectionId) ? _fromSectionId : null;

                      return DropdownButtonFormField<int?>(
                        value: safeVal,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        items: items,
                        onChanged: (v) {
                          setState(() => _fromSectionId = v);
                          _loadSheet();
                        },
                      );
                    })(),
                  ],
                ),
              ),

              // Arrow Indicator
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, color: AppTheme.royalBlue, size: 24),
              ),

              // TO (Target)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TO TARGET (NEW YEAR)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.emerald)),
                    const SizedBox(height: 6),
                    // Target Class Dropdown
                    (() {
                      final uniqueClasses = <int, Map<String, dynamic>>{};
                      for (final c in _classes) {
                        if (c is Map && c['id'] != null) {
                          uniqueClasses[c['id'] as int] = Map<String, dynamic>.from(c);
                        }
                      }
                      final items = uniqueClasses.values.map<DropdownMenuItem<int>>((c) {
                        return DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(c['class_name'] ?? 'Class', style: const TextStyle(fontSize: 12)),
                        );
                      }).toList();
                      final safeVal = uniqueClasses.containsKey(_toClassId) ? _toClassId : (uniqueClasses.isNotEmpty ? uniqueClasses.keys.first : null);

                      return DropdownButtonFormField<int>(
                        value: safeVal,
                        isExpanded: true,
                        hint: const Text('Target Class', style: TextStyle(fontSize: 12)),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        items: items,
                        onChanged: (v) {
                          if (v == null) return;
                          final c = uniqueClasses[v];
                          final secs = (c?['sections'] as List<dynamic>? ?? []);
                          setState(() {
                            _toClassId = v;
                            _toSectionId = secs.isNotEmpty ? secs.first['id'] as int? : null;
                          });
                        },
                      );
                    })(),
                    const SizedBox(height: 6),
                    // Target Section Dropdown
                    (() {
                      Map<String, dynamic>? matchingClass;
                      for (final c in _classes) {
                        if (c is Map && c['id'] == _toClassId) {
                          matchingClass = Map<String, dynamic>.from(c);
                          break;
                        }
                      }
                      final rawSecs = (matchingClass?['sections'] as List<dynamic>? ?? []);
                      final uniqueSecs = <int, Map<String, dynamic>>{};
                      for (final s in rawSecs) {
                        if (s is Map && s['id'] != null) {
                          uniqueSecs[s['id'] as int] = Map<String, dynamic>.from(s);
                        }
                      }
                      final items = [
                        const DropdownMenuItem<int?>(value: null, child: Text('All Sec', style: TextStyle(fontSize: 12))),
                        ...uniqueSecs.values.map((s) => DropdownMenuItem<int?>(
                              value: s['id'] as int?,
                              child: Text('Sec ${s['section_name']}', style: const TextStyle(fontSize: 12)),
                            )),
                      ];
                      final safeVal = uniqueSecs.containsKey(_toSectionId) ? _toSectionId : null;

                      return DropdownButtonFormField<int?>(
                        value: safeVal,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        items: items,
                        onChanged: (v) => setState(() => _toSectionId = v),
                      );
                    })(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryBar(int promoting, int repeating, int graduating, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Roster', '${_students.length}', AppTheme.royalBlue),
          _divider(),
          _statItem('Promote', '$promoting', AppTheme.emerald),
          _divider(),
          _statItem('Repeat', '$repeating', AppTheme.amber),
          _divider(),
          _statItem('Graduate', '$graduating', AppTheme.purple),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 20, color: const Color(0xFFE2E8F0));
  }

  Widget _buildQuickActionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.done_all_rounded, size: 14),
            label: const Text('Promote All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _bulkSetAction('promote'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.format_list_numbered_rounded, size: 14),
            label: const Text('Auto-Roll Numbers', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _autoSequenceRollNumbers,
          ),
          const Spacer(),
          Text(
            '${_students.length} Students',
            style: const TextStyle(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList(bool isDark) {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_outlined, size: 48, color: AppTheme.grey),
            const SizedBox(height: 12),
            const Text(
              'No enrolled students found in selected class/section.',
              style: TextStyle(color: AppTheme.grey, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
      itemCount: _students.length,
      itemBuilder: (ctx, idx) {
        final s = _students[idx];
        return _buildStudentPromotionCard(s, idx, isDark);
      },
    );
  }

  Widget _buildStudentPromotionCard(Map<String, dynamic> s, int idx, bool isDark) {
    final action = s['action'] ?? 'promote';
    final photoUrl = s['photo_url'];
    final roll = s['current_roll_no'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _actionColor(action).withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.royalBlue.withOpacity(0.12),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        s['first_name'] != null ? s['first_name'][0].toUpperCase() : 'S',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.royalBlue, fontSize: 16),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Name & Roll
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['name'] ?? 'Student',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppTheme.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Roll #$roll • Adm #${s['admission_no']} • ${s['academic_standing']}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                    ),
                  ],
                ),
              ),

              // Target Roll Field
              SizedBox(
                width: 65,
                height: 34,
                child: TextFormField(
                  initialValue: s['suggested_roll_no']?.toString() ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    labelText: 'New Roll',
                    labelStyle: const TextStyle(fontSize: 9),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => s['suggested_roll_no'] = v.trim(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Action Selector Buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: 'Promote',
                  isSelected: action == 'promote',
                  color: AppTheme.emerald,
                  onTap: () => setState(() => s['action'] = 'promote'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionButton(
                  label: 'Repeat',
                  isSelected: action == 'repeat',
                  color: AppTheme.amber,
                  onTap: () => setState(() => s['action'] = 'repeat'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionButton(
                  label: 'Graduate',
                  isSelected: action == 'graduate',
                  color: AppTheme.purple,
                  onTap: () => setState(() => s['action'] = 'graduate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'promote':
        return AppTheme.emerald;
      case 'repeat':
        return AppTheme.amber;
      case 'graduate':
        return AppTheme.purple;
      default:
        return AppTheme.royalBlue;
    }
  }

  Widget _actionButton({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomExecutionButton(int promoting, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _isExecuting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.rocket_launch_rounded, size: 18),
            label: Text(
              _isExecuting ? 'Processing Progression...' : 'Execute Progression ($promoting Students)',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.royalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            onPressed: _isExecuting ? null : _executePromotion,
          ),
        ),
      ),
    );
  }
}
