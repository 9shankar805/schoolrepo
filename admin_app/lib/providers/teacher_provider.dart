import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TeacherProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> teachers = [];
  List<dynamic> classes = [];

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  int _page = 1;
  int totalPages = 1;
  bool get hasMore => _page < totalPages;

  String searchQuery = '';
  String filterStatus = 'all'; // all | present | absent

  // ---------------------------------------------------------------------------
  // Teacher list fetching
  // ---------------------------------------------------------------------------

  Future<void> fetchTeachers({bool reset = true}) async {
    if (reset) {
      _page = 1;
      teachers = [];
    }
    isLoading = reset;
    error = null;
    notifyListeners();

    final res = await _api.getTeachers(
      query: searchQuery.isNotEmpty ? searchQuery : null,
      status: filterStatus != 'all' ? filterStatus : null,
    );

    isLoading = false;

    if (res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      final List<dynamic> incoming = (data['data'] as List<dynamic>?) ?? [];

      if (reset) {
        teachers = incoming;
      } else {
        teachers = [...teachers, ...incoming];
      }

      final pagination = data['pagination'] as Map<String, dynamic>?;
      if (pagination != null) {
        totalPages = pagination['last_page'] ?? 1;
      } else {
        totalPages = 1;
      }
    } else {
      error = res.message;
    }

    notifyListeners();
  }

  Future<void> loadNextPage() async {
    if (!hasMore || isLoadingMore) return;

    _page++;
    isLoadingMore = true;
    notifyListeners();

    final res = await _api.getTeachers(
      query: searchQuery.isNotEmpty ? searchQuery : null,
      status: filterStatus != 'all' ? filterStatus : null,
    );

    isLoadingMore = false;

    if (res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      final List<dynamic> incoming = (data['data'] as List<dynamic>?) ?? [];
      teachers = [...teachers, ...incoming];
    }

    notifyListeners();
  }

  void setSearch(String query) {
    searchQuery = query;
    fetchTeachers();
  }

  void setFilterStatus(String status) {
    filterStatus = status;
    fetchTeachers();
  }

  // ---------------------------------------------------------------------------
  // Classes
  // ---------------------------------------------------------------------------

  Future<void> fetchClasses() async {
    final res = await _api.getClasses();
    if (res.success && res.data != null) {
      classes = res.data as List<dynamic>;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Future<bool> createTeacher(Map<String, dynamic> data) async {
    final res = await _api.createTeacher(data);
    if (res.success) {
      await fetchTeachers();
      return true;
    }
    error = res.message;
    notifyListeners();
    return false;
  }

  Future<bool> updateTeacher(int id, Map<String, dynamic> data) async {
    final res = await _api.updateTeacher(id, data);
    if (res.success) {
      await fetchTeachers();
      return true;
    }
    error = res.message;
    notifyListeners();
    return false;
  }

  Future<bool> deleteTeacher(int id) async {
    final res = await _api.deleteTeacher(id);
    if (res.success) {
      await fetchTeachers();
      return true;
    }
    error = res.message;
    notifyListeners();
    return false;
  }

  Future<bool> assignClass(int teacherId, Map<String, dynamic> data) async {
    final res = await _api.assignTeacherClass(teacherId, data);
    if (res.success) {
      await fetchTeachers();
      return true;
    }
    error = res.message;
    notifyListeners();
    return false;
  }
}
