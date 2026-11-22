import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/common_widgets.dart';

class AdmissionsManagementScreen extends StatefulWidget {
  final String? initialStatus;

  const AdmissionsManagementScreen({super.key, this.initialStatus});

  @override
  State<AdmissionsManagementScreen> createState() => _AdmissionsManagementScreenState();
}

class _AdmissionsManagementScreenState extends State<AdmissionsManagementScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  String _selectedStatus = 'all'; // all, pending, under_review, approved, enrolled, rejected
  int? _selectedClassId;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  Map<String, dynamic> _kpis = {};
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _classes = [];

  final List<Map<String, String>> _statusTabs = [
    {'id': 'all', 'label': 'All Inquiries'},
    {'id': 'pending', 'label': 'Pending'},
    {'id': 'under_review', 'label': 'Under Review'},
    {'id': 'approved', 'label': 'Approved'},
    {'id': 'enrolled', 'label': 'Enrolled'},
    {'id': 'rejected', 'label': 'Rejected'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      _selectedStatus = widget.initialStatus!;
    }
    _fetchAdmissions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAdmissions() async {
    setState(() => _isLoading = true);

    final res = await _api.getAdmissions(
      status: _selectedStatus,
      classId: _selectedClassId,
      search: _searchQuery,
    );
    if (!mounted) return;

    if (res.success && res.data != null) {
      final data = res.data!;
      final rawKpis = Map<String, dynamic>.from(data['kpis'] ?? {});
      final rawApps = (data['data'] as List<dynamic>? ?? [])
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList();
      final rawClasses = (data['classes'] as List<dynamic>? ?? [])
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();

      setState(() {
        _kpis = rawKpis;
        _applications = rawApps;
        _classes = rawClasses;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _updateStatus(int id, String status, {String? notes}) async {
    final res = await _api.updateAdmissionStatus(id, status, reviewerNotes: notes);
    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.emerald),
      );
      _fetchAdmissions();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  void _showRejectDialog(Map<String, dynamic> app) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Decline Application #${app['application_number']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Applicant: ${app['full_name']}'),
            const SizedBox(height: 8),
            const Text('Reason for rejection (shared in record):', style: TextStyle(fontSize: 12, color: AppTheme.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Class capacity reached / criteria not met',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(app['id'], 'rejected', notes: reasonCtrl.text.trim());
            },
            child: const Text('Reject Application', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEnrollmentModal(Map<String, dynamic> app) {
    final emailCtrl = TextEditingController(
      text: app['email'] != null && app['email'].toString().isNotEmpty
          ? app['email']
          : '${app['first_name']?.toString().toLowerCase()}.${app['id']}@school.edu.np',
    );
    final passwordCtrl = TextEditingController(text: 'Student@123');
    final rollCtrl = TextEditingController();

    int selectedClassId = app['class_id'] ?? (_classes.isNotEmpty ? _classes.first['id'] : 1);
    int? selectedSectionId;

    final targetClass = _classes.firstWhere(
      (c) => c['id'] == selectedClassId,
      orElse: () => _classes.isNotEmpty ? _classes.first : {'sections': []},
    );
    final sections = (targetClass['sections'] as List<dynamic>? ?? []);
    if (sections.isNotEmpty) {
      selectedSectionId = sections.first['id'];
    }

    bool isBusStudent = app['needs_transport'] == true;
    bool isHostelStudent = app['needs_hostel'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.royalBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.how_to_reg_rounded, color: AppTheme.royalBlue, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enroll: ${app['full_name']}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            Text(
                              'App #${app['application_number']} • Applied for ${app['class_name']}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Class & Section Picker
                  const Text('Assign Class & Section *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
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
                              child: Text(c['class_name'] ?? 'Class', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList();
                          final safeVal = uniqueClasses.containsKey(selectedClassId) ? selectedClassId : (uniqueClasses.isNotEmpty ? uniqueClasses.keys.first : null);

                          return DropdownButtonFormField<int>(
                            value: safeVal,
                            hint: const Text('Select Class', style: TextStyle(fontSize: 13)),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: items,
                            onChanged: (v) {
                              if (v == null) return;
                              final c = uniqueClasses[v];
                              final secs = (c?['sections'] as List<dynamic>? ?? []);
                              setModalState(() {
                                selectedClassId = v;
                                selectedSectionId = secs.isNotEmpty ? secs.first['id'] as int? : null;
                              });
                            },
                          );
                        })(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: (() {
                          Map<String, dynamic>? matchingClass;
                          for (final c in _classes) {
                            if (c is Map && c['id'] == selectedClassId) {
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
                          final items = uniqueSecs.values.map<DropdownMenuItem<int>>((s) {
                            return DropdownMenuItem<int>(
                              value: s['id'] as int,
                              child: Text('Sec ${s['section_name']}', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList();
                          final safeVal = uniqueSecs.containsKey(selectedSectionId) ? selectedSectionId : (uniqueSecs.isNotEmpty ? uniqueSecs.keys.first : null);

                          return DropdownButtonFormField<int>(
                            value: safeVal,
                            hint: const Text('Section', style: TextStyle(fontSize: 13)),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: items,
                            onChanged: (v) => setModalState(() => selectedSectionId = v),
                          );
                        })(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Roll Number
                  TextField(
                    controller: rollCtrl,
                    decoration: InputDecoration(
                      labelText: 'Roll Number (Optional, e.g. 01, 15)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Student Portal Email
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Portal Login Email *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextField(
                    controller: passwordCtrl,
                    decoration: InputDecoration(
                      labelText: 'Initial Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Service Toggles
                  CheckboxListTile(
                    title: const Text('Allocate School Bus Transport', style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                      app['needs_transport'] == true ? 'Requested in Application' : 'Optional',
                      style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                    ),
                    value: isBusStudent,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.royalBlue,
                    onChanged: (v) => setModalState(() => isBusStudent = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Allocate Hostel & Bed', style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                      app['needs_hostel'] == true ? 'Requested in Application' : 'Optional',
                      style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                    ),
                    value: isHostelStudent,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.royalBlue,
                    onChanged: (v) => setModalState(() => isHostelStudent = v ?? false),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.verified_user_rounded, size: 18),
                      label: const Text('Confirm Enrollment & Issue Student ID', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (selectedSectionId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a section for enrollment.')),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        final res = await _api.enrollAdmission(app['id'], {
                          'email': emailCtrl.text.trim(),
                          'password': passwordCtrl.text.trim(),
                          'class_id': selectedClassId,
                          'section_id': selectedSectionId,
                          'roll_no': rollCtrl.text.trim(),
                          'is_bus_student': isBusStudent,
                          'is_hostel_student': isHostelStudent,
                        });

                        if (mounted) {
                          if (res.success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: AppTheme.emerald,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _fetchAdmissions();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
                            );
                          }
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

  void _openApplicationDetail(Map<String, dynamic> app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final photoUrl = app['photo_url'];
        final status = app['status'] ?? 'pending';

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.royalBlue.withOpacity(0.12),
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(
                            app['first_name'] != null ? app['first_name'][0].toUpperCase() : 'A',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.royalBlue, fontSize: 18),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app['full_name'],
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'App #${app['application_number']} • Submitted ${app['submitted_date'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusPill(status),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // Details body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    _infoSection('Academic Preferences', [
                      _infoRow('Applied Class', app['class_name'] ?? '-'),
                      _infoRow('Previous School', app['previous_school'] ?? 'N/A'),
                      _infoRow('Previous Class', app['previous_class'] ?? 'N/A'),
                    ]),
                    const SizedBox(height: 14),

                    _infoSection('Guardian Contact', [
                      _infoRow('Guardian Name', app['guardian_name'] ?? '-'),
                      _infoRow('Relationship', app['guardian_relation'] ?? 'Guardian'),
                      _infoRow('Phone', app['guardian_phone'] ?? '-'),
                      _infoRow('Email', app['guardian_email'] ?? 'N/A'),
                    ]),
                    const SizedBox(height: 14),

                    _infoSection('Personal & Physical Information', [
                      _infoRow('Gender', app['gender'] ?? 'Not specified'),
                      _infoRow('Date of Birth', app['birthday'] ?? '-'),
                      _infoRow('Blood Group', app['blood_type'] ?? '-'),
                      _infoRow('Address', app['address'] ?? '-'),
                    ]),
                    const SizedBox(height: 14),

                    _infoSection('Services Requested', [
                      _infoRow('School Bus Transport', app['needs_transport'] == true ? 'Yes (Requested)' : 'No'),
                      _infoRow('Hostel Accommodation', app['needs_hostel'] == true ? 'Yes (Requested)' : 'No'),
                    ]),

                    if (app['reviewer_notes'] != null && app['reviewer_notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _infoSection('Review Notes', [
                        _infoRow('Notes', app['reviewer_notes']),
                        _infoRow('Reviewed By', app['reviewed_by_name'] ?? 'Admin'),
                      ]),
                    ],
                  ],
                ),
              ),

              // Action buttons footer
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7))),
                ),
                child: Row(
                  children: [
                    if (status != 'enrolled' && status != 'rejected') ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.crimson),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showRejectDialog(app);
                          },
                          child: const Text('Decline', style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (status == 'pending') ...[
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.royalBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateStatus(app['id'], 'under_review');
                          },
                          child: const Text('Mark Under Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (status == 'pending' || status == 'under_review') ...[
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateStatus(app['id'], 'approved');
                          },
                          child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                    if (status == 'approved') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.school_rounded, size: 16),
                          label: const Text('Enroll Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showEnrollmentModal(app);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.royalBlue)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.grey)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD SCREEN
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
            _buildPipelineKpiBar(isDark),
            _buildSearchAndClassFilter(isDark),
            _buildStatusFilterChips(isDark),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.royalBlue,
                onRefresh: _fetchAdmissions,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.royalBlue))
                    : _buildApplicationsList(isDark),
              ),
            ),
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
                  'Admissions & Inquiries (भर्ना)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.dark,
                  ),
                ),
                const Text(
                  'Application Pipeline, Review & Student Enrollment',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.royalBlue),
            onPressed: _fetchAdmissions,
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineKpiBar(bool isDark) {
    final total = _kpis['total_applications'] ?? 0;
    final pending = _kpis['pending'] ?? 0;
    final review = _kpis['under_review'] ?? 0;
    final approved = _kpis['approved'] ?? 0;
    final enrolled = _kpis['enrolled'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _kpiPill('Total', '$total', AppTheme.royalBlue),
          _divider(),
          _kpiPill('Pending', '$pending', AppTheme.amber),
          _divider(),
          _kpiPill('Review', '$review', AppTheme.blue),
          _divider(),
          _kpiPill('Approved', '$approved', AppTheme.emerald),
          _divider(),
          _kpiPill('Enrolled', '$enrolled', AppTheme.purple),
        ],
      ),
    );
  }

  Widget _kpiPill(String label, String count, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 22, color: const Color(0xFFE2E8F0));
  }

  Widget _buildSearchAndClassFilter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  _searchQuery = v.trim();
                  _fetchAdmissions();
                },
                decoration: InputDecoration(
                  hintText: 'Search applicant, app # or phone...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppTheme.grey),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.grey),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 38,
              child: (() {
                final uniqueClasses = <int, Map<String, dynamic>>{};
                for (final c in _classes) {
                  if (c is Map && c['id'] != null) {
                    uniqueClasses[c['id'] as int] = Map<String, dynamic>.from(c);
                  }
                }
                final items = [
                  const DropdownMenuItem<int?>(value: null, child: Text('All Grades', style: TextStyle(fontSize: 12))),
                  ...uniqueClasses.values.map((c) => DropdownMenuItem<int?>(
                        value: c['id'] as int?,
                        child: Text(c['class_name'] ?? 'Class', style: const TextStyle(fontSize: 12)),
                      )),
                ];
                final safeVal = uniqueClasses.containsKey(_selectedClassId) ? _selectedClassId : null;

                return DropdownButtonFormField<int?>(
                  value: safeVal,
                  hint: const Text('All Grades', style: TextStyle(fontSize: 12)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: items,
                  onChanged: (v) {
                    setState(() => _selectedClassId = v);
                    _fetchAdmissions();
                  },
                );
              })(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChips(bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _statusTabs.length,
        itemBuilder: (ctx, idx) {
          final t = _statusTabs[idx];
          final isSelected = _selectedStatus == t['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(t['label']!),
              selected: isSelected,
              selectedColor: AppTheme.royalBlue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.grey,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11,
              ),
              onSelected: (_) {
                setState(() => _selectedStatus = t['id']!);
                _fetchAdmissions();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildApplicationsList(bool isDark) {
    if (_applications.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.royalBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_shared_rounded, size: 32, color: AppTheme.royalBlue),
              ),
              const SizedBox(height: 14),
              Text(
                'No Applications Found',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppTheme.dark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'No student applications match your filter criteria.',
                style: TextStyle(fontSize: 12, color: AppTheme.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: _applications.length,
      itemBuilder: (ctx, idx) {
        final app = _applications[idx];
        return _buildApplicationCard(app, isDark);
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app, bool isDark) {
    final status = app['status'] ?? 'pending';
    final photoUrl = app['photo_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: App Number, Submitted Time, Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.royalBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${app['application_number']}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.royalBlue,
                  ),
                ),
              ),
              Text(
                app['time_ago'] ?? app['submitted_date'] ?? '',
                style: const TextStyle(fontSize: 10, color: AppTheme.grey, fontWeight: FontWeight.w600),
              ),
              _buildStatusPill(status),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Avatar, Name, Class & Guardian
          InkWell(
            onTap: () => _openApplicationDetail(app),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.royalBlue.withOpacity(0.12),
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          app['first_name'] != null ? app['first_name'][0].toUpperCase() : 'A',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.royalBlue, fontSize: 16),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app['full_name'],
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppTheme.dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Class: ${app['class_name'] ?? '-'} • Guardian: ${app['guardian_name'] ?? '-'} (${app['guardian_phone'] ?? '-'})',
                        style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.grey),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Row 3: Action Buttons
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_rounded, size: 14),
                label: const Text('View 360', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _openApplicationDetail(app),
              ),
              const Spacer(),
              if (status == 'pending' || status == 'under_review') ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.crimson),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _showRejectDialog(app),
                  child: const Text('Decline', style: TextStyle(color: AppTheme.crimson, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _updateStatus(app['id'], 'approved'),
                  child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
              if (status == 'approved') ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.school_rounded, size: 14),
                  label: const Text('Enroll Student', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _showEnrollmentModal(app),
                ),
              ],
              if (status == 'enrolled') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.purple),
                      const SizedBox(width: 4),
                      Text(
                        'Enrolled ID #${app['student_id'] ?? ''}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.purple),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = AppTheme.amber;
        label = 'Pending';
        break;
      case 'under_review':
        color = AppTheme.blue;
        label = 'Under Review';
        break;
      case 'approved':
        color = AppTheme.emerald;
        label = 'Approved';
        break;
      case 'enrolled':
        color = AppTheme.purple;
        label = 'Enrolled';
        break;
      case 'rejected':
        color = AppTheme.crimson;
        label = 'Rejected';
        break;
      default:
        color = AppTheme.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
