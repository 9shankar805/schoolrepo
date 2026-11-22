import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ApprovalsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _leaves = [];
  List<dynamic> _expenses = [];
  List<dynamic> _admissions = [];
  Map<String, dynamic> _counts = {
    'total': 0,
    'leaves': 0,
    'expenses': 0,
    'admissions': 0,
  };

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<dynamic> get leaves => _leaves;
  List<dynamic> get expenses => _expenses;
  List<dynamic> get admissions => _admissions;
  Map<String, dynamic> get counts => _counts;
  int get totalPending => _counts['total'] ?? 0;

  Future<void> fetchApprovals() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.getApprovals();
    _isLoading = false;

    if (res.success && res.data != null) {
      final data = res.data!['data'] ?? {};
      _leaves = data['leaves'] ?? [];
      _expenses = data['expenses'] ?? [];
      _admissions = data['admissions'] ?? [];
      _counts = res.data!['counts'] is Map
          ? Map<String, dynamic>.from(res.data!['counts'] as Map)
          : _counts;
      _errorMessage = null;
    } else {
      _errorMessage = res.message;
    }
    notifyListeners();
  }

  Future<bool> handleLeave(int id, String action, {String? notes}) async {
    final res = await _api.handleLeave(id, action, notes: notes);
    if (res.success) {
      _leaves.removeWhere((item) => item['id'] == id);
      _updateCounts();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> handleExpense(int id, String action, {String? notes}) async {
    final res = await _api.handleExpense(id, action, notes: notes);
    if (res.success) {
      _expenses.removeWhere((item) => item['id'] == id);
      _updateCounts();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> handleAdmission(int id, String action, {String? notes}) async {
    final res = await _api.handleAdmission(id, action, notes: notes);
    if (res.success) {
      _admissions.removeWhere((item) => item['id'] == id);
      _updateCounts();
      notifyListeners();
      return true;
    }
    return false;
  }

  void _updateCounts() {
    _counts['leaves'] = _leaves.length;
    _counts['expenses'] = _expenses.length;
    _counts['admissions'] = _admissions.length;
    _counts['total'] = _leaves.length + _expenses.length + _admissions.length;
  }
}
