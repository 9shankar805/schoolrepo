import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/hr_leave_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'teacher_management_screen.dart';

class StaffMonitorScreen extends StatefulWidget {
  const StaffMonitorScreen({Key? key}) : super(key: key);

  @override
  State<StaffMonitorScreen> createState() => _StaffMonitorScreenState();
}

class _StaffMonitorScreenState extends State<StaffMonitorScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String _rosterFilter = 'all'; // all | present | absent | unmarked

  // Quick Message tab
  String _msgTarget = 'teachers';
  final _msgSubjectCtrl = TextEditingController();
  final _msgBodyCtrl = TextEditingController();
  bool _isSendingMsg = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStaff();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HrLeaveProvider>().fetchLeaveApplications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _msgSubjectCtrl.dispose();
    _msgBodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoading = true);
    final res = await _api.getStaffOverview();
    setState(() {
      _isLoading = false;
      if (res.success) _data = res.data;
    });
  }

  void _openTeacherManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TeacherManagementScreen()),
    ).then((_) => _fetchStaff());
  }

  void _showStaffProfileSheet(Map<String, dynamic> t) {
    final status = t['status'] ?? 'unmarked';
    final statusColor = status == 'present' || status == 'late'
        ? AppTheme.emerald
        : (status == 'absent' || status == 'leave'
            ? AppTheme.crimson
            : AppTheme.textMuted);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(child: AppTheme.iosHandle()),
            const SizedBox(height: 20),
            // Avatar + name
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Text(
                    (t['name'] as String? ?? 'T')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['name'] ?? 'Staff Member',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t['subject'] ?? t['designation'] ?? 'Teacher',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            // Details
            _DetailRow(
                icon: Icons.email_rounded,
                label: 'Email',
                value: t['email'] ?? '—'),
            _DetailRow(
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: t['phone'] ?? '—'),
            _DetailRow(
                icon: Icons.class_rounded,
                label: 'Subjects',
                value: t['subjects'] ?? t['subject'] ?? '—'),
            _DetailRow(
                icon: Icons.today_rounded,
                label: "Today's Periods",
                value: '${t['periods_today'] ?? 0}'),
            const SizedBox(height: 20),
            // Actions
            Row(
              children: [
                if (t['phone'] != null &&
                    (t['phone'] as String).isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone_rounded, size: 16),
                      label: const Text('Call'),
                      onPressed: () =>
                          launchUrl(Uri.parse('tel:${t['phone']}')),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    icon:
                        const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Assign Sub'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalBlue),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showQuickSubstituteDialog(t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                label: const Text('Open Full Profile & Edit'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openTeacherManagement();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickSubstituteDialog(Map<String, dynamic> absentTeacher) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Mark Substitution',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Absent: ${absentTeacher['name']}',
              style: const TextStyle(
                  color: AppTheme.crimson,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text('Substitution notes (optional):',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Cover Mathematics Chapter 5 revision',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.assignSubstitute(
                0, // routine_id — 0 means general absence mark
                absentTeacher['id'] ?? 0,
                notes: notesCtrl.text.trim().isEmpty
                    ? 'Absent — substitution recorded'
                    : notesCtrl.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res.message),
                  backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendStaffMessage() async {
    final subject = _msgSubjectCtrl.text.trim();
    final body = _msgBodyCtrl.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in subject and message.')),
      );
      return;
    }
    setState(() => _isSendingMsg = true);
    final res = await _api.sendBroadcast(
      title: subject,
      message: body,
      targetGroup: _msgTarget,
      isEmergency: false,
    );
    setState(() => _isSendingMsg = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
      ));
      if (res.success) {
        _msgSubjectCtrl.clear();
        _msgBodyCtrl.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _data?['counts'] ?? {};
    final List<dynamic> roster =
        (_data?['roster'] as List<dynamic>?) ?? [];
    final filtered = roster.where((t) {
      if (_rosterFilter == 'present')
        return t['status'] == 'present' || t['status'] == 'late';
      if (_rosterFilter == 'absent')
        return t['status'] == 'absent' || t['status'] == 'leave';
      if (_rosterFilter == 'unmarked') return t['status'] == 'unmarked';
      return true;
    }).toList();

    final hrLeave = context.watch<HrLeaveProvider>();
    final pendingLeaves = hrLeave.pendingCount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Staff & Teacher Roster',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              _fetchStaff();
              hrLeave.fetchLeaveApplications();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.manage_accounts_rounded,
                  size: 16, color: Colors.white),
              label: const Text('Manage',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              onPressed: _openTeacherManagement,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: [
            const Tab(text: 'Roster'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Leave Requests'),
                  if (pendingLeaves > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.crimson,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingLeaves',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const Tab(text: 'Quick Message'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.royalBlue,
        elevation: 4,
        icon: const Icon(Icons.manage_accounts_rounded, color: Colors.white),
        label: const Text('Manage Teachers',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: _openTeacherManagement,
      ),
      body: _isLoading && _data == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRosterTab(counts, filtered),
                _buildLeaveTab(hrLeave),
                _buildMessageTab(),
              ],
            ),
    );
  }

  // ── Tab 1: Roster ───────────────────────────────────────────────────────────
  Widget _buildRosterTab(
      Map<String, dynamic> counts, List<dynamic> filtered) {
    return RefreshIndicator(
      onRefresh: _fetchStaff,
      child: Column(
        children: [
          // Teacher Management Hub Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.royalBlue.withOpacity(0.08),
                  AppTheme.royalBlue.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.royalBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.royalBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.badge_rounded,
                      color: AppTheme.royalBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teacher Management Hub',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Add faculty, edit profiles, assign classes or remove teachers.',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.royalBlue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _openTeacherManagement,
                  child: const Text(
                    'Open',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Filter chips
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _FilterChip(
                  label: 'All (${counts['total'] ?? 0})',
                  selected: _rosterFilter == 'all',
                  onTap: () => setState(() => _rosterFilter = 'all'),
                  color: AppTheme.royalBlue,
                ),
                _FilterChip(
                  label: 'Present (${counts['present'] ?? 0})',
                  selected: _rosterFilter == 'present',
                  onTap: () => setState(() => _rosterFilter = 'present'),
                  color: AppTheme.emerald,
                ),
                _FilterChip(
                  label:
                      'Absent (${(counts['absent'] ?? 0) + (counts['on_leave'] ?? 0)})',
                  selected: _rosterFilter == 'absent',
                  onTap: () => setState(() => _rosterFilter = 'absent'),
                  color: AppTheme.crimson,
                ),
                _FilterChip(
                  label: 'Unmarked (${counts['unmarked'] ?? 0})',
                  selected: _rosterFilter == 'unmarked',
                  onTap: () =>
                      setState(() => _rosterFilter = 'unmarked'),
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderLight),

          // Staff list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 44, color: AppTheme.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No staff members match the filter.',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final t = filtered[idx];
                      final status = t['status'] ?? 'unmarked';
                      final statusColor = status == 'present' ||
                              status == 'late'
                          ? AppTheme.emerald
                          : (status == 'absent' || status == 'leave'
                              ? AppTheme.crimson
                              : AppTheme.textMuted);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          onTap: () => _showStaffProfileSheet(t),
                          leading: CircleAvatar(
                            backgroundColor:
                                statusColor.withOpacity(0.12),
                            child: Text(
                              (t['name'] as String? ?? 'T')[0]
                                  .toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: statusColor),
                            ),
                          ),
                          title: Text(
                            t['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          subtitle: Text(
                            t['subject'] ??
                                t['email'] ??
                                t['phone'] ??
                                '',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      statusColor.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10),
                                ),
                              ),
                              if (t['phone'] != null &&
                                  (t['phone'] as String)
                                      .isNotEmpty) ...[
                                const SizedBox(width: 4),
                                InkWell(
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  onTap: () => launchUrl(
                                      Uri.parse('tel:${t['phone']}')),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.phone,
                                        size: 18,
                                        color: AppTheme.royalBlue),
                                  ),
                                ),
                              ],
                              const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: AppTheme.textMuted),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Leave Requests ───────────────────────────────────────────────────
  Widget _buildLeaveTab(HrLeaveProvider hrLeave) {
    if (hrLeave.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final leaves = hrLeave.leaveApplications;

    return RefreshIndicator(
      onRefresh: hrLeave.fetchLeaveApplications,
      child: Column(
        children: [
          // Filter bar
          Container(
            height: 48,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['all', 'pending', 'approved', 'rejected']
                  .map((s) => Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(s[0].toUpperCase() + s.substring(1)),
                          selected: hrLeave.filterStatus == s,
                          selectedColor:
                              AppTheme.royalBlue.withOpacity(0.15),
                          onSelected: (_) => hrLeave.setFilter(s),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hrLeave.filterStatus == s
                                ? AppTheme.royalBlue
                                : AppTheme.textMuted,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: leaves.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_available,
                            size: 48, color: AppTheme.emerald),
                        const SizedBox(height: 10),
                        Text(
                          'No leave requests found.',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: leaves.length,
                    itemBuilder: (ctx, idx) {
                      final l = leaves[idx];
                      final status = l['status'] ?? 'pending';
                      final statusColor = status == 'approved'
                          ? AppTheme.emerald
                          : (status == 'rejected'
                              ? AppTheme.crimson
                              : AppTheme.gold);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      l['user_name'] ??
                                          l['staff_name'] ??
                                          'Staff Member',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          statusColor.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${l['leave_type'] ?? 'Leave'} • ${l['from_date'] ?? ''} to ${l['to_date'] ?? ''}  (${l['total_days'] ?? 1} days)',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted),
                              ),
                              if ((l['reason'] ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  l['reason'],
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMain),
                                ),
                              ],
                              if (status == 'pending') ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _handleLeaveAction(
                                                hrLeave,
                                                l['id'],
                                                'rejected'),
                                        style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppTheme.crimson),
                                        child:
                                            const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _handleLeaveAction(
                                                hrLeave,
                                                l['id'],
                                                'approved'),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.emerald),
                                        child: const Text('Approve'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLeaveAction(
      HrLeaveProvider hrLeave, dynamic id, String action) async {
    final ok = action == 'approved'
        ? await hrLeave.approveLeave(id as int)
        : await hrLeave.rejectLeave(id as int);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(ok ? 'Leave $action successfully.' : hrLeave.error ?? 'Failed'),
        backgroundColor: ok ? AppTheme.emerald : AppTheme.crimson,
      ));
    }
  }

  // ── Tab 3: Quick Message ────────────────────────────────────────────────────
  Widget _buildMessageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.royalBlue.withOpacity(0.07),
                  AppTheme.secondary.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.royalBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded,
                    color: AppTheme.royalBlue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff Broadcast Message',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const Text(
                        'Send an immediate push notification to selected staff group.',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Send To',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _msgTarget,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                      value: 'teachers',
                      child: Text('Teaching Staff Only')),
                  DropdownMenuItem(
                      value: 'all',
                      child: Text('All Staff (Teaching + Support)')),
                  DropdownMenuItem(
                      value: 'parents',
                      child: Text('Parents & Guardians')),
                ],
                onChanged: (val) => setState(() => _msgTarget = val!),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Subject',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _msgSubjectCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Staff Meeting — Monday 2 PM',
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.borderLight),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Message',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _msgBodyCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              hintText:
                  'Type your message to staff here...',
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.borderLight),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSendingMsg ? null : _sendStaffMessage,
              icon: _isSendingMsg
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Send Staff Broadcast'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalBlue),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.royalBlue),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textMuted)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMain)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? color : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
