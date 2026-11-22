import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _school;
  List<String> _permissions = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get school => _school;
  List<String> get permissions => _permissions;
  bool get isAuthenticated => _api.isAuthenticated;

  String get adminName => _user?['name'] ?? 'Administrator';
  String get adminRole => _user?['role'] ?? 'Admin';
  String get primaryRole => adminRole;
  List<dynamic> get allRoles => _user?['all_roles'] ?? [];
  String get schoolName => _school?['name'] ?? 'Nepal School Hub';
  String? get userPhoto => _user?['photo'];

  // Role & Permission Checks
  bool hasRole(String role) {
    if (adminRole.toLowerCase() == role.toLowerCase()) return true;
    return allRoles.any((r) => r.toString().toLowerCase() == role.toLowerCase());
  }

  bool can(String permissionName) {
    if (isSuperOrAdmin) return true; // SuperAdmin & Principal have full bypass
    return _permissions.contains(permissionName);
  }

  bool get isSuperOrAdmin =>
      hasRole('super-admin') || hasRole('admin') || hasRole('principal') || hasRole('organization-owner');
  bool get isAccountant => hasRole('accountant') || hasRole('saas-billing');
  bool get isCoordinator => hasRole('academic-coordinator') || hasRole('vice-principal');
  bool get isHrManager => hasRole('hr-manager');
  bool get isExamController => hasRole('exam-controller') || isSuperOrAdmin;
  bool get isHostelManager => hasRole('hostel-manager') || hasRole('hostel-warden') || isSuperOrAdmin;
  bool get isTransportManager => hasRole('transport-manager') || isSuperOrAdmin;
  bool get isLibrarian => hasRole('librarian') || isSuperOrAdmin;
  bool get canManageRbac => isSuperOrAdmin || can('manage permissions');

  Future<void> checkSession() async {
    await _api.init();
    if (_api.isAuthenticated) {
      _user = await _api.getSavedUser();
      _school = await _api.getSavedSchool();
      if (_user?['permissions'] != null) {
        _permissions = List<String>.from(_user!['permissions']);
      }
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.login(email, password);

    _isLoading = false;
    if (res.success && res.data != null) {
      _user = res.data!['user'];
      _school = res.data!['school'];
      if (_user?['permissions'] != null) {
        _permissions = List<String>.from(_user!['permissions']);
      }
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _user = null;
    _school = null;
    notifyListeners();
  }

  void setActiveSchool(Map<String, dynamic> school) {
    _school = school;
    notifyListeners();
  }
}
