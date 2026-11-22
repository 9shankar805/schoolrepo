import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/approvals_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/metric_card.dart';
import '../widgets/common_widgets.dart';
import 'broadcast_screen.dart';
import 'qr_scanner_screen.dart';
import 'login_screen.dart';
import 'academics_screen.dart';
import 'operations_hub_screen.dart';
import 'roles_permissions_screen.dart';
import 'coordinator_hub_screen.dart';
import 'hostel_manager_screen.dart';
import 'transport_manager_screen.dart';
import 'exam_controller_screen.dart';
import 'librarian_screen.dart';
import 'approvals_screen.dart';
import 'discipline_pastoral_screen.dart';
import 'routine_maker_screen.dart';
import 'visitor_manager_screen.dart';
import 'teacher_management_screen.dart';
import 'student_attendance_screen.dart';
import 'notifications_screen.dart';
import 'academic_calendar_screen.dart';
import 'staff_hr_payroll_screen.dart';
import 'certificate_manager_screen.dart';
import 'school_settings_screen.dart';
import 'admissions_management_screen.dart';
import 'student_promotion_screen.dart';
import 'student_id_card_screen.dart';
import 'campus_infirmary_screen.dart';
import 'syllabus_homework_screen.dart';
import 'staff_leave_management_screen.dart';
import 'analytics_reports_screen.dart';
import 'crisis_sos_screen.dart';
import '../services/app_security_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final dash = Provider.of<DashboardProvider>(context);
    final approvals = Provider.of<ApprovalsProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);

    final kpis = dash.kpis ?? {};
    final finance = dash.finance ?? {};

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            await Future.wait([
              dash.fetchDashboard(silent: true),
              approvals.fetchApprovals(),
            ]);
          },
          child: dash.isLoading && dash.data == null
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern Header Matching Parent App
                      _buildHeader(context, auth, dash, theme, isDark),
                      const SizedBox(height: 18),

                      // Executive Hero Gradient Card
                      _buildHeroCard(context, auth, dash, approvals, kpis, finance),
                      const SizedBox(height: 18),

                      // Urgent Approvals Banner
                      if (approvals.totalPending > 0) ...[
                        _buildApprovalsAlert(context, approvals, isDark),
                        const SizedBox(height: 18),
                      ],

                      // 4-Grid Key Metrics
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const StudentAttendanceScreen()),
                              );
                            },
                            child: MetricCard(
                              title: 'Students Today',
                              value: '${kpis['student_att_rate'] ?? 0}%',
                              subtitle: '${kpis['students_present'] ?? 0} / ${kpis['total_students'] ?? 0}',
                              icon: Icons.school_rounded,
                              color: AppTheme.primary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TeacherManagementScreen()),
                              );
                            },
                            child: MetricCard(
                              title: 'Staff On Duty',
                              value: '${kpis['teachers_present'] ?? 0}',
                              subtitle: 'Total: ${kpis['total_teachers'] ?? 0}',
                              icon: Icons.badge_rounded,
                              color: AppTheme.green,
                            ),
                          ),
                          MetricCard(
                            title: 'Cash Collected Today',
                            value: 'NPR ${(finance['today_collection'] ?? 0).toInt()}',
                            subtitle: 'Today',
                            icon: Icons.payments_rounded,
                            color: AppTheme.orange,
                          ),
                          MetricCard(
                            title: 'Total Dues',
                            value: 'NPR ${(finance['total_dues_amount'] ?? 0).toInt()}',
                            subtitle: '${finance['total_unpaid_bills'] ?? 0} invoices',
                            icon: Icons.receipt_long_rounded,
                            color: AppTheme.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick Executive Actions
                      const SectionHeader(title: 'Executive Actions'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionButton(
                              icon: Icons.qr_code_scanner_rounded,
                              label: 'Gate Scanner',
                              color: AppTheme.primary,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickActionButton(
                              icon: Icons.campaign_rounded,
                              label: 'Broadcast',
                              color: AppTheme.red,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const BroadcastScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickActionButton(
                              icon: Icons.auto_stories_rounded,
                              label: 'Academics',
                              color: AppTheme.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AcademicsScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickActionButton(
                              icon: Icons.hub_rounded,
                              label: 'Operations',
                              color: AppTheme.secondary,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const OperationsHubScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Specialized Command Hubs
                      const SectionHeader(title: 'Command Hubs'),
                      const SizedBox(height: 12),

                      _buildHubTile(
                        context: context,
                        icon: Icons.how_to_reg_rounded,
                        color: AppTheme.royalBlue,
                        title: 'Student Attendance & Roll Call',
                        subtitle: 'Live campus attendance rate, class roll call sheets, quick mark & audit trail',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StudentAttendanceScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.person_add_alt_1_rounded,
                        color: AppTheme.emerald,
                        title: 'Admissions & Inquiries Pipeline',
                        subtitle: 'Review applications, applicant 360, class assignment & student enrollment',
                        badgeCount: (dash.overview?['kpis']?['pending_admissions'] as int?) ?? 0,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdmissionsManagementScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.settings_suggest_rounded,
                        color: AppTheme.purple,
                        title: 'School Settings & QR Branding',
                        subtitle: 'Institution details, payment QR codes, academic year & branding palette',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SchoolSettingsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.auto_mode_rounded,
                        color: AppTheme.royalBlue,
                        title: 'Student Promotion & Progression',
                        subtitle: 'Annual batch promotion, grade rollover & graduation assessment',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StudentPromotionScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.badge_rounded,
                        color: AppTheme.emerald,
                        title: 'Student ID Cards & Digital Badges',
                        subtitle: 'CR80 standard card studio, gate security passes & bulk generator',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StudentIdCardScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.analytics_rounded,
                        color: AppTheme.royalBlue,
                        title: 'Analytics & Executive Reports',
                        subtitle: 'Attendance velocity, fee collection summaries & academic report query studio',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AnalyticsReportsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.security_rounded,
                        color: AppTheme.emerald,
                        title: 'Front Desk & Campus Visitors',
                        subtitle: 'Active headcount, live security roster & emergency roll call',
                        badgeCount: (dash.overview?['kpis']?['active_visitors'] as int?) ?? 0,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const VisitorManagerScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.shield_outlined,
                        color: AppTheme.amber,
                        title: 'Pastoral Care, Discipline & Merits',
                        subtitle: 'Behavioral logging, merit honors, suspension tracking & executive sign-off',
                        badgeCount: (dash.overview?['kpis']?['pending_disciplinary_sign_offs'] as int?) ?? 0,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DisciplinePastoralScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.event_note_rounded,
                        color: AppTheme.primary,
                        title: 'Academic Calendar & Event Planner',
                        subtitle: 'Term dates, exams, holidays & 1-tap push alerts to campus',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AcademicCalendarScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.payments_rounded,
                        color: AppTheme.blue,
                        title: 'Staff HR, Contracts & Payroll',
                        subtitle: 'Monthly disbursement, salary slips, probation alerts & faculty workshops',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StaffHrPayrollScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.event_busy_rounded,
                        color: AppTheme.purple,
                        title: 'HR Staff Leave Center',
                        subtitle: 'Faculty leave applications, quota balances, approvals & coverage',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StaffLeaveManagementScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.verified_user_rounded,
                        color: AppTheme.secondary,
                        title: 'Certificates & Document Issuance',
                        subtitle: 'Transfer Certificates (TC), Character & Bonafide with digital seal',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CertificateManagerScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.local_hospital_rounded,
                        color: AppTheme.rose,
                        title: 'Campus Infirmary & Medical Records',
                        subtitle: 'Daily clinic roster, resting students, symptoms, treatment & emergency badges',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CampusInfirmaryScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.radar_rounded,
                        color: AppTheme.purple,
                        title: 'Academic Syllabus & Homework Radar',
                        subtitle: 'Grade-wise coverage pace, daily homework overload alerts & lesson verification',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SyllabusHomeworkScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildHubTile(
                        context: context,
                        icon: Icons.shield_rounded,
                        color: AppTheme.crimson,
                        title: 'Crisis Alert & Lockdown SOS Protocol',
                        subtitle: '1-tap emergency templates, high-priority push/SMS broadcast & all-clear',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CrisisSosScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      if (auth.isCoordinator || auth.isSuperOrAdmin) ...[
                        _buildHubTile(
                          context: context,
                          icon: Icons.calendar_month_rounded,
                          color: AppTheme.primary,
                          title: 'Routine & Timetable Studio',
                          subtitle: 'Bell schedules, clash prevention, period generator & faculty workload',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RoutineMakerScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildHubTile(
                          context: context,
                          icon: Icons.tune_rounded,
                          color: AppTheme.blue,
                          title: 'Coordinator Command Hub',
                          subtitle: 'Teacher substitutions, question papers & marks entry lock',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CoordinatorHubScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildHubTile(
                          context: context,
                          icon: Icons.badge_rounded,
                          color: AppTheme.royalBlue,
                          title: 'Teacher & Faculty Management',
                          subtitle: 'Add faculty, edit profiles, assign classes & class teachers, roster',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TeacherManagementScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (auth.isHostelManager || auth.isSuperOrAdmin) ...[
                        _buildHubTile(
                          context: context,
                          icon: Icons.bed_rounded,
                          color: AppTheme.teal,
                          title: 'Hostel & Boarding Hub',
                          subtitle: 'Room & bed allocation, evening roll call & visitor logs',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HostelManagerScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (auth.isTransportManager || auth.isSuperOrAdmin) ...[
                        _buildHubTile(
                          context: context,
                          icon: Icons.directions_bus_rounded,
                          color: AppTheme.blue,
                          title: 'Transport & Fleet Hub',
                          subtitle: 'Bus routes, passenger manifests, boarding logs & fuel',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TransportManagerScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (auth.isExamController || auth.isSuperOrAdmin) ...[
                        _buildHubTile(
                          context: context,
                          icon: Icons.assignment_turned_in_rounded,
                          color: AppTheme.secondary,
                          title: 'Exam Controller Hub',
                          subtitle: 'Marks entry tracking, admit cards clearance & terminal results release',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ExamControllerScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (auth.isLibrarian || auth.isSuperOrAdmin) ...[
                        _buildHubTile(
                          context: context,
                          icon: Icons.local_library_rounded,
                          color: const Color(0xFFC026D3),
                          title: 'Library Circulation Hub',
                          subtitle: 'Issue/return circulation, catalog stock & overdue fines',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LibrarianScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (auth.canManageRbac) ...[
                        _buildRbacTile(context),
                        const SizedBox(height: 10),
                      ],

                      const SizedBox(height: 18),

                      // 7-Day Attendance Trend
                      const SectionHeader(title: '7-Day Attendance Trend'),
                      const SizedBox(height: 12),
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: SizedBox(
                          height: 180,
                          child: dash.attendanceTrend.isEmpty
                              ? const Center(child: Text('No attendance recorded this week', style: TextStyle(color: AppTheme.grey)))
                              : BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: 100,
                                    barTouchData: BarTouchData(enabled: true),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 28,
                                          interval: 25,
                                          getTitlesWidget: (val, _) => Text(
                                            '${val.toInt()}%',
                                            style: const TextStyle(fontSize: 10, color: AppTheme.grey),
                                          ),
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (val, _) {
                                            final idx = val.toInt();
                                            if (idx >= 0 && idx < dash.attendanceTrend.length) {
                                              return Text(
                                                dash.attendanceTrend[idx]['day'],
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                    ),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    barGroups: dash.attendanceTrend.asMap().entries.map((entry) {
                                      final total = (entry.value['present'] as int) + (entry.value['absent'] as int);
                                      final pct = total > 0 ? ((entry.value['present'] as int) / total) * 100 : 85.0;
                                      return BarChartGroupData(
                                        x: entry.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: pct,
                                            gradient: AppTheme.primaryGradient,
                                            width: 14,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Recent Notices
                      const SectionHeader(title: 'Recent School Notices'),
                      const SizedBox(height: 12),
                      if (dash.recentNotices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No recent notices published.', style: TextStyle(color: AppTheme.grey))),
                        )
                      else
                        ...dash.recentNotices.map((n) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n['title'] ?? 'School Circular',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : AppTheme.dark,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          n['date'] ?? '',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    n['snippet'] ?? '',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.grey, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider auth, DashboardProvider dash, ThemeProvider theme, bool isDark) {
    final initials = auth.adminName.isNotEmpty ? auth.adminName[0].toUpperCase() : 'A';
    final roleName = auth.primaryRole.isNotEmpty ? auth.primaryRole.replaceAll('-', ' ').toUpperCase() : 'ADMIN';

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Namaste! 🇳🇵', style: TextStyle(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      roleName,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Welcome, ${auth.adminName} 👋',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.dark,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              InkWell(
                onTap: () => _showCampusSwitcherSheet(context, auth, dash),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.royalBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.royalBlue.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.apartment_rounded, size: 11, color: AppTheme.royalBlue),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          auth.schoolName.isNotEmpty ? auth.schoolName : 'Main Campus',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.royalBlue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 14, color: AppTheme.royalBlue),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Action Buttons Row: Notifications, Theme Toggle, Quick Actions Popup Menu
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleIconButton(
                  icon: Icons.notifications_none_rounded,
                  iconColor: AppTheme.royalBlue,
                  size: 38,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    );
                    dash.refreshUnreadNotifications();
                  },
                ),
                if (dash.unreadNotifications > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.crimson,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppTheme.darkCard : Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        dash.unreadNotifications > 9 ? '9+' : '${dash.unreadNotifications}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            CircleIconButton(
              icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 38,
              onTap: () => theme.toggle(),
            ),
            const SizedBox(width: 6),
            // Quick Actions & Settings Popup Menu
            PopupMenuButton<String>(
              tooltip: 'Quick Actions & Settings',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              color: isDark ? AppTheme.darkCard : Colors.white,
              elevation: 8,
              offset: const Offset(0, 44),
              icon: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderLight, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : AppTheme.dark,
                ),
              ),
              onSelected: (action) async {
                switch (action) {
                  case 'qr':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                    );
                    break;
                  case 'lock':
                    _showSecurityLockSheet(context);
                    break;
                  case 'settings':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SchoolSettingsScreen()),
                    );
                    break;
                  case 'logout':
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'qr',
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppTheme.royalBlue),
                      SizedBox(width: 12),
                      Text('Campus Gate Scanner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'lock',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.primary),
                      SizedBox(width: 12),
                      Text('Lock Command Center', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 18, color: AppTheme.grey),
                      SizedBox(width: 12),
                      Text('School Settings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: AppTheme.red),
                      SizedBox(width: 12),
                      Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context, AuthProvider auth, DashboardProvider dash, ApprovalsProvider approvals, Map<String, dynamic> kpis, Map<String, dynamic> finance) {
    return GradientCard(
      colors: const [Color(0xFF6C3CE9), Color(0xFF8E24AA)],
      padding: const EdgeInsets.all(18),
      radius: 24,
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
                      auth.schoolName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dash.todayDate.isNotEmpty ? dash.todayDate : 'Command Center Overview',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (approvals.totalPending > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pending_actions_rounded, size: 14, color: AppTheme.gold),
                      const SizedBox(width: 4),
                      Text(
                        '${approvals.totalPending} Pending',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeroStat(
                  'Att. Rate',
                  '${kpis['student_att_rate'] ?? 0}%',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StudentAttendanceScreen()),
                    );
                  },
                ),
                Container(width: 1, height: 26, color: Colors.white.withOpacity(0.2)),
                _buildHeroStat(
                  'Staff On Duty',
                  '${kpis['teachers_present'] ?? 0}',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeacherManagementScreen()),
                    );
                  },
                ),
                Container(width: 1, height: 26, color: Colors.white.withOpacity(0.2)),
                _buildHeroStat('Intake NPR', '${(finance['today_collection'] ?? 0).toInt()}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value, {VoidCallback? onTap}) {
    final content = Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }

  Widget _buildApprovalsAlert(BuildContext context, ApprovalsProvider approvals, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ApprovalsScreen()),
        );
      },
      child: AppCard(
        padding: const EdgeInsets.all(14),
        color: isDark ? AppTheme.darkCard : const Color(0xFFFFF8F1),
        border: Border.all(color: AppTheme.orange.withOpacity(0.4), width: 1.2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${approvals.totalPending} Action Items Pending',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.orange,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${approvals.counts['leaves']} leaves, ${approvals.counts['expenses']} expenses, ${approvals.counts['admissions']} admissions',
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildHubTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? Colors.white : AppTheme.dark,
                        ),
                      ),
                      if (badgeCount != null && badgeCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$badgeCount Inside',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildRbacTile(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RolesPermissionsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E38), Color(0xFF13132B)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Roles & Permissions Governance',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Assign roles & configure permissions for Coordinators, Accountants, and Staff',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.gold),
          ],
        ),
      ),
    );
  }

  void _showCampusSwitcherSheet(BuildContext context, AuthProvider auth, DashboardProvider dash) {
    final api = ApiService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: FutureBuilder<ApiResponse<List<dynamic>>>(
            future: api.getAvailableSchools(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final schools = snapshot.data?.data ?? [];
              return Column(
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
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.apartment_rounded, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Switch Campus / Branch',
                              style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            const Text(
                              'Multi-campus administration without re-login',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (schools.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No other branches found.', style: TextStyle(color: AppTheme.textMuted))),
                    )
                  else
                    ...schools.map((sch) {
                      final isCurrent = sch['is_current'] == true || (auth.school != null && auth.school!['id'] == sch['id']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppTheme.royalBlue.withOpacity(0.06) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent ? AppTheme.royalBlue : Colors.grey.shade200,
                            width: isCurrent ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isCurrent ? AppTheme.royalBlue : Colors.grey.shade300,
                            child: Icon(Icons.school, color: isCurrent ? Colors.white : Colors.grey.shade700, size: 20),
                          ),
                          title: Text(
                            sch['name'] ?? 'School Branch',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Code: ${sch['code'] ?? 'N/A'} • ${sch['city'] ?? sch['address'] ?? 'Nepal'}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          trailing: isCurrent
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppTheme.royalBlue, borderRadius: BorderRadius.circular(8)),
                                  child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.royalBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    final res = await api.switchActiveSchool(sch['id']);
                                    if (res.success) {
                                      auth.setActiveSchool(sch);
                                      await dash.fetchDashboard(silent: false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Switched to ${sch['name']}')),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(res.message)),
                                      );
                                    }
                                  },
                                  child: const Text('Switch', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                        ),
                      );
                    }).toList(),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showSecurityLockSheet(BuildContext context) {
    final sec = AppSecurityService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
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
                        decoration: BoxDecoration(color: AppTheme.crimson.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.security_rounded, color: AppTheme.crimson, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Executive App Security & Privacy',
                              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const Text(
                              'Biometric FaceID / Fingerprint & 2-min Auto Lock',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.crimson,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                      label: const Text('Lock App Immediately', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        sec.lockApp();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Biometric & PIN Lock Protection',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Locks screen on launch and after 2 minutes in background.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      value: sec.isLockEnabled,
                      activeColor: AppTheme.royalBlue,
                      onChanged: (enabled) async {
                        await sec.setLockEnabled(enabled);
                        setSheetState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const Icon(Icons.pin_rounded, color: AppTheme.royalBlue),
                    title: const Text('Executive Master PIN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Default PIN: 1234. Tap to change.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showChangePinDialog(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change 4-Digit Master PIN', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New 4-Digit PIN', hintText: 'e.g. 5678'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
            onPressed: () async {
              if (pinCtrl.text.trim().length == 4) {
                await AppSecurityService().setLockEnabled(true, pin: pinCtrl.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Master PIN updated successfully!')));
              }
            },
            child: const Text('Save PIN', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.dark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
