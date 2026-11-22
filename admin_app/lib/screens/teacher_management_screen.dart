import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'teacher_form_screen.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({Key? key}) : super(key: key);

  @override
  State<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<dynamic> _teachers = [];
  Map<String, dynamic> _counts = {};
  List<dynamic> _classesOptions = [];

  String _filter = 'all'; // all, present, absent, class_teacher, unmarked
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getTeachers(),
      _api.getTeacherOptions(),
    ]);

    setState(() {
      _isLoading = false;
      final tRes = results[0];
      if (tRes.success && tRes.data != null) {
        final data = tRes.data as Map<String, dynamic>;
        _teachers = (data['data'] as List<dynamic>?) ?? [];
        _counts = (data['counts'] as Map<String, dynamic>?) ?? {};
      }

      final oRes = results[1];
      if (oRes.success && oRes.data != null) {
        final oData = oRes.data as Map<String, dynamic>;
        _classesOptions = (oData['classes'] as List<dynamic>?) ?? [];
      }
    });
  }

  List<dynamic> get _filteredTeachers {
    return _teachers.where((t) {
      // 1. Status Filter
      final status = t['status'] ?? 'unmarked';
      final isClassTeacher = t['is_class_teacher'] == true;

      if (_filter == 'present' && !(status == 'present' || status == 'late')) {
        return false;
      }
      if (_filter == 'absent' && !(status == 'absent' || status == 'leave')) {
        return false;
      }
      if (_filter == 'class_teacher' && !isClassTeacher) {
        return false;
      }
      if (_filter == 'unmarked' && status != 'unmarked') {
        return false;
      }

      // 2. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (t['name'] ?? '').toString().toLowerCase();
        final email = (t['email'] ?? '').toString().toLowerCase();
        final phone = (t['phone'] ?? '').toString().toLowerCase();

        final matchesInfo = name.contains(q) || email.contains(q) || phone.contains(q);

        final assigned = (t['assigned_classes'] as List<dynamic>?) ?? [];
        final matchesClasses = assigned.any((a) {
          final cName = (a['class_name'] ?? '').toString().toLowerCase();
          final sName = (a['section_name'] ?? '').toString().toLowerCase();
          final subName = (a['course_name'] ?? '').toString().toLowerCase();
          return cName.contains(q) || sName.contains(q) || subName.contains(q);
        });

        return matchesInfo || matchesClasses;
      }

      return true;
    }).toList();
  }

  String? _resolvePhotoUrl(dynamic rawUrl) {
    if (rawUrl == null) return null;
    final str = rawUrl.toString();
    if (str.isEmpty) return null;
    if (str.startsWith('http')) return str;
    final base = _api.baseUrl.replaceAll(RegExp(r'/api(/.*)?$'), '');
    return '$base/storage/${str.replaceFirst(RegExp(r'^/?storage/'), '').replaceFirst(RegExp(r'^/'), '')}';
  }

  // ===========================================================================
  // ADD TEACHER (FULL MULTI-SECTION FORM)
  // ===========================================================================
  Future<void> _showAddTeacherModal() async {
    final res = await TeacherFormScreen.open(context);
    if (res == true) {
      _loadData();
    }
  }

  // ===========================================================================
  // EDIT TEACHER (FULL MULTI-SECTION FORM)
  // ===========================================================================
  Future<void> _showEditTeacherModal(Map<String, dynamic> teacher) async {
    final res = await TeacherFormScreen.open(context, teacher: teacher);
    if (res == true) {
      _loadData();
    }
  }

  // ===========================================================================
  // ASSIGN CLASS MODAL
  // ===========================================================================
  void _showAssignClassModal(Map<String, dynamic> teacher) {
    int? selectedClassId;
    int? selectedSectionId;
    int? selectedCourseId;
    bool isClassTeacher = false;
    bool isAssigning = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedClassObj = _classesOptions.firstWhere(
            (c) => c['id'] == selectedClassId,
            orElse: () => null,
          );
          final sections = (selectedClassObj?['sections'] as List<dynamic>?) ?? [];
          final courses = (selectedClassObj?['courses'] as List<dynamic>?) ?? [];

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Class / Subject',
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'To: ${teacher['name']}',
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  (() {
                    final uniqueClasses = <int, Map<String, dynamic>>{};
                    for (final c in _classesOptions) {
                      if (c is Map && c['id'] != null) {
                        uniqueClasses[c['id'] as int] = Map<String, dynamic>.from(c);
                      }
                    }
                    final items = uniqueClasses.values.map<DropdownMenuItem<int>>((c) {
                      return DropdownMenuItem<int>(
                        value: c['id'] as int,
                        child: Text(c['class_name'] ?? 'Class'),
                      );
                    }).toList();
                    final safeVal = uniqueClasses.containsKey(selectedClassId) ? selectedClassId : null;

                    return DropdownButtonFormField<int>(
                      value: safeVal,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Class / Grade *', isDense: true),
                      hint: const Text('Select Class'),
                      items: items,
                      onChanged: (val) {
                        setModalState(() {
                          selectedClassId = val;
                          selectedSectionId = null;
                          selectedCourseId = null;
                        });
                      },
                    );
                  })(),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: (() {
                          final uniqueSecs = <int, Map<String, dynamic>>{};
                          for (final s in sections) {
                            if (s is Map && s['id'] != null) {
                              uniqueSecs[s['id'] as int] = Map<String, dynamic>.from(s);
                            }
                          }
                          final items = uniqueSecs.values.map<DropdownMenuItem<int>>((s) {
                            return DropdownMenuItem<int>(
                              value: s['id'] as int,
                              child: Text(s['section_name'] ?? 'Sec'),
                            );
                          }).toList();
                          final safeVal = uniqueSecs.containsKey(selectedSectionId) ? selectedSectionId : null;

                          return DropdownButtonFormField<int>(
                            value: safeVal,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Section *', isDense: true),
                            hint: const Text('Section'),
                            items: items,
                            onChanged: (val) => setModalState(() => selectedSectionId = val),
                          );
                        })(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                              child: Text(co['course_name'] ?? 'Course'),
                            );
                          }).toList();
                          final safeVal = uniqueCourses.containsKey(selectedCourseId) ? selectedCourseId : null;

                          return DropdownButtonFormField<int>(
                            value: safeVal,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Subject', isDense: true),
                            hint: const Text('Subject (opt)'),
                            items: items,
                            onChanged: (val) => setModalState(() => selectedCourseId = val),
                          );
                        })(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Appoint as Class Teacher', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: const Text('Grants class-teacher status for this specific section', style: TextStyle(fontSize: 11)),
                    value: isClassTeacher,
                    activeColor: AppTheme.emerald,
                    onChanged: (v) => setModalState(() => isClassTeacher = v),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: isAssigning
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                      label: Text(
                        isAssigning ? 'Assigning...' : 'Confirm Class Assignment',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      onPressed: isAssigning
                          ? null
                          : () async {
                              if (selectedClassId == null || selectedSectionId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select both Class and Section.')),
                                );
                                return;
                              }

                              setModalState(() => isAssigning = true);

                              final res = await _api.assignTeacherClass(teacher['id'] as int, {
                                'class_id': selectedClassId,
                                'section_id': selectedSectionId,
                                if (selectedCourseId != null) 'course_id': selectedCourseId,
                                'is_class_teacher': isClassTeacher,
                              });

                              setModalState(() => isAssigning = false);

                              if (res.success) {
                                Navigator.pop(ctx);
                                _loadData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res.message), backgroundColor: AppTheme.emerald),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TEACHER 360 PROFILE MODAL
  // ===========================================================================
  void _showTeacher360Modal(Map<String, dynamic> summary) async {
    final teacherId = summary['id'] as int;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<ApiResponse<Map<String, dynamic>>>(
          future: _api.getTeacherDetails(teacherId),
          builder: (ctx, snapshot) {
            final t = snapshot.data?.data ?? summary;
            final isDetailsLoading = snapshot.connectionState == ConnectionState.waiting;

            final status = t['status'] ?? 'unmarked';
            final statusColor = status == 'present' || status == 'late'
                ? AppTheme.emerald
                : (status == 'absent' || status == 'leave' ? AppTheme.crimson : AppTheme.textMuted);

            final assignedClasses = (t['assigned_classes'] as List<dynamic>?) ?? [];
            final qualifications = (t['qualifications'] as List<dynamic>?) ?? [];
            final routineSlots = (t['routine_slots'] as List<dynamic>?) ?? [];
            final isClassTeacher = t['is_class_teacher'] == true;

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Teacher 360° Profile',
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.borderLight),

                  // Content
                  Expanded(
                    child: isDetailsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Hero Profile Info
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 34,
                                      backgroundColor: AppTheme.royalBlue.withOpacity(0.12),
                                      backgroundImage: t['photo_url'] != null
                                          ? NetworkImage(_resolvePhotoUrl(t['photo_url'])!)
                                          : null,
                                      child: t['photo_url'] == null
                                          ? Text(
                                              (t['name'] ?? 'T')[0],
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.royalBlue,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  t['name'] ?? '',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              if (isClassTeacher) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.amber.withOpacity(0.18),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: const [
                                                      Icon(Icons.star_rounded, size: 12, color: AppTheme.amber),
                                                      SizedBox(width: 2),
                                                      Text(
                                                        'Class Teacher',
                                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.amber),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            t['email'] ?? 'No email',
                                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                                ),
                                              ),
                                              if (t['clock_in'] != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  'In: ${t['clock_in']}',
                                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                ),
                                              ],
                                              const Spacer(),
                                              if (t['phone'] != null && (t['phone'] as String).isNotEmpty)
                                                InkWell(
                                                  onTap: () => launchUrl(Uri.parse('tel:${t['phone']}')),
                                                  borderRadius: BorderRadius.circular(20),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.royalBlue.withOpacity(0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.phone_rounded, color: AppTheme.royalBlue, size: 18),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),
                                const Divider(height: 1, color: AppTheme.borderLight),
                                const SizedBox(height: 16),

                                // Details Grid
                                _sectionHeader('PERSONAL & EMPLOYMENT DETAILS'),
                                const SizedBox(height: 10),
                                _infoTile('Phone', t['phone'] ?? '-'),
                                _infoTile('Gender', t['gender'] ?? '-'),
                                _infoTile('Address', '${t['address'] ?? ''} ${t['city'] ?? ''}'.trim().isEmpty ? '-' : '${t['address'] ?? ''} ${t['city'] ?? ''}'.trim()),
                                if (t['basic_salary'] != null)
                                  _infoTile('Salary', 'NPR ${t['basic_salary']}'),
                                if (t['pan_no'] != null && (t['pan_no'] as String).isNotEmpty)
                                  _infoTile('PAN No.', t['pan_no']),

                                const SizedBox(height: 20),

                                // Assigned Classes & Subjects
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _sectionHeader('ASSIGNED CLASSES & SUBJECTS (${assignedClasses.length})'),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppTheme.royalBlue),
                                      label: const Text('Assign Class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalBlue)),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _showAssignClassModal(t);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (assignedClasses.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.borderLight),
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          const Icon(Icons.school_outlined, size: 32, color: AppTheme.textMuted),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'No classes currently assigned to this teacher.',
                                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.royalBlue,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                            label: const Text('Assign First Class', style: TextStyle(color: Colors.white, fontSize: 12)),
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _showAssignClassModal(t);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ...assignedClasses.map((ac) {
                                    final isCt = ac['is_class_teacher'] == true;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isCt ? AppTheme.amber.withOpacity(0.5) : AppTheme.borderLight,
                                          width: isCt ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: (isCt ? AppTheme.amber : AppTheme.royalBlue).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              isCt ? Icons.star_rounded : Icons.menu_book_rounded,
                                              size: 20,
                                              color: isCt ? AppTheme.amber : AppTheme.royalBlue,
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
                                                      '${ac['class_name']} - ${ac['section_name']}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                    if (isCt) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.amber.withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: const Text(
                                                          'CLASS TEACHER',
                                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.amber),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Subject: ${ac['course_name']}',
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.crimson, size: 20),
                                            tooltip: 'Remove Assignment',
                                            onPressed: () async {
                                              final assignmentId = ac['id'] as int;
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (dCtx) => AlertDialog(
                                                  title: const Text('Unassign Class?'),
                                                  content: Text('Remove ${ac['class_name']} - ${ac['section_name']} from ${t['name']}?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(dCtx, true),
                                                      style: TextButton.styleFrom(foregroundColor: AppTheme.crimson),
                                                      child: const Text('Remove'),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                final res = await _api.removeTeacherAssignment(teacherId, assignmentId);
                                                if (res.success) {
                                                  Navigator.pop(ctx);
                                                  _loadData();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Class unassigned successfully.'), backgroundColor: AppTheme.emerald),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),

                                const SizedBox(height: 20),

                                // Weekly Routine Periods
                                if (routineSlots.isNotEmpty) ...[
                                  _sectionHeader('ACTIVE TIMETABLE PERIODS (${routineSlots.length})'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: routineSlots.take(6).map((r) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${r['class_name']} (${r['start_time']}-${r['end_time']})',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Qualifications
                                if (qualifications.isNotEmpty) ...[
                                  _sectionHeader('QUALIFICATIONS'),
                                  const SizedBox(height: 8),
                                  ...qualifications.map((q) => Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.school_rounded, size: 18, color: AppTheme.royalBlue),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${q['title']} - ${q['institution'] ?? ''}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  const SizedBox(height: 20),
                                ],

                                // Actions
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.crimson,
                                          side: const BorderSide(color: AppTheme.crimson),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                        label: const Text('Remove Teacher'),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _confirmDeleteTeacher(t);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.royalBlue,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                                        label: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _showEditTeacherModal(t);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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

  // ===========================================================================
  // DELETE CONFIRMATION
  // ===========================================================================
  void _confirmDeleteTeacher(Map<String, dynamic> teacher) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
            SizedBox(width: 8),
            Text('Remove Teacher'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${teacher['name']} from the school app? All active class assignments and credentials will be deactivated.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimson,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.deleteTeacher(teacher['id'] as int);
              if (res.success) {
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res.message), backgroundColor: AppTheme.emerald),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
                );
              }
            },
            child: const Text('Confirm Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================
  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppTheme.royalBlue,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD SCREEN
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final list = _filteredTeachers;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Teacher Management',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: AppTheme.royalBlue),
            tooltip: 'Add Teacher',
            onPressed: _showAddTeacherModal,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.royalBlue,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Teacher', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: _showAddTeacherModal,
      ),
      body: _isLoading && _teachers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // 1. KPI Stats Cards
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _StatCard(
                          title: 'Total Faculty',
                          count: '${_counts['total'] ?? _teachers.length}',
                          color: AppTheme.royalBlue,
                          icon: Icons.people_alt_rounded,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          title: 'On Duty',
                          count: '${_counts['present'] ?? 0}',
                          color: AppTheme.emerald,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          title: 'Absent / Leave',
                          count: '${(_counts['absent'] ?? 0) + (_counts['on_leave'] ?? 0)}',
                          color: AppTheme.crimson,
                          icon: Icons.cancel_outlined,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          title: 'Class Teachers',
                          count: '${_counts['class_teachers'] ?? 0}',
                          color: AppTheme.amber,
                          icon: Icons.star_rounded,
                        ),
                      ],
                    ),
                  ),

                  // 2. Search Field
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by teacher name, phone, class or subject...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),

                  // 3. Status Filters
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterPill(
                            label: 'All (${_teachers.length})',
                            selected: _filter == 'all',
                            color: AppTheme.royalBlue,
                            onTap: () => setState(() => _filter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            label: 'On Duty (${_counts['present'] ?? 0})',
                            selected: _filter == 'present',
                            color: AppTheme.emerald,
                            onTap: () => setState(() => _filter = 'present'),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            label: 'Class Teachers (${_counts['class_teachers'] ?? 0})',
                            selected: _filter == 'class_teacher',
                            color: AppTheme.amber,
                            onTap: () => setState(() => _filter = 'class_teacher'),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            label: 'Absent (${(_counts['absent'] ?? 0) + (_counts['on_leave'] ?? 0)})',
                            selected: _filter == 'absent',
                            color: AppTheme.crimson,
                            onTap: () => setState(() => _filter = 'absent'),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            label: 'Unmarked (${_counts['unmarked'] ?? 0})',
                            selected: _filter == 'unmarked',
                            color: AppTheme.textMuted,
                            onTap: () => setState(() => _filter = 'unmarked'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1, color: AppTheme.borderLight),

                  // 4. Teacher List
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_search_rounded, size: 54, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'No teachers found',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Try adjusting your search or filter criteria.',
                                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: list.length,
                            itemBuilder: (ctx, idx) {
                              final t = list[idx];
                              final status = t['status'] ?? 'unmarked';
                              final statusColor = status == 'present' || status == 'late'
                                  ? AppTheme.emerald
                                  : (status == 'absent' || status == 'leave' ? AppTheme.crimson : AppTheme.textMuted);

                              final assigned = (t['assigned_classes'] as List<dynamic>?) ?? [];
                              final isClassTeacher = t['is_class_teacher'] == true;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isClassTeacher ? AppTheme.amber.withOpacity(0.4) : AppTheme.borderLight,
                                    width: isClassTeacher ? 1.4 : 1,
                                  ),
                                ),
                                elevation: 0.5,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showTeacher360Modal(t),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Avatar, Name, Status, Actions Menu
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
                                                  backgroundImage: t['photo_url'] != null
                                                      ? NetworkImage(_resolvePhotoUrl(t['photo_url'])!)
                                                      : null,
                                                  child: t['photo_url'] == null
                                                      ? Text(
                                                          (t['name'] ?? 'T')[0],
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppTheme.royalBlue,
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                Positioned(
                                                  right: 0,
                                                  bottom: 0,
                                                  child: Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: statusColor,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.white, width: 2),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          t['name'] ?? '',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                      if (isClassTeacher) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.amber.withOpacity(0.16),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: const [
                                                              Icon(Icons.star_rounded, size: 12, color: AppTheme.amber),
                                                              SizedBox(width: 2),
                                                              Text(
                                                                'Class Teacher',
                                                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.amber),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    t['email'] ?? t['phone'] ?? '',
                                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Status pill & Popup
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.textMuted),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              onSelected: (val) {
                                                if (val == 'view') {
                                                  _showTeacher360Modal(t);
                                                } else if (val == 'assign') {
                                                  _showAssignClassModal(t);
                                                } else if (val == 'edit') {
                                                  _showEditTeacherModal(t);
                                                } else if (val == 'delete') {
                                                  _confirmDeleteTeacher(t);
                                                }
                                              },
                                              itemBuilder: (pCtx) => [
                                                const PopupMenuItem(
                                                  value: 'view',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.badge_rounded, size: 18, color: AppTheme.royalBlue),
                                                      SizedBox(width: 8),
                                                      Text('View 360° Profile'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'assign',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.add_task_rounded, size: 18, color: AppTheme.emerald),
                                                      SizedBox(width: 8),
                                                      Text('Assign Class / Subject'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit_rounded, size: 18, color: AppTheme.royalBlue),
                                                      SizedBox(width: 8),
                                                      Text('Edit Profile'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.crimson),
                                                      SizedBox(width: 8),
                                                      Text('Remove Teacher', style: TextStyle(color: AppTheme.crimson)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // Assigned classes chips
                                        if (assigned.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: assigned.take(3).map((a) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.school_outlined, size: 12, color: AppTheme.royalBlue),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${a['class_name']}-${a['section_name']} (${a['course_name']})',
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList()
                                              ..addAll(assigned.length > 3
                                                  ? [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          '+${assigned.length - 3} more',
                                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                                                        ),
                                                      )
                                                    ]
                                                  : []),
                                          ),
                                        ],

                                        // Quick Call and Details Row
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            if (t['phone'] != null && (t['phone'] as String).isNotEmpty)
                                              InkWell(
                                                onTap: () => launchUrl(Uri.parse('tel:${t['phone']}')),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.call_rounded, size: 14, color: AppTheme.royalBlue),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      t['phone'],
                                                      style: const TextStyle(fontSize: 11, color: AppTheme.royalBlue, fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              const Text('No phone registered', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                            const Spacer(),
                                            Text(
                                              'Tap to view 360 card',
                                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted.withOpacity(0.8), fontStyle: FontStyle.italic),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.textMuted),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

// =============================================================================
// SUB-WIDGETS
// =============================================================================
class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 16, color: color),
                Text(
                  count,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.14) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? color : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
