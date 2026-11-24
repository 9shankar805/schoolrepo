import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/app_data.dart';
import '../widgets/common_widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/teacher_provider.dart';
import '../providers/theme_provider.dart';
import 'notifications_screen.dart';
import 'attendance_screen.dart';
import 'gradebook_screen.dart';
import 'announcements_screen.dart';
import 'schedule_screen.dart';
import 'students_screen.dart';
import 'assignments_screen.dart';
import 'exams_screen.dart';
import 'classes_screen.dart';
import 'marks_entry_screen.dart';
import 'question_paper_generator_screen.dart';
import 'lesson_planner_screen.dart';
import 'leave_application_screen.dart';
import 'class_incharge_hub_screen.dart';
import 'nepali_calendar_screen.dart';
import 'payslip_screen.dart';
import 'seating_chart_screen.dart';
import 'parent_communication_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _tipController = PageController();
  int _tipIndex = 0;
  String? _navigatingModule;
  String? _selectedClass;

  String _getActiveClass(TeacherProvider teacherProvider, AuthProvider authProvider) {
    if (_selectedClass != null && _selectedClass!.isNotEmpty) {
      return _selectedClass!;
    }
    // 1. Check official class in-charge info from auth
    final incharge = authProvider.classInchargeInfo;
    if (incharge != null) {
      final cName = incharge['class_name']?.toString() ?? incharge['name']?.toString() ?? '';
      final sName = incharge['section_name']?.toString() ?? incharge['section']?.toString() ?? '';
      if (cName.isNotEmpty) {
        return sName.isNotEmpty ? '$cName — $sName' : cName;
      }
    }
    // 2. Prioritize explicitly marked in-charge class among teacher assigned classes
    if (teacherProvider.teacherClasses.isNotEmpty) {
      final inchargeClasses = teacherProvider.teacherClasses.where((c) => c.isClassTeacher).toList();
      if (inchargeClasses.isNotEmpty && inchargeClasses.first.section.trim().isNotEmpty) {
        return inchargeClasses.first.section.trim();
      }
    }
    // 3. Next upcoming class period if present (e.g. today's routine period)
    final nextCls = teacherProvider.nextClass?['class_name']?.toString() ??
        teacherProvider.nextClass?['section']?.toString();
    if (nextCls != null && nextCls.trim().isNotEmpty) {
      return nextCls.trim();
    }
    // 4. Assigned classes fallback
    if (teacherProvider.teacherClasses.isNotEmpty) {
      final firstSec = teacherProvider.teacherClasses.first.section.trim();
      if (firstSec.isNotEmpty) return firstSec;
    }

    return 'Class 1 — A';
  }

  void _showClassSelectorSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentClass = _getActiveClass(teacherProvider, authProvider);

    // Build real list of unique classes taught by this teacher
    final List<String> availableClasses = [];

    // Prioritize in-charge class
    final incharge = authProvider.classInchargeInfo;
    if (incharge != null) {
      final cName = incharge['class_name']?.toString() ?? incharge['name']?.toString() ?? '';
      final sName = incharge['section_name']?.toString() ?? incharge['section']?.toString() ?? '';
      if (cName.isNotEmpty) {
        final formatted = sName.isNotEmpty ? '$cName — $sName' : cName;
        if (!availableClasses.contains(formatted)) {
          availableClasses.add(formatted);
        }
      }
    }

    // Add classes from teacherClasses
    for (final tc in teacherProvider.teacherClasses) {
      final sec = tc.section.trim();
      if (sec.isNotEmpty && !availableClasses.contains(sec)) {
        availableClasses.add(sec);
      }
    }

    // Add next upcoming class if available
    final nextCls = teacherProvider.nextClass?['class_name']?.toString() ??
        teacherProvider.nextClass?['section']?.toString();
    if (nextCls != null && nextCls.trim().isNotEmpty && !availableClasses.contains(nextCls.trim())) {
      availableClasses.add(nextCls.trim());
    }

    // Safe fallback if list is still empty
    if (availableClasses.isEmpty) {
      availableClasses.add('Class 1 — A');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Image.asset(
                  'assets/icons/3d/book.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => const Icon(Icons.class_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  'Switch Active Class',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${availableClasses.length} ${availableClasses.length == 1 ? 'Class' : 'Classes'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...availableClasses.map((cls) {
              final isChosen = cls == currentClass;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isChosen
                      ? (isDark ? const Color(0xFF2563EB).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
                      : (isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isChosen
                        ? const Color(0xFF2563EB)
                        : (isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0)),
                    width: isChosen ? 1.4 : 0.8,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: Image.asset(
                    'assets/icons/3d/book.png',
                    width: 22,
                    height: 22,
                    errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: isChosen ? const Color(0xFF2563EB) : Colors.grey, size: 20),
                  ),
                  title: Text(
                    cls,
                    style: TextStyle(
                      fontWeight: isChosen ? FontWeight.w900 : FontWeight.w700,
                      color: isChosen
                          ? const Color(0xFF2563EB)
                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                  ),
                  trailing: isChosen
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20)
                      : null,
                  onTap: () {
                    setState(() => _selectedClass = cls);
                    Navigator.pop(ctx);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _handleModuleTap(String label, Widget screen) async {
    if (_navigatingModule != null) return;
    setState(() => _navigatingModule = label);
    // Yield 1 frame so Flutter renders the rotating indicator on screen immediately
    await Future.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    } finally {
      if (mounted) {
        setState(() => _navigatingModule = null);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TeacherProvider>(context, listen: false).refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer3<AuthProvider, TeacherProvider, ThemeProvider>(
      builder: (context, auth, teacher, themeProv, child) {
        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => teacher.refreshAll(),
              color: AppTheme.primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // Veda Top App Bar & School Header
                  SliverToBoxAdapter(
                    child: _buildVedaHeader(isDark, auth, themeProv).animate().fadeIn(duration: 350.ms),
                  ),

                  // Quick Stats Strip
                  SliverToBoxAdapter(
                    child: _buildVedaStats(isDark, teacher).animate().fadeIn(delay: 80.ms),
                  ),

                  // Hero: Next Period / Ongoing Class Card
                  SliverToBoxAdapter(
                    child: _buildHeroClassCard(isDark, teacher).animate().fadeIn(delay: 150.ms),
                  ),

                  // Notice & Urgent Announcements Banner
                  SliverToBoxAdapter(
                    child: _buildNoticeBanner(isDark, teacher).animate().fadeIn(delay: 220.ms),
                  ),

                  // Academic Modules (Veda Academic Hub)
                  SliverToBoxAdapter(
                    child: _buildAcademicModules(isDark).animate().fadeIn(delay: 280.ms),
                  ),

                  // Teacher Utilities & HR Tools (Veda Guru Utilities)
                  SliverToBoxAdapter(
                    child: _buildTeacherTools(isDark).animate().fadeIn(delay: 340.ms),
                  ),

                  // Today's Routine Timeline
                  SliverToBoxAdapter(
                    child: _buildRoutineTimeline(isDark, teacher).animate().fadeIn(delay: 400.ms),
                  ),

                  // Pending Assignments & Review Card
                  SliverToBoxAdapter(
                    child: _buildPendingReviews(isDark, teacher).animate().fadeIn(delay: 450.ms),
                  ),

                  // Upcoming Terminal Examinations
                  SliverToBoxAdapter(
                    child: _buildUpcomingExamCard(isDark, teacher).animate().fadeIn(delay: 500.ms),
                  ),

                  // Teaching Tip Carousel
                  SliverToBoxAdapter(
                    child: _buildTeachingTipsCarousel(isDark).animate().fadeIn(delay: 550.ms),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Dynamic real-time Nepali date & BS year calculator
  String _getTodayNepaliDate() {
    final now = DateTime.now();
    final dayOfWeekNepali = [
      '', 'सोमबार', 'मंगलबार', 'बुधबार', 'बिहीबार', 'शुक्रबार', 'शनिबार', 'आइतबार'
    ];
    final nepaliDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    const engMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final engFormatted = '${now.day} ${engMonths[now.month - 1]} ${now.year}';
    final dayNepali = dayOfWeekNepali[now.weekday];

    // Standard Bikram Sambat conversion approximation
    int bsYear = now.year + 57;
    int bsMonth = now.month + 8;
    if (bsMonth > 12) {
      bsMonth -= 12;
    }
    int bsDay = now.day + 7;
    if (bsDay > 30) {
      bsDay -= 30;
    }

    final bsMonthsNepali = [
      'वैशाख', 'जेठ', 'असार', 'साउन', 'भदौ', 'असोज',
      'कार्तिक', 'मंसिर', 'पुस', 'माघ', 'फागुन', 'चैत'
    ];

    String toNepaliDigits(int num) {
      return num.toString().split('').map((c) {
        final d = int.tryParse(c);
        return d != null ? nepaliDigits[d] : c;
      }).join();
    }

    final bsDayNepali = toNepaliDigits(bsDay);
    final bsMonthName = bsMonthsNepali[(bsMonth - 1).clamp(0, 11)];
    final bsYearNepali = toNepaliDigits(bsYear);

    return '$bsDayNepali $bsMonthName $bsYearNepali • $dayNepali ($engFormatted)';
  }

  String _getTodayBSYear() {
    final now = DateTime.now();
    final nepaliDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    int bsYear = now.year + 57;
    final bsYearStr = bsYear.toString().split('').map((c) => nepaliDigits[int.tryParse(c) ?? 0]).join();
    return '$bsYearStr B.S.';
  }

  Widget _buildVedaHeader(bool isDark, AuthProvider auth, ThemeProvider themeProv) {
    final teacherProvider = Provider.of<TeacherProvider>(context);
    final unread = teacherProvider.unreadMessagesCount;
    final teacherName = auth.teacherName.isNotEmpty ? auth.teacherName : 'Teacher';
    final schoolName = auth.schoolName.isNotEmpty ? auth.schoolName : 'Nepal School Hub';
    final designation = auth.teacherDesignation.isNotEmpty ? auth.teacherDesignation : 'Faculty Member';
    final activeClass = _getActiveClass(teacherProvider, auth);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar: Active class selector + Bell + Menu (Zero-overflow layout)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showClassSelectorSheet(context),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              activeClass,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 19,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Change class',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 1.2,
                        width: 78,
                        margin: const EdgeInsets.only(top: 2, bottom: 2),
                        color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                      ),
                      Text(
                        schoolName,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Theme Switcher
              CircleIconButton(
                icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                size: 36,
                iconColor: isDark ? Colors.amber : const Color(0xFF475569),
                onTap: () => themeProv.toggleTheme(),
              ),
              const SizedBox(width: 6),

              // Notification Bell
              CircleIconButton(
                icon: Icons.notifications_outlined,
                size: 36,
                badge: unread,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
              const SizedBox(width: 6),

              // Navy Menu Pill Button matching reference
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Teacher Profile Bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with warm halo ring & online status
              Stack(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFEDD5),
                      border: Border.all(
                        color: const Color(0xFFFBBF24),
                        width: 2.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/illustrations/teacher_profile.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0F4C81), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            auth.teacherName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? AppTheme.darkBg : Colors.white, width: 2.2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Teacher Greeting & Designation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome,',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      teacherName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      designation,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF60A5FA) : AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Real-time Nepali Date Bar (No hardcoded past date!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 17,
                  height: 17,
                  child: Image.asset(
                    'assets/icons/3d/calendar.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _getTodayNepaliDate(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getTodayBSYear(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkSubtext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // --- 2. Veda Quick Stats Strip with 3D Icons ---
  Widget _buildVedaStats(bool isDark, TeacherProvider teacher) {
    final stats = teacher.stats;
    final pendingCount = int.tryParse(stats['pending_assignments']?.toString() ?? '0') ?? 0;
    final isPendingZero = pendingCount == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Row(
        children: [
          _buildVedaStatCard(
            title: 'Classes',
            value: '${stats['classes_count'] ?? 4}',
            imageAsset: 'assets/icons/3d/my_classes.png',
            fallbackIcon: Icons.menu_book_rounded,
            color: const Color(0xFF2563EB),
            bgLight: const Color(0xFFEFF6FF),
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassesScreen())),
          ),
          const SizedBox(width: 8),
          _buildVedaStatCard(
            title: 'Students',
            value: '${stats['students_count'] ?? 115}',
            imageAsset: 'assets/icons/3d/student_info.png',
            fallbackIcon: Icons.groups_rounded,
            color: const Color(0xFF059669),
            bgLight: const Color(0xFFECFDF5),
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsScreen())),
          ),
          const SizedBox(width: 8),
          _buildVedaStatCard(
            title: 'Pending',
            value: '$pendingCount',
            imageAsset: isPendingZero ? 'assets/icons/3d/teachers_attendance.png' : 'assets/icons/3d/clock.png',
            fallbackIcon: isPendingZero ? Icons.task_alt_rounded : Icons.assignment_late_rounded,
            color: isPendingZero ? const Color(0xFF059669) : const Color(0xFFD97706),
            bgLight: isPendingZero ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignmentsScreen())),
          ),
          const SizedBox(width: 8),
          _buildVedaStatCard(
            title: 'Messages',
            value: '${stats['unread_messages'] ?? 0}',
            imageAsset: 'assets/icons/3d/chat_bubble.png',
            fallbackIcon: Icons.chat_bubble_rounded,
            color: const Color(0xFF7C3AED),
            bgLight: const Color(0xFFF5F3FF),
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentCommunicationScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildVedaStatCard({
    required String title,
    required String value,
    required String imageAsset,
    required IconData fallbackIcon,
    required Color color,
    required Color bgLight,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark ? color.withValues(alpha: 0.18) : bgLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(fallbackIcon, color: color, size: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppTheme.dark,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkSubtext,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 3. Hero: Next Period / Live Class Card ---
  Widget _buildHeroClassCard(bool isDark, TeacherProvider teacher) {
    final nextClass = teacher.nextClass;
    final firstClass = teacher.classes.isNotEmpty ? teacher.classes[0] : null;

    final subject = nextClass?['subject']?.toString() ??
        (firstClass is Map ? firstClass['name'] ?? firstClass['subject'] : (firstClass != null ? firstClass.name : 'Nepali'));
    final classSection = nextClass?['class_name']?.toString() ??
        (firstClass is Map ? firstClass['section'] ?? firstClass['class_name'] : (firstClass != null ? firstClass.section : 'Class 1 — A'));
    final timeStr = nextClass?['time']?.toString() ??
        (firstClass is Map ? firstClass['time'] : (firstClass != null ? firstClass.time : '09:00 AM - 09:45 AM'));
    final roomStr = nextClass?['room']?.toString() ??
        (firstClass is Map ? firstClass['room'] : (firstClass != null ? firstClass.room : 'Room 101'));
    final studentsCount = firstClass is Map ? (firstClass['students'] ?? 25) : (firstClass != null ? firstClass.students : 25);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Upcoming Period',
            subtitle: 'Real-time class schedule & attendance',
            actionLabel: 'All Routine',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScheduleScreen()),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4C81), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Status Strip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.5,
                            height: 6.5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80), // Bright green dot
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'UPCOMING CLASS • TODAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: Colors.white70),
                          const SizedBox(width: 3),
                          Text(
                            roomStr.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Subject Name & Class Row with Subject 3D Icon
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1),
                      ),
                      child: Image.asset(
                        _getSubject3DAsset(subject.toString()),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(_getSubjectIcon(subject.toString()), color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            classSection.toString(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Metadata details
                Row(
                  children: [
                    _buildHeroChip(Icons.access_time_rounded, timeStr.toString()),
                    const SizedBox(width: 8),
                    _buildHeroChip(Icons.people_alt_outlined, '$studentsCount Students'),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons on Hero Card (Clean frosted glass + solid white with 3D Icons)
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendanceScreen(startInSpeedCall: true),
                          ),
                        ),
                        icon: SizedBox(
                          width: 18,
                          height: 18,
                          child: Image.asset(
                            'assets/icons/3d/flash.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFFBBF24)),
                          ),
                        ),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Quick Haziri',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          elevation: 0,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                        ),
                        icon: SizedBox(
                          width: 18,
                          height: 18,
                          child: Image.asset(
                            'assets/icons/3d/fluent_clipboard.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.fact_check_rounded, size: 16, color: Color(0xFF0F4C81)),
                          ),
                        ),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Haziri Portal',
                            style: TextStyle(
                              color: Color(0xFF0F4C81),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F4C81),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
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

  Widget _buildHeroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Notice & Urgent Announcements Banner with 3D Megaphone ---
  Widget _buildNoticeBanner(bool isDark, TeacherProvider teacher) {
    final firstAnnounce = teacher.announcements.isNotEmpty ? teacher.announcements.first : null;
    final hasRealNotices = firstAnnounce != null;

    final isUrgent = firstAnnounce is Map
        ? (firstAnnounce['isUrgent'] == true || firstAnnounce['priority'] == 'urgent')
        : false;

    final title = firstAnnounce is Map
        ? (firstAnnounce['title'] ?? 'Digital Notice Board • Tap to view circulars')
        : (firstAnnounce != null ? firstAnnounce.title : 'Digital Notice Board • Tap to view circulars');

    final date = firstAnnounce is Map
        ? (firstAnnounce['nepaliDate'] ?? firstAnnounce['date'] ?? 'Today')
        : (hasRealNotices ? 'Today' : 'Active Session');

    final bannerBg = isUrgent
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF));

    final bannerBorder = isUrgent
        ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA))
        : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFBFDBFE));

    final bannerColor = isUrgent ? const Color(0xFFEF4444) : AppTheme.primary;
    final badgeLabel = isUrgent
        ? 'URGENT NOTICE'
        : (hasRealNotices ? 'SCHOOL NOTICE' : 'NOTICE BOARD');

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: bannerBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: bannerColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/icons/3d/fluent_megaphone.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.campaign_rounded, color: bannerColor, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: bannerColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badgeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            date.toString(),
                            style: const TextStyle(fontSize: 10, color: AppTheme.darkSubtext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title.toString(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : (isUrgent ? const Color(0xFF991B1B) : AppTheme.dark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: bannerColor, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 5. 3D Pastel Bento Grid (Academic Hub) ---
  Widget _buildAcademicModules(bool isDark) {
    final modules = [
      {
        'label': 'Students\nattendance',
        'image': 'assets/icons/3d/students_attendance.png',
        'color': const Color(0xFFDCFCE7),
        'border': const Color(0xFFBBF7D0),
        'screen': const AttendanceScreen(),
      },
      {
        'label': "Teacher's\nAttendance",
        'image': 'assets/icons/3d/teachers_attendance.png',
        'color': const Color(0xFFE0F2FE),
        'border': const Color(0xFFBAE6FD),
        'screen': const AttendanceScreen(),
      },
      {
        'label': 'Homework',
        'image': 'assets/icons/3d/homework.png',
        'color': const Color(0xFFFCE7F3),
        'border': const Color(0xFFFBCFE8),
        'screen': const AssignmentsScreen(),
      },
      {
        'label': "Student's\nLeave",
        'image': 'assets/icons/3d/student_leave.png',
        'color': const Color(0xFFFFE4E6),
        'border': const Color(0xFFFECDD3),
        'screen': const LeaveApplicationScreen(),
      },
      {
        'label': 'My classes',
        'image': 'assets/icons/3d/my_classes.png',
        'color': const Color(0xFFFEF3C7),
        'border': const Color(0xFFFDE68A),
        'screen': const ClassesScreen(),
      },
      {
        'label': 'Student info',
        'image': 'assets/icons/3d/student_info.png',
        'color': const Color(0xFFECFDF5),
        'border': const Color(0xFFA7F3D0),
        'screen': const StudentsScreen(),
      },
      {
        'label': 'Topics\ncompleted',
        'image': 'assets/icons/3d/topics_completed.png',
        'color': const Color(0xFFD1FAE5),
        'border': const Color(0xFFA7F3D0),
        'screen': const LessonPlannerScreen(),
      },
      {
        'label': 'Online class',
        'image': 'assets/icons/3d/online_class.png',
        'color': const Color(0xFFFCE7F3),
        'border': const Color(0xFFFBCFE8),
        'screen': const ScheduleScreen(),
      },
      {
        'label': 'Leaderboard',
        'image': 'assets/icons/3d/leaderboard.png',
        'color': const Color(0xFFE0F2FE),
        'border': const Color(0xFFBAE6FD),
        'screen': const GradebookScreen(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Academic Hub',
                  subtitle: 'Curriculum, evaluations & daily teaching tools',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 12, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text(
                      '3D Bento',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.94,
            ),
            itemBuilder: (context, idx) {
              final m = modules[idx];
              final label = m['label'] as String;
              final isOpening = _navigatingModule == label;
              return _build3DBentoCard(
                label: label,
                imageAsset: m['image'] as String,
                cardColor: m['color'] as Color,
                borderColor: m['border'] as Color,
                isDark: isDark,
                isLoading: isOpening,
                onTap: () => _handleModuleTap(label, m['screen'] as Widget),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 3D Bento Grid Card (Pastel Squircle with 3D Assets) ---
  Widget _build3DBentoCard({
    required String label,
    required String imageAsset,
    required Color cardColor,
    required Color borderColor,
    required bool isDark,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    final bg = isDark
        ? Color.alphaBlend(cardColor.withValues(alpha: 0.18), const Color(0xFF1E293B))
        : cardColor;
    final border = isDark ? cardColor.withValues(alpha: 0.35) : borderColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: (isDark ? Colors.white : cardColor).withValues(alpha: 0.2),
        highlightColor: (isDark ? Colors.white : cardColor).withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isLoading ? AppTheme.primary : border,
              width: isLoading ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : cardColor.withValues(alpha: 0.45),
                blurRadius: isLoading ? 14 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: isLoading
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      )
                    : Image.asset(
                        imageAsset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.grid_view_rounded,
                          size: 32,
                        ),
                      ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 6. Teacher Utilities & HR Tools with 3D Icons ---
  Widget _buildTeacherTools(bool isDark) {
    final tools = [
      {
        'label': 'Notice Board',
        'sub': 'सूचना पाटी',
        'image': 'assets/icons/3d/megaphone.png',
        'color': const Color(0xFFE0F2FE),
        'screen': const AnnouncementsScreen(),
      },
      {
        'label': 'B.S. Calendar',
        'sub': 'Patro 2081',
        'image': 'assets/icons/3d/calendar.png',
        'color': const Color(0xFFFFE4E6),
        'screen': const NepaliCalendarScreen(),
      },
      {
        'label': 'Class Seating',
        'sub': 'कक्षा बसाइ',
        'image': 'assets/icons/3d/target.png',
        'color': const Color(0xFFFEF3C7),
        'screen': const SeatingChartScreen(),
      },
      {
        'label': 'My Salary',
        'sub': 'Payslip (रु.)',
        'image': 'assets/icons/3d/wallet.png',
        'color': const Color(0xFFDCFCE7),
        'screen': const PayslipScreen(),
      },
      {
        'label': 'Parent Connect',
        'sub': 'Direct Messages',
        'image': 'assets/icons/3d/chat_bubble.png',
        'color': const Color(0xFFFCE7F3),
        'screen': const ParentCommunicationScreen(),
      },
      {
        'label': 'AI Question Paper',
        'sub': 'Auto Generator',
        'image': 'assets/icons/3d/rocket.png',
        'color': const Color(0xFFEDE9FE),
        'screen': const QuestionPaperGeneratorScreen(),
      },
      {
        'label': 'Marks Entry',
        'sub': 'द्रुत अंक प्रविष्टि',
        'image': 'assets/icons/3d/medal.png',
        'color': const Color(0xFFECFDF5),
        'screen': const MarksEntryScreen(),
      },
      {
        'label': 'Bus & Travel',
        'sub': 'स्कुल बस ट्र्याक',
        'image': 'assets/icons/3d/bus_travel.png',
        'color': const Color(0xFFFEF9C3),
        'screen': const ScheduleScreen(),
      },
      {
        'label': 'Class Incharge',
        'sub': 'कक्षा इन्चार्ज हब',
        'image': 'assets/icons/3d/crown.png',
        'color': const Color(0xFFFEF3C7),
        'screen': const ClassInchargeHubScreen(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Teacher Power Tools 🇳🇵',
            subtitle: 'Nepali calendar, class seating, salary & AI tools',
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tools.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, idx) {
              final t = tools[idx];
              final label = t['label'] as String;
              final color = t['color'] as Color;
              final isOpening = _navigatingModule == label;
              return _buildSquircleToolCard(
                label: label,
                sub: t['sub'] as String,
                imageAsset: t['image'] as String,
                color: color,
                isDark: isDark,
                isLoading: isOpening,
                onTap: () => _handleModuleTap(label, t['screen'] as Widget),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSquircleToolCard({
    required String label,
    required String sub,
    required String imageAsset,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isLoading
                  ? AppTheme.primary
                  : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
              width: isLoading ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isLoading
                    ? AppTheme.primary.withValues(alpha: 0.25)
                    : const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: isLoading ? 14 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      )
                    : Image.asset(
                        imageAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.apps_rounded, size: 24),
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                isLoading ? 'Opening...' : sub,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isLoading ? AppTheme.primary : AppTheme.darkSubtext,
                  fontWeight: isLoading ? FontWeight.w700 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 7. Today's Routine Timeline ---
  Widget _buildRoutineTimeline(bool isDark, TeacherProvider teacher) {
    final timelineItems = teacher.timeline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: "Today's Routine (समय तालिका)",
            subtitle: 'Day periods & assigned classroom sessions',
            actionLabel: 'Full Routine',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScheduleScreen()),
            ),
          ),
          const SizedBox(height: 12),
          if (timelineItems.isNotEmpty)
            ...timelineItems.map((item) => _buildTimelineCard(item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map), isDark))
          else if (teacher.classes.isNotEmpty)
            ...teacher.classes.take(3).toList().asMap().entries.map((entry) {
              final c = entry.value;
              final idx = entry.key;
              final name = c is Map ? (c['name'] ?? c['subject'] ?? 'Subject') : (c is TeacherClass ? c.name : 'Subject');
              final section = c is Map ? (c['section'] ?? 'Section A') : (c is TeacherClass ? c.section : 'Section A');
              final room = c is Map ? (c['room'] ?? 'Room ${101 + idx}') : (c is TeacherClass ? c.room : 'Room ${101 + idx}');
              
              final startMin = 9 * 60 + (idx * 45);
              final h = startMin ~/ 60;
              final m = startMin % 60;
              final amPm = h >= 12 ? 'PM' : 'AM';
              final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
              final fallbackTime = '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $amPm';
              
              final time = c is Map ? (c['time'] ?? fallbackTime) : (c is TeacherClass ? c.time : fallbackTime);

              return _buildTimelineCard({
                'period': 'Period ${idx + 1}',
                'time': time,
                'class': name,
                'section': section,
                'room': room,
                'status': idx == 0 ? 'LIVE' : 'Upcoming',
              }, isDark);
            })
          else
            ...AppData.todaySchedule.take(2).map((item) => _buildTimelineCard(item, isDark)),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> item, bool isDark) {
    final period = item['period']?.toString() ?? 'Period';
    final time = item['time']?.toString() ?? '09:00 AM';
    final subject = (item['class'] ?? item['title'] ?? item['subject'])?.toString() ?? 'General';
    final section = (item['section'] ?? item['description'])?.toString() ?? 'Section A';
    final room = item['room']?.toString() ?? 'Room 101';
    final isBreak = period.toLowerCase().contains('break');
    final isOngoing = item['status'] == 'In Progress' || item['status'] == 'LIVE';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOngoing
              ? AppTheme.primary
              : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
          width: isOngoing ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Period & Time column
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: isBreak
                  ? const Color(0xFFEA580C).withValues(alpha: 0.12)
                  : (isOngoing ? AppTheme.primary.withValues(alpha: 0.12) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  period,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isBreak
                        ? const Color(0xFFEA580C)
                        : (isOngoing ? AppTheme.primary : (isDark ? Colors.white70 : const Color(0xFF475569))),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time.split(' - ')[0],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkSubtext,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Subject 3D Icon Badge
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isOngoing
                  ? AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.1)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOngoing ? AppTheme.primary.withValues(alpha: 0.3) : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
                width: 0.8,
              ),
            ),
            child: Image.asset(
              _getSubject3DAsset(subject),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                _getSubjectIcon(subject),
                size: 18,
                color: isOngoing ? AppTheme.primary : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Subject & Section info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOngoing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.green.withValues(alpha: 0.3), width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 2.5, backgroundColor: AppTheme.green),
                            SizedBox(width: 3),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        section,
                        style: const TextStyle(fontSize: 11, color: AppTheme.darkSubtext),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.location_on_outlined, size: 12, color: isDark ? Colors.white60 : Colors.black54),
                    const SizedBox(width: 2),
                    Text(
                      room,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.darkSubtext),
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

  // Subject 3D Asset matcher
  String _getSubject3DAsset(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('nepali') || lower.contains('नेपाली') || lower.contains('english') || lower.contains('language')) {
      return 'assets/icons/3d/fluent_books.png';
    }
    if (lower.contains('math') || lower.contains('opt.') || lower.contains('calculus') || lower.contains('compulsory')) {
      return 'assets/icons/3d/puzzle.png';
    }
    if (lower.contains('sci')) {
      return 'assets/icons/3d/bulb.png';
    }
    if (lower.contains('social') || lower.contains('geo') || lower.contains('history')) {
      return 'assets/icons/3d/map_pin.png';
    }
    if (lower.contains('computer') || lower.contains('code') || lower.contains('it')) {
      return 'assets/icons/3d/nav_computer.png';
    }
    return 'assets/icons/3d/fluent_books.png';
  }

  // Subject Icon matcher
  IconData _getSubjectIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('nepali') || lower.contains('नेपाली')) return Icons.menu_book_rounded;
    if (lower.contains('english')) return Icons.spellcheck_rounded;
    if (lower.contains('math') || lower.contains('opt.') || lower.contains('calculus') || lower.contains('compulsory')) {
      return Icons.calculate_rounded;
    }
    if (lower.contains('sci')) return Icons.science_rounded;
    if (lower.contains('computer')) return Icons.terminal_rounded;
    return Icons.school_rounded;
  }

  // Helper for due date formatting
  String _formatDueDate(String rawDue) {
    if (rawDue.isEmpty) return 'Upcoming';
    final parsed = DateTime.tryParse(rawDue);
    if (parsed != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(parsed.year, parsed.month, parsed.day);
      final diff = dueDay.difference(today).inDays;
      if (diff == 0) return 'Due Today';
      if (diff == 1) return 'Due Tomorrow';
      if (diff > 1 && diff <= 5) return 'Due in $diff days';
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return 'Due ${parsed.day} ${months[parsed.month - 1]}';
    }
    return rawDue.startsWith('Due') ? rawDue : 'Due $rawDue';
  }

  // Visual helper for assignment subject
  (IconData, Color) _getAssignmentSubjectVisual(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) {
      return (Icons.calculate_rounded, const Color(0xFF2563EB));
    } else if (s.contains('nepali')) {
      return (Icons.menu_book_rounded, const Color(0xFF7C3AED));
    } else if (s.contains('sci')) {
      return (Icons.science_rounded, const Color(0xFF059669));
    } else if (s.contains('eng')) {
      return (Icons.auto_stories_rounded, const Color(0xFF0284C7));
    } else if (s.contains('social')) {
      return (Icons.public_rounded, const Color(0xFFD97706));
    }
    return (Icons.assignment_rounded, const Color(0xFF4F46E5));
  }

  // Submission status chip
  Widget _buildSubmissionChip(int subInt, int totalInt, bool isDark) {
    final isComplete = subInt >= totalInt && totalInt > 0;
    if (isComplete) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
            SizedBox(width: 4),
            Text(
              '100% Done',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
      );
    }

    final pct = totalInt > 0 ? (subInt / totalInt * 100).round() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        '$subInt/$totalInt ($pct%)',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  // --- 8. Pending Assignment Reviews ---
  Widget _buildPendingReviews(bool isDark, TeacherProvider teacher) {
    final list = teacher.assignments.isNotEmpty ? teacher.assignments : AppData.assignments;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Pending Homework Reviews (गृहकार्य)',
            subtitle: 'Submissions awaiting evaluation',
            actionLabel: 'All Grihakarya',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AssignmentsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ...list.take(2).map((a) {
            final title = a is Map ? (a['title'] ?? 'Homework') : a.title;
            final submitted = a is Map ? (a['submitted_count'] ?? a['submitted'] ?? 0) : a.submitted;
            final total = a is Map ? (a['total_count'] ?? a['total'] ?? 25) : a.total;
            final classSec = a is Map ? (a['class_name'] ?? a['classSection'] ?? 'Grade 10') : a.classSection;
            final due = a is Map ? (a['due_date'] ?? a['dueDate'] ?? 'Tomorrow') : a.dueDate;
            final totalInt = (total is int && total > 0) ? total : 25;
            final subInt = submitted is int ? submitted : 0;
            final pct = (subInt / totalInt).clamp(0.0, 1.0);
            final isComplete = subInt >= totalInt && totalInt > 0;
            final (subIcon, subColor) = _getAssignmentSubjectVisual(title.toString());

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject 3D Icon chip
                      Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: subColor.withValues(alpha: isDark ? 0.22 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: subColor.withValues(alpha: 0.25), width: 0.8),
                        ),
                        child: Image.asset(
                          'assets/icons/3d/homework.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(subIcon, color: subColor, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Title & section/due
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$classSec • ${_formatDueDate(due.toString())}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.darkSubtext),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Chip
                      _buildSubmissionChip(subInt, totalInt, isDark),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress Bar & Percentage
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isComplete ? const Color(0xFF10B981) : AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(pct * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isComplete ? const Color(0xFF10B981) : AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Bottom review action
                  Row(
                    children: [
                      Text(
                        isComplete
                            ? 'All submissions evaluated'
                            : '${totalInt - subInt} pending evaluation',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isComplete ? const Color(0xFF10B981) : AppTheme.darkSubtext,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AssignmentsScreen()),
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Evaluate',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- 9. Upcoming Exam Card ---
  Widget _buildUpcomingExamCard(bool isDark, TeacherProvider teacher) {
    final firstExam = teacher.exams.isNotEmpty ? teacher.exams.first : null;
    final subject = firstExam is Map ? (firstExam['subject'] ?? firstExam['name'] ?? 'Terminal Examination') : (firstExam != null ? firstExam.subject : 'Terminal Examination');
    final classSec = firstExam is Map ? (firstExam['class_name'] ?? firstExam['classSection'] ?? 'Secondary Wing') : (firstExam != null ? firstExam.classSection : 'Secondary Wing');
    final room = firstExam is Map ? (firstExam['room'] ?? 'Hall A') : (firstExam != null ? firstExam.room : 'Hall A');
    final rawDate = firstExam is Map ? (firstExam['date'] ?? firstExam['date_ad'] ?? '') : (firstExam != null ? firstExam.date : '');
    final date = (rawDate.isNotEmpty && !rawDate.contains('2026')) ? rawDate : 'Mangsir 2081 (Dec 2026)';
    final time = firstExam is Map ? (firstExam['time'] ?? '10:00 AM - 01:00 PM') : (firstExam != null ? firstExam.time : '10:00 AM - 01:00 PM');
    final daysLeft = firstExam is Map ? (firstExam['days_left'] ?? 14) : (firstExam != null ? firstExam.daysLeft : 14);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Upcoming Examination (परीक्षा)',
            subtitle: 'Board & terminal exam schedules',
            actionLabel: 'Exam Routine',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamsScreen()),
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamsScreen()),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icons/3d/calendar.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subject.toString(),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Theory',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$classSec • $room',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.darkSubtext),
                      ),
                      Text(
                        '$date • $time',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$daysLeft',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                          height: 1.1,
                        ),
                      ),
                      const Text(
                        'days left',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.darkSubtext),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 10. Teaching Tips Carousel ---
  Widget _buildTeachingTipsCarousel(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: '💡 Teacher Pedagogical Insights',
            subtitle: 'Best practices for Nepal curriculum excellence',
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: PageView.builder(
              controller: _tipController,
              onPageChanged: (i) => setState(() => _tipIndex = i),
              itemCount: AppData.teachingTips.length,
              itemBuilder: (_, i) {
                final tip = AppData.teachingTips[i];
                return AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                        ),
                        child: Image.asset(
                          'assets/icons/3d/bulb.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'PEDAGOGICAL INSIGHT • #${i + 1}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tip['tip'] as String,
                              style: const TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              AppData.teachingTips.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _tipIndex ? 16 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: i == _tipIndex ? AppTheme.primary : AppTheme.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
