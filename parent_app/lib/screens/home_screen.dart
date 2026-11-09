import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/app_data.dart';
import '../providers/api_provider.dart';
import '../widgets/common_widgets.dart';

import 'notifications_screen.dart';
import 'bus_tracking_screen.dart';
import 'grades_screen.dart';
import 'attendance_screen.dart';
import 'exams_screen.dart';
import 'assignments_screen.dart';
import 'report_card_screen.dart';
import 'teacher_contact_screen.dart';
import 'meeting_screen.dart';
import 'events_screen.dart';
import 'health_screen.dart';
import 'leave_request_screen.dart';
import 'schedule_screen.dart';
import 'fees_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final api = context.watch<ApiProvider>();
    final child = api.selectedChild;
    final unread = api.unreadNotificationsCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => api.loadAllData(),
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (api.isLoading)
                const SliverToBoxAdapter(child: AppLinearLoader()),
              SliverToBoxAdapter(
                child: _buildHeader(context, api, isDark, unread),
              ),
              SliverToBoxAdapter(
                child: _buildChildSelector(api, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildChildSummaryCard(context, child, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildPendingFeeBanner(context, api, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildBusLiveTicker(context, api, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildServicesGrid(context, api, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildTodaySchedule(context, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildUpcomingExamCard(context, api, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildRecentAlerts(context, api, isDark),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ApiProvider api, bool isDark, int unread) {
    final profile = api.userProfile;
    final parentName = profile?['name'] ?? profile?['full_name'] ?? 'Parent Account';
    final initials = parentName.isNotEmpty ? parentName[0].toUpperCase() : 'P';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.primary.withValues(alpha: 0.2),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9CA3AF) : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: Icons.notifications_none_rounded,
            badge: unread,
            size: 40,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildSelector(ApiProvider api, bool isDark) {
    if (api.children.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: api.children.map((child) {
            final isSelected = child.id == api.selectedChild.id;
            final displayName = child.firstName.isNotEmpty ? child.firstName : child.name.split(' ').first;
            final gradeTag = child.grade.replaceAll('Grade ', 'Gr ');

            return GestureDetector(
              onTap: () => api.selectChild(child),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF7475F9)
                      : (isDark ? AppTheme.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF7475F9)
                        : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                    width: 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7475F9).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white38 : AppTheme.textMuted),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$displayName • $gradeTag',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChildSummaryCard(BuildContext context, Child child, bool isDark) {
    const cardBgColor = Color(0xFF7475F9);
    const cardGradient = LinearGradient(
      colors: [Color(0xFF7A7BF9), Color(0xFF6A6BF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cardBgColor.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Concentric decorative circle arcs in top-right corner matching reference image
              Positioned(
                top: -36,
                right: -36,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 14,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -65,
                right: -65,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 16,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Overline: School Branding & Active Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  child.schoolName.isNotEmpty ? child.schoolName : 'Nepal School Hub Academy',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Student Row: Avatar + Name + Grade & Section
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              child.avatar.isNotEmpty ? child.avatar : child.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                child.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${child.grade} • Section ${child.section} • Roll #${child.rollNo}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Inset Metric Panel matching the exact layout in user's reference image
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF16191E) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _FintechStatTile(
                              icon: Icons.calendar_today_rounded,
                              iconColor: const Color(0xFF7475F9),
                              label: 'GPA',
                              value: child.gpa.toStringAsFixed(2),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const GradesScreen()),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE5E7EB),
                          ),
                          Expanded(
                            child: _FintechStatTile(
                              icon: Icons.how_to_reg_rounded,
                              iconColor: const Color(0xFF059669),
                              label: 'Attendance',
                              value: '${(child.attendance * 100).toInt()}%',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE5E7EB),
                          ),
                          Expanded(
                            child: _FintechStatTile(
                              icon: Icons.workspace_premium_outlined,
                              iconColor: const Color(0xFFD97706),
                              label: 'Class Rank',
                              value: '#${child.rank}',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ReportCardScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingFeeBanner(BuildContext context, ApiProvider api, bool isDark) {
    final pendingFees = api.fees.where((f) => f.status.toLowerCase() == 'pending').toList();
    if (pendingFees.isEmpty) return const SizedBox.shrink();

    final double totalPending = pendingFees.fold(0.0, (sum, f) => sum + f.dueAmount);
    final firstDue = pendingFees.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.orangeLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFFDE68A),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.payment_rounded, color: AppTheme.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fee Due: NPR ${totalPending.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.orange,
                    ),
                  ),
                  Text(
                    'Due by ${firstDue.dueDate}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF9CA3AF) : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeesScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.orange,
                  borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                ),
                child: const Text(
                  'Pay Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusLiveTicker(BuildContext context, ApiProvider api, bool isDark) {
    final bus = api.busInfo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AppCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusTrackingScreen()),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusInner),
              ),
              child: const Icon(
                Icons.directions_bus_outlined,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        bus.busNumber,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      StatusBadge(label: 'ETA ${bus.eta}', color: AppTheme.primary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Next: ${bus.nextStop}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF9CA3AF) : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : AppTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesGrid(BuildContext context, ApiProvider api, bool isDark) {
    final pendingAssignments = api.assignments.where((a) => !a.isCompleted).length;
    final nextExamDays = api.exams.isNotEmpty ? api.exams.first.daysLeft : null;

    final modules = [
      {
        'label': 'Homework',
        'icon': Icons.assignment_outlined,
        'screen': const AssignmentsScreen(),
        'badge': pendingAssignments > 0 ? '$pendingAssignments' : null,
      },
      {
        'label': 'Exams',
        'icon': Icons.quiz_outlined,
        'screen': const ExamsScreen(),
        'badge': nextExamDays != null ? '${nextExamDays}d' : null,
      },
      {
        'label': 'Report Card',
        'icon': Icons.description_outlined,
        'screen': const ReportCardScreen(),
      },
      {
        'label': 'Faculty',
        'icon': Icons.people_outline_rounded,
        'screen': const TeacherContactScreen(),
      },
      {
        'label': 'Leave',
        'icon': Icons.event_busy_outlined,
        'screen': const LeaveRequestScreen(),
      },
      {
        'label': 'Meetings',
        'icon': Icons.calendar_month_outlined,
        'screen': const MeetingScreen(),
      },
      {
        'label': 'Events',
        'icon': Icons.celebration_outlined,
        'screen': const EventsScreen(),
      },
      {
        'label': 'Health',
        'icon': Icons.health_and_safety_outlined,
        'screen': const HealthScreen(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'School Services'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: modules.length,
            itemBuilder: (_, i) {
              final m = modules[i];
              final badge = m['badge'] as String?;

              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => m['screen'] as Widget),
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : AppTheme.border,
                              width: 1.0,
                            ),
                          ),
                          child: Icon(
                            m['icon'] as IconData,
                            color: isDark ? Colors.white70 : AppTheme.textPrimary,
                            size: 22,
                          ),
                        ),
                        if (badge != null)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m['label'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySchedule(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: "Today's Schedule",
            actionLabel: 'Full Routine',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScheduleScreen()),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: AppData.schedule.take(3).map((item) {
                final isLast = item == AppData.schedule[2];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : AppTheme.greyLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['time'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['subject'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${item['teacher']} • ${item['room']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF9CA3AF) : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            item['duration'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF9CA3AF) : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        color: isDark ? AppTheme.darkBorder : AppTheme.border,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingExamCard(BuildContext context, ApiProvider api, bool isDark) {
    final exam = api.exams.isNotEmpty ? api.exams.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Upcoming Examination',
            actionLabel: 'All Exams',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamsScreen()),
            ),
            padding: const EdgeInsets.all(14),
            child: exam == null
                ? const Text('No upcoming exams scheduled.')
                : Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                        ),
                        child: const Icon(
                          Icons.quiz_outlined,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam.subject,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${exam.type} • ${exam.date}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF9CA3AF) : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: '${exam.daysLeft}d left',
                        color: exam.daysLeft <= 3 ? AppTheme.red : AppTheme.orange,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlerts(BuildContext context, ApiProvider api, bool isDark) {
    final recent = api.notifications.take(2).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'School Notices',
            actionLabel: 'All Notices',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: recent.asMap().entries.map((entry) {
                final idx = entry.key;
                final n = entry.value;
                final isLast = idx == recent.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            color: isDark ? Colors.white70 : AppTheme.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  n.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF9CA3AF) : AppTheme.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            n.time,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF9CA3AF) : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        color: isDark ? AppTheme.darkBorder : AppTheme.border,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final VoidCallback? onTap;

  const _HeroStatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusInner),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF9CA3AF) : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _FintechStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FintechStatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      letterSpacing: -0.2,
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
}
