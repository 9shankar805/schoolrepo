import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/approvals_provider.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import 'dashboard_screen.dart';
import 'approvals_screen.dart';
import 'student_search_screen.dart';
import 'finance_screen.dart';
import 'staff_monitor_screen.dart';
import 'academics_screen.dart';
import 'operations_hub_screen.dart';
import 'coordinator_hub_screen.dart';
import 'hostel_manager_screen.dart';
import 'accountant_dashboard_screen.dart';
import 'vouchers_screen.dart';
import 'student_fees_screen.dart';
import 'inventory_assets_screen.dart';
import 'transport_manager_screen.dart';
import 'exam_controller_screen.dart';
import 'librarian_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _AdminNavData {
  final IconData icon;
  final String label;
  final int? badge;

  const _AdminNavData({
    required this.icon,
    required this.label,
    this.badge,
  });
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboard();
      Provider.of<ApprovalsProvider>(context, listen: false).fetchApprovals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final approvals = Provider.of<ApprovalsProvider>(context);
    final pendingCount = approvals.totalPending;

    // Role-Tailored Navigation Configuration
    final List<Widget> screens;
    final List<_AdminNavData> navItems;

    if (auth.isCoordinator) {
      screens = const [
        DashboardScreen(),
        CoordinatorHubScreen(),
        ApprovalsScreen(),
        AcademicsScreen(),
        StaffMonitorScreen(),
      ];
      navItems = [
        const _AdminNavData(icon: Icons.grid_view_rounded, label: 'Dashboard'),
        const _AdminNavData(icon: Icons.tune_rounded, label: 'Coordination'),
        _AdminNavData(icon: Icons.fact_check_rounded, label: 'Approvals', badge: pendingCount > 0 ? pendingCount : null),
        const _AdminNavData(icon: Icons.auto_stories_rounded, label: 'Academics'),
        const _AdminNavData(icon: Icons.badge_rounded, label: 'Staff'),
      ];
    } else if (auth.isAccountant && !auth.isSuperOrAdmin) {
      screens = const [
        AccountantDashboardScreen(),
        VouchersScreen(),
        FinanceScreen(),
        StudentFeesScreen(),
        InventoryAssetsScreen(),
      ];
      navItems = [
        const _AdminNavData(icon: Icons.point_of_sale_rounded, label: 'Intake'),
        _AdminNavData(icon: Icons.receipt_long_rounded, label: 'Vouchers', badge: pendingCount > 0 ? pendingCount : null),
        const _AdminNavData(icon: Icons.account_balance_wallet_rounded, label: 'Finance'),
        const _AdminNavData(icon: Icons.request_quote_rounded, label: 'Student Fees'),
        const _AdminNavData(icon: Icons.inventory_2_rounded, label: 'Inventory'),
      ];
    } else if (auth.hasRole('hostel-manager') && !auth.isSuperOrAdmin) {
      screens = const [
        DashboardScreen(),
        HostelManagerScreen(),
        ApprovalsScreen(),
        StudentSearchScreen(),
        OperationsHubScreen(),
      ];
      navItems = [
        const _AdminNavData(icon: Icons.grid_view_rounded, label: 'Dashboard'),
        const _AdminNavData(icon: Icons.bed_rounded, label: 'Hostel'),
        _AdminNavData(icon: Icons.fact_check_rounded, label: 'Requests', badge: pendingCount > 0 ? pendingCount : null),
        const _AdminNavData(icon: Icons.people_alt_rounded, label: 'Boarders'),
        const _AdminNavData(icon: Icons.hub_rounded, label: 'Operations'),
      ];
    } else if (auth.hasRole('transport-manager') && !auth.isSuperOrAdmin) {
      screens = const [
        DashboardScreen(),
        TransportManagerScreen(),
        ApprovalsScreen(),
        StudentSearchScreen(),
        OperationsHubScreen(),
      ];
      navItems = [
        const _AdminNavData(icon: Icons.grid_view_rounded, label: 'Dashboard'),
        const _AdminNavData(icon: Icons.directions_bus_rounded, label: 'Transport'),
        _AdminNavData(icon: Icons.fact_check_rounded, label: 'Requests', badge: pendingCount > 0 ? pendingCount : null),
        const _AdminNavData(icon: Icons.airline_seat_recline_normal_rounded, label: 'Fleet'),
        const _AdminNavData(icon: Icons.hub_rounded, label: 'Operations'),
      ];
    } else if (auth.hasRole('exam-controller') && !auth.isSuperOrAdmin) {
      screens = const [
        DashboardScreen(),
        ExamControllerScreen(),
        AcademicsScreen(),
        StudentSearchScreen(),
        OperationsHubScreen(),
      ];
      navItems = [
        const _AdminNavData(icon: Icons.grid_view_rounded, label: 'Dashboard'),
        const _AdminNavData(icon: Icons.assignment_turned_in_rounded, label: 'Exams'),
        const _AdminNavData(icon: Icons.auto_stories_rounded, label: 'Academics'),
        const _AdminNavData(icon: Icons.people_alt_rounded, label: 'Students'),
        const _AdminNavData(icon: Icons.hub_rounded, label: 'Operations'),
      ];
    } else if (auth.hasRole('librarian') && !auth.isSuperOrAdmin) {
      screens = const [
        DashboardScreen(),
        LibrarianScreen(),
        StudentSearchScreen(),
        InventoryAssetsScreen(),
        OperationsHubScreen(),
      ];
      navItems = [
        const _AdminNavData(icon: Icons.grid_view_rounded, label: 'Dashboard'),
        const _AdminNavData(icon: Icons.local_library_rounded, label: 'Circulation'),
        const _AdminNavData(icon: Icons.people_alt_rounded, label: 'Members'),
        const _AdminNavData(icon: Icons.inventory_2_rounded, label: 'Assets'),
        const _AdminNavData(icon: Icons.hub_rounded, label: 'Operations'),
      ];
    } else {
      screens = const [
        DashboardScreen(),
        ApprovalsScreen(),
        StudentSearchScreen(),
        FinanceScreen(),
        StaffMonitorScreen(),
      ];
      navItems = [
        const _AdminNavData(icon: Icons.grid_view_rounded, label: 'Command'),
        _AdminNavData(icon: Icons.fact_check_rounded, label: 'Approvals', badge: pendingCount > 0 ? pendingCount : null),
        const _AdminNavData(icon: Icons.people_alt_rounded, label: 'Students'),
        const _AdminNavData(icon: Icons.account_balance_wallet_rounded, label: 'Finance'),
        const _AdminNavData(icon: Icons.badge_rounded, label: 'Staff'),
      ];
    }

    final safeIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

    return Scaffold(
      extendBody: true,
      body: IosAmbientBackground(
        child: IndexedStack(
          index: safeIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (idx) {
              final item = navItems[idx];
              final isSelected = idx == safeIndex;

              if (isSelected) {
                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = idx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return GestureDetector(
                onTap: () => setState(() => _currentIndex = idx),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      child: Icon(item.icon, color: AppTheme.grey, size: 22),
                    ),
                    if (item.badge != null && item.badge! > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppTheme.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(
                            child: Text(
                              item.badge! > 9 ? '9+' : '${item.badge}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
