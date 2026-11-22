import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HrLeaveProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> leaveApplications = [];
  List<dynamic> leaveTypes = [];

  bool isLoading = false;
  String? error;

  String filterStatus = 'all'; // all | pending | approved | rejected

  int get pendingCount =>
      leaveApplications.where((l) => (l['status'] ?? '') == 'pending').length;

  // ---------------------------------------------------------------------------
  // Fetching
  // ---------------------------------------------------------------------------

  Future<void> fetchLeaveApplications() async {
    isLoading = true;
    error = null;
    notifyListeners();

    final res = await _api.getHrLeaveApplications(
      status: filterStatus != 'all' ? filterStatus : null,
    );

    isLoading = false;

    if (res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      leaveApplications = (data['data'] as List<dynamic>?) ?? [];
    } else {
      error = res.message;
    }

    notifyListeners();
  }

  Future<void> fetchLeaveTypes() async {
    final res = await _api.getLeaveTypes();
    if (res.success && res.data != null) {
      leaveTypes = res.data as List<dynamic>;
      notifyListeners();
    }
  }

  void setFilter(String status) {
    filterStatus = status;
    fetchLeaveApplications();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<bool> approveLeave(int id, {String? notes}) async {
    final res = await _api.reviewHrLeave(id, 'approved', notes: notes);
    if (res.success) {
      await fetchLeaveApplications();
      return true;
    }
    error = res.message;
    notifyListeners();
    return false;
  }

  Future<bool> rejectLeave(int id, {String? notes}) async {
    final res = await _api.reviewHrLeave(id, 'rejected', notes: notes);
    if (res.success) {
      await fetchLeaveApplications();
      return true;
    }
    error = res.message;
    notifyListeners();
    return false;
  }
}
