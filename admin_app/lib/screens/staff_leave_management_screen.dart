import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class StaffLeaveManagementScreen extends StatefulWidget {
  const StaffLeaveManagementScreen({Key? key}) : super(key: key);

  @override
  State<StaffLeaveManagementScreen> createState() => _StaffLeaveManagementScreenState();
}

class _StaffLeaveManagementScreenState extends State<StaffLeaveManagementScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isProcessingAction = false;
  String _selectedStatus = 'all'; // all, pending, approved, rejected, today
  String _selectedRole = 'all';   // all, teacher, staff
  int? _selectedLeaveTypeId;
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic> _kpis = {
    'total_applications': 0,
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'on_leave_today': 0,
  };

  List<dynamic> _leaves = [];
  List<dynamic> _leaveTypes = [];
  List<dynamic> _staffList = [];

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
      _api.getStaffLeaves(
        status: _selectedStatus,
        role: _selectedRole,
        leaveTypeId: _selectedLeaveTypeId,
        search: _searchController.text.trim(),
      ),
      _api.getStaffLeaveOptions(),
    ]);

    if (!mounted) return;

    final leavesRes = results[0];
    final optionsRes = results[1];

    setState(() {
      _isLoading = false;
      if (leavesRes.success && leavesRes.data != null) {
        _kpis = (leavesRes.data!['kpis'] as Map<String, dynamic>?) ?? _kpis;
        _leaves = (leavesRes.data!['leaves'] as List<dynamic>?) ?? [];
      }
      if (optionsRes.success && optionsRes.data != null) {
        _leaveTypes = (optionsRes.data!['leave_types'] as List<dynamic>?) ?? [];
        _staffList = (optionsRes.data!['staff'] as List<dynamic>?) ?? [];
      }
    });
  }

  Future<void> _handleLeaveAction(int id, String action) async {
    final noteController = TextEditingController();
    final isApprove = action == 'approve';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isApprove ? AppTheme.emerald : AppTheme.crimson).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isApprove ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                color: isApprove ? AppTheme.emerald : AppTheme.crimson,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isApprove ? 'Approve Leave' : 'Reject Leave',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApprove
                  ? 'Approve this staff leave request? Remaining balance will be adjusted and attendance will be marked automatically.'
                  : 'Reject this staff leave request? Please provide the rejection reason.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: isApprove ? 'Reviewer Remarks (Optional)' : 'Rejection Reason *',
                hintText: isApprove ? 'e.g. Approved with substitute coverage.' : 'e.g. Critical exam day duties.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? AppTheme.emerald : AppTheme.crimson,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (!isApprove && noteController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(isApprove ? 'Approve Request' : 'Reject Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingAction = true);
    final res = await _api.handleStaffLeave(
      id,
      action: action,
      reviewerNotes: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
    );
    setState(() => _isProcessingAction = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
      if (res.success) {
        _loadData();
      }
    }
  }

  void _showLeaveDetailModal(Map<String, dynamic> item) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StaffLeaveDetailSheet(
        leaveId: item['id'],
        initialData: item,
        onAction: (act) {
          Navigator.pop(ctx);
          _handleLeaveAction(item['id'], act);
        },
      ),
    );
  }

  void _showCreateLeaveModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateStaffLeaveSheet(
        staffList: _staffList,
        leaveTypes: _leaveTypes,
        onCreated: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Staff Leave Center',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.royalBlue),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.royalBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Grant Leave', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        onPressed: _showCreateLeaveModal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKpiGrid(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildStatusFilters(),
                    const SizedBox(height: 8),
                    _buildRoleFilters(),
                    const SizedBox(height: 16),
                    _buildLeavesList(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKpiGrid() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final itemWidth = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildKpiCard(
            title: 'Pending Requests',
            value: _kpis['pending']?.toString() ?? '0',
            icon: Icons.hourglass_top_rounded,
            color: AppTheme.amber,
            width: itemWidth,
            active: _selectedStatus == 'pending',
            onTap: () {
              setState(() => _selectedStatus = _selectedStatus == 'pending' ? 'all' : 'pending');
              _loadData();
            },
          ),
          _buildKpiCard(
            title: 'On Leave Today',
            value: _kpis['on_leave_today']?.toString() ?? '0',
            icon: Icons.event_busy_rounded,
            color: AppTheme.purple,
            width: itemWidth,
            active: _selectedStatus == 'today',
            onTap: () {
              setState(() => _selectedStatus = _selectedStatus == 'today' ? 'all' : 'today');
              _loadData();
            },
          ),
          _buildKpiCard(
            title: 'Approved',
            value: _kpis['approved']?.toString() ?? '0',
            icon: Icons.check_circle_rounded,
            color: AppTheme.emerald,
            width: itemWidth,
            active: _selectedStatus == 'approved',
            onTap: () {
              setState(() => _selectedStatus = _selectedStatus == 'approved' ? 'all' : 'approved');
              _loadData();
            },
          ),
          _buildKpiCard(
            title: 'Total Requests',
            value: _kpis['total_applications']?.toString() ?? '0',
            icon: Icons.folder_shared_rounded,
            color: AppTheme.royalBlue,
            width: itemWidth,
            active: _selectedStatus == 'all',
            onTap: () {
              setState(() => _selectedStatus = 'all');
              _loadData();
            },
          ),
        ],
      );
    });
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : AppTheme.glassBorder,
            width: active ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
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
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: (_) => _loadData(),
        decoration: InputDecoration(
          hintText: 'Search staff by name, email, or phone...',
          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.royalBlue, size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _loadData();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    final filters = [
      {'id': 'all',      'label': 'All Requests'},
      {'id': 'pending',  'label': 'Pending'},
      {'id': 'today',    'label': 'On Leave Today'},
      {'id': 'approved', 'label': 'Approved'},
      {'id': 'rejected', 'label': 'Rejected'},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final f = filters[idx];
          final isSelected = _selectedStatus == f['id'];
          return ChoiceChip(
            label: Text(f['label']!),
            selected: isSelected,
            onSelected: (val) {
              if (val) {
                setState(() => _selectedStatus = f['id']!);
                _loadData();
              }
            },
            selectedColor: AppTheme.royalBlue,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textPrimary,
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: isSelected ? AppTheme.royalBlue : AppTheme.glassBorder),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleFilters() {
    final roles = [
      {'id': 'all',     'label': 'All Staff'},
      {'id': 'teacher', 'label': 'Teachers & Faculty'},
      {'id': 'staff',   'label': 'Admin & Support Staff'},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: roles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final r = roles[idx];
          final isSelected = _selectedRole == r['id'];
          return FilterChip(
            label: Text(r['label']!),
            selected: isSelected,
            onSelected: (val) {
              setState(() => _selectedRole = r['id']!);
              _loadData();
            },
            selectedColor: AppTheme.purple.withOpacity(0.15),
            checkmarkColor: AppTheme.purple,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.purple : AppTheme.textMuted,
            ),
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isSelected ? AppTheme.purple : AppTheme.glassBorder),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeavesList() {
    if (_leaves.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.royalBlue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available_rounded, size: 48, color: AppTheme.royalBlue),
            ),
            const SizedBox(height: 16),
            Text(
              'No Staff Leave Applications',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'There are no leave applications matching your current filter criteria.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _leaves.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final item = _leaves[idx] as Map<String, dynamic>;
        return _buildLeaveCard(item);
      },
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isOnLeaveToday = item['is_on_leave_today'] == true;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isOnLeaveToday) {
      statusColor = AppTheme.purple;
      statusLabel = 'On Leave Today';
      statusIcon = Icons.beach_access_rounded;
    } else if (isApproved) {
      statusColor = AppTheme.emerald;
      statusLabel = 'Approved';
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (status == 'rejected') {
      statusColor = AppTheme.crimson;
      statusLabel = 'Rejected';
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColor = AppTheme.amber;
      statusLabel = 'Pending Review';
      statusIcon = Icons.hourglass_empty_rounded;
    }

    final balance = item['balance'] as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOnLeaveToday ? AppTheme.purple.withOpacity(0.4) : AppTheme.glassBorder,
          width: isOnLeaveToday ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLeaveDetailModal(item),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Staff Info & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
                      backgroundImage: item['staff_photo_url'] != null
                          ? NetworkImage(item['staff_photo_url'])
                          : null,
                      child: item['staff_photo_url'] == null
                          ? Text(
                              (item['staff_name'] ?? 'S')[0].toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.royalBlue,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['staff_name'] ?? 'Staff Member',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['staff_role'] ?? 'Staff',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Middle: Leave Type and Dates
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.royalBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item['leave_type_name'] ?? 'Leave',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.royalBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${item['from_date']} to ${item['to_date']}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${item['total_days']} ${item['total_days'] == 1 ? 'day' : 'days'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.purple,
                        ),
                      ),
                    ],
                  ),
                ),

                // Reason
                if (item['reason'] != null && item['reason'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '"${item['reason']}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textPrimary.withOpacity(0.85),
                    ),
                  ),
                ],

                // Leave Balance preview
                if (balance != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Annual Quota Balance',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      Text(
                        '${balance['remaining_days']} / ${balance['total_days']} days left',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (balance['remaining_days'] as int) < 3 ? AppTheme.crimson : AppTheme.emerald,
                        ),
                      ),
                    ],
                  ),
                ],

                // Action buttons for pending leaves
                if (isPending) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.crimson,
                            side: const BorderSide(color: AppTheme.crimson),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _handleLeaveAction(item['id'], 'reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _handleLeaveAction(item['id'], 'approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Staff Leave Detail 360 Bottom Sheet
// -----------------------------------------------------------------------------
class _StaffLeaveDetailSheet extends StatefulWidget {
  final int leaveId;
  final Map<String, dynamic> initialData;
  final Function(String action) onAction;

  const _StaffLeaveDetailSheet({
    Key? key,
    required this.leaveId,
    required this.initialData,
    required this.onAction,
  }) : super(key: key);

  @override
  State<_StaffLeaveDetailSheet> createState() => _StaffLeaveDetailSheetState();
}

class _StaffLeaveDetailSheetState extends State<_StaffLeaveDetailSheet> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final res = await _api.getStaffLeaveDetails(widget.leaveId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        _detail = res.data;
      } else {
        _detail = widget.initialData;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _detail ?? widget.initialData;
    final isPending = (data['status'] ?? '').toString().toLowerCase() == 'pending';
    final balances = (data['balances'] as List<dynamic>?) ?? [];
    final history = (data['recent_history'] as List<dynamic>?) ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Leave Application 360°',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Staff Card
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
                              backgroundImage: data['staff_photo_url'] != null
                                  ? NetworkImage(data['staff_photo_url'])
                                  : null,
                              child: data['staff_photo_url'] == null
                                  ? Text(
                                      (data['staff_name'] ?? 'S')[0].toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                        color: AppTheme.royalBlue,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['staff_name'] ?? 'Staff Member',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                  Text(
                                    data['staff_role'] ?? 'Staff',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (data['staff_email'] != null)
                                    Text(
                                      data['staff_email'],
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Request Details
                        _buildSectionHeader('Application Details'),
                        const SizedBox(height: 10),
                        _buildDetailTile('Leave Type', data['leave_type_name'] ?? 'General Leave'),
                        _buildDetailTile('Duration', '${data['from_date']} to ${data['to_date']} (${data['total_days']} days)'),
                        _buildDetailTile('Reason', data['reason'] ?? 'Not specified'),
                        _buildDetailTile('Current Status', (data['status'] ?? 'pending').toString().toUpperCase()),
                        if (data['reviewed_by_name'] != null)
                          _buildDetailTile('Reviewed By', '${data['reviewed_by_name']} on ${data['reviewed_at'] ?? ''}'),
                        if (data['reviewer_notes'] != null && data['reviewer_notes'].toString().isNotEmpty)
                          _buildDetailTile('Reviewer Remarks', data['reviewer_notes']),

                        const SizedBox(height: 20),

                        // Entitlements & Balances
                        _buildSectionHeader('Annual Leave Quotas & Utilization'),
                        const SizedBox(height: 10),
                        if (balances.isEmpty)
                          Text('No balance quotas found for this staff.', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted))
                        else
                          ...balances.map((b) => _buildBalanceRow(b)).toList(),

                        const SizedBox(height: 20),

                        // History
                        if (history.isNotEmpty) ...[
                          _buildSectionHeader('Past Leave Requests (This Year)'),
                          const SizedBox(height: 10),
                          ...history.map((h) => _buildHistoryRow(h)).toList(),
                        ],
                      ],
                    ),
                  ),
          ),
          if (isPending)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.crimson,
                        side: const BorderSide(color: AppTheme.crimson),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => widget.onAction('reject'),
                      child: const Text('Reject Leave', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => widget.onAction('approve'),
                      child: const Text('Approve Leave', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        fontSize: 14,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildDetailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(dynamic b) {
    final remaining = (b['remaining_days'] ?? 0) as int;
    final total = (b['total_days'] ?? 0) as int;
    final pct = total > 0 ? (total - remaining) / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                b['name'] ?? 'Leave',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                '$remaining / $total days remaining',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: remaining < 3 ? AppTheme.crimson : AppTheme.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                remaining < 3 ? AppTheme.crimson : AppTheme.royalBlue,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(dynamic h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h['leave_type'] ?? 'Leave', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12)),
              Text('${h['from_date']} - ${h['to_date']}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (h['status'] == 'approved' ? AppTheme.emerald : AppTheme.crimson).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              (h['status'] ?? '').toString().toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: h['status'] == 'approved' ? AppTheme.emerald : AppTheme.crimson,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Grant / Create Staff Leave Modal
// -----------------------------------------------------------------------------
class _CreateStaffLeaveSheet extends StatefulWidget {
  final List<dynamic> staffList;
  final List<dynamic> leaveTypes;
  final VoidCallback onCreated;

  const _CreateStaffLeaveSheet({
    Key? key,
    required this.staffList,
    required this.leaveTypes,
    required this.onCreated,
  }) : super(key: key);

  @override
  State<_CreateStaffLeaveSheet> createState() => _CreateStaffLeaveSheetState();
}

class _CreateStaffLeaveSheetState extends State<_CreateStaffLeaveSheet> {
  final ApiService _api = ApiService();
  int? _selectedUserId;
  int? _selectedLeaveTypeId;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  final TextEditingController _reasonController = TextEditingController();
  bool _directApprove = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.staffList.isNotEmpty) {
      _selectedUserId = widget.staffList.first['id'];
    }
    if (widget.leaveTypes.isNotEmpty) {
      _selectedLeaveTypeId = widget.leaveTypes.first['id'];
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _calculatedDays {
    return _toDate.difference(_fromDate).inDays + 1;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedUserId == null || _selectedLeaveTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select staff member and leave type.')),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for the leave.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final res = await _api.createStaffLeave({
      'user_id': _selectedUserId,
      'leave_type_id': _selectedLeaveTypeId,
      'from_date': _fromDate.toIso8601String().substring(0, 10),
      'to_date': _toDate.toIso8601String().substring(0, 10),
      'reason': _reasonController.text.trim(),
      'status': _directApprove ? 'approved' : 'pending',
    });
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
      if (res.success) {
        widget.onCreated();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grant / Record Staff Leave',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Select Staff Member
                  Text(
                    'Staff Member *',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.glassBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: (() {
                        final uniqueStaff = <int, Map<String, dynamic>>{};
                        for (final s in widget.staffList) {
                          if (s is Map && s['id'] != null) {
                            uniqueStaff[s['id'] as int] = Map<String, dynamic>.from(s);
                          }
                        }
                        final items = uniqueStaff.values.map<DropdownMenuItem<int>>((s) {
                          return DropdownMenuItem<int>(
                            value: s['id'] as int,
                            child: Text(
                              '${s['name']} (${s['role']})',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList();
                        final safeVal = uniqueStaff.containsKey(_selectedUserId) ? _selectedUserId : (uniqueStaff.isNotEmpty ? uniqueStaff.keys.first : null);

                        return DropdownButton<int>(
                          isExpanded: true,
                          value: safeVal,
                          items: items,
                          onChanged: (val) => setState(() => _selectedUserId = val),
                        );
                      })(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Select Leave Type
                  Text(
                    'Leave Type *',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.glassBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: (() {
                        final uniqueTypes = <int, Map<String, dynamic>>{};
                        for (final t in widget.leaveTypes) {
                          if (t is Map && t['id'] != null) {
                            uniqueTypes[t['id'] as int] = Map<String, dynamic>.from(t);
                          }
                        }
                        final items = uniqueTypes.values.map<DropdownMenuItem<int>>((t) {
                          return DropdownMenuItem<int>(
                            value: t['id'] as int,
                            child: Text(
                              '${t['name']} (${t['days_allowed'] ?? 0} days quota)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList();
                        final safeVal = uniqueTypes.containsKey(_selectedLeaveTypeId) ? _selectedLeaveTypeId : (uniqueTypes.isNotEmpty ? uniqueTypes.keys.first : null);

                        return DropdownButton<int>(
                          isExpanded: true,
                          value: safeVal,
                          items: items,
                          onChanged: (val) => setState(() => _selectedLeaveTypeId = val),
                        );
                      })(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date Range Picker Card
                  Text(
                    'Leave Duration *',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.royalBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppTheme.royalBlue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_fromDate.toIso8601String().substring(0, 10)}  to  ${_toDate.toIso8601String().substring(0, 10)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to choose date range',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.royalBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_calculatedDays ${_calculatedDays == 1 ? 'day' : 'days'}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: AppTheme.royalBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reason
                  Text(
                    'Reason for Leave *',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _reasonController,
                    decoration: InputDecoration(
                      hintText: 'Enter reason or purpose of leave...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Direct Approve Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Directly Approve & Deduct Balance',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Immediately marks staff on leave in attendance register and updates annual quota balance.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    value: _directApprove,
                    activeColor: AppTheme.emerald,
                    onChanged: (val) => setState(() => _directApprove = val),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Confirm & Record Leave',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
