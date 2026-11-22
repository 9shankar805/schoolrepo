import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;
  int _unreadNotifications = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get data => _dashboardData;
  Map<String, dynamic>? get overview => _dashboardData;

  Map<String, dynamic>? get kpis => _dashboardData?['kpis'];
  Map<String, dynamic>? get finance => _dashboardData?['finance'];
  Map<String, dynamic>? get approvalsBadge => _dashboardData?['approvals_badge'];
  List<dynamic> get attendanceTrend => _dashboardData?['attendance_trend'] ?? [];
  List<dynamic> get recentNotices => _dashboardData?['recent_notices'] ?? [];
  String get todayDate => _dashboardData?['today_date'] ?? '';

  int get pendingApprovalsCount => approvalsBadge?['total_pending'] ?? 0;
  int get unreadNotifications => _unreadNotifications;

  Future<void> fetchDashboard({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final results = await Future.wait([
      _api.getDashboardOverview(),
      _api.getUnreadNotificationCount(),
    ]);

    final res = results[0] as ApiResponse<Map<String, dynamic>>;
    _unreadNotifications = results[1] as int;

    _isLoading = false;

    if (res.success && res.data != null) {
      _dashboardData = res.data;
      _errorMessage = null;
    } else {
      _errorMessage = res.message;
    }
    notifyListeners();
  }

  Future<void> refreshUnreadNotifications() async {
    _unreadNotifications = await _api.getUnreadNotificationCount();
    notifyListeners();
  }
}
