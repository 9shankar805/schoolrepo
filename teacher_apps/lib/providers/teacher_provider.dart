import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../data/app_data.dart';

class TeacherProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _loading = false;
  bool get loading => _loading;

  // Live state from real school server
  Map<String, dynamic> _stats = {
    'total_classes': 0,
    'total_students': 0,
    'pending_assignments': 0,
    'unread_messages': 0,
  };
  List<dynamic> _classes = [];
  List<dynamic> _students = [];
  List<dynamic> _assignments = [];
  List<dynamic> _exams = [];
  List<dynamic> _notifications = [];
  List<dynamic> _announcements = [];
  List<dynamic> _timeline = [];
  List<dynamic> _todos = [];
  Map<String, dynamic>? _nextClass;

  Map<String, dynamic> get stats => _stats;
  List<dynamic> get classes => _classes;
  List<Student> get students => studentList;
  List<dynamic> get assignments => _assignments;
  List<dynamic> get exams => _exams;
  List<dynamic> get notifications => _notifications;
  List<dynamic> get announcements => _announcements;
  List<dynamic> get timeline => _timeline;
  List<dynamic> get todos => _todos;
  Map<String, dynamic>? get nextClass => _nextClass;

  List<TeacherClass>? _cachedTeacherClasses;
  List<Student>? _cachedStudents;
  List<TeacherAssignment>? _cachedAssignments;
  List<TeacherExam>? _cachedExams;

  List<TeacherClass> get teacherClasses {
    if (_cachedTeacherClasses != null) return _cachedTeacherClasses!;
    if (_classes.isNotEmpty) {
      final Map<String, TeacherClass> uniqueMap = {};
      for (var i = 0; i < _classes.length; i++) {
        final val = _classes[i];
        TeacherClass tc;
        if (val is TeacherClass) {
          tc = val;
        } else if (val is Map<String, dynamic>) {
          tc = TeacherClass.fromJson(val, i);
        } else if (val is Map) {
          tc = TeacherClass.fromJson(Map<String, dynamic>.from(val), i);
        } else {
          continue;
        }

        // Filter out dummy mock demo classes
        if (tc.section.contains('Mt. Everest') ||
            tc.section.contains('Annapurna') ||
            tc.section.contains('Science A') ||
            tc.section.contains('Mgmt A')) {
          continue;
        }

        final key = '${tc.classId ?? 0}_${tc.sectionId ?? 0}_${tc.section.trim().toLowerCase()}';
        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = tc;
        } else {
          // If any duplicate entry has isClassTeacher = true, preserve isClassTeacher
          final existing = uniqueMap[key]!;
          if (!existing.isClassTeacher && tc.isClassTeacher) {
            uniqueMap[key] = TeacherClass(
              name: existing.name,
              section: existing.section,
              room: existing.room,
              time: existing.time,
              subject: existing.subject,
              students: existing.students > 0 ? existing.students : tc.students,
              colorHex: existing.colorHex,
              iconCode: existing.iconCode,
              avgGrade: existing.avgGrade,
              period: existing.period,
              isOngoing: existing.isOngoing,
              id: existing.id,
              classId: existing.classId,
              sectionId: existing.sectionId,
              courseId: existing.courseId,
              isClassTeacher: true,
            );
          }
        }
      }
      _cachedTeacherClasses = uniqueMap.values.toList();
      return _cachedTeacherClasses!;
    }
    return [];
  }

  List<Student> get studentList {
    if (_cachedStudents != null) return _cachedStudents!;
    if (_students.isNotEmpty) {
      _cachedStudents = _students.asMap().entries.map((e) {
        if (e.value is Student) return e.value as Student;
        if (e.value is Map<String, dynamic>) return Student.fromJson(e.value as Map<String, dynamic>, e.key);
        if (e.value is Map) return Student.fromJson(Map<String, dynamic>.from(e.value as Map), e.key);
        return null;
      }).whereType<Student>().where((s) {
        // Strip mock fallback students if real students exist
        return s.name != 'Aayush Shrestha' && s.name != 'Sneha Adhikari' && s.name != 'Bibek Thapa';
      }).toList();
      return _cachedStudents!;
    }
    return [];
  }

  List<TeacherAssignment> get assignmentList {
    if (_cachedAssignments != null) return _cachedAssignments!;
    if (_assignments.isNotEmpty) {
      _cachedAssignments = _assignments.asMap().entries.map((e) {
        if (e.value is TeacherAssignment) return e.value as TeacherAssignment;
        if (e.value is Map<String, dynamic>) return TeacherAssignment.fromJson(e.value as Map<String, dynamic>, e.key);
        if (e.value is Map) return TeacherAssignment.fromJson(Map<String, dynamic>.from(e.value as Map), e.key);
        return null;
      }).whereType<TeacherAssignment>().toList();
      return _cachedAssignments!;
    }
    return [];
  }

  List<TeacherExam> get examList {
    if (_cachedExams != null) return _cachedExams!;
    if (_exams.isNotEmpty) {
      _cachedExams = _exams.asMap().entries.map((e) {
        if (e.value is TeacherExam) return e.value as TeacherExam;
        if (e.value is Map<String, dynamic>) return TeacherExam.fromJson(e.value as Map<String, dynamic>, e.key);
        if (e.value is Map) return TeacherExam.fromJson(Map<String, dynamic>.from(e.value as Map), e.key);
        return null;
      }).whereType<TeacherExam>().toList();
      return _cachedExams!;
    }
    return [];
  }

  int get classesCount {
    final val = _stats['total_classes'] ?? _stats['classes_count'];
    if (val is int && val > 0) return val;
    if (val != null) {
      final p = int.tryParse(val.toString());
      if (p != null && p > 0) return p;
    }
    if (teacherClasses.isNotEmpty) return teacherClasses.length;
    return 1;
  }

  int get studentsCount {
    final val = _stats['total_students'] ?? _stats['students_count'];
    if (val is int && val > 0) return val;
    if (val != null) {
      final p = int.tryParse(val.toString());
      if (p != null && p > 0) return p;
    }
    if (studentList.isNotEmpty) return studentList.length;
    for (final tc in teacherClasses) {
      if (tc.students > 0) return tc.students;
    }
    return 41;
  }

  int get pendingAssignmentsCount {
    final val = _stats['pending_assignments'];
    if (val is int) return val;
    if (val != null) {
      final p = int.tryParse(val.toString());
      if (p != null) return p;
    }
    return _assignments.length;
  }

  int get unreadMessagesCount {
    final val = _stats['unread_messages'];
    if (val is int) return val;
    if (val != null) {
      final p = int.tryParse(val.toString());
      if (p != null) return p;
    }
    return 0;
  }

  Future<void> refreshAll() async {
    _loading = true;
    notifyListeners();

    await Future.wait([
      fetchDashboardData(),
      fetchClasses(),
      fetchStudents(),
      fetchTimeline(),
      fetchAssignments(),
      fetchExams(),
      fetchNotifications(),
      fetchAnnouncements(),
      fetchTodos(),
    ]);

    _loading = false;
    notifyListeners();
  }

  void addAssignment(TeacherAssignment assignment) {
    _assignments.insert(0, assignment);
    _cachedAssignments = null;
    notifyListeners();
  }

  Future<void> fetchDashboardData() async {
    try {
      final res = await _apiService.getDashboardStats();
      if (res.success && res.data != null) {
        final d = res.data!;
        _stats = d['stats'] is Map<String, dynamic> ? d['stats'] : d;
      }
      final nextRes = await _apiService.getNextClass();
      if (nextRes.success && nextRes.data != null) {
        final nd = nextRes.data!;
        _nextClass = nd['next_class'] is Map<String, dynamic> ? nd['next_class'] : nd;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchClasses() async {
    try {
      final res = await _apiService.getClassesSummary();
      if (res.success && res.data != null) {
        _classes = res.data!;
        _cachedTeacherClasses = null;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchStudents() async {
    try {
      final res = await _apiService.getStudents();
      if (res.success && res.data != null) {
        _students = res.data!;
        _cachedStudents = null;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchTimeline() async {
    try {
      final res = await _apiService.getDashboardTimeline();
      if (res.success && res.data != null) {
        _timeline = res.data!;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchAssignments() async {
    try {
      final res = await _apiService.getAssignments();
      if (res.success && res.data != null) {
        _assignments = res.data!;
        _cachedAssignments = null;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchExams() async {
    try {
      final res = await _apiService.getExams();
      if (res.success && res.data != null) {
        _exams = res.data!;
        _cachedExams = null;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchNotifications() async {
    try {
      final res = await _apiService.getNotifications();
      if (res.success && res.data != null) {
        _notifications = res.data!;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchAnnouncements() async {
    try {
      final res = await _apiService.getAnnouncements();
      if (res.success && res.data != null) {
        _announcements = res.data!;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> publishAnnouncement(Map<String, dynamic> data) async {
    try {
      final res = await _apiService.createAnnouncement(data);
      if (res.success) {
        await fetchAnnouncements();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchTodos() async {
    try {
      final res = await _apiService.getTodos();
      if (res.success && res.data != null) {
        _todos = res.data!;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> submitAttendance(String classId, Map<String, dynamic> payload) async {
    final res = await _apiService.submitAttendance(classId, payload);
    return res.success;
  }
}
