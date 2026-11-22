import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CertificateManagerScreen extends StatefulWidget {
  const CertificateManagerScreen({Key? key}) : super(key: key);

  @override
  State<CertificateManagerScreen> createState() => _CertificateManagerScreenState();
}

class _CertificateManagerScreenState extends State<CertificateManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  // Tab 1: Transfers / TC State
  bool _transfersLoading = true;
  String _transferStatus = 'all'; // 'all', 'pending', 'approved', 'rejected'
  final TextEditingController _transferSearchCtrl = TextEditingController();
  List<dynamic> _transfers = [];

  // Tab 2: Issued Certificates State
  bool _certificatesLoading = true;
  String _certType = 'all'; // 'all', 'character', 'bonafide', 'admission', 'achievement'
  final TextEditingController _certSearchCtrl = TextEditingController();
  List<dynamic> _certificates = [];

  Map<String, dynamic> _kpis = {
    'total_certificates_issued': 0,
    'issued_this_month': 0,
    'pending_tc_requests': 0,
    'approved_tc_issued': 0,
    'available_templates': 0,
  };

  static const List<Map<String, String>> _certificateTypes = [
    {'key': 'all', 'label': 'All Certificates'},
    {'key': 'transfer', 'label': 'Transfer (TC)'},
    {'key': 'character', 'label': 'Character Certificate'},
    {'key': 'bonafide', 'label': 'Bonafide Certificate'},
    {'key': 'school_leaving', 'label': 'School Leaving (SLC)'},
    {'key': 'migration', 'label': 'Migration Certificate'},
    {'key': 'admission', 'label': 'Admission Proof'},
    {'key': 'achievement', 'label': 'Merit & Achievement'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadOverview();
    _loadTransfers();
    _loadCertificates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transferSearchCtrl.dispose();
    _certSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    final res = await _api.getCertificatesOverview();
    if (res.success && res.data != null) {
      if (mounted) {
        setState(() {
          _kpis = (res.data!['kpis'] as Map<String, dynamic>?) ?? _kpis;
        });
      }
    }
  }

  Future<void> _loadTransfers() async {
    setState(() => _transfersLoading = true);
    final res = await _api.getTransferCertificates(
      status: _transferStatus == 'all' ? null : _transferStatus,
      search: _transferSearchCtrl.text.trim().isEmpty ? null : _transferSearchCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _transfersLoading = false;
        _transfers = res.success ? (res.data ?? []) : [];
      });
    }
  }

  Future<void> _loadCertificates() async {
    setState(() => _certificatesLoading = true);
    final res = await _api.getIssuedCertificates(
      type: _certType == 'all' ? null : _certType,
      search: _certSearchCtrl.text.trim().isEmpty ? null : _certSearchCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _certificatesLoading = false;
        _certificates = res.success ? (res.data ?? []) : [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingTcs = (_kpis['pending_tc_requests'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Official Document & Certificate Center',
              style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.dark),
            ),
            Text(
              'Transfer Certificates (TC), Character & Bonafide Issuance',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: () {
              _loadOverview();
              _loadTransfers();
              _loadCertificates();
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
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Transfer Certificates (TC)'),
                  if (pendingTcs > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.crimson, borderRadius: BorderRadius.circular(10)),
                      child: Text('$pendingTcs', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Character & Bonafide'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransfersTab(),
          _buildCertificatesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: _tabController.index == 0 ? AppTheme.primary : AppTheme.secondary,
        icon: Icon(_tabController.index == 0 ? Icons.logout_rounded : Icons.verified_user_rounded, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Issue Departure TC' : 'Generate Certificate',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showQuickIssueTcSheet();
          } else {
            _showGenerateCertificateSheet();
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: TRANSFER CERTIFICATE (TC) MANAGER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTransfersTab() {
    final pendingCount = (_kpis['pending_tc_requests'] as int?) ?? 0;
    final approvedCount = (_kpis['approved_tc_issued'] as int?) ?? 0;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadOverview();
        await _loadTransfers();
      },
      child: CustomScrollView(
        slivers: [
          // Telemetry
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: pendingCount > 0 ? AppTheme.amber : Colors.grey.shade200, width: pendingCount > 0 ? 1.5 : 1.0),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Pending TC Requests', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                        Text('$pendingCount', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: pendingCount > 0 ? AppTheme.amber : AppTheme.dark)),
                        Text('Awaiting Principal', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.grey)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Total TCs Issued', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                        Text('$approvedCount', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.emerald)),
                        Text('Departed Students', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.grey)),
                      ]),
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
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: TextField(
                      controller: _transferSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search student, admission no, or TC number...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.grey),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.grey, size: 20),
                        suffixIcon: _transferSearchCtrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _transferSearchCtrl.clear(); _loadTransfers(); })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _loadTransfers(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChoiceChip('All Requests', 'all', _transferStatus, (v) { setState(() => _transferStatus = v); _loadTransfers(); }),
                        const SizedBox(width: 6),
                        _buildChoiceChip('Pending Approval', 'pending', _transferStatus, (v) { setState(() => _transferStatus = v); _loadTransfers(); }, badge: pendingCount > 0 ? '$pendingCount' : null),
                        const SizedBox(width: 6),
                        _buildChoiceChip('Issued & Approved', 'approved', _transferStatus, (v) { setState(() => _transferStatus = v); _loadTransfers(); }),
                        const SizedBox(width: 6),
                        _buildChoiceChip('Rejected', 'rejected', _transferStatus, (v) { setState(() => _transferStatus = v); _loadTransfers(); }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Transfers List
          if (_transfersLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_transfers.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 56, color: AppTheme.grey.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No Transfer Certificates Found', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Tap "+ Issue Departure TC" to authorize a certificate for a student.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
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
                    final item = _transfers[index];
                    return _buildTransferCard(item);
                  },
                  childCount: _transfers.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(dynamic item) {
    final int id = item['id'] ?? 0;
    final String sName = item['student_name'] ?? 'Student';
    final String classSec = item['class_section'] ?? 'Class';
    final String admNo = item['admission_no'] ?? '-';
    final String toSchool = item['to_school'] ?? 'External School';
    final String reason = item['reason'] ?? 'Relocation';
    final String status = (item['status'] ?? 'pending').toString().toLowerCase();
    final String? tcNumber = item['tc_number'];
    final String transferDate = item['transfer_date'] ?? 'N/A';
    final String? approver = item['approver_name'];

    Color statusColor = AppTheme.amber;
    String statusLabel = 'PENDING APPROVAL';
    if (status == 'approved') {
      statusColor = AppTheme.emerald;
      statusLabel = 'AUTHORIZED & ISSUED';
    } else if (status == 'rejected') {
      statusColor = AppTheme.crimson;
      statusLabel = 'REJECTED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == 'pending' ? AppTheme.amber.withOpacity(0.4) : Colors.grey.shade200, width: status == 'pending' ? 1.5 : 1.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Icon(Icons.school_rounded, color: statusColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.dark)),
                      Text('$classSec • Adm: $admNo', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusLabel, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tcNumber != null && tcNumber.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text('TC NO: $tcNumber', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.emerald)),
                      ),
                      const Spacer(),
                      Text('Issued $transferDate', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text('Destination: $toSchool', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.dark)),
                const SizedBox(height: 2),
                Text('Reason: $reason', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                if (approver != null) ...[
                  const SizedBox(height: 4),
                  Text('Authorized by Principal: $approver', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                ],
                if (status == 'pending') ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.crimson)),
                        child: const Text('Reject', style: TextStyle(color: AppTheme.crimson, fontSize: 12)),
                        onPressed: () => _handleApproveRejectTc(id, 'rejected'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Authorize & Issue TC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _handleApproveRejectTc(id, 'approved'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleApproveRejectTc(int id, String status) {
    final TextEditingController notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'approved' ? 'Authorize Transfer Certificate' : 'Reject Transfer Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status == 'approved'
                ? 'Approving will generate the official TC serial number and record departure.'
                : 'Provide rejection notes for student records:'),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, decoration: const InputDecoration(hintText: 'Executive notes / remarks', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: status == 'approved' ? AppTheme.emerald : AppTheme.crimson, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.approveTransferCertificate(id, status: status, notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
              if (res.success) {
                _loadOverview();
                _loadTransfers();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
              }
            },
            child: Text(status == 'approved' ? 'Authorize' : 'Reject'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: CHARACTER, BONAFIDE & STUDY CERTIFICATES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCertificatesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadOverview();
        await _loadCertificates();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Core 4 Main Certificates Header & Carousel
                  Row(
                    children: [
                      Container(width: 3.5, height: 15, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 7),
                      Text('Core Certificates', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.dark)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                        child: Text('Essential 4', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCoreCertQuickCard(
                          title: 'Transfer (TC)',
                          nepali: 'स्थानान्तरण प्रमाण-पत्र',
                          icon: Icons.output_rounded,
                          color: const Color(0xFF4F46E5),
                          typeKey: 'transfer',
                        ),
                        _buildCoreCertQuickCard(
                          title: 'Character Cert',
                          nepali: 'चारित्रिक प्रमाण-पत्र',
                          icon: Icons.verified_rounded,
                          color: const Color(0xFF059669),
                          typeKey: 'character',
                        ),
                        _buildCoreCertQuickCard(
                          title: 'Bonafide Cert',
                          nepali: 'बोनाफाइड प्रमाण-पत्र',
                          icon: Icons.badge_outlined,
                          color: const Color(0xFF0284C7),
                          typeKey: 'bonafide',
                        ),
                        _buildCoreCertQuickCard(
                          title: 'Leaving (SLC)',
                          nepali: 'विद्यालय छाडेको',
                          icon: Icons.school_rounded,
                          color: const Color(0xFF7C3AED),
                          typeKey: 'school_leaving',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: TextField(
                      controller: _certSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search certificate no, student name, or purpose...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.grey),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.grey, size: 20),
                        suffixIcon: _certSearchCtrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _certSearchCtrl.clear(); _loadCertificates(); })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _loadCertificates(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _certificateTypes.map((c) {
                        final isSel = _certType == c['key'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(c['label']!),
                            selected: isSel,
                            selectedColor: AppTheme.secondary,
                            labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.dark),
                            onSelected: (_) {
                              setState(() => _certType = c['key']!);
                              _loadCertificates();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_certificatesLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_certificates.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium_outlined, size: 56, color: AppTheme.grey.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No Issued Certificates Found', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Tap "+ Generate Certificate" to issue a Character or Bonafide certificate.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
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
                    final item = _certificates[index];
                    return _buildIssuedCertCard(item);
                  },
                  childCount: _certificates.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIssuedCertCard(dynamic item) {
    final int id = item['id'] ?? 0;
    final String certNumber = item['certificate_number'] ?? 'CERT-000';
    final String sName = item['student_name'] ?? 'Student';
    final String classSec = item['class_section'] ?? 'Class';
    final String typeLabel = item['type_label'] ?? 'Certificate';
    final String purpose = item['purpose'] ?? 'General';
    final String issuedDate = item['issued_date'] ?? 'N/A';
    final String status = (item['status'] ?? 'issued').toString().toLowerCase();

    final bool isRevoked = status == 'revoked';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(certNumber, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isRevoked ? AppTheme.crimson.withOpacity(0.12) : AppTheme.emerald.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(isRevoked ? 'REVOKED' : 'VALID / ISSUED', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: isRevoked ? AppTheme.crimson : AppTheme.emerald)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(sName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.dark)),
            Text('$classSec • $typeLabel', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.secondary)),
            const SizedBox(height: 6),
            Text('Purpose: $purpose', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.verified_outlined, size: 14, color: AppTheme.emerald),
                const SizedBox(width: 4),
                Text('Digital Seal & Signature Verified', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Issued $issuedDate', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                if (!isRevoked) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.block_rounded, size: 16, color: AppTheme.crimson),
                    tooltip: 'Revoke Certificate',
                    onPressed: () => _confirmRevokeCert(id, certNumber),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRevokeCert(int id, String certNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Certificate?'),
        content: Text('Are you sure you want to revoke $certNumber? The digital verification link will show invalid.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.revokeCertificate(id);
              if (res.success) {
                _loadOverview();
                _loadCertificates();
              }
            },
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  // Quick Issue TC Sheet
  void _showQuickIssueTcSheet() {
    int? selectedStudentId;
    String? selectedStudentName;
    List<dynamic> studentSearchResults = [];
    bool isSearching = false;

    final TextEditingController toSchoolCtrl = TextEditingController();
    final TextEditingController reasonCtrl = TextEditingController(text: 'Transfer of parents / Higher studies');
    bool carryMarksheet = true;
    bool carryCharacter = true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Issue Departure Transfer Certificate', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                // Student Picker
                Text('Departing Student *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (selectedStudentName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(selectedStudentName!, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.primary))),
                        IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setModalState(() { selectedStudentId = null; selectedStudentName = null; })),
                      ],
                    ),
                  ),
                ] else ...[
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Type 2+ letters of student name...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: isSearching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) async {
                      if (val.trim().length >= 2) {
                        setModalState(() => isSearching = true);
                        final res = await _api.searchStudents(val.trim());
                        setModalState(() {
                          isSearching = false;
                          studentSearchResults = res.success ? (res.data ?? []) : [];
                        });
                      }
                    },
                  ),
                  if (studentSearchResults.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 130),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: studentSearchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final st = studentSearchResults[i];
                          final stName = st['name'] ?? '${st['first_name'] ?? ''} ${st['last_name'] ?? ''}'.trim();
                          final stClass = st['class_name'] ?? st['class'] ?? '';
                          return ListTile(
                            dense: true,
                            title: Text(stName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                            subtitle: Text(stClass, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
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
                const SizedBox(height: 12),
                Text('Destination School / College *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(controller: toSchoolCtrl, decoration: InputDecoration(hintText: 'e.g. St. Xavier College, Kathmandu', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 12),
                Text('Reason for Departure *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(controller: reasonCtrl, decoration: InputDecoration(hintText: 'e.g. Higher secondary education / Family relocation', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: carryMarksheet,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Attach Terminal Marksheet & Grade Sheet', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                  onChanged: (v) => setModalState(() => carryMarksheet = v ?? true),
                ),
                CheckboxListTile(
                  value: carryCharacter,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Bundle Character Certificate automatically', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                  onChanged: (v) => setModalState(() => carryCharacter = v ?? true),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isSaving ? null : () async {
                      if (selectedStudentId == null || toSchoolCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select student and specify destination school')));
                        return;
                      }
                      setModalState(() => isSaving = true);
                      final res = await _api.quickIssueTransferCertificate({
                        'student_id': selectedStudentId,
                        'to_school': toSchoolCtrl.text.trim(),
                        'reason': reasonCtrl.text.trim(),
                        'carry_marksheet': carryMarksheet,
                        'carry_character': carryCharacter,
                      });
                      setModalState(() => isSaving = false);
                      if (res.success) {
                        Navigator.pop(ctx);
                        _loadOverview();
                        _loadTransfers();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                      }
                    },
                    child: Text(isSaving ? 'Issuing...' : 'Authorize & Issue TC', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoreCertQuickCard({
    required String title,
    required String nepali,
    required IconData icon,
    required Color color,
    required String typeKey,
  }) {
    return Container(
      width: 145,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              InkWell(
                onTap: () => _showGenerateCertificateSheet(typeKey),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 11),
                      const SizedBox(width: 2),
                      Text('Issue', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.dark), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(nepali, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w500, color: AppTheme.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // Generate Certificate Sheet
  void _showGenerateCertificateSheet([String initialType = 'character']) {
    int? selectedStudentId;
    String? selectedStudentName;
    List<dynamic> studentSearchResults = [];
    bool isSearching = false;

    String certType = initialType;
    final Map<String, String> defaultPurposes = {
      'transfer': 'Transfer to another recognized institution / college',
      'character': 'Academic verification & higher studies application',
      'bonafide': 'Official verification / passport / bank / scholarship',
      'school_leaving': 'Completion of secondary school course & higher studies',
      'migration': 'Board migration & university admission clearance',
      'admission': 'Proof of enrollment & admission verification',
      'achievement': 'Academic & co-curricular excellence recognition',
    };
    final TextEditingController purposeCtrl = TextEditingController(
      text: defaultPurposes[initialType] ?? 'Academic verification & further studies',
    );
    bool withDigitalStamp = true;
    bool withSignature = true;
    String language = 'en';
    DateTime issueDate = DateTime.now();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Generate Official Certificate', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                // Student Picker
                Text('Student *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (selectedStudentName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.secondary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(selectedStudentName!, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.secondary))),
                        IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setModalState(() { selectedStudentId = null; selectedStudentName = null; })),
                      ],
                    ),
                  ),
                ] else ...[
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Search student by name...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: isSearching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) async {
                      if (val.trim().length >= 2) {
                        setModalState(() => isSearching = true);
                        final res = await _api.searchStudents(val.trim());
                        setModalState(() {
                          isSearching = false;
                          studentSearchResults = res.success ? (res.data ?? []) : [];
                        });
                      }
                    },
                  ),
                  if (studentSearchResults.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 130),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: studentSearchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final st = studentSearchResults[i];
                          final stName = st['name'] ?? '${st['first_name'] ?? ''} ${st['last_name'] ?? ''}'.trim();
                          final stClass = st['class_name'] ?? st['class'] ?? '';
                          return ListTile(
                            dense: true,
                            title: Text(stName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                            subtitle: Text(stClass, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
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
                const SizedBox(height: 12),
                Text('Certificate Type *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: certType,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  items: const [
                    DropdownMenuItem(value: 'transfer', child: Text('Transfer Certificate (TC)')),
                    DropdownMenuItem(value: 'character', child: Text('Character Certificate')),
                    DropdownMenuItem(value: 'bonafide', child: Text('Bonafide Study Certificate')),
                    DropdownMenuItem(value: 'school_leaving', child: Text('School Leaving Certificate (SLC)')),
                    DropdownMenuItem(value: 'migration', child: Text('Migration Certificate')),
                    DropdownMenuItem(value: 'admission', child: Text('Proof of Admission')),
                    DropdownMenuItem(value: 'achievement', child: Text('Achievement & Honors Certificate')),
                  ],
                  onChanged: (v) { if (v != null) setModalState(() => certType = v); },
                ),
                const SizedBox(height: 12),
                Text('Purpose of Issuance', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(controller: purposeCtrl, decoration: InputDecoration(hintText: 'e.g. Higher secondary admissions, passport/visa, scholarship', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 12),
                // Verification Toggles
                SwitchListTile(
                  value: withDigitalStamp,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Apply Digital School Seal / Stamp', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text('Authenticates document with school emblem', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                  onChanged: (v) => setModalState(() => withDigitalStamp = v),
                ),
                SwitchListTile(
                  value: withSignature,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Apply Principal Digital Signature', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text('Official executive endorsement & QR code verification', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                  onChanged: (v) => setModalState(() => withSignature = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isSaving ? null : () async {
                      if (selectedStudentId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student')));
                        return;
                      }
                      setModalState(() => isSaving = true);
                      final res = await _api.generateCertificate({
                        'student_id': selectedStudentId,
                        'type': certType,
                        'purpose': purposeCtrl.text.trim(),
                        'issued_date': DateFormat('yyyy-MM-dd').format(issueDate),
                        'with_digital_stamp': withDigitalStamp,
                        'with_signature': withSignature,
                        'language': language,
                      });
                      setModalState(() => isSaving = false);
                      if (res.success) {
                        Navigator.pop(ctx);
                        _loadOverview();
                        _loadCertificates();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                      }
                    },
                    child: Text(isSaving ? 'Generating...' : '1-Tap Generate & Issue Certificate', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value, String selectedValue, ValueChanged<String> onSelected, {String? badge}) {
    final isSel = selectedValue == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badge != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: isSel ? Colors.white : AppTheme.crimson, borderRadius: BorderRadius.circular(8)),
              child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isSel ? AppTheme.primary : Colors.white)),
            ),
          ],
        ],
      ),
      selected: isSel,
      selectedColor: AppTheme.primary,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.dark),
      onSelected: (_) => onSelected(value),
    );
  }
}
