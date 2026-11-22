import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TeacherFormScreen extends StatefulWidget {
  final Map<String, dynamic>? teacher;

  const TeacherFormScreen({Key? key, this.teacher}) : super(key: key);

  /// Convenient helper to open the form and await result
  static Future<bool?> open(BuildContext context, {Map<String, dynamic>? teacher}) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherFormScreen(teacher: teacher),
      ),
    );
  }

  @override
  State<TeacherFormScreen> createState() => _TeacherFormScreenState();
}

class _TeacherFormScreenState extends State<TeacherFormScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  bool get _isEdit => widget.teacher != null;
  bool _isLoadingOptions = true;
  bool _isSaving = false;

  // Uploaded photo storage
  Uint8List? _pickedImageBytes;
  String? _pickedImageBase64;

  // Options from backend
  List<dynamic> _classesOptions = [];
  List<dynamic> _subjectsOptions = [];
  List<dynamic> _contractTypesOptions = [];
  List<dynamic> _qualificationTypesOptions = [];

  // Form Controllers
  // 1. Identity & Contact
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _photoUrlCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _zipCtrl;
  late TextEditingController _birthdayCtrl;
  late TextEditingController _passwordCtrl;

  // 2. Subject & Assignment
  late TextEditingController _primarySubjectCtrl;
  int? _selectedClassId;
  int? _selectedSectionId;
  int? _selectedCourseId;
  bool _isClassTeacher = false;

  // 3. Qualifications
  String _qualificationType = 'degree';
  late TextEditingController _qualTitleCtrl;
  late TextEditingController _institutionCtrl;
  late TextEditingController _fieldOfStudyCtrl;
  late TextEditingController _qualYearCtrl;
  late TextEditingController _qualGradeCtrl;

  // 4. Contract & Compensation
  String _contractType = 'permanent';
  late TextEditingController _positionCtrl;
  late TextEditingController _basicSalaryCtrl;
  late TextEditingController _panNoCtrl;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _bankAccountNoCtrl;

  String _gender = 'Male';
  String _bloodType = 'O+';

  @override
  void initState() {
    super.initState();
    final t = widget.teacher ?? {};

    // Initialize Identity & Contact
    _firstNameCtrl = TextEditingController(text: t['first_name'] ?? '');
    _lastNameCtrl = TextEditingController(text: t['last_name'] ?? '');
    _emailCtrl = TextEditingController(text: t['email'] ?? '');
    _phoneCtrl = TextEditingController(text: t['phone'] ?? '');
    _photoUrlCtrl = TextEditingController(text: t['photo_url'] ?? t['photo'] ?? '');
    _addressCtrl = TextEditingController(text: t['address'] ?? '');
    _cityCtrl = TextEditingController(text: t['city'] ?? 'Kathmandu');
    _zipCtrl = TextEditingController(text: t['zip'] ?? '');

    // Format birthday cleanly (strip ISO8601 timestamp suffix if present)
    String initialBirthday = (t['birthday'] ?? '').toString();
    if (initialBirthday.contains('T')) {
      initialBirthday = initialBirthday.split('T').first;
    }
    _birthdayCtrl = TextEditingController(text: initialBirthday);
    _passwordCtrl = TextEditingController(text: _isEdit ? '' : 'password123');

    // Initialize Gender & Blood Type
    _gender = (t['gender'] == 'Female' || t['gender'] == 'Other') ? t['gender'] : 'Male';
    _bloodType = t['blood_type'] ?? 'O+';
    if (!['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].contains(_bloodType)) {
      _bloodType = 'O+';
    }

    // Initialize Subject & Assignment
    final assigned = (t['assigned_classes'] as List<dynamic>?) ?? [];
    if (assigned.isNotEmpty) {
      final firstAssigned = assigned.first as Map<String, dynamic>;
      _selectedClassId = firstAssigned['class_id'] as int?;
      _selectedSectionId = firstAssigned['section_id'] as int?;
      _selectedCourseId = firstAssigned['course_id'] as int?;
      _isClassTeacher = firstAssigned['is_class_teacher'] == true;
    } else {
      _isClassTeacher = t['is_class_teacher'] == true;
    }
    _primarySubjectCtrl = TextEditingController(text: t['primary_subject'] ?? t['position'] ?? '');

    // Initialize Qualifications
    final primQual = (t['primary_qualification'] as Map<String, dynamic>?) ??
        ((t['qualifications'] is List && (t['qualifications'] as List).isNotEmpty)
            ? (t['qualifications'] as List).first as Map<String, dynamic>
            : null);
    _qualificationType = primQual?['type'] ?? 'degree';
    _qualTitleCtrl = TextEditingController(text: primQual?['title'] ?? t['qualification'] ?? '');
    _institutionCtrl = TextEditingController(text: primQual?['institution'] ?? '');
    _fieldOfStudyCtrl = TextEditingController(text: primQual?['field_of_study'] ?? '');
    _qualYearCtrl = TextEditingController(text: primQual?['end_year']?.toString() ?? '');
    _qualGradeCtrl = TextEditingController(text: primQual?['grade'] ?? '');

    // Initialize Contract & Salary
    _contractType = t['contract_type'] ?? 'permanent';
    _positionCtrl = TextEditingController(text: t['position'] ?? 'Faculty');
    _basicSalaryCtrl = TextEditingController(text: t['basic_salary'] != null ? t['basic_salary'].toString() : '');
    _panNoCtrl = TextEditingController(text: t['pan_no'] ?? '');
    _bankNameCtrl = TextEditingController(text: t['bank_name'] ?? '');
    _bankAccountNoCtrl = TextEditingController(text: t['bank_account_no'] ?? '');

    _loadOptions();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _photoUrlCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _zipCtrl.dispose();
    _birthdayCtrl.dispose();
    _passwordCtrl.dispose();
    _primarySubjectCtrl.dispose();
    _qualTitleCtrl.dispose();
    _institutionCtrl.dispose();
    _fieldOfStudyCtrl.dispose();
    _qualYearCtrl.dispose();
    _qualGradeCtrl.dispose();
    _positionCtrl.dispose();
    _basicSalaryCtrl.dispose();
    _panNoCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() => _isLoadingOptions = true);
    final res = await _api.getTeacherOptions();
    setState(() {
      _isLoadingOptions = false;
      if (res.success && res.data != null) {
        final d = res.data as Map<String, dynamic>;
        _classesOptions = (d['classes'] as List<dynamic>?) ?? [];
        _subjectsOptions = (d['subjects'] as List<dynamic>?) ?? [];
        _contractTypesOptions = (d['contract_types'] as List<dynamic>?) ?? [];
        _qualificationTypesOptions = (d['qualification_types'] as List<dynamic>?) ?? [];
      }
    });
  }

  Future<void> _pickBirthday() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 25));
    if (_birthdayCtrl.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_birthdayCtrl.text);
      if (parsed != null) initial = parsed;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() => _birthdayCtrl.text = '$y-$m-$d');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _pickedImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Profile Photo',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.royalBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppTheme.royalBlue),
                  ),
                  title: const Text('Take a Photo (Camera)', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppTheme.emerald),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _resolvePreviewPhoto() {
    final raw = _photoUrlCtrl.text.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final base = _api.baseUrl.replaceAll(RegExp(r'/api(/.*)?$'), '');
    return '$base/storage/${raw.replaceFirst(RegExp(r'^/?storage/'), '').replaceFirst(RegExp(r'^/'), '')}';
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct validation errors before saving.'),
          backgroundColor: AppTheme.crimson,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final photoValue = _pickedImageBase64 ?? (_photoUrlCtrl.text.trim().isNotEmpty ? _photoUrlCtrl.text.trim() : null);

    final payload = <String, dynamic>{
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim().toLowerCase(),
      'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      'gender': _gender,
      'birthday': _birthdayCtrl.text.trim().isNotEmpty ? _birthdayCtrl.text.trim() : null,
      'blood_type': _bloodType,
      'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      'city': _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : null,
      'zip': _zipCtrl.text.trim().isNotEmpty ? _zipCtrl.text.trim() : null,
      'photo': photoValue,
      'photo_url': _pickedImageBase64 != null ? null : (_photoUrlCtrl.text.trim().isNotEmpty ? _photoUrlCtrl.text.trim() : null),

      // Employment & Contract
      'contract_type': _contractType,
      'position': _positionCtrl.text.trim().isNotEmpty ? _positionCtrl.text.trim() : 'Faculty',
      'basic_salary': _basicSalaryCtrl.text.trim().isNotEmpty ? double.tryParse(_basicSalaryCtrl.text.trim()) : null,
      'pan_no': _panNoCtrl.text.trim().isNotEmpty ? _panNoCtrl.text.trim() : null,
      'bank_name': _bankNameCtrl.text.trim().isNotEmpty ? _bankNameCtrl.text.trim() : null,
      'bank_account_no': _bankAccountNoCtrl.text.trim().isNotEmpty ? _bankAccountNoCtrl.text.trim() : null,

      // Qualifications
      'qualification_type': _qualificationType,
      'qualification_title': _qualTitleCtrl.text.trim().isNotEmpty ? _qualTitleCtrl.text.trim() : null,
      'institution': _institutionCtrl.text.trim().isNotEmpty ? _institutionCtrl.text.trim() : null,
      'field_of_study': _fieldOfStudyCtrl.text.trim().isNotEmpty ? _fieldOfStudyCtrl.text.trim() : null,
      'qualification_year': _qualYearCtrl.text.trim().isNotEmpty ? int.tryParse(_qualYearCtrl.text.trim()) : null,
      'qualification_grade': _qualGradeCtrl.text.trim().isNotEmpty ? _qualGradeCtrl.text.trim() : null,

      // Subject Specialization & Class Assignment
      'primary_subject': _primarySubjectCtrl.text.trim().isNotEmpty ? _primarySubjectCtrl.text.trim() : null,
      'class_id': _selectedClassId,
      'section_id': _selectedSectionId,
      'course_id': _selectedCourseId,
      'is_class_teacher': _isClassTeacher,
    };

    if (_passwordCtrl.text.trim().isNotEmpty) {
      payload['password'] = _passwordCtrl.text.trim();
    }

    final ApiResponse res;
    if (_isEdit) {
      final teacherId = widget.teacher!['id'] as int;
      res = await _api.updateTeacher(teacherId, payload);
    } else {
      res = await _api.createTeacher(payload);
    }

    setState(() => _isSaving = false);

    if (res.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppTheme.emerald,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current class object for section/course cascade
    final selectedClassObj = _classesOptions.firstWhere(
      (c) => c['id'] == _selectedClassId,
      orElse: () => null,
    );
    final sections = (selectedClassObj?['sections'] as List<dynamic>?) ?? [];
    final courses = (selectedClassObj?['courses'] as List<dynamic>?) ?? [];

    final previewPhoto = _resolvePreviewPhoto();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Teacher Profile' : 'Add New Teacher',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              onPressed: _isSaving ? null : _handleSave,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_isEdit ? Icons.save_rounded : Icons.person_add_rounded, color: Colors.white),
              label: Text(
                _isSaving
                    ? 'Saving Teacher...'
                    : (_isEdit ? 'Update Teacher Profile' : 'Confirm & Create Teacher'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
              ),
              onPressed: _isSaving ? null : _handleSave,
            ),
          ),
        ),
      ),
      body: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------------------------------------------------------
                    // SECTION 1: Identity & Photo
                    // ---------------------------------------------------------
                    _buildCard(
                      title: 'FACULTY IDENTITY & PHOTO',
                      icon: Icons.badge_rounded,
                      children: [
                        // Avatar Row with Interactive Photo Upload
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _showImageSourceDialog,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 38,
                                    backgroundColor: AppTheme.royalBlue.withOpacity(0.12),
                                    backgroundImage: _pickedImageBytes != null
                                        ? MemoryImage(_pickedImageBytes!)
                                        : (previewPhoto != null ? NetworkImage(previewPhoto) : null) as ImageProvider?,
                                    child: (_pickedImageBytes == null && previewPhoto == null)
                                        ? Text(
                                            _firstNameCtrl.text.isNotEmpty
                                                ? _firstNameCtrl.text[0].toUpperCase()
                                                : 'T',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.royalBlue,
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.royalBlue,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Profile Photo',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _showImageSourceDialog,
                                        icon: const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.white),
                                        label: Text(
                                          _pickedImageBytes != null ? 'Change Photo' : 'Upload Photo',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.royalBlue,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                      ),
                                      if (_pickedImageBytes != null || _photoUrlCtrl.text.isNotEmpty)
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _pickedImageBytes = null;
                                              _pickedImageBase64 = null;
                                              _photoUrlCtrl.clear();
                                            });
                                          },
                                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.crimson),
                                          label: const Text('Remove', style: TextStyle(color: AppTheme.crimson, fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppTheme.crimson),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (_pickedImageBytes != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.emerald),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Photo selected for upload',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
                            title: const Text(
                              'Or enter image URL manually',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                            ),
                            children: [
                              TextFormField(
                                controller: _photoUrlCtrl,
                                decoration: InputDecoration(
                                  hintText: 'https://... image link or photo URL',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  suffixIcon: _photoUrlCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () {
                                            _photoUrlCtrl.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // First Name & Last Name
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameCtrl,
                                decoration: const InputDecoration(labelText: 'First Name *', isDense: true),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameCtrl,
                                decoration: const InputDecoration(labelText: 'Last Name *', isDense: true),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Gender, Blood Group & Birthday
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _gender,
                                decoration: const InputDecoration(labelText: 'Gender *', isDense: true),
                                items: ['Male', 'Female', 'Other']
                                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                    .toList(),
                                onChanged: (val) => setState(() => _gender = val ?? 'Male'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _bloodType,
                                decoration: const InputDecoration(labelText: 'Blood Group', isDense: true),
                                items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                    .toList(),
                                onChanged: (val) => setState(() => _bloodType = val ?? 'O+'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _birthdayCtrl,
                          readOnly: true,
                          onTap: _pickBirthday,
                          decoration: InputDecoration(
                            labelText: 'Date of Birth (YYYY-MM-DD)',
                            isDense: true,
                            prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_month_rounded, size: 20, color: AppTheme.royalBlue),
                              onPressed: _pickBirthday,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ---------------------------------------------------------
                    // SECTION 2: Contact & Location
                    // ---------------------------------------------------------
                    _buildCard(
                      title: 'CONTACT & RESIDENCE',
                      icon: Icons.contact_mail_rounded,
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Official / Login Email *',
                            isDense: true,
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email is required';
                            if (!v.contains('@')) return 'Invalid email address';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Contact Phone Number',
                            isDense: true,
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _addressCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Residential Street / Tole',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _cityCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'City / District',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ---------------------------------------------------------
                    // SECTION 3: Subject & Class Assignment
                    // ---------------------------------------------------------
                    _buildCard(
                      title: 'TEACHING SUBJECT & CLASS ASSIGNMENT',
                      icon: Icons.school_rounded,
                      children: [
                        TextFormField(
                          controller: _primarySubjectCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Primary Subject / Discipline (e.g. Mathematics, Science)',
                            isDense: true,
                            prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),

                        (() {
                          final uniqueClasses = <int, Map<String, dynamic>>{};
                          for (final c in _classesOptions) {
                            if (c is Map && c['id'] != null) {
                              uniqueClasses[c['id'] as int] = Map<String, dynamic>.from(c);
                            }
                          }
                          final items = uniqueClasses.values.map<DropdownMenuItem<int>>((c) {
                            return DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text(c['class_name'] ?? 'Class'),
                            );
                          }).toList();
                          final safeVal = uniqueClasses.containsKey(_selectedClassId) ? _selectedClassId : null;

                          return DropdownButtonFormField<int>(
                            value: safeVal,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Assigned Class / Grade', isDense: true),
                            hint: const Text('Select Class'),
                            items: items,
                            onChanged: (val) {
                              setState(() {
                                _selectedClassId = val;
                                _selectedSectionId = null;
                                _selectedCourseId = null;
                              });
                            },
                          );
                        })(),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: (() {
                                final uniqueSecs = <int, Map<String, dynamic>>{};
                                for (final s in sections) {
                                  if (s is Map && s['id'] != null) {
                                    uniqueSecs[s['id'] as int] = Map<String, dynamic>.from(s);
                                  }
                                }
                                final items = uniqueSecs.values.map<DropdownMenuItem<int>>((s) {
                                  return DropdownMenuItem<int>(
                                    value: s['id'] as int,
                                    child: Text(s['section_name'] ?? 'Sec'),
                                  );
                                }).toList();
                                final safeVal = uniqueSecs.containsKey(_selectedSectionId) ? _selectedSectionId : null;

                                return DropdownButtonFormField<int>(
                                  value: safeVal,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Section', isDense: true),
                                  hint: const Text('Section'),
                                  items: items,
                                  onChanged: (val) => setState(() => _selectedSectionId = val),
                                );
                              })(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: (() {
                                final uniqueCourses = <int, Map<String, dynamic>>{};
                                for (final co in courses) {
                                  if (co is Map && co['id'] != null) {
                                    uniqueCourses[co['id'] as int] = Map<String, dynamic>.from(co);
                                  }
                                }
                                final items = uniqueCourses.values.map<DropdownMenuItem<int>>((co) {
                                  return DropdownMenuItem<int>(
                                    value: co['id'] as int,
                                    child: Text(co['course_name'] ?? 'Subject'),
                                  );
                                }).toList();
                                final safeVal = uniqueCourses.containsKey(_selectedCourseId) ? _selectedCourseId : null;

                                return DropdownButtonFormField<int>(
                                  value: safeVal,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Assigned Course', isDense: true),
                                  hint: const Text('Course / Subject'),
                                  items: items,
                                  onChanged: (val) => setState(() => _selectedCourseId = val),
                                );
                              })(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Designate as Section Class Teacher',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Authorizes teacher for daily roll calls and terminal mark sheet sign-offs',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: _isClassTeacher,
                          activeColor: AppTheme.emerald,
                          onChanged: (_selectedClassId != null && _selectedSectionId != null)
                              ? (v) => setState(() => _isClassTeacher = v)
                              : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ---------------------------------------------------------
                    // SECTION 4: Qualifications & Education
                    // ---------------------------------------------------------
                    _buildCard(
                      title: 'ACADEMIC QUALIFICATIONS & DEGREE',
                      icon: Icons.history_edu_rounded,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: ['degree', 'diploma', 'certification', 'training', 'other'].contains(_qualificationType)
                                    ? _qualificationType
                                    : 'degree',
                                decoration: const InputDecoration(labelText: 'Level / Type', isDense: true),
                                items: const [
                                  DropdownMenuItem(value: 'degree', child: Text('Degree (Bachelors / Masters / PhD)')),
                                  DropdownMenuItem(value: 'diploma', child: Text('Diploma')),
                                  DropdownMenuItem(value: 'certification', child: Text('Certification')),
                                  DropdownMenuItem(value: 'training', child: Text('Training')),
                                  DropdownMenuItem(value: 'other', child: Text('Other')),
                                ],
                                onChanged: (val) => setState(() => _qualificationType = val ?? 'degree'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _qualTitleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Highest Degree Title (e.g. Master of Education, M.Sc Physics, B.Ed)',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _institutionCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'University / Board (e.g. Tribhuvan University)',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _fieldOfStudyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Major / Field',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qualYearCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Passing Year (e.g. 2021)',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _qualGradeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Division / Grade (e.g. 1st Div)',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ---------------------------------------------------------
                    // SECTION 5: Employment, Contract & Compensation
                    // ---------------------------------------------------------
                    _buildCard(
                      title: 'EMPLOYMENT, CONTRACT & COMPENSATION',
                      icon: Icons.payments_rounded,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: ['permanent', 'temporary', 'part_time', 'visiting', 'probation'].contains(_contractType)
                                    ? _contractType
                                    : 'permanent',
                                decoration: const InputDecoration(labelText: 'Contract Type *', isDense: true),
                                items: const [
                                  DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                                  DropdownMenuItem(value: 'probation', child: Text('Probation')),
                                  DropdownMenuItem(value: 'temporary', child: Text('Temporary / Fixed-term')),
                                  DropdownMenuItem(value: 'part_time', child: Text('Part-Time')),
                                  DropdownMenuItem(value: 'visiting', child: Text('Visiting Faculty')),
                                ],
                                onChanged: (val) => setState(() => _contractType = val ?? 'permanent'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _basicSalaryCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Monthly Basic Salary (NPR)',
                                  isDense: true,
                                  prefixText: 'Rs. ',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _positionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Official Designation (e.g. Senior Secondary Teacher)',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _panNoCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'PAN Number',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _bankNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Name',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _bankAccountNoCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Bank Account Number',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ---------------------------------------------------------
                    // SECTION 6: Security & Credentials
                    // ---------------------------------------------------------
                    _buildCard(
                      title: 'PORTAL LOGIN & SECURITY',
                      icon: Icons.lock_outline_rounded,
                      children: [
                        TextFormField(
                          controller: _passwordCtrl,
                          decoration: InputDecoration(
                            labelText: _isEdit
                                ? 'New Password (leave empty to keep current password)'
                                : 'Initial Account Password *',
                            isDense: true,
                            prefixIcon: const Icon(Icons.key_rounded, size: 20),
                          ),
                          validator: (v) {
                            if (!_isEdit && (v == null || v.length < 6)) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.royalBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.royalBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.royalBlue,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
