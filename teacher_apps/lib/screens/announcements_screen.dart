import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../providers/teacher_provider.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isInitialLoading = false;

  final List<String> _categories = [
    'All Notices',
    'Exam Routine',
    'Administration',
    'Academic',
    'Emergency 🚨',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnnouncements();
    });
  }

  Future<void> _loadAnnouncements() async {
    final teacher = Provider.of<TeacherProvider>(context, listen: false);
    if (teacher.announcements.isEmpty) {
      setState(() => _isInitialLoading = true);
    }
    await teacher.fetchAnnouncements();
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _getNotice3DAsset(Map<String, dynamic> item) {
    final isUrgent = item['isUrgent'] == true;
    if (isUrgent) return 'assets/icons/3d/fire.png';

    final category = (item['category'] ?? '').toString().toLowerCase();
    final title = (item['title'] ?? '').toString().toLowerCase();

    if (title.contains('closure') || title.contains('holiday') || title.contains('snow') || title.contains('weather')) {
      return 'assets/icons/3d/bell.png';
    }
    if (title.contains('science') || title.contains('fair') || title.contains('stem') || title.contains('project') || title.contains('tech') || title.contains('robot')) {
      return 'assets/icons/3d/rocket.png';
    }
    if (category.contains('exam') || title.contains('exam') || title.contains('routine') || title.contains('test') || title.contains('date')) {
      return 'assets/icons/3d/calendar.png';
    }
    if (category.contains('admin') || title.contains('staff') || title.contains('meeting') || title.contains('office') || title.contains('principal')) {
      return 'assets/icons/3d/settings.png';
    }
    if (title.contains('award') || title.contains('competition') || title.contains('winner') || title.contains('sports') || title.contains('trophy')) {
      return 'assets/icons/3d/medal.png';
    }
    if (category.contains('academic') || title.contains('class') || title.contains('book') || title.contains('curriculum') || title.contains('syllabus')) {
      return 'assets/icons/3d/fluent_books.png';
    }
    return 'assets/icons/3d/megaphone.png';
  }

  String _getCategory3DAsset(String cat) {
    if (cat.contains('Exam')) return 'assets/icons/3d/calendar.png';
    if (cat.contains('Admin')) return 'assets/icons/3d/settings.png';
    if (cat.contains('Academic')) return 'assets/icons/3d/fluent_books.png';
    if (cat.contains('Emergency')) return 'assets/icons/3d/fire.png';
    return 'assets/icons/3d/megaphone.png';
  }

  Color _resolveNoticeColor(String category, bool isUrgent) {
    if (isUrgent) return AppTheme.red;
    final cat = category.toLowerCase();
    if (cat.contains('exam')) return AppTheme.primary;
    if (cat.contains('admin')) return AppTheme.purple;
    if (cat.contains('academic')) return const Color(0xFF2563EB);
    return AppTheme.teal;
  }

  String _formatNoticeDate(Map<dynamic, dynamic> map) {
    if (map['nepaliDate'] != null && map['nepaliDate'].toString().isNotEmpty) {
      return map['nepaliDate'].toString();
    }
    final rawDate = map['created_at'] ?? map['date'];
    if (rawDate != null) {
      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final minute = dt.minute.toString().padLeft(2, '0');
        return '${dt.day} ${months[dt.month - 1]} ${dt.year} ($hour:$minute $ampm)';
      } catch (_) {
        return rawDate.toString();
      }
    }
    return 'Recent';
  }

  Map<String, dynamic> _normalizeNotice(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final priority = (map['priority'] ?? '').toString().toLowerCase();
    final isUrgent = map['isUrgent'] == true ||
        priority == 'urgent' ||
        priority == 'high' ||
        priority == 'emergency';
    final isPinned = map['pinned'] == true || isUrgent;

    String category = map['category']?.toString() ?? '';
    if (category.isEmpty) {
      if (priority == 'exam') {
        category = 'Exam Routine';
      } else if (priority == 'admin' || priority == 'administration' || priority == 'holiday') {
        category = 'Administration';
      } else if (isUrgent) {
        category = 'Emergency 🚨';
      } else {
        category = 'Academic';
      }
    }

    return {
      'id': map['id']?.toString() ?? '',
      'title': (map['title'] ?? 'Notice').toString(),
      'body': (map['body'] ?? map['notice'] ?? map['content'] ?? map['snippet'] ?? '').toString(),
      'nepaliDate': _formatNoticeDate(map),
      'author': (map['author'] ?? 'Office of the Principal').toString(),
      'designation': (map['designation'] ?? 'Principal').toString(),
      'target': (map['target'] ?? map['audience'] ?? 'School Wide • All Staff').toString(),
      'category': category,
      'pinned': isPinned,
      'isUrgent': isUrgent,
      'attachment': map['attachment']?.toString(),
      'attachment_url': map['attachment_url']?.toString(),
      'color': _resolveNoticeColor(category, isUrgent),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCat = _categories[_selectedCategoryIndex];
    final teacher = Provider.of<TeacherProvider>(context);

    // Normalize raw API notices from the teacher provider
    final normalizedList = teacher.announcements.map((a) => _normalizeNotice(a)).toList();

    // Filter by selected category and search query
    final filteredNotices = normalizedList.where((a) {
      final matchesCategory = _selectedCategoryIndex == 0 ||
          (selectedCat == 'Emergency 🚨'
              ? a['isUrgent'] == true
              : a['category'] == selectedCat);

      if (_searchQuery.isEmpty) return matchesCategory;

      final q = _searchQuery.toLowerCase();
      final title = (a['title'] as String).toLowerCase();
      final body = (a['body'] as String).toLowerCase();
      final author = (a['author'] as String).toLowerCase();

      return matchesCategory &&
          (title.contains(q) || body.contains(q) || author.contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notice Board (सूचना पाटी)',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
            ),
            Text(
              'Nepal School Hub Digital Circulars • 2081',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : AppTheme.darkSubtext,
              ),
            ),
          ],
        ),
        leading: Navigator.canPop(context)
            ? CircleIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
                size: 38,
              )
            : null,
        leadingWidth: Navigator.canPop(context) ? 60 : null,
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              onPressed: () => _showComposeSheet(context, isDark),
              icon: Image.asset(
                'assets/icons/3d/megaphone.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.edit_note_rounded, size: 18),
              ),
              label: const Text(
                'Publish',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => teacher.fetchAnnouncements(),
        color: AppTheme.primary,
        child: Column(
          children: [
            // Search & Filter Bar with 3D Search Icon
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search circulars, routines, memos...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.darkSubtext),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/icons/3d/search.png',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppTheme.darkSubtext,
                      ),
                    ),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppTheme.darkCard : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                    ),
                  ),
                ),
              ),
            ),

            // Categories Horizontal Selector with 3D Category Badges
            SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final sel = i == _selectedCategoryIndex;
                  final name = _categories[i];
                  final iconPath = _getCategory3DAsset(name);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: sel
                            ? const LinearGradient(
                                colors: [Color(0xFF0F4C81), Color(0xFF2563EB)],
                              )
                            : null,
                        color: sel ? null : (isDark ? AppTheme.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel
                              ? AppTheme.primary
                              : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
                          width: 1,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            iconPath,
                            width: 16,
                            height: 16,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : AppTheme.dark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Notices List View or Empty/Loading State
            Expanded(
              child: _isInitialLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : filteredNotices.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkCard : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    _searchQuery.isNotEmpty
                                        ? 'assets/icons/3d/search.png'
                                        : 'assets/icons/3d/megaphone.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(
                                      _searchQuery.isNotEmpty
                                          ? Icons.search_off_rounded
                                          : Icons.campaign_outlined,
                                      size: 40,
                                      color: isDark ? Colors.white38 : Colors.black26,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No matching circulars'
                                      : 'No notices on the board yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppTheme.dark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Try searching with a different term'
                                      : 'New school circulars and academic notices published by the administration will appear here.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.darkSubtext,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => _showComposeSheet(context, isDark),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Publish First Notice'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                          itemCount: filteredNotices.length,
                          itemBuilder: (ctx, i) {
                            return _buildNoticeCard(filteredNotices[i], isDark, i)
                                .animate()
                                .fadeIn(delay: (i * 60).ms)
                                .slideY(begin: 0.05);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDetailSheet(BuildContext context, Map<String, dynamic> item, bool isDark) {
    final color = item['color'] as Color;
    final hasAttachment = item['attachment'] != null && item['attachment'].toString().isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 36),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: isDark ? 0.35 : 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    _getNotice3DAsset(item),
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
                          Flexible(
                            child: Text(
                              item['author'] as String,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppTheme.dark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 14, color: AppTheme.primary),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['nepaliDate'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkSubtext,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Text(
                    '#${item['category']}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              item['title'] as String,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                (item['body'] as String).isNotEmpty
                    ? (item['body'] as String)
                    : 'This circular was published by the administration for all staff and students.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Image.asset(
                  'assets/icons/3d/student_info.png',
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Target Audience: ${item['target']}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkSubtext,
                    ),
                  ),
                ),
              ],
            ),
            if (hasAttachment) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.primary.withValues(alpha: 0.12) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25), width: 1),
                ),
                child: Row(
                  children: [
                    Image.asset('assets/icons/3d/homework.png', width: 22, height: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item['attachment'] as String,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.download_rounded, size: 18, color: AppTheme.primary),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Close Circular', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> item, bool isDark, int index) {
    final isUrgent = item['isUrgent'] == true;
    final isPinned = item['pinned'] == true;
    final color = item['color'] as Color;
    final hasAttachment = item['attachment'] != null && item['attachment'].toString().isNotEmpty;

    return GestureDetector(
      onTap: () => _showNoticeDetailSheet(context, item, isDark),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUrgent
                ? AppTheme.red.withValues(alpha: 0.5)
                : (isPinned
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder)),
            width: isUrgent || isPinned ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isUrgent ? AppTheme.red : const Color(0xFF0F172A))
                  .withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              decoration: BoxDecoration(
                color: isUrgent
                    ? AppTheme.red.withValues(alpha: isDark ? 0.15 : 0.06)
                    : (isPinned
                        ? AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.04)
                        : null),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: Row(
                children: [
                  // 3D Icon Avatar
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: color.withValues(alpha: isDark ? 0.35 : 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      _getNotice3DAsset(item),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.campaign_outlined,
                        color: color,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Author & Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item['author'] as String,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppTheme.dark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: AppTheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item['nepaliDate'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkSubtext,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badges
                  if (isUrgent)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'URGENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else if (isPinned)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin_rounded, size: 11, color: AppTheme.primary),
                          SizedBox(width: 3),
                          Text(
                            'PINNED',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Popup menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.darkSubtext),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (val) {
                      if (val == 'share') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notice link copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Share Notice', style: TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Title & Body
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      height: 1.3,
                    ),
                  ),
                  if ((item['body'] as String).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item['body'] as String,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : AppTheme.darkSubtext,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Attachment Chip if any
            if (hasAttachment)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.primary.withValues(alpha: 0.12)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/3d/homework.png',
                        width: 18,
                        height: 18,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 18,
                          color: AppTheme.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['attachment'] as String,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.download_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Target audience bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : AppTheme.lightBg,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(17)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppTheme.darkCardBorder
                        : AppTheme.cardBorder.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/icons/3d/student_info.png',
                    width: 15,
                    height: 15,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.people_alt_outlined, size: 13, color: AppTheme.darkSubtext),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Target: ${item['target']}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkSubtext,
                      ),
                    ),
                  ),
                  Text(
                    '#${item['category']}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
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

  void _showComposeSheet(BuildContext context, bool isDark) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String target = 'All Classes';
    String category = 'Academic';
    bool isUrgent = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                    Expanded(
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/icons/3d/megaphone.png',
                            width: 26,
                            height: 26,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.campaign_rounded, color: AppTheme.primary, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: Text(
                              'Publish Notice (नयाँ सूचना)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title Input
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notice Title *',
                    hintText: 'e.g. Unit Test Schedule, Staff Meeting',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Body Input
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Notice Body / Details *',
                    hintText: 'Write the complete circular details here...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Target Selector
                const Text(
                  'Target Audience',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: target,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    'All Classes',
                    'High School Faculty',
                    'Grade 10 Students',
                    'School Wide • All Staff',
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) setModal(() => target = val);
                  },
                ),
                const SizedBox(height: 12),

                // Category Selector
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    'Academic',
                    'Exam Routine',
                    'Administration',
                    'Emergency 🚨',
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModal(() {
                        category = val;
                        if (val == 'Emergency 🚨') isUrgent = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Urgent Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Image.asset(
                    'assets/icons/3d/fire.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  title: const Text(
                    'Mark as Urgent / Broadcast',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Will pin to the top and highlight in red',
                    style: TextStyle(fontSize: 11, color: AppTheme.darkSubtext),
                  ),
                  value: isUrgent,
                  activeThumbColor: AppTheme.red,
                  onChanged: (val) => setModal(() => isUrgent = val),
                ),
                const SizedBox(height: 16),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final title = titleCtrl.text.trim();
                            final body = bodyCtrl.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppTheme.red,
                                  content: Text('Please enter a notice title'),
                                ),
                              );
                              return;
                            }

                            setModal(() => isSubmitting = true);

                            final teacher = Provider.of<TeacherProvider>(context, listen: false);
                            final success = await teacher.publishAnnouncement({
                              'title': title,
                              'body': body.isNotEmpty ? body : 'Official notice for faculty and students.',
                              'notice': body.isNotEmpty ? body : 'Official notice for faculty and students.',
                              'target_audience': target,
                              'target': target,
                              'category': category,
                              'is_urgent': isUrgent,
                              'priority': isUrgent ? 'urgent' : 'normal',
                            });

                            if (!context.mounted) return;
                            Navigator.pop(sheetCtx);

                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppTheme.green,
                                  content: Text('Notice published to Notice Board successfully ✅'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppTheme.orange,
                                  content: Text('Notice could not be published to the server. Please check connection.'),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/icons/3d/megaphone.png',
                                width: 20,
                                height: 20,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Broadcast Notice Now',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
