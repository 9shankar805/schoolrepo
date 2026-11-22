import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class VisitorManagerScreen extends StatefulWidget {
  const VisitorManagerScreen({Key? key}) : super(key: key);

  @override
  State<VisitorManagerScreen> createState() => _VisitorManagerScreenState();
}

class _VisitorManagerScreenState extends State<VisitorManagerScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isCheckingIn = false;
  String _selectedStatus = 'active'; // 'active', 'checked_out', 'all'
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic> _stats = {
    'active_now': 0,
    'today_total': 0,
    'today_checked_out': 0,
    'avg_stay_label': '0m',
  };

  List<dynamic> _visitors = [];

  static const List<String> _purposePresets = [
    'Meeting Principal',
    'Parent Conference / PTM',
    'Fee Payment & Accounts',
    'Admission Inquiry',
    'Vendor / Supplier',
    'Maintenance / Contractor',
    'Government Inspection',
    'Guest / Official Visit',
  ];

  static const List<String> _meetingPresets = [
    'Principal',
    'Vice Principal',
    'Account Office',
    'Academic Coordinator',
    'Class Teacher',
    'Admin Office',
  ];

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  Future<void> _loadVisitors() async {
    setState(() => _isLoading = true);
    final res = await _api.getVisitors(
      status: _selectedStatus,
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );

    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        final data = res.data!;
        _stats = (data['stats'] as Map<String, dynamic>?) ?? _stats;
        _visitors = (data['visitors'] as List<dynamic>?) ?? [];
      } else {
        _visitors = [];
      }
    });
  }

  Future<void> _handleCheckOut(dynamic visitor) async {
    final vId = visitor['id'] as int;
    final vName = visitor['name'] ?? 'Visitor';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Check Out Visitor?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'Confirm that $vName (Badge: ${visitor['badge_number']}) has exited the campus premises.',
          style: const TextStyle(fontSize: 13, color: AppTheme.dark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Exit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _api.checkOutVisitor(vId);
    if (res.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
      _loadVisitors();
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

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot call $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int activeCount = (_stats['active_now'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Front Desk & Campus Visitors',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.dark,
              ),
            ),
            Text(
              'Security reception, active roll call & visitor passes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Emergency Roll Call Button
          TextButton.icon(
            onPressed: _showEmergencyRollCallModal,
            icon: const Icon(Icons.emergency_rounded, color: AppTheme.crimson, size: 20),
            label: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.crimsonLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    'Roll Call',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.crimson,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: const BoxDecoration(
                      color: AppTheme.crimson,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.dark),
            onPressed: _loadVisitors,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. KPI Headcount Ribbon
          _buildHeadcountRibbon(),

          // 2. Search & Filter Bar
          _buildSearchAndFilterBar(),

          // 3. Visitor Roster List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _visitors.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadVisitors,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: _visitors.length,
                          itemBuilder: (ctx, idx) {
                            final v = _visitors[idx];
                            return _buildVisitorCard(v);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _showCheckInModal,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: Text(
          'Check-In Visitor',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Headcount Ribbon
  // ---------------------------------------------------------------------------
  Widget _buildHeadcountRibbon() {
    final activeNow = _stats['active_now'] ?? 0;
    final todayTotal = _stats['today_total'] ?? 0;
    final todayCheckedOut = _stats['today_checked_out'] ?? 0;
    final avgStay = _stats['avg_stay_label'] ?? '0m';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Active Inside Now (Highlighted)
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emerald.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'INSIDE CAMPUS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$activeNow',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Active Visitors',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Today Total
          Expanded(
            flex: 3,
            child: _buildMiniKpi(
              label: 'Total Today',
              val: '$todayTotal',
              icon: Icons.login_rounded,
              color: AppTheme.royalBlue,
            ),
          ),
          const SizedBox(width: 8),

          // Checked Out
          Expanded(
            flex: 3,
            child: _buildMiniKpi(
              label: 'Exited',
              val: '$todayCheckedOut',
              icon: Icons.logout_rounded,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 8),

          // Avg Stay
          Expanded(
            flex: 3,
            child: _buildMiniKpi(
              label: 'Avg Stay',
              val: avgStay,
              icon: Icons.timer_outlined,
              color: AppTheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKpi({
    required String label,
    required String val,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            val,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.dark,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Search & Filter Bar
  // ---------------------------------------------------------------------------
  Widget _buildSearchAndFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Search TextField
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search visitor name, phone, badge, or purpose...',
              hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _loadVisitors();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AppTheme.lightBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
            ),
            onSubmitted: (_) => _loadVisitors(),
          ),
          const SizedBox(height: 10),

          // Status Filter Tabs
          Row(
            children: [
              _buildFilterChip(
                label: 'Active On Campus (${_stats['active_now'] ?? 0})',
                statusKey: 'active',
                color: AppTheme.emerald,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Checked Out (${_stats['today_checked_out'] ?? 0})',
                statusKey: 'checked_out',
                color: AppTheme.royalBlue,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'All Logs',
                statusKey: 'all',
                color: AppTheme.dark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String statusKey,
    required Color color,
  }) {
    final isSelected = _selectedStatus == statusKey;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedStatus != statusKey) {
            setState(() => _selectedStatus = statusKey);
            _loadVisitors();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : AppTheme.lightBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected ? color : AppTheme.borderLight,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? color : AppTheme.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Visitor Card Item
  // ---------------------------------------------------------------------------
  Widget _buildVisitorCard(dynamic v) {
    final bool isActive = v['status'] == 'active';
    final name = v['name'] ?? 'Visitor';
    final phone = v['phone'] ?? '';
    final badge = v['badge_number'] ?? 'VIS';
    final organization = v['organization'] ?? 'Private / Guardian';
    final purpose = v['purpose'] ?? 'General Visit';
    final personToMeet = v['person_to_meet'] ?? 'Office';
    final checkInTime = v['check_in_time'] ?? '00:00';
    final durationLabel = v['duration_label'] ?? '0m';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppTheme.emerald.withOpacity(0.3) : AppTheme.borderLight,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showBadgeDetailModal(v),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar + Name + Status Tag
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isActive ? AppTheme.emeraldLight : AppTheme.greyLight,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'V',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isActive ? AppTheme.emerald : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name & Organization
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppTheme.dark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.lightBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.dark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          organization,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Status Indicator Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.emeraldLight : AppTheme.lightBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          isActive ? 'ON CAMPUS' : 'EXITED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isActive ? AppTheme.emerald : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Middle: Purpose & Meeting Details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flag_outlined, size: 13, color: AppTheme.royalBlue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                purpose,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.dark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_pin_circle_outlined, size: 13, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'Meeting: $personToMeet',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Timing & Duration Tag
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'In: $checkInTime',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.dark),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.emeraldLight : AppTheme.greyLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'Stay: $durationLabel' : 'Duration: $durationLabel',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive ? AppTheme.emerald : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bottom Actions Row
              Row(
                children: [
                  // Call Visitor
                  if (phone.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _makePhoneCall(phone),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: AppTheme.borderLight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.call_outlined, size: 14, color: AppTheme.primary),
                      label: Text(phone, style: const TextStyle(fontSize: 11, color: AppTheme.dark)),
                    ),

                  const Spacer(),

                  // Digital Badge Button
                  TextButton.icon(
                    onPressed: () => _showBadgeDetailModal(v),
                    icon: const Icon(Icons.badge_outlined, size: 14, color: AppTheme.royalBlue),
                    label: const Text('Pass Badge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalBlue)),
                  ),

                  // 1-Tap Checkout Button (for active visitors)
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => _handleCheckOut(v),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white),
                      label: Text(
                        'Check Out',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Quick Visitor Check-in Modal Sheet
  // ---------------------------------------------------------------------------
  void _showCheckInModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final orgCtrl = TextEditingController();
    final idNumberCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    String selectedPurpose = _purposePresets.first;
    String selectedPersonToMeet = _meetingPresets.first;
    String selectedIdType = 'citizenship';

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
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Visitor Check-In & Gate Pass',
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
                    const SizedBox(height: 6),
                    const Text(
                      'Register visitor arrival and generate official security access badge.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 18),

                    // Full Name
                    Text('Visitor Full Name *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Dr. Anil Sharma, Maya Shrestha',
                        filled: true,
                        fillColor: AppTheme.lightBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone & Organization
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mobile Phone *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  hintText: '98XXXXXXXX',
                                  filled: true,
                                  fillColor: AppTheme.lightBg,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
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
                              Text('Organization / Affiliation', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: orgCtrl,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Parent / MOE / Private',
                                  filled: true,
                                  fillColor: AppTheme.lightBg,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Purpose of Visit (Presets + Custom)
                    Text('Purpose of Visit *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPurpose,
                          isExpanded: true,
                          items: _purposePresets.map<DropdownMenuItem<String>>((p) {
                            return DropdownMenuItem<String>(
                              value: p,
                              child: Text(p, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedPurpose = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Person / Department to Meet
                    Text('Person / Office to Meet *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPersonToMeet,
                          isExpanded: true,
                          items: _meetingPresets.map<DropdownMenuItem<String>>((m) {
                            return DropdownMenuItem<String>(
                              value: m,
                              child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedPersonToMeet = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ID Type & ID Number
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID Type', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderLight),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedIdType,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'citizenship', child: Text('Citizenship', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'national_id', child: Text('National ID', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'license', child: Text('Driving License', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'passport', child: Text('Passport', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'other', child: Text('Other ID', style: TextStyle(fontSize: 12))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => selectedIdType = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID / Registration No.', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: idNumberCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Optional ID number',
                                  filled: true,
                                  fillColor: AppTheme.lightBg,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Special Notes
                    Text('Notes / Observations', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        hintText: 'Any special remarks or vehicle number...',
                        filled: true,
                        fillColor: AppTheme.lightBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 22),

                    // Submit Check-in Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isCheckingIn
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final phone = phoneCtrl.text.trim();

                                if (name.isEmpty || phone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Name and Phone number are required.')),
                                  );
                                  return;
                                }

                                Navigator.pop(modalCtx);
                                setState(() => _isLoading = true);

                                final payload = {
                                  'name': name,
                                  'phone': phone,
                                  'organization': orgCtrl.text.trim().isEmpty ? null : orgCtrl.text.trim(),
                                  'purpose': selectedPurpose,
                                  'person_to_meet': selectedPersonToMeet,
                                  'id_type': selectedIdType,
                                  'id_number': idNumberCtrl.text.trim().isEmpty ? null : idNumberCtrl.text.trim(),
                                  'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                };

                                final res = await _api.checkInVisitor(payload);
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
                                  _loadVisitors();
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
                          'Generate Gate Badge & Confirm Check-In',
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
  // 5. Emergency Campus Roll Call Modal (Crisis Evacuation Mode)
  // ---------------------------------------------------------------------------
  void _showEmergencyRollCallModal() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppTheme.crimson)),
    );

    final res = await _api.getEmergencyRollCall();
    if (mounted) Navigator.pop(context); // Dismiss loader

    if (!res.success || res.data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load emergency roll call.')),
        );
      }
      return;
    }

    final data = res.data!;
    final totalOnCampus = data['total_on_campus'] ?? 0;
    final campusName = data['campus_name'] ?? 'School Campus';
    final generatedAt = data['generated_at'] ?? '';
    final List<dynamic> visitors = data['visitors'] ?? [];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // High-Visibility Emergency Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emergency_rounded, color: Colors.white, size: 26),
                            const SizedBox(width: 8),
                            Text(
                              'EMERGENCY EVACUATION ROLL CALL',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              campusName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              generatedAt,
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$totalOnCampus',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.crimson,
                                ),
                              ),
                              const Text(
                                'VISITORS INSIDE',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Roll Call Instruction
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.crimsonLight,
                child: const Text(
                  'Account for each person at the evacuation assembly point. Tap call to locate unaccounted visitors.',
                  style: TextStyle(fontSize: 11, color: AppTheme.crimson, fontWeight: FontWeight.w600),
                ),
              ),

              // Visitors Evacuation List
              Expanded(
                child: visitors.isEmpty
                    ? const Center(
                        child: Text(
                          'No external visitors currently logged inside the campus.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: visitors.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (ctx, idx) {
                          final v = visitors[idx];
                          final phone = v['phone'] ?? '';

                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.crimsonLight,
                                child: Text(
                                  '${idx + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v['name'] ?? 'Visitor',
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                                    ),
                                    Text(
                                      'Badge: ${v['badge_number']} • ${v['organization']}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                    Text(
                                      'Meeting: ${v['person_to_meet']} (In: ${v['check_in_time']})',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.dark, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              if (phone.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.phone_forwarded_rounded, color: AppTheme.emerald, size: 22),
                                  tooltip: 'Emergency Call',
                                  onPressed: () => _makePhoneCall(phone),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Visitor Pass / Digital Badge Modal
  // ---------------------------------------------------------------------------
  void _showBadgeDetailModal(dynamic v) {
    final bool isActive = v['status'] == 'active';
    final name = v['name'] ?? 'Visitor';
    final badge = v['badge_number'] ?? 'VIS';
    final phone = v['phone'] ?? '-';
    final org = v['organization'] ?? 'Private / Guardian';
    final purpose = v['purpose'] ?? 'General';
    final meeting = v['person_to_meet'] ?? 'Office';
    final inTime = v['check_in_time'] ?? '-';
    final inDate = v['check_in_date'] ?? '-';
    final duration = v['duration_label'] ?? '-';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge Top Card Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary : AppTheme.dark,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.security_rounded, color: Colors.white, size: 22),
                        Text(
                          'CAMPUS VISITOR PASS',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 13,
                          ),
                        ),
                        const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge Body Details
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      org,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _badgeDetailRow('Phone', phone),
                    _badgeDetailRow('Purpose', purpose),
                    _badgeDetailRow('Person to Meet', meeting),
                    _badgeDetailRow('Checked In', '$inDate at $inTime'),
                    _badgeDetailRow('Duration', duration),
                    _badgeDetailRow('Status', isActive ? 'ACTIVE INSIDE' : 'CHECKED OUT', isHighlighted: isActive),
                  ],
                ),
              ),

              // Action
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close Pass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _badgeDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? AppTheme.emerald : AppTheme.dark,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Empty State
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                Icons.people_outline_rounded,
                size: 44,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Visitors in this Category',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check in arriving guests, parents, and vendors to issue security badges and maintain campus safety.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showCheckInModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
              label: Text(
                'Check-In First Visitor',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
