import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    required this.statusCode,
  });
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Target endpoint defaults
  static const String liveProductionUrl = 'https://nshlms.com/api/admin-app';
  static const String fallbackLiveUrl = 'https://nepalschoolhub.techprocod.com.np/api/admin-app';
  static const String localLanUrl = 'http://192.168.1.70:8000/api/admin-app';
  static const String androidEmulatorUrl = 'http://10.0.2.2:8000/api/admin-app';
  static const String localhostUrl = 'http://127.0.0.1:8000/api/admin-app';

  static const String _tokenKey = 'admin_auth_token';
  static const String _userDataKey = 'admin_user_data';
  static const String _schoolDataKey = 'admin_school_data';
  static const String _serverUrlKey = 'admin_server_url';

  String _baseUrl = liveProductionUrl;
  String? _token;

  
  static dynamic safeJson(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>((k, v) => MapEntry(k.toString(), safeJson(v)));
    } else if (value is List) {
      return value.map((v) => safeJson(v)).toList();
    }
    return value;
  }

  static dynamic _parseJson(dynamic source) {
    if (source == null) return null;
    try {
      final decoded = source is String ? jsonDecode(source) : source;
      return safeJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> safeMap(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>((k, v) => MapEntry(k.toString(), safeJson(v)));
    }
    return <String, dynamic>{};
  }

  String get baseUrl => _baseUrl;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    // Locked to official live production cloud endpoint
    _baseUrl = liveProductionUrl;
    await prefs.setString(_serverUrlKey, liveProductionUrl);
  }

  Future<void> setCustomBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }

  Map<String, String> _headers({bool withAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // ---------------------------------------------------------------------------
  // 1. Authentication
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: _headers(withAuth: false),
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'device_name': 'flutter-admin-mobile',
        }),
      );

      final dynamic decoded = _parseJson(response.body);
      final Map<String, dynamic> body = decoded is Map ? safeMap(decoded) : <String, dynamic>{};

      if (response.statusCode == 200 && body['status'] == 'success') {
        _token = body['token'];
        final prefs = await SharedPreferences.getInstance();
        if (_token != null) {
          await prefs.setString(_tokenKey, _token!);
        }
        if (body['user'] != null) {
          await prefs.setString(_userDataKey, jsonEncode(body['user']));
        }
        if (body['school'] != null) {
          await prefs.setString(_schoolDataKey, jsonEncode(body['school']));
        }

        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Login successful',
          data: body,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? (body['errors'] != null ? body['errors'].toString() : 'Login failed'),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network connection failed: $e',
        statusCode: 500,
      );
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: _headers(withAuth: true),
        );
      }
    } catch (_) {}
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_schoolDataKey);
  }

  Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_userDataKey);
    if (str != null) {
      try {
        final decoded = _parseJson(str);
        if (decoded is Map) {
          return safeMap(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> getSavedSchool() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_schoolDataKey);
    if (str != null) {
      try {
        final decoded = _parseJson(str);
        if (decoded is Map) {
          return safeMap(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. Executive Dashboard Overview
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getDashboardOverview() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/dashboard/overview'),
        headers: _headers(withAuth: true),
      );

      final dynamic decoded = _parseJson(response.body);
      final Map<String, dynamic> body = decoded is Map ? safeMap(decoded) : <String, dynamic>{};
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] is Map ? safeMap(body['data']) : null,
          statusCode: response.statusCode,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load dashboard overview',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error connecting to server: $e',
        statusCode: 500,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Approvals Queue (Leaves, Expenses, Admissions)
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getApprovals() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/approvals'),
        headers: _headers(withAuth: true),
      );

      final dynamic decoded = _parseJson(response.body);
      final Map<String, dynamic> body = decoded is Map ? safeMap(decoded) : <String, dynamic>{};
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body,
          statusCode: response.statusCode,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load approvals',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: $e',
        statusCode: 500,
      );
    }
  }

  Future<ApiResponse<dynamic>> handleLeave(int id, String action, {String? notes}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/approvals/leave/$id'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'action': action,
          'reviewer_notes': notes,
        }),
      );
      final body = _parseJson(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Leave updated',
        data: body['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> handleExpense(int id, String action, {String? notes}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/approvals/expense/$id'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'action': action,
          'notes': notes,
        }),
      );
      final body = _parseJson(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Expense updated',
        data: body['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> handleAdmission(int id, String action, {String? notes}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/approvals/admission/$id'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'action': action,
          'reviewer_notes': notes,
        }),
      );
      final body = _parseJson(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Admission updated',
        data: body['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Student Directory & 360° Profile
  // ---------------------------------------------------------------------------
  Future<ApiResponse<List<dynamic>>> searchStudents(String query, {int? classId}) async {
    try {
      final uri = Uri.parse('$_baseUrl/students/search').replace(queryParameters: {
        'q': query,
        if (classId != null) 'class_id': classId.toString(),
      });
      final response = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as List<dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getStudentsDirectory({
    String? query,
    int? classId,
    int? sectionId,
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (query != null && query.isNotEmpty) params['q'] = query;
      if (classId != null) params['class_id'] = classId.toString();
      if (sectionId != null) params['section_id'] = sectionId.toString();

      final uri = Uri.parse('$_baseUrl/students/search').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getStudentClasses() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/students/classes'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as List<dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
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
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/students'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          if (email != null && email.isNotEmpty) 'email': email,
          'gender': gender,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (birthday != null && birthday.isNotEmpty) 'birthday': birthday,
          if (bloodType != null && bloodType.isNotEmpty) 'blood_type': bloodType,
          if (address != null && address.isNotEmpty) 'address': address,
          'class_id': classId,
          if (sectionId != null) 'section_id': sectionId,
          if (rollNo != null && rollNo.isNotEmpty) 'roll_no': rollNo,
          if (admissionNo != null && admissionNo.isNotEmpty) 'admission_no': admissionNo,
          'father_name': fatherName,
          'father_phone': fatherPhone,
          if (motherName != null && motherName.isNotEmpty) 'mother_name': motherName,
          if (motherPhone != null && motherPhone.isNotEmpty) 'mother_phone': motherPhone,
          if (password != null && password.isNotEmpty) 'password': password,
        }),
      );
      final body = _parseJson(response.body);
      return ApiResponse(
        success: response.statusCode == 201 && body['status'] == 'success',
        message: body['message'] ?? 'Student enrolled successfully',
        data: body['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> updateStudent(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/students/$id'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Student updated',
        data: body['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> deleteStudent(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/students/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Student archived',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getStudentDetails(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/students/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'],
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 5. Staff & Substitution
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getStaffOverview() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/staff/overview'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body,
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 5b. Teacher Management & Class Assignments (CRUD)
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getTeachers({String? query, String? status, int? classId}) async {
    try {
      final params = <String, String>{};
      if (query != null && query.isNotEmpty) params['q'] = query;
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (classId != null) params['class_id'] = classId.toString();

      final uri = Uri.parse('$_baseUrl/teachers').replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body,
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load teachers', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getTeacherOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/teachers/options'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: (body['data'] is Map<String, dynamic>) ? body['data'] as Map<String, dynamic> : body,
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load options', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getTeacherDetails(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/teachers/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: (body['data'] is Map<String, dynamic>) ? body['data'] as Map<String, dynamic> : body,
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load teacher details', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createTeacher(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/teachers'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Teacher created successfully',
          data: (body['data'] is Map<String, dynamic>) ? body['data'] as Map<String, dynamic> : body,
          statusCode: response.statusCode,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? (body['errors'] != null ? body['errors'].toString() : 'Failed to create teacher'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateTeacher(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/teachers/$id'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Teacher profile updated',
          data: (body['data'] is Map<String, dynamic>) ? body['data'] as Map<String, dynamic> : body,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? (body['errors'] != null ? body['errors'].toString() : 'Failed to update teacher'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> deleteTeacher(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/teachers/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? (response.statusCode == 200 ? 'Teacher removed' : 'Failed to delete teacher'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> assignTeacherClass(int teacherId, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/teachers/$teacherId/assign-class'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Class assigned successfully',
          data: body,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to assign class',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> removeTeacherAssignment(int teacherId, int assignmentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/teachers/$teacherId/assignments/$assignmentId'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Assignment removed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 6. Finance & Dues
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getFinanceOverview() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/finance/overview'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body,
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> sendFeeReminder({int? classId, String? message}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/finance/send-reminder'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'class_id': classId,
          'message': message,
        }),
      );
      final body = _parseJson(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Reminder sent',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 7. Broadcast & Notices
  // ---------------------------------------------------------------------------
  Future<ApiResponse<List<dynamic>>> getNotices() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/broadcast/notices'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as List<dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> sendBroadcast({
    required String title,
    required String message,
    required String targetGroup,
    bool isEmergency = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/broadcast/send'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'title': title,
          'message': message,
          'target_group': targetGroup,
          'is_emergency': isEmergency,
        }),
      );
      final body = _parseJson(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Broadcast sent',
        data: body['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 8. Gate QR Scanner Verification
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> verifyGateQr(String qrData, {String gateType = 'entry'}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/gate/verify-qr'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'qr_data': qrData,
          'gate_type': gateType,
        }),
      );
      final body = _parseJson(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Badge verified',
          data: body['user'],
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Verification failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 9. Academics, Routines & Exams / Timetable Maker Suite
  // ---------------------------------------------------------------------------
  Future<ApiResponse<List<dynamic>>> getClasses() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/academic/classes'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getRoutineConfig() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/academic/routine-config'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load routine configuration', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getRoutines({
    int? classId,
    int? sectionId,
    int? weekday,
    int? teacherId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (classId != null) queryParams['class_id'] = classId.toString();
      if (sectionId != null) queryParams['section_id'] = sectionId.toString();
      if (weekday != null) queryParams['weekday'] = weekday.toString();
      if (teacherId != null) queryParams['teacher_id'] = teacherId.toString();

      final uri = Uri.parse('$_baseUrl/academic/routines').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createRoutine(
    Map<String, dynamic> data, {
    bool forceOverride = false,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      if (forceOverride) payload['force_override'] = true;
      final res = await http.post(
        Uri.parse('$_baseUrl/academic/routines'),
        headers: _headers(withAuth: true),
        body: jsonEncode(payload),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Slot created successfully',
          data: body['data'] is Map<String, dynamic> ? body['data'] : body,
          statusCode: res.statusCode,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to save routine slot',
        data: body is Map<String, dynamic> ? body : null,
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateRoutine(
    int id,
    Map<String, dynamic> data, {
    bool forceOverride = false,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      if (forceOverride) payload['force_override'] = true;
      final res = await http.put(
        Uri.parse('$_baseUrl/academic/routines/$id'),
        headers: _headers(withAuth: true),
        body: jsonEncode(payload),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200) {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Slot updated successfully',
          data: body['data'] is Map<String, dynamic> ? body['data'] : body,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to update routine slot',
        data: body is Map<String, dynamic> ? body : null,
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> deleteRoutine(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/academic/routines/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200) {
        return ApiResponse(success: true, message: body['message'] ?? 'Deleted successfully', statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error deleting slot', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> cloneSectionRoutine({
    required int sourceClassId,
    required int sourceSectionId,
    required int targetClassId,
    required int targetSectionId,
    bool replaceExisting = true,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/academic/routines/clone-section'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'source_class_id': sourceClassId,
          'source_section_id': sourceSectionId,
          'target_class_id': targetClassId,
          'target_section_id': targetSectionId,
          'replace_existing': replaceExisting,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Cloned successfully', data: body['count'], statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to clone routine', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> generatePeriodSchedule(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/academic/routines/generate-periods'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Schedule generated successfully', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error generating period schedule', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getTeacherTimetable(int teacherId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/academic/teacher-timetable?teacher_id=$teacherId'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error fetching teacher timetable', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getExams() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/academic/exams'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> toggleResultLock(bool publish) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/academic/toggle-results'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'publish': publish}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Result lock updated',
        data: body['results_published'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 10. Operations: Hostel, Library, Inventory, Audit Logs & AI
  // ---------------------------------------------------------------------------
  Future<ApiResponse<List<dynamic>>> getHostelOverview() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/operations/hostel'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getLibraryOverview() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/operations/library'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getInventoryOverview() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/operations/inventory'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getAuditLogs() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/operations/audit-logs'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<String>> sendAiPrompt(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/operations/ai-chat'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'prompt': prompt}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(success: true, message: 'Success', data: body['reply'] ?? '', statusCode: 200);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 11. RBAC: Roles & Permissions Governance
  // ---------------------------------------------------------------------------
  Future<ApiResponse<List<dynamic>>> getRoles() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/rbac/roles'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getPermissions() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/rbac/permissions'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getStaffUsers({String query = ''}) async {
    try {
      final uri = Uri.parse('$_baseUrl/rbac/users').replace(queryParameters: {'q': query});
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> assignUserRoles(int userId, List<String> roles) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/rbac/assign-role'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'user_id': userId, 'roles': roles}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Role updated',
        data: body['user'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> updateRolePermissions(int roleId, List<String> permissions) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/rbac/update-role-permissions'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'role_id': roleId, 'permissions': permissions}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Permissions updated',
        data: body['role'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 12. Academic Coordinator Operational Controls
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getCoordinatorSubstitutions() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/coordinator/substitutions'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> assignSubstitute(int routineId, int substituteTeacherId, {String? notes}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/coordinator/substitute'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'routine_id': routineId,
          'substitute_teacher_id': substituteTeacherId,
          'notes': notes,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Substitute assigned',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getQuestionPapers() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/coordinator/question-papers'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Error', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> reviewQuestionPaper(int id, String action, {String? notes}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/coordinator/question-papers/$id/review'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'action': action, 'notes': notes}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Review recorded',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> toggleMarksWindow(bool open) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/coordinator/toggle-marks-window'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'open': open}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Marks window updated',
        data: body['marks_window_open'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 12. Hostel Manager API
  // ---------------------------------------------------------------------------

  Future<ApiResponse<List<dynamic>>> getCoordinatorSyllabi() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/coordinator/syllabi'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: (body['data'] as List<dynamic>?) ?? [],
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load syllabi',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getHostelManagerOverview() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/hostel-manager/overview'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load hostel overview', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getHostelAvailableSlots() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/hostel-manager/available-slots'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] ?? [], statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load slots', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> allocateHostelBed({
    required int studentId,
    required int hostelRoomId,
    required int hostelBedId,
    String? startDate,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hostel-manager/allocate'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'student_id': studentId,
          'hostel_room_id': hostelRoomId,
          'hostel_bed_id': hostelBedId,
          if (startDate != null) 'start_date': startDate,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Student allocated to hostel bed',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> vacateHostelBed(int allocationId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hostel-manager/vacate/$allocationId'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Bed vacated successfully',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> createHostelRoom({
    required String roomNumber,
    required int capacity,
    String roomType = 'Non-AC',
    double costPerBed = 0,
    String? description,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hostel-manager/rooms'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'room_number': roomNumber,
          'capacity': capacity,
          'room_type': roomType,
          'cost_per_bed': costPerBed,
          'description': description,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Room created successfully',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getHostelRollCall() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/hostel-manager/roll-call'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] ?? [], statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load roll call', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> saveHostelRollCall(List<Map<String, dynamic>> records) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hostel-manager/roll-call'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'records': records}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Roll call recorded',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getHostelVisitors() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/hostel-manager/visitors'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] ?? [], statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load visitors', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> recordHostelVisitor({
    required int studentId,
    required String visitorName,
    required String relation,
    String? purpose,
    String? inTime,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hostel-manager/visitors'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'student_id': studentId,
          'visitor_name': visitorName,
          'relation': relation,
          'purpose': purpose,
          'in_time': inTime,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Visitor recorded successfully',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 13. Accountant Dedicated Operations API
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getAccountantDashboard() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/accountant/dashboard'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load accountant dashboard', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAccountantVouchers({String status = 'all'}) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/accountant/vouchers?status=$status'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load vouchers', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> createAccountantVoucher({
    required String title,
    required String category,
    required double amount,
    String? vendor,
    String? vendorInvoiceNo,
    String paymentMethod = 'Cash',
    String? expenseDate,
    String? notes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/accountant/vouchers'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'title': title,
          'category': category,
          'amount': amount,
          'vendor': vendor,
          'vendor_invoice_no': vendorInvoiceNo,
          'payment_method': paymentMethod,
          if (expenseDate != null) 'expense_date': expenseDate,
          'notes': notes,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Voucher created',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> approveAccountantVoucher(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/accountant/vouchers/$id/approve'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Voucher approved',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> rejectAccountantVoucher(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/accountant/vouchers/$id/reject'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Voucher rejected',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAccountantPaymentProofs({String status = 'all'}) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/accountant/payment-proofs?status=$status'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load proofs', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> approveAccountantPaymentProof(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/accountant/payment-proofs/$id/approve'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Proof approved and credited',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> rejectAccountantPaymentProof(int id, {required String reason}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/accountant/payment-proofs/$id/reject'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'reason': reason}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Proof rejected',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getStudentLedger(int studentId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/accountant/student-ledger/$studentId'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load student ledger', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> collectFee({
    required int studentId,
    required double amount,
    required String paymentMethod,
    int? invoiceId,
    String? reference,
    String? notes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/accountant/collect-fee'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'student_id': studentId,
          'amount': amount,
          'payment_method': paymentMethod,
          if (invoiceId != null) 'invoice_id': invoiceId,
          if (reference != null) 'reference': reference,
          if (notes != null) 'notes': notes,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Fee payment recorded',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAccountantInventory() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/accountant/inventory'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load inventory', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 14. Transport & Fleet Manager API
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getTransportDashboard() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/transport/dashboard'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load transport dashboard', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getTransportVehicles({String status = 'all'}) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/transport/vehicles?status=$status'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] ?? [], statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load vehicles', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> createTransportVehicle({
    required String name,
    required String registrationNumber,
    required int capacity,
    String type = 'bus',
    String? make,
    String? model,
    String fuelType = 'Diesel',
    String? insuranceExpiry,
    String? fitnessExpiry,
    String? notes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/transport/vehicles'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'name': name,
          'registration_number': registrationNumber,
          'capacity': capacity,
          'type': type,
          'make': make,
          'model': model,
          'fuel_type': fuelType,
          if (insuranceExpiry != null) 'insurance_expiry': insuranceExpiry,
          if (fitnessExpiry != null) 'fitness_expiry': fitnessExpiry,
          'notes': notes,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Vehicle created',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> updateTransportVehicleStatus(int id, {required String status, String? notes}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/transport/vehicles/$id/status'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'status': status, 'notes': notes}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Status updated',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getTransportRoutes() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/transport/routes'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] ?? [], statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load routes', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getTransportPassengers({int? routeId}) async {
    try {
      final url = routeId != null ? '$_baseUrl/transport/passengers?route_id=$routeId' : '$_baseUrl/transport/passengers';
      final res = await http.get(Uri.parse(url), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] ?? [], statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load passengers', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> assignTransportPassenger({
    required int studentId,
    required int routeId,
    int? stopId,
    String direction = 'both',
    double? monthlyFee,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/transport/assign-passenger'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'student_id': studentId,
          'route_id': routeId,
          if (stopId != null) 'stop_id': stopId,
          'direction': direction,
          if (monthlyFee != null) 'monthly_fee': monthlyFee,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Passenger assigned',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> removeTransportPassenger(int id) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/transport/remove-passenger/$id'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Passenger removed',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getTransportAttendance({String? date, String trip = 'morning', int? routeId}) async {
    try {
      var url = '$_baseUrl/transport/attendance?trip=$trip';
      if (date != null) url += '&date=$date';
      if (routeId != null) url += '&route_id=$routeId';

      final res = await http.get(Uri.parse(url), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] ?? [], statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load attendance', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> saveTransportAttendance({
    required String trip,
    String? date,
    required List<Map<String, dynamic>> records,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/transport/attendance'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'trip': trip,
          if (date != null) 'date': date,
          'records': records,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Attendance saved',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getTransportFuelLogs() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/transport/fuel-logs'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] ?? [], statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load fuel logs', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> createTransportFuelLog({
    required int vehicleId,
    required double litres,
    required double costPerLitre,
    int? odometerReading,
    String? fuelStation,
    String? notes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/transport/fuel-logs'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'vehicle_id': vehicleId,
          'litres': litres,
          'cost_per_litre': costPerLitre,
          if (odometerReading != null) 'odometer_reading': odometerReading,
          if (fuelStation != null) 'fuel_station': fuelStation,
          if (notes != null) 'notes': notes,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Fuel log saved',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ==========================================
  // EXAM CONTROLLER SUITE METHODS
  // ==========================================

  Future<ApiResponse<Map<String, dynamic>>> getExamDashboard() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/exam-controller/dashboard'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load exam dashboard',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getExamMarksProgress({int? classId, int? examId}) async {
    try {
      final params = <String, String>{};
      if (classId != null) params['class_id'] = classId.toString();
      if (examId != null) params['exam_id'] = examId.toString();

      final uri = Uri.parse('$_baseUrl/exam-controller/marks-progress').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );

      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load marks submission progress',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> toggleExamMarksWindow(bool open) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/exam-controller/toggle-marks-window'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'open': open}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Marks window status updated',
        data: body,
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> sendExamMarkReminder({int? teacherId, int? courseId, String? message}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/exam-controller/send-mark-reminder'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          if (teacherId != null) 'teacher_id': teacherId,
          if (courseId != null) 'course_id': courseId,
          if (message != null) 'message': message,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Reminder sent successfully',
        data: body,
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getExamAdmitCards({int? classId, String? search}) async {
    try {
      final params = <String, String>{};
      if (classId != null) params['class_id'] = classId.toString();
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse('$_baseUrl/exam-controller/admit-cards').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );

      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load admit cards',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> toggleAdmitCardLock(int studentId, {String? reason}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/exam-controller/admit-cards/$studentId/toggle-lock'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          if (reason != null) 'reason': reason,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Admit card status updated',
        data: body,
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> toggleExamResults(bool publish) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/exam-controller/toggle-results'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'publish': publish}),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Exam results visibility updated',
        data: body,
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getExamGradeDistribution({int? examId}) async {
    try {
      final params = <String, String>{};
      if (examId != null) params['exam_id'] = examId.toString();

      final uri = Uri.parse('$_baseUrl/exam-controller/grade-distribution').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );

      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load grade distribution',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ==========================================
  // LIBRARIAN SUITE METHODS
  // ==========================================

  Future<ApiResponse<Map<String, dynamic>>> getLibrarianDashboard() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/librarian/dashboard'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load library dashboard',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getLibrarianBooks({String? search, String? availability}) async {
    try {
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (availability != null && availability.isNotEmpty) params['availability'] = availability;

      final uri = Uri.parse('$_baseUrl/librarian/books').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );

      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load books catalog',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> createLibrarianBook({
    required String title,
    required String author,
    String? isbn,
    String? shelfLocation,
    required int qty,
    String? publisher,
    double? price,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/librarian/books'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'title': title,
          'author': author,
          if (isbn != null) 'isbn': isbn,
          if (shelfLocation != null) 'shelf_location': shelfLocation,
          'qty': qty,
          if (publisher != null) 'publisher': publisher,
          if (price != null) 'price': price,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 201 && body['status'] == 'success',
        message: body['message'] ?? 'Book created successfully',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getLibrarianCirculation({String? status, String? search}) async {
    try {
      final params = <String, String>{};
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse('$_baseUrl/librarian/circulation').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );

      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load circulation records',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> issueLibrarianBook({
    required int bookId,
    required int memberId,
    int? loanDays,
    double? finePerDay,
    String? notes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/librarian/issue'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'book_id': bookId,
          'member_id': memberId,
          if (loanDays != null) 'loan_days': loanDays,
          if (finePerDay != null) 'fine_per_day': finePerDay,
          if (notes != null) 'notes': notes,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 201 && body['status'] == 'success',
        message: body['message'] ?? 'Book issued successfully',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> returnLibrarianBook(int issueId, {String? notes, bool? collectFineNow}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/librarian/return/$issueId'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          if (notes != null) 'notes': notes,
          if (collectFineNow != null) 'collect_fine_now': collectFineNow,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Book returned successfully',
        data: body,
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> collectLibrarianFine(int issueId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/librarian/collect-fine/$issueId'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Fine collected successfully',
        data: body,
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getLibrarianMembers({String? search}) async {
    try {
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse('$_baseUrl/librarian/members').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );

      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load library members',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 16. Front Desk & Campus Visitor Management (Safety & Reception)
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getVisitors({
    String status = 'all',
    String? search,
    String? date,
  }) async {
    try {
      final params = <String, String>{'status': status};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (date != null && date.isNotEmpty) params['date'] = date;

      final uri = Uri.parse('$_baseUrl/visitors').replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load visitors', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> checkInVisitor(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/visitors/check-in'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Visitor checked in',
          data: body['data'] is Map<String, dynamic> ? body['data'] : body,
          statusCode: res.statusCode,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to check in visitor',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> checkOutVisitor(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/visitors/$id/check-out'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Checked out successfully',
          data: body['data'] is Map<String, dynamic> ? body['data'] : body,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to check out visitor',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getEmergencyRollCall() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/visitors/emergency-roll-call'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load emergency roll call',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getVisitorDetails(int id) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/visitors/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load visitor details',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> deleteVisitor(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/visitors/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Record removed', statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to remove visitor',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 17. Student Pastoral Care, Discipline & Merit Tracking
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getDisciplineOverview() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/discipline/overview'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as Map<String, dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load discipline overview',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getDisciplinaryIncidents({
    String? severity,
    String? status,
    int? classId,
    int? studentId,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (severity != null && severity != 'all') queryParams['severity'] = severity;
      if (status != null && status != 'all') queryParams['status'] = status;
      if (classId != null) queryParams['class_id'] = classId.toString();
      if (studentId != null) queryParams['student_id'] = studentId.toString();
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final uri = Uri.parse('$_baseUrl/discipline/incidents').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as List<dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load incidents',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createDisciplinaryIncident(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/discipline/incidents'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Incident logged successfully',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: res.statusCode,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to log incident',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateDisciplinaryIncident(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/discipline/incidents/$id'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Incident updated successfully',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to update incident',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> signOffDisciplinaryIncident(
    int id, {
    String? executiveNotes,
    String? actionTaken,
    bool? markResolved,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/discipline/incidents/$id/sign-off'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          if (executiveNotes != null) 'executive_notes': executiveNotes,
          if (actionTaken != null) 'action_taken': actionTaken,
          if (markResolved != null) 'mark_resolved': markResolved,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Executive sign-off recorded',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to record sign-off',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> toggleResolveIncident(int id, {bool? resolved}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/discipline/incidents/$id/resolve'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          if (resolved != null) 'resolved': resolved,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Status updated',
          data: body,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to update resolution status',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> deleteDisciplinaryIncident(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/discipline/incidents/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Incident deleted', statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to delete incident',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // Achievements & Commendations
  Future<ApiResponse<List<dynamic>>> getAchievements({
    String? category,
    String? level,
    int? studentId,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category != null && category != 'all') queryParams['category'] = category;
      if (level != null && level != 'all') queryParams['level'] = level;
      if (studentId != null) queryParams['student_id'] = studentId.toString();
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final uri = Uri.parse('$_baseUrl/discipline/achievements').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as List<dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load achievements',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createAchievement(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/discipline/achievements'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Commendation awarded successfully',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: res.statusCode,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to award commendation',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> deleteAchievement(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/discipline/achievements/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Commendation removed', statusCode: 200);
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to remove commendation',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getAchievementLeaderboard({String? category}) async {
    try {
      final uri = Uri.parse('$_baseUrl/discipline/achievements/leaderboard').replace(
        queryParameters: category != null && category != 'all' ? {'category': category} : null,
      );
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as List<dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load leaderboard',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // Student Attendance Tracking & Class Roll-Call
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getAttendanceOverview({String? date}) async {
    try {
      final uri = Uri.parse('$_baseUrl/attendance/overview').replace(
        queryParameters: date != null ? {'date': date} : null,
      );
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load attendance overview',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAttendanceSheet({
    required int classId,
    required int sectionId,
    String? date,
  }) async {
    try {
      final params = <String, String>{
        'class_id': classId.toString(),
        'section_id': sectionId.toString(),
      };
      if (date != null) params['date'] = date;

      final uri = Uri.parse('$_baseUrl/attendance/sheet').replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load attendance sheet',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> saveAttendance({
    required int classId,
    required int sectionId,
    required String date,
    required List<Map<String, dynamic>> attendance,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/attendance/save'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'class_id': classId,
          'section_id': sectionId,
          'date': date,
          'attendance': attendance,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Attendance recorded successfully',
          data: body as Map<String, dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to save attendance',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> quickMarkAttendance({
    required int classId,
    required int sectionId,
    required String date,
    required String status,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/attendance/quick-mark'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'class_id': classId,
          'section_id': sectionId,
          'date': date,
          'status': status,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Quick mark completed',
          data: body as Map<String, dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to quick mark',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // Executive Notifications & Push Alerts Center
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getNotifications({String? type}) async {
    try {
      final uri = Uri.parse('$_baseUrl/notifications').replace(
        queryParameters: type != null && type != 'all' ? {'type': type} : null,
      );
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load notifications',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/notifications/unread-count'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return (body['unread_count'] as int?) ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<ApiResponse<dynamic>> markNotificationRead(String id) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/notifications/$id/read'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Marked as read',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> markAllNotificationsRead() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/notifications/mark-all-read'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'All marked as read',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> deleteNotification(String id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/notifications/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Notification removed',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> registerPushToken(
    String token, {
    String platform = 'android',
    String? deviceName,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/notifications/register-token'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'token': token,
          'platform': platform,
          'device_name': deviceName,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Token registered',
        data: body['data'] is Map<String, dynamic> ? body['data'] : body,
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 19. Institutional Academic Calendar & Event Planner
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getEventsOverview() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/events/overview'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load events overview', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getEvents({
    int? month,
    int? year,
    String? category,
    bool? isHoliday,
    String? audience,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();
      if (category != null && category != 'all') queryParams['category'] = category;
      if (isHoliday == true) queryParams['is_holiday'] = '1';
      if (audience != null && audience != 'all') queryParams['audience'] = audience;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final uri = Uri.parse('$_baseUrl/events').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load events', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createEvent(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/events'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Event created', data: body['data'] as Map<String, dynamic>?, statusCode: res.statusCode);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to create event', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateEvent(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/events/$id'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Event updated', data: body['data'] as Map<String, dynamic>?, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to update event', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> deleteEvent(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/events/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Event deleted', statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to delete event', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 20. Staff HR, Contracts & Payroll Overview
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getPayrollOverview({int? month, int? year}) async {
    try {
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      final uri = Uri.parse('$_baseUrl/hr/payroll/overview').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load payroll overview', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getPayrollSlips({
    int? month,
    int? year,
    String? status,
    String? type,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();
      if (status != null && status != 'all') queryParams['status'] = status;
      if (type != null && type != 'all') queryParams['type'] = type;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final uri = Uri.parse('$_baseUrl/hr/payroll/slips').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load payroll slips', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> markPayrollPaid(
    int id,
    String type, {
    String? paymentMethod,
    String? paymentDate,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hr/payroll/mark-paid'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'id': id,
          'type': type,
          if (paymentMethod != null) 'payment_method': paymentMethod,
          if (paymentDate != null) 'payment_date': paymentDate,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Marked as paid', statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to update payment status', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getStaffContracts({
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status != 'all') queryParams['status'] = status;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final uri = Uri.parse('$_baseUrl/hr/contracts').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load contracts', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> createStaffContract(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hr/contracts'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Contract registered', statusCode: res.statusCode);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to register contract', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getStaffTrainings({
    String? type,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (type != null && type != 'all') queryParams['type'] = type;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final uri = Uri.parse('$_baseUrl/hr/trainings').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load trainings', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> createStaffTraining(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hr/trainings'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Training recorded', statusCode: res.statusCode);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to record training', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 21. Official Certificates & Document Issuance Center
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getCertificatesOverview() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/certificates/overview'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load certificates overview', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getTransferCertificates({
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status != 'all') queryParams['status'] = status;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final uri = Uri.parse('$_baseUrl/certificates/transfers').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load transfers', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> approveTransferCertificate(
    int id, {
    String status = 'approved',
    String? notes,
    String? tcNumber,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/certificates/transfers/$id/approve'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'status': status,
          if (notes != null) 'notes': notes,
          if (tcNumber != null) 'tc_number': tcNumber,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Action completed', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to approve transfer', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> quickIssueTransferCertificate(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/certificates/transfers/quick-issue'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'TC issued', data: body as Map<String, dynamic>?, statusCode: res.statusCode);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to issue TC', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getIssuedCertificates({
    String? type,
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (type != null && type != 'all') queryParams['type'] = type;
      if (status != null && status != 'all') queryParams['status'] = status;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final uri = Uri.parse('$_baseUrl/certificates/issued').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load issued certificates', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getCertificateTemplates() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/certificates/templates'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load templates', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> generateCertificate(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/certificates/generate'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Certificate generated', data: body as Map<String, dynamic>?, statusCode: res.statusCode);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to generate certificate', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> revokeCertificate(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/certificates/issued/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Certificate revoked', statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to revoke certificate', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // School Settings, Branding & Payment QR Configuration
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getSchoolSettings() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/school'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load school settings',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateSchoolSettings(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/school'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Settings updated successfully',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to update settings',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getSchoolSessions() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/school/sessions'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load sessions',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createSchoolSession(String sessionName, {bool setAsActive = false}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/school/sessions'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'session_name': sessionName,
          'set_as_active': setAsActive,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 201 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Academic session created',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 201,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to create session',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> switchSchoolSession(int sessionId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/school/switch-session'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'session_id': sessionId}),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Session switched',
          data: body['current'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to switch session',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // Admissions Management & Enrollment Pipeline
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getAdmissions({
    String? status,
    int? classId,
    String? search,
    int page = 1,
  }) async {
    try {
      final qp = <String, String>{
        'page': page.toString(),
        if (status != null && status != 'all') 'status': status,
        if (classId != null) 'class_id': classId.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse('$_baseUrl/admissions').replace(queryParameters: qp.isNotEmpty ? qp : null);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load admissions',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAdmissionDetails(int id) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/admissions/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load admission details',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateAdmissionStatus(
    int id,
    String status, {
    String? reviewerNotes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/admissions/$id/status'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'status': status,
          if (reviewerNotes != null) 'reviewer_notes': reviewerNotes,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Status updated',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to update status',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> enrollAdmission(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/admissions/$id/enroll'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 201 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Student enrolled successfully',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 201,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to enroll student',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 22. Campus Infirmary & Medical Health Records
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getHealthOverview() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/health/overview'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load health overview', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getSickBayRoster({String? status, String? search}) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status != 'all') queryParams['status'] = status;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final uri = Uri.parse('$_baseUrl/health/sick-bay').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load sick bay roster', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> checkInSickBay(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/health/sick-bay/check-in'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Student admitted', data: body['data'] as Map<String, dynamic>?, statusCode: res.statusCode);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to check in student', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> dischargeSickBay(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/health/sick-bay/$id/discharge'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Student discharged', statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to discharge student', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> notifySickBayGuardian(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/health/sick-bay/$id/notify-guardian'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Guardian notified', statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to log notification', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getCriticalHealthAlerts() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/health/critical-alerts'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load critical alerts', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getStudentMedicalRecord(int studentId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/health/student/$studentId'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load medical record', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 23. Academic Syllabus Coverage & Homework Radar
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getSyllabusProgress({int? classId}) async {
    try {
      final queryParams = <String, String>{};
      if (classId != null) queryParams['class_id'] = classId.toString();

      final uri = Uri.parse('$_baseUrl/academics/syllabus-progress').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load syllabus progress', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getHomeworkRadar({String? date, int? classId}) async {
    try {
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date;
      if (classId != null) queryParams['class_id'] = classId.toString();

      final uri = Uri.parse('$_baseUrl/academics/homework-radar').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load homework radar', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> createHomework(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/academics/homework'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Homework created', statusCode: res.statusCode);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to create homework', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getLessonPlans({String? status, int? teacherId}) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status != 'all') queryParams['status'] = status;
      if (teacherId != null) queryParams['teacher_id'] = teacherId.toString();

      final uri = Uri.parse('$_baseUrl/academics/lesson-plans').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load lesson plans', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> verifyLessonPlan(int id, {required String status, String? notes}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/academics/lesson-plans/$id/verify'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'status': status,
          if (notes != null) 'notes': notes,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Plan status updated', statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to update plan status', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 24. Multi-Campus / Branch Switcher
  // ---------------------------------------------------------------------------
  Future<ApiResponse<List<dynamic>>> getAvailableSchools() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/auth/schools'), headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body['data'] as List<dynamic>, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load schools', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // New: Fee Structures, Payroll, HR Leaves, Notices, Notifications extras
  // ---------------------------------------------------------------------------

  // Fee Structures
  Future<ApiResponse<Map<String, dynamic>>> getFeeStructures() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/finance/fee-structures'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load fee structures', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> createFeeStructure(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/finance/fee-structures'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: (res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success',
        message: body['message'] ?? 'Fee structure created',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> updateFeeStructure(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/finance/fee-structures/$id'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Fee structure updated',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> deleteFeeStructure(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/finance/fee-structures/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Fee structure deleted',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // HR Leaves
  Future<ApiResponse<Map<String, dynamic>>> getHrLeaveApplications({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final uri = Uri.parse('$_baseUrl/hr/leaves').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: 'Success', data: body, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load leave applications', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getLeaveTypes() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/hr/leave-types'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as List<dynamic>? ?? [],
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load leave types', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> reviewHrLeave(int id, String action, {String? notes}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hr/leaves/$id/review'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'action': action,
          if (notes != null) 'notes': notes,
        }),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Leave reviewed',
        data: body['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // Notice creation
  Future<ApiResponse<dynamic>> createNotice({
    required String title,
    required String body,
    required String audience,
    String priority = 'normal',
    String? publishDate,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/broadcast/notices'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'title': title,
          'body': body,
          'audience': audience,
          'priority': priority,
          if (publishDate != null) 'publish_date': publishDate,
        }),
      );
      final respBody = _parseJson(res.body);
      return ApiResponse(
        success: (res.statusCode == 200 || res.statusCode == 201) && respBody['status'] == 'success',
        message: respBody['message'] ?? 'Notice created',
        data: respBody['data'],
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }


  Future<ApiResponse<Map<String, dynamic>>> switchActiveSchool(int schoolId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/switch-school'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'school_id': schoolId}),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(success: true, message: body['message'] ?? 'Branch switched', data: body['school'] as Map<String, dynamic>?, statusCode: 200);
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to switch campus', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // Student Promotion & Academic Year-End Progression
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getPromotionOptions() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/promotions/options'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load promotion options',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getPromotionSheet({
    required int sessionId,
    required int classId,
    int? sectionId,
  }) async {
    try {
      final qp = <String, String>{
        'session_id': sessionId.toString(),
        'class_id': classId.toString(),
        if (sectionId != null) 'section_id': sectionId.toString(),
      };
      final uri = Uri.parse('$_baseUrl/promotions/sheet').replace(queryParameters: qp);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load promotion sheet',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> promoteStudents(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/promotions/promote'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Students promoted successfully',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to execute progression',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // Student ID Card Studio, Digital Badges & QR Security Passes
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getIdCardStudents({
    int? classId,
    int? sectionId,
    int? sessionId,
    String? search,
  }) async {
    try {
      final qp = <String, String>{
        if (classId != null) 'class_id': classId.toString(),
        if (sectionId != null) 'section_id': sectionId.toString(),
        if (sessionId != null) 'session_id': sessionId.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };
      final uri = Uri.parse('$_baseUrl/id-cards/students').replace(queryParameters: qp.isNotEmpty ? qp : null);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load ID cards',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getIdCardDetails(int studentId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/id-cards/card/$studentId'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['card'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load ID card details',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> bulkGenerateIdCards({
    required int classId,
    int? sectionId,
    int? sessionId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/id-cards/bulk-generate'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'class_id': classId,
          if (sectionId != null) 'section_id': sectionId,
          if (sessionId != null) 'session_id': sessionId,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'ID cards generated',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to generate ID cards',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getIdCardTemplates() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/id-cards/templates'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['templates'] as List<dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load templates',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // HR / Staff Leave Management
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getStaffLeaves({
    String? status,
    String? role,
    String? search,
    int? leaveTypeId,
    int? year,
    int page = 1,
  }) async {
    try {
      final qp = <String, String>{
        if (status != null && status != 'all') 'status': status,
        if (role != null && role != 'all') 'role': role,
        if (search != null && search.isNotEmpty) 'search': search,
        if (leaveTypeId != null) 'leave_type_id': leaveTypeId.toString(),
        if (year != null) 'year': year.toString(),
        'page': page.toString(),
      };
      final uri = Uri.parse('$_baseUrl/hr/leaves').replace(queryParameters: qp.isNotEmpty ? qp : null);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load staff leaves',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getStaffLeaveOptions() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/hr/leaves/options'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load leave options',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getStaffLeaveDetails(int id, {int? year}) async {
    try {
      final qp = <String, String>{
        if (year != null) 'year': year.toString(),
      };
      final uri = Uri.parse('$_baseUrl/hr/leaves/$id').replace(queryParameters: qp.isNotEmpty ? qp : null);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['leave'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load leave details',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> handleStaffLeave(
    int id, {
    required String action,
    String? reviewerNotes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hr/leaves/$id/action'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          'action': action,
          if (reviewerNotes != null) 'reviewer_notes': reviewerNotes,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Leave application processed',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to process leave application',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createStaffLeave(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/hr/leaves'),
        headers: _headers(withAuth: true),
        body: jsonEncode(data),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Leave recorded successfully',
          data: body as Map<String, dynamic>?,
          statusCode: res.statusCode,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to record leave',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<void>> deleteStaffLeave(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/hr/leaves/$id'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && body['status'] == 'success',
        message: body['message'] ?? 'Leave deleted',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // Executive Analytics & Institutional Reports
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getAnalyticsOverview() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/analytics/overview'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load executive analytics',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAttendanceReport({
    required String dateFrom,
    required String dateTo,
    int? classId,
    int? sectionId,
    String type = 'students',
  }) async {
    try {
      final qp = <String, String>{
        'date_from': dateFrom,
        'date_to': dateTo,
        'type': type,
        if (classId != null) 'class_id': classId.toString(),
        if (sectionId != null) 'section_id': sectionId.toString(),
      };
      final uri = Uri.parse('$_baseUrl/reports/attendance').replace(queryParameters: qp);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load attendance report',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getFinanceReport({
    String? dateFrom,
    String? dateTo,
    String? paymentMethod,
  }) async {
    try {
      final qp = <String, String>{
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        if (paymentMethod != null && paymentMethod != 'all') 'payment_method': paymentMethod,
      };
      final uri = Uri.parse('$_baseUrl/reports/finance').replace(queryParameters: qp.isNotEmpty ? qp : null);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load finance report',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAcademicsReport({
    int? sessionId,
    int? examId,
    int? classId,
    int? sectionId,
  }) async {
    try {
      final qp = <String, String>{
        if (sessionId != null) 'session_id': sessionId.toString(),
        if (examId != null) 'exam_id': examId.toString(),
        if (classId != null) 'class_id': classId.toString(),
        if (sectionId != null) 'section_id': sectionId.toString(),
      };
      final uri = Uri.parse('$_baseUrl/reports/academics').replace(queryParameters: qp.isNotEmpty ? qp : null);
      final res = await http.get(uri, headers: _headers(withAuth: true));
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load academics report',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getReportOptions() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/reports/options'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to load report options',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> exportReport(Map<String, dynamic> params) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/reports/export'),
        headers: _headers(withAuth: true),
        body: jsonEncode(params),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Report exported',
          data: body as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Failed to export report',
        statusCode: res.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  // ---------------------------------------------------------------------------
  // 25. Crisis Alert & Emergency Lockdown SOS Protocol
  // ---------------------------------------------------------------------------
  Future<ApiResponse<Map<String, dynamic>>> getCrisisStatus() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/crisis/status'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load crisis status', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getCrisisTemplates() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/crisis/templates'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as List<dynamic>? ?? [],
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load templates', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> dispatchCrisisSos(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/crisis/dispatch'),
        headers: _headers(withAuth: true),
        body: jsonEncode(payload),
      );
      final body = _parseJson(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'SOS broadcast dispatched',
          data: body['data'] as Map<String, dynamic>?,
          statusCode: res.statusCode,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to dispatch SOS', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<dynamic>> declareCrisisAllClear({String? notes}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/crisis/all-clear'),
        headers: _headers(withAuth: true),
        body: jsonEncode({
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        }),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Crisis marked as resolved',
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to resolve crisis', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

  Future<ApiResponse<List<dynamic>>> getCrisisHistory() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/crisis/history'),
        headers: _headers(withAuth: true),
      );
      final body = _parseJson(res.body);
      if (res.statusCode == 200 && body['status'] == 'success') {
        return ApiResponse(
          success: true,
          message: 'Success',
          data: body['data'] as List<dynamic>? ?? [],
          statusCode: 200,
        );
      }
      return ApiResponse(success: false, message: body['message'] ?? 'Failed to load history', statusCode: res.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: '$e', statusCode: 500);
    }
  }

}
