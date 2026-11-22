import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'routine_maker_screen.dart';

class CoordinatorHubScreen extends StatefulWidget {
  const CoordinatorHubScreen({Key? key}) : super(key: key);

  @override
  State<CoordinatorHubScreen> createState() => _CoordinatorHubScreenState();
}

class _CoordinatorHubScreenState extends State<CoordinatorHubScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic>? _subData;
  List<dynamic> _questionPapers = [];
  List<dynamic> _syllabi = [];
  bool _marksWindowOpen = false;
  bool _isTogglingMarks = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getCoordinatorSubstitutions(),
      _api.getQuestionPapers(),
      _api.getCoordinatorSyllabi(),
    ]);

    setState(() {
      _isLoading = false;
      if (results[0].success && results[0].data != null) {
        _subData = results[0].data as Map<String, dynamic>;
        _marksWindowOpen = _subData?['summary']?['marks_window_open'] ?? false;
      }
      if (results[1].success && results[1].data != null) {
        final qp = results[1].data as Map<String, dynamic>;
        _questionPapers = qp['data'] ?? [];
      }
      if (results[2].success && results[2].data != null) {
        _syllabi = results[2].data as List<dynamic>;
      }
    });
  }

  Future<void> _handleToggleMarks(bool open) async {
    setState(() => _isTogglingMarks = true);
    final res = await _api.toggleMarksWindow(open);
    setState(() {
      _isTogglingMarks = false;
      if (res.success) {
        _marksWindowOpen = open;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: open ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
    }
  }

  void _showAssignSubstituteDialog(Map<String, dynamic> slot) {
    final List<dynamic> subs = slot['recommended_substitutes'] ?? [];
    int? selectedSubId = subs.isNotEmpty ? subs[0]['id'] : null;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Assign Substitution',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${slot['class_name']} • ${slot['subject_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Time: ${slot['start_time']} - ${slot['end_time']} (Room: ${slot['room']})', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              Text('Absent: ${slot['original_teacher']}', style: const TextStyle(fontSize: 12, color: AppTheme.crimson)),
              const Divider(height: 20),
              const Text('Select Free Teacher for this Period:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              if (subs.isEmpty)
                const Text('No free teachers available during this time slot.', style: TextStyle(color: AppTheme.crimson, fontSize: 12))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderLight),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: (() {
                      final uniqueSubs = <int, Map<String, dynamic>>{};
                      for (final t in subs) {
                        if (t is Map && t['id'] != null) {
                          uniqueSubs[t['id'] as int] = Map<String, dynamic>.from(t);
                        }
                      }
                      final items = uniqueSubs.values.map<DropdownMenuItem<int>>((t) {
                        return DropdownMenuItem<int>(
                          value: t['id'],
                          child: Text('${t['name']} (Free)', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList();
                      final safeValue = uniqueSubs.containsKey(selectedSubId)
                          ? selectedSubId
                          : (uniqueSubs.isNotEmpty ? uniqueSubs.keys.first : null);

                      return DropdownButton<int>(
                        value: safeValue,
                        isExpanded: true,
                        items: items,
                        onChanged: (val) => setDialogState(() => selectedSubId = val),
                      );
                    })(),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  hintText: 'Add note (e.g. Conduct chapter 4 test)...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedSubId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final res = await _api.assignSubstitute(
                        slot['routine_id'],
                        selectedSubId!,
                        notes: notesController.text.trim(),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                          ),
                        );
                        if (res.success) _loadAll();
                      }
                    },
              child: const Text('Confirm Substitution'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewPaperDialog(Map<String, dynamic> paper, String action) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          action == 'approve' ? 'Approve Question Paper' : 'Return for Revision',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${paper['title']} — ${paper['subject']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${paper['class_label']} • ${paper['exam_name']}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 14),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                hintText: action == 'approve' ? 'Optional coordinator remarks...' : 'Specify required question changes...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.reviewQuestionPaper(paper['id'], action, notes: notesController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.message),
                    backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                  ),
                );
                if (res.success) _loadAll();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: action == 'approve' ? AppTheme.emerald : AppTheme.crimson),
            child: Text(action == 'approve' ? 'Approve for Exam' : 'Return to Teacher'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> vacantSlots = _subData?['vacant_slots'] ?? [];
    final summary = _subData?['summary'] ?? {};

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Academic Coordinator Control',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.royalBlue),
            tooltip: 'Routine & Timetable Studio',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoutineMakerScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: [
            Tab(text: 'Substitution (${vacantSlots.length})'),
            Tab(text: 'Papers (${_questionPapers.length})'),
            const Tab(text: 'Gradebook Control'),
            const Tab(text: 'Syllabus'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Substitution
                _buildSubstitutionTab(vacantSlots, summary),
                // Tab 2: Question Papers
                _buildPapersTab(),
                // Tab 3: Marks Window
                _buildGradebookTab(),
                // Tab 4: Syllabus
                _buildSyllabusTab(),
              ],
            ),
    );
  }

  Widget _buildSubstitutionTab(List<dynamic> vacantSlots, Map<String, dynamic> summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('${summary['absent_teachers_count'] ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.crimson)),
                    const Text('Absent Teachers', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
                Container(width: 1, height: 35, color: AppTheme.borderLight),
                Column(
                  children: [
                    Text('${summary['vacant_periods_today'] ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.gold)),
                    const Text('Periods Requiring Cover', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Vacant Periods Today',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (vacantSlots.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, size: 44, color: AppTheme.emerald),
                  const SizedBox(height: 8),
                  Text('All Classes Covered Today', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('No teachers are reported absent for active routine periods.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            )
          else
            ...vacantSlots.map((slot) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${slot['class_name']} — ${slot['subject_name']}',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.crimsonLight, borderRadius: BorderRadius.circular(6)),
                            child: const Text('NEEDS COVER', style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Time: ${slot['start_time']} - ${slot['end_time']} • Room: ${slot['room']}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text('Absent Teacher: ${slot['original_teacher']}', style: const TextStyle(fontSize: 12, color: AppTheme.crimson)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAssignSubstituteDialog(slot),
                          icon: const Icon(Icons.person_add_alt_1, size: 16),
                          label: const Text('Assign Free Substitute Teacher'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
                        ),
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

  Widget _buildPapersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _questionPapers.length,
      itemBuilder: (ctx, idx) {
        final p = _questionPapers[idx];
        final isApproved = p['status'] == 'approved';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        p['title'] ?? 'Question Paper',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved ? AppTheme.emeraldLight : AppTheme.goldLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (p['status'] as String).toUpperCase(),
                        style: TextStyle(
                          color: isApproved ? AppTheme.emerald : AppTheme.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${p['class_label']} • ${p['subject']} • ${p['exam_name']}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                Text(
                  'Full Marks: ${p['full_marks']} • Pass Marks: ${p['pass_marks']} • Duration: ${p['duration']}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                if (!isApproved)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showReviewPaperDialog(p, 'reject'),
                          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.crimson),
                          child: const Text('Return / Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showReviewPaperDialog(p, 'approve'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                          child: const Text('Approve for Exam'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradebookTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teacher Gradebook Marks Window',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _marksWindowOpen
                                ? 'STATUS: OPEN — Subject teachers are currently permitted to submit and modify marks in their mobile apps.'
                                : 'STATUS: LOCKED — Marks submission is closed. Teachers cannot alter gradebook entries.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _marksWindowOpen ? AppTheme.emerald : AppTheme.crimson,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _isTogglingMarks
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : Switch(
                            value: _marksWindowOpen,
                            activeColor: AppTheme.emerald,
                            onChanged: (val) => _handleToggleMarks(val),
                          ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Operational Guidelines for Academic Coordinators',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '• Keep the marks submission window locked during regular teaching weeks.\n• Open the window for 5–7 days following terminal examination weeks to collect teacher marksheets.\n• Once all grades are vetted, close the window before final report cards are generated.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusTab() {
    if (_syllabi.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_rounded, size: 56, color: AppTheme.emerald),
              const SizedBox(height: 12),
              Text(
                'All Syllabi On Track',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text(
                'No syllabus items have been reported behind schedule.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _syllabi.length,
      itemBuilder: (ctx, idx) {
        final s = _syllabi[idx];
        final pct = (s['completion_percentage'] as num?)?.toDouble() ?? 0.0;
        final status = s['status'] ?? 'On Track';
        final statusColor = status == 'Completed'
            ? AppTheme.emerald
            : (status == 'Delayed' ? AppTheme.crimson : AppTheme.royalBlue);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        s['subject_name'] ?? s['course_name'] ?? 'Subject',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${s['class_name'] ?? ''} • ${s['teacher_name'] ?? 'Unassigned'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 8,
                          backgroundColor: AppTheme.borderLight,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${pct.toInt()}%',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: statusColor),
                    ),
                  ],
                ),
                if ((s['topics_covered'] ?? 0) > 0 ||
                    (s['total_topics'] ?? 0) > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${s['topics_covered'] ?? 0} of ${s['total_topics'] ?? 0} topics completed',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
