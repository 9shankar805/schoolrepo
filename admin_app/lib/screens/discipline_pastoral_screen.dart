import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DisciplinePastoralScreen extends StatefulWidget {
  const DisciplinePastoralScreen({Key? key}) : super(key: key);

  @override
  State<DisciplinePastoralScreen> createState() => _DisciplinePastoralScreenState();
}

class _DisciplinePastoralScreenState extends State<DisciplinePastoralScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  // Incidents State
  bool _incidentsLoading = true;
  List<dynamic> _incidents = [];
  String _selectedSeverity = 'all'; // 'all', 'minor', 'moderate', 'major'
  String _selectedStatus = 'all';   // 'all', 'pending_sign_off', 'unresolved', 'resolved', 'suspension'
  final TextEditingController _incidentSearchCtrl = TextEditingController();

  Map<String, dynamic> _kpis = {
    'total_incidents': 0,
    'pending_sign_off': 0,
    'unresolved': 0,
    'suspensions_active': 0,
    'total_commendations': 0,
  };

  // Commendations / Merits State
  bool _achievementsLoading = true;
  List<dynamic> _achievements = [];
  String _selectedCategory = 'all'; // 'all', 'academic', 'sports', 'arts', 'science', 'leadership', 'community'
  String _selectedLevel = 'all';    // 'all', 'school', 'district', 'state', 'national', 'international'
  final TextEditingController _achievementSearchCtrl = TextEditingController();

  // Presets
  static const List<String> _incidentTypes = [
    'Tardiness / Truancy',
    'Uniform & Dress Defiance',
    'Classroom Disturbance',
    'Insubordination / Disrespect',
    'Bullying & Harassment',
    'Physical Altercation / Fighting',
    'Vandalism & Campus Damage',
    'Digital / Phone Policy Breach',
    'Academic Dishonesty / Cheating',
    'Substance / Contraband Violation',
    'Other Behavioral Infraction',
  ];

  static const List<String> _actionTakenPresets = [
    'Verbal Warning & Counseling',
    'Written Reprimand on Record',
    'Parent Conference Scheduled',
    'Detention (After School - 1hr)',
    'Behavioral Improvement Contract',
    'Counseling & Pastoral Referral',
    'In-School Suspension (1-3 Days)',
    'Out-of-School Suspension',
    'Loss of Campus Privileges',
    'Community Service / Campus Work',
  ];

  static const List<String> _parentNotificationPresets = [
    'Phone Call Completed',
    'In-Person Meeting Conducted',
    'Official Letter / Notice Sent',
    'SMS Notification Dispatched',
    'Pending Guardian Outreach',
  ];

  static const Map<String, String> _categoryLabels = {
    'academic': 'Academic Excellence',
    'sports': 'Sports & Athletics',
    'arts': 'Arts & Culture',
    'science': 'Science & STEM',
    'community': 'Community Service',
    'leadership': 'Leadership & Council',
    'competition': 'Competitive Honors',
    'other': 'General Merit',
  };

  static const List<String> _awardTypes = [
    'Gold Medal',
    'Silver Medal',
    'Bronze Medal',
    'Championship Trophy',
    'Certificate of Excellence',
    'Honor Roll Badge',
    'Leadership Star of Month',
    'Exemplary Conduct Citation',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadOverview();
    _loadIncidents();
    _loadAchievements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _incidentSearchCtrl.dispose();
    _achievementSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    final res = await _api.getDisciplineOverview();
    if (res.success && res.data != null) {
      if (mounted) {
        setState(() {
          _kpis = (res.data!['kpis'] as Map<String, dynamic>?) ?? _kpis;
        });
      }
    }
  }

  Future<void> _loadIncidents() async {
    setState(() => _incidentsLoading = true);
    final isSuspensionFilter = _selectedStatus == 'suspension';
    final statusParam = isSuspensionFilter ? 'unresolved' : _selectedStatus;

    final res = await _api.getDisciplinaryIncidents(
      severity: _selectedSeverity == 'all' ? null : _selectedSeverity,
      status: statusParam == 'all' ? null : statusParam,
      search: _incidentSearchCtrl.text.trim().isEmpty ? null : _incidentSearchCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _incidentsLoading = false;
        if (res.success && res.data != null) {
          if (isSuspensionFilter) {
            _incidents = (res.data ?? []).where((item) {
              final act = (item['action_taken'] ?? '').toString().toLowerCase();
              return act.contains('suspension') || act.contains('suspend');
            }).toList();
          } else {
            _incidents = res.data ?? [];
          }
        } else {
          _incidents = [];
        }
      });
    }
  }

  Future<void> _loadAchievements() async {
    setState(() => _achievementsLoading = true);
    final res = await _api.getAchievements(
      category: _selectedCategory == 'all' ? null : _selectedCategory,
      level: _selectedLevel == 'all' ? null : _selectedLevel,
      search: _achievementSearchCtrl.text.trim().isEmpty ? null : _achievementSearchCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _achievementsLoading = false;
        if (res.success && res.data != null) {
          _achievements = res.data ?? [];
        } else {
          _achievements = [];
        }
      });
    }
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No guardian contact number recorded.')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not place call to $phone')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD SCREEN
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pendingCount = (_kpis['pending_sign_off'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pastoral Care & Merits',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.dark,
              ),
            ),
            Text(
              'Behavioral Tracking, Suspensions & Commendations',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppTheme.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded, color: AppTheme.gold),
            tooltip: 'Merit Leaderboard',
            onPressed: _showLeaderboardSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            tooltip: 'Refresh',
            onPressed: () {
              _loadOverview();
              _loadIncidents();
              _loadAchievements();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('Discipline & Logs'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.crimson,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                  const Icon(Icons.emoji_events_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('Merits & Honors'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDisciplineTab(),
          _buildMeritsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: _tabController.index == 0 ? AppTheme.primary : AppTheme.secondary,
        icon: Icon(_tabController.index == 0 ? Icons.add_moderator_rounded : Icons.star_rounded, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Log Incident' : 'Award Merit',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showLogIncidentSheet();
          } else {
            _showAwardMeritSheet();
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: DISCIPLINARY INCIDENTS & SUSPENSIONS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDisciplineTab() {
    final pendingSignOff = (_kpis['pending_sign_off'] as int?) ?? 0;
    final activeSuspensions = (_kpis['suspensions_active'] as int?) ?? 0;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadOverview();
        await _loadIncidents();
      },
      child: CustomScrollView(
        slivers: [
          // Telemetry Ribbon
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryCard(
                          title: 'Total Incidents',
                          count: '${_kpis['total_incidents'] ?? 0}',
                          subtitle: 'All time logs',
                          color: AppTheme.primary,
                          icon: Icons.assignment_late_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTelemetryCard(
                          title: 'Pending Sign-Off',
                          count: '$pendingSignOff',
                          subtitle: 'Awaiting Principal',
                          color: pendingSignOff > 0 ? AppTheme.amber : AppTheme.emerald,
                          icon: Icons.approval_outlined,
                          isAlert: pendingSignOff > 0,
                          onTap: () {
                            setState(() => _selectedStatus = 'pending_sign_off');
                            _loadIncidents();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryCard(
                          title: 'Active Suspensions',
                          count: '$activeSuspensions',
                          subtitle: 'Excluded / In-School',
                          color: activeSuspensions > 0 ? AppTheme.crimson : AppTheme.grey,
                          icon: Icons.gavel_rounded,
                          isAlert: activeSuspensions > 0,
                          onTap: () {
                            setState(() => _selectedStatus = 'suspension');
                            _loadIncidents();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTelemetryCard(
                          title: 'Unresolved Cases',
                          count: '${_kpis['unresolved'] ?? 0}',
                          subtitle: 'Under monitoring',
                          color: AppTheme.blue,
                          icon: Icons.pending_actions_outlined,
                          onTap: () {
                            setState(() => _selectedStatus = 'unresolved');
                            _loadIncidents();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Filters & Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _incidentSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search student, roll, or infraction...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.grey),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.grey, size: 20),
                        suffixIcon: _incidentSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _incidentSearchCtrl.clear();
                                  _loadIncidents();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _loadIncidents(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Status', 'all', _selectedStatus, (val) {
                          setState(() => _selectedStatus = val);
                          _loadIncidents();
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Pending Sign-Off', 'pending_sign_off', _selectedStatus, (val) {
                          setState(() => _selectedStatus = val);
                          _loadIncidents();
                        }, badge: pendingSignOff > 0 ? '$pendingSignOff' : null),
                        const SizedBox(width: 6),
                        _buildFilterChip('Suspensions', 'suspension', _selectedStatus, (val) {
                          setState(() => _selectedStatus = val);
                          _loadIncidents();
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Unresolved', 'unresolved', _selectedStatus, (val) {
                          setState(() => _selectedStatus = val);
                          _loadIncidents();
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Resolved', 'resolved', _selectedStatus, (val) {
                          setState(() => _selectedStatus = val);
                          _loadIncidents();
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Severity Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text('Severity: ', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.grey)),
                        const SizedBox(width: 4),
                        _buildSeverityFilterChip('All', 'all'),
                        const SizedBox(width: 6),
                        _buildSeverityFilterChip('Minor', 'minor', color: AppTheme.blue),
                        const SizedBox(width: 6),
                        _buildSeverityFilterChip('Moderate', 'moderate', color: AppTheme.amber),
                        const SizedBox(width: 6),
                        _buildSeverityFilterChip('Severe', 'major', color: AppTheme.crimson),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Incidents List
          if (_incidentsLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_incidents.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined, size: 56, color: AppTheme.emerald.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text(
                        'No Disciplinary Incidents Found',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.dark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Student conduct is in good standing with selected filters.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _incidents[index];
                    return _buildIncidentCard(item);
                  },
                  childCount: _incidents.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(dynamic item) {
    final int id = item['id'] ?? 0;
    final String sName = item['student_name'] ?? 'Unknown Student';
    final String classSec = item['class_section'] ?? 'Class';
    final String admNo = item['student_admission_no'] ?? '-';
    final String severity = (item['severity'] ?? 'minor').toString().toLowerCase();
    final String type = item['incident_type'] ?? 'Infraction';
    final String dateLabel = item['incident_date_label'] ?? 'N/A';
    final String timeAgo = item['incident_time_ago'] ?? '';
    final String description = item['description'] ?? '';
    final String actionTaken = item['action_taken'] ?? 'Under Review';
    final String reporter = item['reported_by_name'] ?? 'Faculty';
    final String parentNotified = item['parent_notified'] ?? 'Pending';
    final bool resolved = (item['resolved'] as bool?) ?? false;
    final bool isSignedOff = (item['is_signed_off'] as bool?) ?? false;
    final String? signerName = item['signed_off_by_name'];
    final String? signedAt = item['signed_off_at'];
    final String? executiveNotes = item['executive_notes'];
    final String? guardianPhone = item['guardian_phone'];

    final isSuspension = actionTaken.toLowerCase().contains('suspension') || actionTaken.toLowerCase().contains('suspend');

    // Severity styling
    Color severityColor = AppTheme.blue;
    String severityLabel = 'MINOR';
    if (severity == 'major') {
      severityColor = AppTheme.crimson;
      severityLabel = 'SEVERE / MAJOR';
    } else if (severity == 'moderate') {
      severityColor = AppTheme.amber;
      severityLabel = 'MODERATE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuspension ? AppTheme.crimson.withOpacity(0.4) : (!isSignedOff ? AppTheme.amber.withOpacity(0.3) : Colors.grey.shade200),
          width: isSuspension ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Student Info & Severity Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: severityColor.withOpacity(0.12),
                  child: Text(
                    sName.isNotEmpty ? sName[0].toUpperCase() : 'S',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: severityColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sName,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            classSec,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            ' • Adm: $admNo',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppTheme.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Severity Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    severityLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: severityColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Incident Content
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Incident Type & Date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.dark,
                        ),
                      ),
                    ),
                    Text(
                      '$dateLabel ${timeAgo.isNotEmpty ? '($timeAgo)' : ''}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Reported by: $reporter',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppTheme.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Description Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.dark,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Action Taken & Suspension Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSuspension ? Icons.gavel_rounded : Icons.handyman_outlined,
                      size: 16,
                      color: isSuspension ? AppTheme.crimson : AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Action Taken: ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.dark,
                              ),
                            ),
                            TextSpan(
                              text: actionTaken,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: isSuspension ? FontWeight.w700 : FontWeight.w500,
                                color: isSuspension ? AppTheme.crimson : AppTheme.dark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Resolved badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: resolved ? AppTheme.emerald.withOpacity(0.12) : AppTheme.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        resolved ? 'Resolved' : 'Active Case',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: resolved ? AppTheme.emerald : AppTheme.amber,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Guardian Contact & Notification Row
                Row(
                  children: [
                    Icon(Icons.family_restroom_rounded, size: 14, color: AppTheme.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Guardian Notification: ',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w600),
                    ),
                    Expanded(
                      child: Text(
                        parentNotified,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.dark, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (guardianPhone != null && guardianPhone.isNotEmpty)
                      InkWell(
                        onTap: () => _makePhoneCall(guardianPhone),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone_in_talk_rounded, size: 12, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Call Parent',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Executive Sign-Off Section
                if (isSignedOff) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emerald.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 16, color: AppTheme.emerald),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Executive Sign-Off: $signerName',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.emerald,
                                ),
                              ),
                            ),
                            if (signedAt != null)
                              Text(
                                signedAt,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: AppTheme.grey,
                                ),
                              ),
                          ],
                        ),
                        if (executiveNotes != null && executiveNotes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Remarks: "$executiveNotes"',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.dark,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Awaiting Principal / Director Executive Sign-Off',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.amber,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _showExecutiveSignOffSheet(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.amber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(
                            'Sign Off',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Bottom Action Tools
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        resolved ? Icons.restart_alt_rounded : Icons.check_circle_outline_rounded,
                        size: 15,
                        color: resolved ? AppTheme.amber : AppTheme.emerald,
                      ),
                      label: Text(
                        resolved ? 'Reopen Case' : 'Mark Resolved',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: resolved ? AppTheme.amber : AppTheme.emerald,
                        ),
                      ),
                      onPressed: () async {
                        final res = await _api.toggleResolveIncident(id, resolved: !resolved);
                        if (res.success) {
                          _loadOverview();
                          _loadIncidents();
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        if (val == 'sign_off') {
                          _showExecutiveSignOffSheet(item);
                        } else if (val == 'delete') {
                          _confirmDeleteIncident(id);
                        }
                      },
                      itemBuilder: (context) => [
                        if (!isSignedOff)
                          const PopupMenuItem(
                            value: 'sign_off',
                            child: Row(
                              children: [
                                Icon(Icons.approval_rounded, size: 18, color: AppTheme.primary),
                                SizedBox(width: 8),
                                Text('Executive Sign-Off'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.crimson),
                              SizedBox(width: 8),
                              Text('Remove Log', style: TextStyle(color: AppTheme.crimson)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: COMMENDATIONS & MERIT AWARDS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMeritsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadOverview();
        await _loadAchievements();
      },
      child: CustomScrollView(
        slivers: [
          // Merits Telemetry Ribbon
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTelemetryCard(
                      title: 'Total Merits',
                      count: '${_kpis['total_commendations'] ?? _achievements.length}',
                      subtitle: 'Recognitions awarded',
                      color: AppTheme.gold,
                      icon: Icons.military_tech_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTelemetryCard(
                      title: 'Top Performers',
                      count: 'View Board',
                      subtitle: 'House & Student ranks',
                      color: AppTheme.primary,
                      icon: Icons.emoji_events_rounded,
                      onTap: _showLeaderboardSheet,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filters & Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _achievementSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search student, award title, or medal...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.grey),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.grey, size: 20),
                        suffixIcon: _achievementSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _achievementSearchCtrl.clear();
                                  _loadAchievements();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _loadAchievements(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Categories', 'all', _selectedCategory, (val) {
                          setState(() => _selectedCategory = val);
                          _loadAchievements();
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Academic', 'academic', _selectedCategory, (val) {
                          setState(() => _selectedCategory = val);
                          _loadAchievements();
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Sports', 'sports', _selectedCategory, (val) {
                          setState(() => _selectedCategory = val);
                          _loadAchievements();
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Leadership', 'leadership', _selectedCategory, (val) {
                          setState(() => _selectedCategory = val);
                          _loadAchievements();
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Science / STEM', 'science', _selectedCategory, (val) {
                          setState(() => _selectedCategory = val);
                          _loadAchievements();
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Arts', 'arts', _selectedCategory, (val) {
                          setState(() => _selectedCategory = val);
                          _loadAchievements();
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Level Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text('Level: ', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.grey)),
                        const SizedBox(width: 4),
                        _buildLevelFilterChip('All Levels', 'all'),
                        const SizedBox(width: 6),
                        _buildLevelFilterChip('School', 'school'),
                        const SizedBox(width: 6),
                        _buildLevelFilterChip('District', 'district'),
                        const SizedBox(width: 6),
                        _buildLevelFilterChip('State', 'state'),
                        const SizedBox(width: 6),
                        _buildLevelFilterChip('National', 'national'),
                        const SizedBox(width: 6),
                        _buildLevelFilterChip('International', 'international'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Achievements List
          if (_achievementsLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_achievements.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium_outlined, size: 56, color: AppTheme.gold.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text(
                        'No Commendations Recorded',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.dark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Recognize student excellence by tapping "Award Merit".',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _achievements[index];
                    return _buildMeritCard(item);
                  },
                  childCount: _achievements.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeritCard(dynamic item) {
    final int id = item['id'] ?? 0;
    final String sName = item['student_name'] ?? 'Student';
    final String classSec = item['class_section'] ?? 'Class';
    final String title = item['title'] ?? 'Merit Commendation';
    final String category = item['category'] ?? 'academic';
    final String categoryLabel = item['category_label'] ?? _categoryLabels[category] ?? category.toUpperCase();
    final String awardType = item['award_type'] ?? 'Merit Award';
    final String levelLabel = item['level_label'] ?? 'School Level';
    final String awardDate = item['awarded_date_label'] ?? 'N/A';
    final String issuingBody = item['issuing_body'] ?? 'School';
    final String description = item['description'] ?? '';
    final String recorder = item['recorded_by_name'] ?? 'Staff';

    // Category accent
    Color badgeColor = AppTheme.gold;
    IconData badgeIcon = Icons.military_tech_rounded;
    if (category == 'sports') {
      badgeColor = AppTheme.emerald;
      badgeIcon = Icons.fitness_center_rounded;
    } else if (category == 'science') {
      badgeColor = AppTheme.blue;
      badgeIcon = Icons.science_rounded;
    } else if (category == 'arts') {
      badgeColor = AppTheme.secondary;
      badgeIcon = Icons.palette_rounded;
    } else if (category == 'leadership') {
      badgeColor = AppTheme.primary;
      badgeIcon = Icons.stars_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top student ribbon
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: badgeColor.withOpacity(0.12),
                  child: Icon(badgeIcon, color: badgeColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sName,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.dark,
                        ),
                      ),
                      Text(
                        classSec,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Level Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    levelLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Award Content
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Award Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dark,
                        ),
                      ),
                    ),
                    Text(
                      awardDate,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Tags: Award Type & Category
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded, size: 12, color: AppTheme.gold),
                          const SizedBox(width: 4),
                          Text(
                            awardType,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        categoryLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.dark,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Footer: Issuing body & Recorder
                Row(
                  children: [
                    Icon(Icons.apartment_rounded, size: 13, color: AppTheme.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Issued by $issuingBody • Recorded by $recorder',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.grey),
                      tooltip: 'Remove Merit',
                      onPressed: () => _confirmDeleteAchievement(id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM SHEETS & ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  // 1. Executive Disciplinary Sign-Off Sheet
  void _showExecutiveSignOffSheet(dynamic incident) {
    final int id = incident['id'] ?? 0;
    final String sName = incident['student_name'] ?? 'Student';
    final String type = incident['incident_type'] ?? 'Infraction';
    final String currentAction = incident['action_taken'] ?? '';

    final TextEditingController notesCtrl = TextEditingController();
    final TextEditingController actionCtrl = TextEditingController(text: currentAction);
    bool markResolved = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.approval_rounded, color: AppTheme.amber, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Executive Disciplinary Sign-Off',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.dark,
                                ),
                              ),
                              Text(
                                'Principal / Director Formal Review',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Student & Incident summary box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Student: $sName', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('Infraction: $type', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Formal Action Taken input
                    Text(
                      'Confirmed Action / Resolution',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.dark),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: actionCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. 2-Day Suspension, Parent Conference, Counseling',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Executive Notes
                    Text(
                      'Executive Remarks / Directive',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.dark),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add remarks for faculty record and student file...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mark Resolved Checkbox
                    CheckboxListTile(
                      value: markResolved,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        'Mark this disciplinary case as resolved now',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      onChanged: (val) => setModalState(() => markResolved = val ?? false),
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.amber,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(
                          isSaving ? 'Recording Sign-Off...' : 'Confirm Executive Sign-Off',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                final res = await _api.signOffDisciplinaryIncident(
                                  id,
                                  executiveNotes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                  actionTaken: actionCtrl.text.trim().isEmpty ? null : actionCtrl.text.trim(),
                                  markResolved: markResolved,
                                );
                                setModalState(() => isSaving = false);
                                if (res.success) {
                                  Navigator.pop(ctx);
                                  _loadOverview();
                                  _loadIncidents();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Disciplinary sign-off completed successfully!')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message)),
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
        );
      },
    );
  }

  // 2. Log Behavioral Incident Bottom Sheet
  void _showLogIncidentSheet() {
    int? selectedStudentId;
    String? selectedStudentName;
    List<dynamic> studentSearchResults = [];
    bool isSearching = false;

    DateTime incidentDate = DateTime.now();
    String severity = 'minor';
    String incidentType = _incidentTypes.first;
    final TextEditingController customTypeCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    String actionTaken = _actionTakenPresets.first;
    final TextEditingController customActionCtrl = TextEditingController();
    String parentNotification = _parentNotificationPresets.first;

    bool signOffNow = false;
    final TextEditingController executiveNotesCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Log Behavioral Incident',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.dark,
                                ),
                              ),
                              Text(
                                'Mobile behavioral record & pastoral incident tracking',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Student Search / Selection
                    Text(
                      'Student *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.dark),
                    ),
                    const SizedBox(height: 6),
                    if (selectedStudentName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedStudentName!,
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.primary),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                setModalState(() {
                                  selectedStudentId = null;
                                  selectedStudentName = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      TextFormField(
                        decoration: InputDecoration(
                          hintText: 'Type 2+ letters of student name or admission no...',
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) async {
                          if (val.trim().length >= 2) {
                            setModalState(() => isSearching = true);
                            final res = await _api.searchStudents(val.trim());
                            setModalState(() {
                              isSearching = false;
                              if (res.success && res.data != null) {
                                studentSearchResults = res.data ?? [];
                              }
                            });
                          }
                        },
                      ),
                      if (studentSearchResults.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 140),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: studentSearchResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final st = studentSearchResults[i];
                              final stName = st['name'] ?? '${st['first_name'] ?? ''} ${st['last_name'] ?? ''}'.trim();
                              final stClass = st['class_name'] ?? st['class'] ?? '';
                              final stRoll = st['roll_no'] ?? st['admission_no'] ?? '';
                              return ListTile(
                                dense: true,
                                title: Text(stName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                                subtitle: Text('$stClass • #$stRoll', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                                onTap: () {
                                  setModalState(() {
                                    selectedStudentId = st['id'];
                                    selectedStudentName = '$stName ($stClass)';
                                    studentSearchResults = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),

                    // Date & Severity Row
                    Row(
                      children: [
                        // Incident Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: incidentDate,
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setModalState(() => incidentDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        DateFormat('yyyy-MM-dd').format(incidentDate),
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Severity
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Severity Tag *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: severity,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'minor', child: Text('Minor')),
                                      DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                                      DropdownMenuItem(value: 'major', child: Text('Severe / Major')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => severity = val);
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

                    // Incident Type
                    Text('Incident Category / Type *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: incidentType,
                          isExpanded: true,
                          items: _incidentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.plusJakartaSans(fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => incidentType = val);
                          },
                        ),
                      ),
                    ),
                    if (incidentType == 'Other Behavioral Infraction') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customTypeCtrl,
                        decoration: InputDecoration(
                          hintText: 'Specify infraction...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Description
                    Text('Incident Narrative / Description *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Provide facts: time, location, classroom, individuals involved...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Action Taken & Suspension Tracker
                    Text('Administrative Action Taken', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: actionTaken,
                          isExpanded: true,
                          items: _actionTakenPresets.map((a) => DropdownMenuItem(value: a, child: Text(a, style: GoogleFonts.plusJakartaSans(fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => actionTaken = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Guardian Notification
                    Text('Parent / Guardian Notification Status', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: parentNotification,
                          isExpanded: true,
                          items: _parentNotificationPresets.map((p) => DropdownMenuItem(value: p, child: Text(p, style: GoogleFonts.plusJakartaSans(fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => parentNotification = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Executive Direct Sign-Off switch
                    SwitchListTile(
                      value: signOffNow,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Direct Executive Sign-Off (Principal/Admin)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Approve and endorse incident resolution immediately',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey),
                      ),
                      onChanged: (val) => setModalState(() => signOffNow = val),
                    ),
                    if (signOffNow) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: executiveNotesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Executive remarks & guidance...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          isSubmitting ? 'Logging Incident...' : 'Log Behavioral Incident',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (selectedStudentId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select a student')),
                                  );
                                  return;
                                }
                                if (descCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please provide an incident description')),
                                  );
                                  return;
                                }

                                final finalType = (incidentType == 'Other Behavioral Infraction' && customTypeCtrl.text.trim().isNotEmpty)
                                    ? customTypeCtrl.text.trim()
                                    : incidentType;

                                setModalState(() => isSubmitting = true);

                                final res = await _api.createDisciplinaryIncident({
                                  'student_id': selectedStudentId,
                                  'incident_date': DateFormat('yyyy-MM-dd').format(incidentDate),
                                  'severity': severity,
                                  'incident_type': finalType,
                                  'description': descCtrl.text.trim(),
                                  'action_taken': actionTaken,
                                  'parent_notified': parentNotification,
                                  'sign_off_now': signOffNow,
                                  'executive_notes': signOffNow && executiveNotesCtrl.text.trim().isNotEmpty
                                      ? executiveNotesCtrl.text.trim()
                                      : null,
                                });

                                setModalState(() => isSubmitting = false);

                                if (res.success) {
                                  Navigator.pop(ctx);
                                  _loadOverview();
                                  _loadIncidents();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Behavioral incident recorded successfully!')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message)),
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
        );
      },
    );
  }

  // 3. Award Student Merit Bottom Sheet
  void _showAwardMeritSheet() {
    int? selectedStudentId;
    String? selectedStudentName;
    List<dynamic> studentSearchResults = [];
    bool isSearching = false;

    final TextEditingController titleCtrl = TextEditingController();
    String category = 'academic';
    String awardType = _awardTypes.first;
    String level = 'school';
    DateTime awardDate = DateTime.now();
    final TextEditingController issuingBodyCtrl = TextEditingController(text: 'School Administration');
    final TextEditingController descCtrl = TextEditingController();

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.emoji_events_rounded, color: AppTheme.gold, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Award Student Merit',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.dark,
                                ),
                              ),
                              Text(
                                'Positive commendations, honors & leadership badges',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Student Picker
                    Text('Recipient Student *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (selectedStudentName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppTheme.gold, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedStudentName!,
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.dark),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                setModalState(() {
                                  selectedStudentId = null;
                                  selectedStudentName = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      TextFormField(
                        decoration: InputDecoration(
                          hintText: 'Type 2+ letters to search student...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) async {
                          if (val.trim().length >= 2) {
                            setModalState(() => isSearching = true);
                            final res = await _api.searchStudents(val.trim());
                            setModalState(() {
                              isSearching = false;
                              if (res.success && res.data != null) {
                                studentSearchResults = res.data ?? [];
                              }
                            });
                          }
                        },
                      ),
                      if (studentSearchResults.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 140),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: studentSearchResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final st = studentSearchResults[i];
                              final stName = st['name'] ?? '${st['first_name'] ?? ''} ${st['last_name'] ?? ''}'.trim();
                              final stClass = st['class_name'] ?? st['class'] ?? '';
                              final stRoll = st['roll_no'] ?? st['admission_no'] ?? '';
                              return ListTile(
                                dense: true,
                                title: Text(stName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                                subtitle: Text('$stClass • #$stRoll', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                                onTap: () {
                                  setModalState(() {
                                    selectedStudentId = st['id'];
                                    selectedStudentName = '$stName ($stClass)';
                                    studentSearchResults = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),

                    // Award Title
                    Text('Award Title *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. 1st Place - Inter-School Science Fair 2026',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category & Award Type
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Category *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: category,
                                    isExpanded: true,
                                    items: _categoryLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.plusJakartaSans(fontSize: 12)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => category = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Award Type', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: awardType,
                                    isExpanded: true,
                                    items: _awardTypes.map((a) => DropdownMenuItem(value: a, child: Text(a, style: GoogleFonts.plusJakartaSans(fontSize: 12)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => awardType = val);
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

                    // Level & Date
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Competition Level *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: level,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'school', child: Text('School Level')),
                                      DropdownMenuItem(value: 'district', child: Text('District Level')),
                                      DropdownMenuItem(value: 'state', child: Text('State Level')),
                                      DropdownMenuItem(value: 'national', child: Text('National Level')),
                                      DropdownMenuItem(value: 'international', child: Text('International')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => level = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date Awarded *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: awardDate,
                                    firstDate: DateTime.now().subtract(const Duration(days: 730)),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setModalState(() => awardDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        DateFormat('yyyy-MM-dd').format(awardDate),
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
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

                    // Issuing Body
                    Text('Issuing Body / Organization', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: issuingBodyCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Nepal Science Olympiad Council, School Board',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description / Citation
                    Text('Citation / Achievement Summary', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Details on project, medal criteria, or outstanding leadership...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.emoji_events_rounded),
                        label: Text(
                          isSubmitting ? 'Recording Merit...' : 'Confer Merit & Commendation',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (selectedStudentId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select a student')),
                                  );
                                  return;
                                }
                                if (titleCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please provide an award title')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final res = await _api.createAchievement({
                                  'student_id': selectedStudentId,
                                  'title': titleCtrl.text.trim(),
                                  'category': category,
                                  'award_type': awardType,
                                  'level': level,
                                  'awarded_date': DateFormat('yyyy-MM-dd').format(awardDate),
                                  'issuing_body': issuingBodyCtrl.text.trim().isEmpty ? null : issuingBodyCtrl.text.trim(),
                                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                                });

                                setModalState(() => isSubmitting = false);

                                if (res.success) {
                                  Navigator.pop(ctx);
                                  _loadOverview();
                                  _loadAchievements();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Student merit awarded and recorded successfully!')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message)),
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
        );
      },
    );
  }

  // 4. Merit Leaderboard Sheet
  void _showLeaderboardSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<ApiResponse<List<dynamic>>>(
          future: _api.getAchievementLeaderboard(),
          builder: (context, snapshot) {
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            final leaders = snapshot.data?.data ?? [];

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.leaderboard_rounded, color: AppTheme.gold, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        'Student Merit Honor Board',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ranked by total positive commendations and awards earned',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isLoading)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (leaders.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No merit records yet.',
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: leaders.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = leaders[idx];
                          final rank = idx + 1;
                          final name = item['student_name'] ?? 'Student';
                          final classSec = item['class_section'] ?? 'Class';
                          final total = item['total_achievements'] ?? 0;

                          Color rankColor = AppTheme.grey;
                          if (rank == 1) rankColor = AppTheme.gold;
                          if (rank == 2) rankColor = const Color(0xFFBDC3C7);
                          if (rank == 3) rankColor = const Color(0xFFCD7F32);

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: rankColor.withOpacity(0.18),
                              child: Text(
                                '#$rank',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: rankColor,
                                ),
                              ),
                            ),
                            title: Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text(classSec, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 14, color: AppTheme.gold),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$total Merits',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: AppTheme.gold,
                                    ),
                                  ),
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
          },
        );
      },
    );
  }

  // Confirm delete incident
  void _confirmDeleteIncident(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Disciplinary Record?'),
        content: const Text('This will remove the infraction from student history permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.deleteDisciplinaryIncident(id);
              if (res.success) {
                _loadOverview();
                _loadIncidents();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Confirm delete achievement
  void _confirmDeleteAchievement(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Merit Commendation?'),
        content: const Text('Are you sure you want to remove this achievement from student record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.deleteAchievement(id);
              if (res.success) {
                _loadOverview();
                _loadAchievements();
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTelemetryCard({
    required String title,
    required String count,
    required String subtitle,
    required Color color,
    required IconData icon,
    bool isAlert = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAlert ? color : Colors.grey.shade200,
            width: isAlert ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Spacer(),
                if (isAlert)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              count,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.dark,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: AppTheme.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String selectedValue, ValueChanged<String> onSelected, {String? badge}) {
    final isSelected = selectedValue == value;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.dark,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppTheme.crimson,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppTheme.primary : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityFilterChip(String label, String value, {Color? color}) {
    final isSelected = _selectedSeverity == value;
    final c = color ?? AppTheme.primary;
    return InkWell(
      onTap: () {
        setState(() => _selectedSeverity = value);
        _loadIncidents();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? c : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? c : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.dark,
          ),
        ),
      ),
    );
  }

  Widget _buildLevelFilterChip(String label, String value) {
    final isSelected = _selectedLevel == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedLevel = value);
        _loadAchievements();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.secondary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.dark,
          ),
        ),
      ),
    );
  }
}
