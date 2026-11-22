import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/common_widgets.dart';
import 'approvals_screen.dart';
import 'student_attendance_screen.dart';
import 'staff_monitor_screen.dart';
import 'teacher_management_screen.dart';
import 'broadcast_screen.dart';
import 'visitor_manager_screen.dart';
import 'admissions_management_screen.dart';
import 'school_settings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, unread, approval, attendance, notice, security
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _fcmRegistered = false;

  final List<Map<String, String>> _filters = [
    {'id': 'all', 'label': 'All Alerts'},
    {'id': 'unread', 'label': 'Unread'},
    {'id': 'approval', 'label': 'Approvals'},
    {'id': 'attendance', 'label': 'Attendance'},
    {'id': 'notice', 'label': 'Circulars'},
    {'id': 'security', 'label': 'Front Desk'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _fetchUnreadCount();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final res = await _api.getNotifications(type: _selectedFilter);
    if (!mounted) return;

    if (res.success && res.data != null) {
      final raw = (res.data!['notifications'] as List<dynamic>? ?? [])
          .map((n) => Map<String, dynamic>.from(n as Map))
          .toList();

      setState(() {
        _notifications = raw;
        _unreadCount = res.data!['unread_count'] as int? ?? _unreadCount;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _fetchUnreadCount() async {
    final count = await _api.getUnreadNotificationCount();
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  Future<void> _markAsRead(String id) async {
    final res = await _api.markNotificationRead(id);
    if (res.success && mounted) {
      setState(() {
        for (var n in _notifications) {
          if (n['id'] == id) {
            n['is_read'] = true;
            break;
          }
        }
        if (_unreadCount > 0) _unreadCount--;
      });
    }
  }

  Future<void> _markAllRead() async {
    final res = await _api.markAllNotificationsRead();
    if (res.success && mounted) {
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
        _unreadCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read.'),
          backgroundColor: AppTheme.emerald,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteNotification(String id) async {
    final res = await _api.deleteNotification(id);
    if (res.success && mounted) {
      setState(() {
        _notifications.removeWhere((n) => n['id'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert dismissed.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _testRegisterDevicePush() async {
    // Registers current device push token to backend
    const dummyToken = 'fcm_admin_app_executive_token_live';
    final res = await _api.registerPushToken(
      dummyToken,
      platform: 'android',
      deviceName: 'Executive Admin Device',
    );

    if (mounted) {
      if (res.success) {
        setState(() => _fcmRegistered = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('FCM Push Notification Token synchronized successfully! ✅'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${res.message}'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }

  void _navigateToTarget(String? targetScreen) {
    if (targetScreen == null) return;
    Widget? screen;

    switch (targetScreen) {
      case 'approvals':
        screen = const ApprovalsScreen();
        break;
      case 'attendance':
        screen = const StudentAttendanceScreen();
        break;
      case 'staff':
      case 'teachers':
        screen = const TeacherManagementScreen();
        break;
      case 'staff_monitor':
        screen = const StaffMonitorScreen();
        break;
      case 'broadcast':
        screen = const BroadcastScreen();
        break;
      case 'visitors':
        screen = const VisitorManagerScreen();
        break;
      case 'admissions':
        screen = const AdmissionsManagementScreen();
        break;
      case 'settings':
      case 'school':
        screen = const SchoolSettingsScreen();
        break;
      default:
        screen = null;
    }

    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'approval':
        return Icons.fact_check_rounded;
      case 'attendance':
        return Icons.how_to_reg_rounded;
      case 'notice':
        return Icons.campaign_rounded;
      case 'security':
        return Icons.security_rounded;
      case 'finance':
        return Icons.payments_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'approval':
        return AppTheme.royalBlue;
      case 'attendance':
        return AppTheme.emerald;
      case 'notice':
        return AppTheme.purple;
      case 'security':
        return AppTheme.crimson;
      case 'finance':
        return AppTheme.gold;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, isDark),
            _buildPushStatusBanner(isDark),
            _buildFilterPills(isDark),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.royalBlue,
                onRefresh: () async {
                  await Future.wait([
                    _fetchNotifications(),
                    _fetchUnreadCount(),
                  ]);
                },
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.royalBlue))
                    : _buildNotificationsList(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 38,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Notifications & Alerts',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.dark,
                      ),
                    ),
                    if (_unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.crimson,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_unreadCount new',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Text(
                  'Executive Sign-offs, Roll Call & Institutional Alerts',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark All Read',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.royalBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPushStatusBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.royalBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.royalBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: AppTheme.royalBlue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fcmRegistered
                  ? 'FCM Push Token Synced: Instant phone alerts enabled'
                  : 'FCM Push Notifications Active for Executive Account',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.royalBlue,
              ),
            ),
          ),
          InkWell(
            onTap: _testRegisterDevicePush,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.royalBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Sync Token',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPills(bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (ctx, idx) {
          final f = _filters[idx];
          final isSelected = _selectedFilter == f['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              selectedColor: AppTheme.royalBlue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.grey,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
              onSelected: (_) {
                setState(() => _selectedFilter = f['id']!);
                _fetchNotifications();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationsList(bool isDark) {
    if (_notifications.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.royalBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 38,
                  color: AppTheme.royalBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'All Caught Up!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.dark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No alerts match your current filter.',
                style: TextStyle(fontSize: 12, color: AppTheme.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _notifications.length,
      itemBuilder: (ctx, idx) {
        final n = _notifications[idx];
        return _buildNotificationCard(n, isDark);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n, bool isDark) {
    final id = n['id']?.toString() ?? '';
    final title = n['title'] ?? 'Notification';
    final body = n['body'] ?? '';
    final type = n['type'] ?? 'system';
    final priority = n['priority'] ?? 'normal';
    final isRead = n['is_read'] == true;
    final timeAgo = n['time_ago'] ?? 'Recent';
    final targetScreen = n['target_screen'] as String?;

    final iconColor = _colorForType(type);
    final iconData = _iconForType(type);
    final isUrgent = priority == 'urgent' || priority == 'high';

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.crimson,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => _deleteNotification(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? (isDark ? AppTheme.darkCard : Colors.white)
              : (isDark ? const Color(0xFF1E2638) : const Color(0xFFF0F6FF)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? (isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7))
                : iconColor.withOpacity(0.35),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Icon with background
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Title & Priority Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: AppTheme.royalBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: isRead ? FontWeight.w700 : FontWeight.w800,
                                fontSize: 13,
                                color: isDark ? Colors.white : AppTheme.dark,
                              ),
                            ),
                          ),
                          if (isUrgent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.crimson.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'URGENT',
                                style: TextStyle(
                                  color: AppTheme.crimson,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        timeAgo,
                        style: const TextStyle(fontSize: 10, color: AppTheme.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Delete / Dismiss Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, size: 18, color: AppTheme.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) {
                    if (val == 'read') _markAsRead(id);
                    if (val == 'dismiss') _deleteNotification(id);
                  },
                  itemBuilder: (ctx) => [
                    if (!isRead)
                      const PopupMenuItem(
                        value: 'read',
                        child: Text('Mark as Read', style: TextStyle(fontSize: 12)),
                      ),
                    const PopupMenuItem(
                      value: 'dismiss',
                      child: Text('Dismiss Alert', style: TextStyle(fontSize: 12, color: AppTheme.crimson)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Notification Body
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Text(
                body,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Target Screen Action Buttons
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Row(
                children: [
                  if (targetScreen != null && targetScreen.isNotEmpty) ...[
                    InkWell(
                      onTap: () {
                        if (!isRead) _markAsRead(id);
                        _navigateToTarget(targetScreen);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _labelForTarget(targetScreen),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: iconColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 12, color: iconColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!isRead)
                    InkWell(
                      onTap: () => _markAsRead(id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.done_rounded, size: 12, color: AppTheme.grey),
                            SizedBox(width: 4),
                            Text(
                              'Mark Read',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.grey),
                            ),
                          ],
                        ),
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

  String _labelForTarget(String target) {
    switch (target) {
      case 'approvals':
        return 'Review Approvals';
      case 'attendance':
        return 'Open Attendance Sheet';
      case 'staff':
      case 'teachers':
        return 'View Faculty';
      case 'staff_monitor':
        return 'Staff Monitor';
      case 'broadcast':
        return 'Broadcast Notice';
      case 'visitors':
        return 'Visitor Log';
      case 'admissions':
        return 'Review Admissions';
      case 'settings':
      case 'school':
        return 'School Settings';
      default:
        return 'Take Action';
    }
  }
}
