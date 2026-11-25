import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/app_data.dart';
import '../widgets/common_widgets.dart';
import '../providers/teacher_provider.dart';
import '../providers/auth_provider.dart';
import 'students_screen.dart';
import 'attendance_screen.dart';
import 'assignments_screen.dart';
import 'marks_entry_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDayIndex = 0; // Monday default matching reference design
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _routineDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final List<String> _routineDayNames = [
    'Monday (सोमबार)',
    'Tuesday (मंगलबार)',
    'Wednesday (बुधबार)',
    'Thursday (बिहीबार)',
    'Friday (शुक्रबार)',
    'Saturday (शनिबार)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacher = Provider.of<TeacherProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final incharge = auth.classInchargeInfo;
    final List<TeacherClass> classList;
    if (teacher.teacherClasses.isNotEmpty) {
      classList = teacher.teacherClasses.where((c) =>
        !c.section.contains('Mt. Everest') &&
        !c.section.contains('Annapurna') &&
        !c.section.contains('Science A') &&
        !c.section.contains('Mgmt A')
      ).toList();
    } else if (incharge != null) {
      final cName = incharge['class_name']?.toString() ?? 'UKG';
      final sName = incharge['section_name']?.toString() ?? 'C';
      classList = [
        TeacherClass(
          name: 'Class Teacher',
          section: '$cName — $sName',
          room: 'Room 101',
          time: '10:00 AM - 04:00 PM',
          subject: 'All Subjects',
          students: teacher.studentsCount > 0 ? teacher.studentsCount : 41,
          isClassTeacher: true,
          classId: incharge['class_id'] is int ? incharge['class_id'] : int.tryParse(incharge['class_id']?.toString() ?? ''),
          sectionId: incharge['section_id'] is int ? incharge['section_id'] : int.tryParse(incharge['section_id']?.toString() ?? ''),
        ),
      ];
    } else {
      classList = [];
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar with Academic Badge & Controls matching reference
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.2),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: Image.asset(
                                        'assets/icons/3d/crown.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.school_rounded,
                                          size: 11,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ACADEMIC SESSION 2081 B.S.',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFF60A5FA) : AppTheme.primary,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'My classes',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Image.asset(
                                    'assets/images/illustrations/teacher_header.png',
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleIconButton(
                              icon: _isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
                              size: 40,
                              onTap: () {
                                setState(() {
                                  _isSearchVisible = !_isSearchVisible;
                                  if (!_isSearchVisible) {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 40,
                              height: 40,
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
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Expandable Animated Search Bar
                    if (_isSearchVisible) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppTheme.darkCardBorder : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, size: 20, color: AppTheme.darkSubtext),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppTheme.dark,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Search subject, section, or room...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.darkSubtext,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  setState(() => _searchQuery = val);
                                },
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Icon(Icons.cancel_rounded, size: 18, color: AppTheme.darkSubtext),
                              ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 150.ms).slideY(begin: -0.1),
                    ],

                    const SizedBox(height: 14),

                    // Professional Segmented Tab Switcher (No text truncation!)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFCBD5E1),
                          width: 0.8,
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        tabAlignment: TabAlignment.fill,
                        labelPadding: EdgeInsets.zero,
                        indicator: BoxDecoration(
                          color: isDark ? const Color(0xFF2563EB) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: isDark ? Colors.white : AppTheme.primary,
                        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        tabs: [
                          Tab(
                            height: 38,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: Image.asset(
                                        'assets/icons/3d/my_classes.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.school_outlined, size: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text('Assigned Classes'),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.white : AppTheme.primary).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${classList.length}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: isDark ? Colors.white : AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Tab(
                            height: 38,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: Image.asset(
                                        'assets/icons/3d/calendar.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.calendar_month_rounded, size: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text('Weekly Routine'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildClassesListTab(isDark, classList),
              _buildWeeklyRoutineTab(isDark, classList),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: Assigned Classes List ---
  Widget _buildClassesListTab(bool isDark, List<TeacherClass> classList) {
    final filtered = classList.where((c) {
      final matchesSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.section.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.room.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedFilter == 'Ongoing') {
        return c.isOngoing;
      }
      return true;
    }).toList();

    final teacher = Provider.of<TeacherProvider>(context);
    final totalStudents = teacher.studentsCount;
    final ongoingCount = classList.where((c) => c.isOngoing).length;

    // Calculate unique sections
    final uniqueSections = classList.map((c) => c.section).toSet().length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Quick Stats Summary Row with 3D Icons
          Row(
            children: [
              _buildSummaryCard(
                label: 'Active Classes',
                value: '${classList.length}',
                subLabel: '$uniqueSections Sections',
                imageAsset: 'assets/icons/3d/my_classes.png',
                fallbackIcon: Icons.menu_book_rounded,
                color: const Color(0xFF2563EB), // Royal Blue
                bgLight: const Color(0xFFEFF6FF),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                label: 'Total Students',
                value: '$totalStudents',
                subLabel: 'Enrolled Roster',
                imageAsset: 'assets/icons/3d/student_info.png',
                fallbackIcon: Icons.groups_rounded,
                color: const Color(0xFF059669), // Emerald Green
                bgLight: const Color(0xFFECFDF5),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                label: 'Avg Class GPA',
                value: '3.6',
                subLabel: 'Distinction (A)',
                imageAsset: 'assets/icons/3d/medal.png',
                fallbackIcon: Icons.auto_awesome_rounded,
                color: const Color(0xFF7C3AED), // Rich Violet
                bgLight: const Color(0xFFF5F3FF),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Filter Chips Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'All (${classList.length})', isDark),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Ongoing',
                  ongoingCount > 0 ? 'Live Now ($ongoingCount)' : 'Live Classes (0)',
                  isDark,
                  icon: Icons.circle,
                  iconColor: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Section Header with Dynamic Count
          SectionHeader(
            title: 'Assigned Subject Sections',
            subtitle: 'Curriculum coverage, student roster & marks',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              child: Text(
                '${filtered.length} ${filtered.length == 1 ? 'Subject' : 'Subjects'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Class Cards List or Empty State
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No classes match your search',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : AppTheme.darkSubtext,
                    ),
                  ),
                ],
              ),
            )
          else
            ...filtered.asMap().entries.map((e) {
              final idx = e.key;
              final cls = e.value;
              return _buildVedaClassCard(cls, idx, isDark)
                  .animate()
                  .fadeIn(delay: (idx * 60).ms)
                  .slideY(begin: 0.05);
            }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String filterKey,
    String label,
    bool isDark, {
    IconData? icon,
    Color? iconColor,
  }) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? AppTheme.darkCardBorder : const Color(0xFFCBD5E1)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 8, color: isSelected ? Colors.white : iconColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required String subLabel,
    required String imageAsset,
    required IconData fallbackIcon,
    required Color color,
    required Color bgLight,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.25 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppTheme.dark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subLabel,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkSubtext,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- Dynamic Subject 3D Asset Matcher ---
  String _getSubject3DAsset(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('nepali') || lower.contains('नेपाली') || lower.contains('english') || lower.contains('grammar') || lower.contains('language')) {
      return 'assets/icons/3d/fluent_books.png';
    }
    if (lower.contains('math') || lower.contains('opt.') || lower.contains('calculus') || lower.contains('compulsory')) {
      return 'assets/icons/3d/puzzle.png';
    }
    if (lower.contains('sci') || lower.contains('physics') || lower.contains('chem') || lower.contains('bio')) {
      return 'assets/icons/3d/bulb.png';
    }
    if (lower.contains('social') || lower.contains('history') || lower.contains('geography')) {
      return 'assets/icons/3d/map_pin.png';
    }
    if (lower.contains('computer') || lower.contains('coding') || lower.contains('ict')) {
      return 'assets/icons/3d/nav_computer.png';
    }
    return 'assets/icons/3d/fluent_books.png';
  }

  // --- Dynamic Subject Icon Matcher ---
  IconData _getSubjectIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('nepali') || lower.contains('नेपाली')) return Icons.menu_book_rounded;
    if (lower.contains('english') || lower.contains('grammar')) return Icons.spellcheck_rounded;
    if (lower.contains('math') || lower.contains('opt.') || lower.contains('calculus') || lower.contains('compulsory')) {
      return Icons.calculate_rounded;
    }
    if (lower.contains('sci') || lower.contains('physics') || lower.contains('chem') || lower.contains('bio')) {
      return Icons.science_rounded;
    }
    if (lower.contains('social') || lower.contains('history') || lower.contains('geography')) return Icons.public_rounded;
    if (lower.contains('computer') || lower.contains('coding') || lower.contains('ict')) return Icons.terminal_rounded;
    if (lower.contains('health') || lower.contains('physical') || lower.contains('sports')) return Icons.sports_soccer_rounded;
    if (lower.contains('art') || lower.contains('draw') || lower.contains('music')) return Icons.palette_rounded;
    return Icons.auto_stories_rounded;
  }

  // --- Dynamic Subject Accent Color Matcher ---
  Color _getSubjectColor(String name, int index) {
    final lower = name.toLowerCase();
    if (lower.contains('nepali') || lower.contains('नेपाली')) return const Color(0xFF6366F1); // Indigo
    if (lower.contains('english')) return const Color(0xFF0284C7); // Sky Blue
    if (lower.contains('math')) return const Color(0xFF2563EB); // Royal Blue
    if (lower.contains('sci')) return const Color(0xFF0D9488); // Teal
    if (lower.contains('social')) return const Color(0xFFD97706); // Amber
    if (lower.contains('computer')) return const Color(0xFF7C3AED); // Purple

    const palette = [
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFF0D9488),
      Color(0xFFD97706),
      Color(0xFFE11D48),
    ];
    return palette[index % palette.length];
  }

  Widget _buildVedaClassCard(TeacherClass cls, int index, bool isDark) {
    final color = _getSubjectColor(cls.name, index);
    final isOngoing = cls.isOngoing || index == 0; // Highlight current period

    // Realistic syllabus computation
    final syllabusFactor = ((cls.avgGrade / 4.0) * 0.88).clamp(0.50, 0.95);
    final syllabusPercentage = (syllabusFactor * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOngoing
              ? (isDark ? const Color(0xFF3B82F6) : AppTheme.primary)
              : (isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0)),
          width: isOngoing ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOngoing
                ? AppTheme.primary.withValues(alpha: isDark ? 0.25 : 0.08)
                : const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.035),
            blurRadius: isOngoing ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ClassDetailScreen(cls: cls)),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: 3D Icon + Subject Title + Live Badge & Student Count
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Image.asset(
                        _getSubject3DAsset(cls.name),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(_getSubjectIcon(cls.name), size: 23, color: color),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  cls.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOngoing) ...[
                                const SizedBox(width: 6),
                                _buildLiveBeaconBadge(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  cls.section,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (cls.isClassTeacher) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Class Teacher',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Elegant Student Roster Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${cls.students}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppTheme.dark,
                            ),
                          ),
                          const Text(
                            'students',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkSubtext,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Timing & Room Pills Row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildPillChip(Icons.access_time_rounded, cls.time, isDark),
                    _buildPillChip(Icons.location_on_outlined, cls.room, isDark),
                  ],
                ),
                const SizedBox(height: 14),

                // Meaningful Progress & Academic Standing
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_outlined, size: 12, color: AppTheme.darkSubtext),
                        SizedBox(width: 4),
                        Text(
                          'Syllabus Coverage',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkSubtext,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$syllabusPercentage% Completed',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: syllabusFactor,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.8), color],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Secondary Indicators: GPA Tag & Chapters
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: Color(0xFF059669)),
                          const SizedBox(width: 3),
                          Text(
                            '${cls.avgGrade.toStringAsFixed(1)} / 4.0 GPA',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 11,
                            color: isDark ? Colors.white60 : AppTheme.darkSubtext,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Ch. ${(syllabusPercentage * 16 / 100).round()}/16 Taught',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkSubtext,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Divider line
                Divider(
                  height: 1,
                  color: isDark ? AppTheme.darkCardBorder : const Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 12),

                // Tactile, Ergonomic Quick Action Pill Buttons with 3D Icons
                Row(
                  children: [
                    Expanded(
                      child: _buildClassQuickBtn(
                        imageAsset: 'assets/icons/3d/fluent_clipboard.png',
                        fallbackIcon: Icons.fact_check_rounded,
                        label: 'Haziri',
                        color: const Color(0xFF059669),
                        bgColor: const Color(0xFFECFDF5),
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildClassQuickBtn(
                        imageAsset: 'assets/icons/3d/student_info.png',
                        fallbackIcon: Icons.groups_rounded,
                        label: 'Students',
                        color: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentsScreen(filterClass: cls.section),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildClassQuickBtn(
                        imageAsset: 'assets/icons/3d/homework.png',
                        fallbackIcon: Icons.assignment_rounded,
                        label: 'Homework',
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AssignmentsScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildClassQuickBtn(
                        imageAsset: 'assets/icons/3d/medal.png',
                        fallbackIcon: Icons.edit_note_rounded,
                        label: 'Marks',
                        color: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF5F3FF),
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MarksEntryScreen(
                              initialClass: cls.section,
                              initialSubject: cls.subject,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Pulsing Live Beacon Badge ---
  Widget _buildLiveBeaconBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.5,
            height: 5.5,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.3, 1.3),
                duration: 900.ms,
              ),
          const SizedBox(width: 4),
          const Text(
            'LIVE NOW',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0xFF059669),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.darkSubtext),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkSubtext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassQuickBtn({
    required String imageAsset,
    required IconData fallbackIcon,
    required String label,
    required Color color,
    required Color bgColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 1),
          decoration: BoxDecoration(
            color: isDark ? color.withValues(alpha: 0.14) : bgColor,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 0.8,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: Image.asset(
                        imageAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: 12.5, color: color),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 2: Weekly Routine Timetable (Matching Reference Design) ---
  Widget _buildWeeklyRoutineTab(bool isDark, [List<TeacherClass>? classList]) {
    final routineItems = _getRoutineForDay(_selectedDayIndex, classList);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal Day Selector Pills (Mon - Sat)
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _routineDays.length,
              itemBuilder: (context, idx) {
                final isSelected = idx == _selectedDayIndex;
                final dayCode = _routineDays[idx];
                return GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 54,
                    height: 50,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1E293B)
                          : (isDark ? AppTheme.darkCard : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1E293B)
                            : (isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.4 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF1E293B).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Center(
                      child: Text(
                        dayCode,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : const Color(0xFF475569)),
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Day header strip
          Row(
            children: [
              Text(
                _routineDayNames[_selectedDayIndex],
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '4 Periods • 1 Free Period',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF60A5FA) : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Daily Routine Timeline Rows
          ...List.generate(routineItems.length, (idx) {
            final item = routineItems[idx];
            return _buildRoutineTimelineRow(item, isDark);
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getRoutineForDay(int dayIdx, [List<TeacherClass>? classList]) {
    final c1 = (classList != null && classList.isNotEmpty) ? classList[0].section : 'Class 1 — A';
    final s1 = (classList != null && classList.isNotEmpty) ? classList[0].name : 'Nepali';
    final c2 = (classList != null && classList.length > 1) ? classList[1].section : (classList != null && classList.isNotEmpty ? classList[0].section : 'Class 2 — A');
    final s2 = (classList != null && classList.length > 1) ? classList[1].name : (classList != null && classList.isNotEmpty ? classList[0].name : 'English');

    if (dayIdx == 0) {
      // Sunday / Day 0
      return [
        {
          'time': '09.00 AM',
          'class': c1,
          'period': 'Period 1',
          'isFree': false,
          'subject': s1,
          'iconAsset': 'assets/icons/3d/homework.png',
          'color': const Color(0xFFE0F2FE),
          'borderColor': const Color(0xFFBAE6FD),
          'accentColor': const Color(0xFF0284C7),
          'progress': 0.85,
          'progressLabel': '85%',
          'chapter': 'Ch1-Grammar & Vocabulary',
          'totalChapters': 12,
          'completedChapters': 8,
        },
        {
          'time': '10.00 AM',
          'class': c2,
          'period': 'Period 2',
          'isFree': true,
          'freeTitle': 'FREE PERIOD',
          'freeSub': 'Teacher prep & break hour',
          'illustration': 'assets/images/illustrations/free_period.png',
        },
        {
          'time': '11.00 AM',
          'class': c1,
          'period': 'Period 3',
          'isFree': false,
          'subject': s1,
          'iconAsset': 'assets/icons/3d/chat_text.png',
          'color': const Color(0xFFFFE4E6),
          'borderColor': const Color(0xFFFECDD3),
          'accentColor': const Color(0xFFE11D48),
          'progress': 0.50,
          'progressLabel': '50%',
          'chapter': 'Ch5-Reading & Literature',
          'totalChapters': 12,
          'completedChapters': 6,
        },
        {
          'time': '12.00 PM',
          'class': c2,
          'period': 'Period 4',
          'isFree': false,
          'subject': s2,
          'iconAsset': 'assets/icons/3d/map_pin.png',
          'color': const Color(0xFFFEF3C7),
          'borderColor': const Color(0xFFFDE68A),
          'accentColor': const Color(0xFFD97706),
          'progress': 0.75,
          'progressLabel': '75%',
          'chapter': 'Ch7-Our Environment & Society',
          'totalChapters': 12,
          'completedChapters': 9,
        },
        {
          'time': '02.00 PM',
          'class': c1,
          'period': 'Period 5',
          'isFree': false,
          'subject': s1,
          'iconAsset': 'assets/icons/3d/target.png',
          'color': const Color(0xFFD1FAE5),
          'borderColor': const Color(0xFFA7F3D0),
          'accentColor': const Color(0xFF059669),
          'progress': 0.92,
          'progressLabel': '92%',
          'chapter': 'Ch10-Exercise & Revision',
          'totalChapters': 12,
          'completedChapters': 11,
        },
      ];
    } else {
      // Other days
      final dayName = _routineDays[dayIdx];
      return [
        {
          'time': '09.00 AM',
          'class': c1,
          'period': 'Period 1',
          'isFree': false,
          'subject': s1,
          'iconAsset': 'assets/icons/3d/rocket.png',
          'color': const Color(0xFFE0F2FE),
          'borderColor': const Color(0xFFBAE6FD),
          'accentColor': const Color(0xFF0284C7),
          'progress': 0.70,
          'progressLabel': '70%',
          'chapter': 'Ch6-Language & Communication',
          'totalChapters': 14,
          'completedChapters': 10,
        },
        {
          'time': '10.00 AM',
          'class': c2,
          'period': 'Period 2',
          'isFree': false,
          'subject': s2,
          'iconAsset': 'assets/icons/3d/target.png',
          'color': const Color(0xFFD1FAE5),
          'borderColor': const Color(0xFFA7F3D0),
          'accentColor': const Color(0xFF059669),
          'progress': 0.80,
          'progressLabel': '80%',
          'chapter': 'Ch8-Expressions & Poems',
          'totalChapters': 15,
          'completedChapters': 12,
        },
        {
          'time': '11.00 AM',
          'class': 'Staff Room',
          'period': 'Break',
          'isFree': true,
          'freeTitle': 'FREE PERIOD',
          'freeSub': '$dayName Mentorship & Lesson Planning',
          'illustration': 'assets/images/illustrations/free_period.png',
        },
        {
          'time': '12.00 PM',
          'class': '10th B',
          'period': 'Period 4',
          'isFree': false,
          'subject': 'Nepali Sahitya',
          'iconAsset': 'assets/icons/3d/chat_bubble.png',
          'color': const Color(0xFFFFE4E6),
          'borderColor': const Color(0xFFFECDD3),
          'accentColor': const Color(0xFFE11D48),
          'progress': 0.88,
          'progressLabel': '88%',
          'chapter': 'Ch11-Hamro Samaj ra Sanskriti',
          'totalChapters': 12,
          'completedChapters': 10,
        },
      ];
    }
  }

  Widget _buildRoutineTimelineRow(Map<String, dynamic> item, bool isDark) {
    final isFree = item['isFree'] == true;
    final time = item['time'] as String;
    final className = item['class'] as String;
    final period = item['period'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Time & Class Period
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  className,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  period,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkSubtext,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right Column: Card
          Expanded(
            child: isFree
                ? _buildFreePeriodCard(item, isDark)
                : _buildPastelSubjectCard(item, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFreePeriodCard(Map<String, dynamic> item, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['freeTitle'] ?? 'FREE PERIOD',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item['freeSub'] ?? 'Teacher prep & break hour',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkSubtext,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            item['illustration'] ?? 'assets/images/illustrations/free_period.png',
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.coffee_rounded,
              color: Color(0xFFD97706),
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastelSubjectCard(Map<String, dynamic> item, bool isDark) {
    final Color cardColor = item['color'] as Color;
    final Color borderColor = item['borderColor'] as Color;
    final Color accentColor = item['accentColor'] as Color;
    final double progress = (item['progress'] as num).toDouble();
    final String subject = item['subject'] as String;
    final String chapter = item['chapter'] as String;
    final String progressLabel = item['progressLabel'] as String;
    final int totalChapters = item['totalChapters'] as int;
    final int completedChapters = item['completedChapters'] as int;
    final String iconAsset = item['iconAsset'] as String;

    final bg = isDark
        ? Color.alphaBlend(cardColor.withValues(alpha: 0.16), const Color(0xFF1E293B))
        : cardColor;
    final border = isDark ? cardColor.withValues(alpha: 0.35) : borderColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : cardColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Subject icon + name + progress %
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Image.asset(
                  iconAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.book_rounded,
                    size: 16,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subject,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                progressLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Chapter Title
          Text(
            chapter,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 7),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4.5,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.65),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 6),

          // Footer Row: Total chapters & completed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total chapters : $totalChapters',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              Text(
                'Completed : $completedChapters',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Class Detail Screen ---
class ClassDetailScreen extends StatelessWidget {
  final TeacherClass cls;
  const ClassDetailScreen({super.key, required this.cls});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacher = Provider.of<TeacherProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: Text('${cls.name} (${cls.section})'),
        leading: CircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
          size: 38,
        ),
        leadingWidth: 60,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        child: Column(
          children: [
            // Header Gradient Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F4C81), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cls.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cls.section,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildDetailStatChip(Icons.groups_rounded, '${cls.students}', 'Students'),
                      const SizedBox(width: 10),
                      _buildDetailStatChip(Icons.location_on_outlined, cls.room.split(' ')[0], 'Room'),
                      const SizedBox(width: 10),
                      _buildDetailStatChip(Icons.stars_rounded, cls.avgGrade.toStringAsFixed(1), 'Avg GPA'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Academic Actions
            const SectionHeader(title: 'Quick Academic Actions'),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _buildActionTile(
                  icon: Icons.fact_check_rounded,
                  label: 'Take Haziri',
                  color: AppTheme.green,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                  ),
                ),
                _buildActionTile(
                  icon: Icons.edit_note_rounded,
                  label: 'Enter Marks',
                  color: AppTheme.blue,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MarksEntryScreen(
                        initialClass: cls.section,
                        initialSubject: cls.subject,
                      ),
                    ),
                  ),
                ),
                _buildActionTile(
                  icon: Icons.assignment_rounded,
                  label: 'Grihakarya',
                  color: AppTheme.orange,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AssignmentsScreen()),
                  ),
                ),
                _buildActionTile(
                  icon: Icons.people_alt_rounded,
                  label: 'Student Roster',
                  color: AppTheme.purple,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StudentsScreen(filterClass: cls.section)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Top Students in this class
            SectionHeader(
              title: 'Student Roster (${cls.section})',
              actionLabel: 'View All',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StudentsScreen(filterClass: cls.section)),
              ),
            ),
            const SizedBox(height: 12),
            ...teacher.studentList.take(5).map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withValues(alpha: 0.1),
                    ),
                    child: Center(
                      child: Text(
                        s.avatar,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
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
                          s.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Roll No: ${s.rollNo} • GPA: ${s.gpa.toStringAsFixed(2)} • Haziri: ${(s.attendance * 100).toInt()}%',
                          style: const TextStyle(fontSize: 11, color: AppTheme.darkSubtext),
                        ),
                      ],
                    ),
                  ),
                  GradeBadge(grade: s.grade),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailStatChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.dark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
