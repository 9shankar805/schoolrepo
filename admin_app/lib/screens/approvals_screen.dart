import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/approvals_provider.dart';
import '../theme/app_theme.dart';
import 'admissions_management_screen.dart';
import 'staff_leave_management_screen.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({Key? key}) : super(key: key);

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _showApprovalDialog({
    required BuildContext context,
    required String title,
    required String subtitle,
    required VoidCallback onApprove,
    required VoidCallback onReject,
  }) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'Add reviewer remarks (optional)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onReject();
            },
            child: const Text('Reject', style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onApprove();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final approvals = Provider.of<ApprovalsProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Executive Approvals',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: [
            Tab(text: 'Leaves (${approvals.leaves.length})'),
            Tab(text: 'Expenses (${approvals.expenses.length})'),
            Tab(text: 'Admissions (${approvals.admissions.length})'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => approvals.fetchApprovals(),
        child: approvals.isLoading && approvals.totalPending == 0
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Staff Leaves
                  _buildLeavesList(approvals),
                  // Tab 2: Expense Vouchers
                  _buildExpensesList(approvals),
                  // Tab 3: Admissions
                  _buildAdmissionsList(approvals),
                ],
              ),
      ),
    );
  }

  Widget _buildLeavesList(ApprovalsProvider approvals) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StaffLeaveManagementScreen()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.purple.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_busy_rounded, color: AppTheme.purple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HR Staff Leave Center',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.purple),
                      ),
                      Text(
                        'Manage quotas, past history, attendance sync & grant leaves',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.purple),
              ],
            ),
          ),
        ),
        if (approvals.leaves.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No pending staff leave applications.')),
          )
        else
          ...approvals.leaves.map((item) {
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
                        Text(
                          item['user_name'] ?? 'Staff',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.royalBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item['total_days']} Days',
                        style: const TextStyle(color: AppTheme.royalBlue, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['leave_type']} • ${item['from_date']} to ${item['to_date']}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Text(
                  '"${item['reason'] ?? 'No reason provided'}"',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showApprovalDialog(
                          context: context,
                          title: 'Reject Leave',
                          subtitle: 'Are you sure you want to reject ${item['user_name']}\'s leave request?',
                          onApprove: () {},
                          onReject: () => approvals.handleLeave(item['id'], 'reject'),
                        ),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.crimson),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showApprovalDialog(
                          context: context,
                          title: 'Approve Leave',
                          subtitle: 'Approve ${item['total_days']} days leave for ${item['user_name']}?',
                          onApprove: () => approvals.handleLeave(item['id'], 'approve'),
                          onReject: () {},
                        ),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ],
  );
}

  Widget _buildExpensesList(ApprovalsProvider approvals) {
    if (approvals.expenses.isEmpty) {
      return const Center(child: Text('No pending expense claims or vouchers.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: approvals.expenses.length,
      itemBuilder: (ctx, idx) {
        final item = approvals.expenses[idx];
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
                        item['title'] ?? 'Expense Claim',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    Text(
                      'NPR ${(item['amount'] as num).toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.crimson,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Category: ${item['category'] ?? 'General'} • Vendor: ${item['vendor']}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                if (item['notes'] != null) ...[
                  const SizedBox(height: 8),
                  Text(item['notes'], style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => approvals.handleExpense(item['id'], 'reject'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.crimson),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => approvals.handleExpense(item['id'], 'approve'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                        child: const Text('Approve Voucher'),
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

  Widget _buildAdmissionsList(ApprovalsProvider approvals) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Banner to Open Full Pipeline
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.emerald.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admissions & Enrollment Hub',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Full pipeline, applicant 360, transport & hostel allocation',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdmissionsManagementScreen()),
                  );
                },
                child: const Text('Open Hub', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ],
          ),
        ),

        if (approvals.admissions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No pending student admission applications.')),
          )
        else
          ...approvals.admissions.map((item) {
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
                        Text(
                          item['student_name'] ?? 'Applicant',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['class_name'] ?? 'New Class',
                            style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Guardian: ${item['guardian_name']} • Phone: ${item['guardian_phone']}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'App No: ${item['application_number']}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => approvals.handleAdmission(item['id'], 'reject'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.crimson),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => approvals.handleAdmission(item['id'], 'approve'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                            child: const Text('Approve & Enroll'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
