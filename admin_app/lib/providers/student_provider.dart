import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StudentProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isSearching = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<dynamic> _students = [];
  Map<String, dynamic>? _selectedStudent;
  bool _isLoadingDetails = false;

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalEnrolled = 0;
  int _totalFiltered = 0;
  bool _hasMore = false;

  String _currentQuery = '';
  int? _selectedClassId;
  int? _selectedSectionId;

  List<dynamic> _classes = [];
  bool _isLoadingClasses = false;

  bool get isSearching => _isSearching;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingDetails => _isLoadingDetails;
  String? get errorMessage => _errorMessage;
  List<dynamic> get students => _students;
  Map<String, dynamic>? get selectedStudent => _selectedStudent;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalEnrolled => _totalEnrolled;
  int get totalFiltered => _totalFiltered;
  bool get hasMore => _hasMore;
  List<dynamic> get classes => _classes;
  int? get selectedClassId => _selectedClassId;
  int? get selectedSectionId => _selectedSectionId;

  Future<void> fetchClasses() async {
    _isLoadingClasses = true;
    final res = await _api.getStudentClasses();
    _isLoadingClasses = false;
    if (res.success && res.data != null) {
      _classes = res.data!;
      notifyListeners();
    }
  }

  Future<void> search(String query, {int? classId, int? sectionId, bool reset = true}) async {
    if (reset) {
      _currentPage = 1;
      _students = [];
      _isSearching = true;
      _errorMessage = null;
      _currentQuery = query;
      _selectedClassId = classId;
      _selectedSectionId = sectionId;
      notifyListeners();
    } else {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    final res = await _api.getStudentsDirectory(
      query: _currentQuery,
      classId: _selectedClassId,
      sectionId: _selectedSectionId,
      page: _currentPage,
      perPage: 30,
    );

    _isSearching = false;
    _isLoadingMore = false;

    if (res.success && res.data != null) {
      final data = res.data!;
      final newStudents = (data['data'] as List<dynamic>?) ?? [];
      final pagination = (data['pagination'] as Map<String, dynamic>?) ?? {};

      _totalEnrolled = data['total_enrolled'] ?? 0;
      _totalFiltered = data['total'] ?? 0;
      _totalPages = pagination['total_pages'] ?? 1;
      _hasMore = pagination['has_more'] ?? false;

      if (reset) {
        _students = newStudents;
      } else {
        _students.addAll(newStudents);
      }
      _errorMessage = null;
    } else {
      _errorMessage = res.message;
      if (reset) _students = [];
    }

    notifyListeners();
  }

  Future<void> loadNextPage() async {
    if (_hasMore && !_isLoadingMore && !_isSearching) {
      _currentPage++;
      await search(_currentQuery, classId: _selectedClassId, sectionId: _selectedSectionId, reset: false);
    }
  }

  Future<void> loadStudentDetails(int id) async {
    _isLoadingDetails = true;
    _selectedStudent = null;
    notifyListeners();

    final res = await _api.getStudentDetails(id);
    _isLoadingDetails = false;

    if (res.success && res.data != null) {
      _selectedStudent = res.data!;
    }
    notifyListeners();
  }

  Future<ApiResponse<dynamic>> createStudent({
    required String firstName,
    required String lastName,
    String? email,
    required String gender,
    String? phone,
    String? birthday,
    String? bloodType,
    String? address,
    required int classId,
    int? sectionId,
    String? rollNo,
    String? admissionNo,
    required String fatherName,
    required String fatherPhone,
    String? motherName,
    String? motherPhone,
    String? password,
  }) async {
    final res = await _api.createStudent(
      firstName: firstName,
      lastName: lastName,
      email: email,
      gender: gender,
      phone: phone,
      birthday: birthday,
      bloodType: bloodType,
      address: address,
      classId: classId,
      sectionId: sectionId,
      rollNo: rollNo,
      admissionNo: admissionNo,
      fatherName: fatherName,
      fatherPhone: fatherPhone,
      motherName: motherName,
      motherPhone: motherPhone,
      password: password,
    );

    if (res.success) {
      // Refresh directory
      await search(_currentQuery, classId: _selectedClassId, sectionId: _selectedSectionId, reset: true);
    }

    return res;
  }
}
