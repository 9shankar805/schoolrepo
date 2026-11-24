import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../data/app_data.dart';
import '../widgets/common_widgets.dart';
import '../providers/teacher_provider.dart';
import '../services/api_service.dart';

class StudentsScreen extends StatefulWidget {
  final String? filterClass;
  const StudentsScreen({super.key, this.filterClass});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedClass = 'All';

  String _normalize(String text) {
    return text
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  List<String> _getClassOptions(TeacherProvider teacher) {
    final opts = <String>['All'];
    if (teacher.teacherClasses.isNotEmpty) {
      for (final c in teacher.teacherClasses) {
        if (!opts.contains(c.section)) opts.add(c.section);
      }
    } else {
      for (final c in AppData.classes) {
        if (!opts.contains(c.section)) opts.add(c.section);
      }
    }
    for (final s in teacher.studentList) {
      final sec = s.displayClassSection;
      if (sec.isNotEmpty && !sec.startsWith('A') && !sec.startsWith('B') && !sec.startsWith('C') && !opts.contains(sec)) {
        opts.add(sec);
      }
    }
    return opts;
  }

  List<Student> _getFiltered(TeacherProvider teacher) {
    List<Student> list = teacher.studentList;

    if (_selectedClass != 'All') {
      final targetNorm = _normalize(_selectedClass);
      list = list.where((s) {
        final secNorm = _normalize(s.displayClassSection);
        final gradeNorm = _normalize(s.grade);
        final cNameNorm = _normalize(s.className ?? '');
        final sNameNorm = _normalize(s.sectionName ?? '');

        // 1. Direct classSection match (e.g. "class 1 - a" == "class 1 - a")
        if (secNorm == targetNorm || secNorm.contains(targetNorm) || targetNorm.contains(secNorm)) {
          return true;
        }

        // 2. Component match (e.g. className = "class 1", sectionName = "a")
        if (cNameNorm.isNotEmpty && targetNorm.contains(cNameNorm)) {
          if (sNameNorm.isEmpty || targetNorm.contains(sNameNorm)) {
            return true;
          }
        }

        // 3. Fallback grade match if grade carries class string
        if (gradeNorm.contains('class') || gradeNorm.contains('grade') || gradeNorm.contains('kg')) {
          if (gradeNorm == targetNorm || gradeNorm.contains(targetNorm) || targetNorm.contains(gradeNorm)) {
            return true;
          }
        }

        return false;
      }).toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase().trim();
      list = list.where((s) =>
          s.name.toLowerCase().contains(q) ||
          s.rollNo.toLowerCase().contains(q) ||
          s.displayClassSection.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Color _gradeColor(String g) {
    if (g.startsWith('A')) return AppTheme.green;
    if (g.startsWith('B')) return AppTheme.blue;
    if (g.startsWith('C')) return AppTheme.orange;
    return AppTheme.red;
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.darkSubtext),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkSubtext),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.filterClass != null) _selectedClass = widget.filterClass!;
  }

  @override
  Widget build(BuildContext context) {
    final teacher = Provider.of<TeacherProvider>(context);
    final classOptions = _getClassOptions(teacher);
    final filtered = _getFiltered(teacher);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        leading: CircleIconButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.pop(context), size: 38),
        leadingWidth: 60,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search students...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.grey),
              filled: true,
              fillColor: isDark ? AppTheme.darkCard : Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: classOptions.length,
            itemBuilder: (_, i) {
              final opt = classOptions[i];
              final sel = opt == _selectedClass;
              return GestureDetector(
                onTap: () => setState(() => _selectedClass = opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: sel ? const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary]) : null,
                    color: sel ? null : (isDark ? AppTheme.darkCard : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(opt, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppTheme.grey)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => teacher.refreshAll(),
            child: filtered.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_search_rounded,
                                size: 44, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _query.isNotEmpty
                                ? 'कुनै विद्यार्थी फेला परेन'
                                : '$_selectedClass मा कुनै विद्यार्थी फेला परेन',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.dark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _query.isNotEmpty
                                ? 'No students matching "$_query"'
                                : 'No students found for $_selectedClass. Pull down to refresh.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return AppCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => StudentDetailScreen(student: s))),
                        child: Row(children: [
                          s.photoUrl != null && s.photoUrl!.isNotEmpty
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: s.photoUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _gradeColor(s.grade).withOpacity(0.2),
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(colors: [
                                          _gradeColor(s.grade),
                                          _gradeColor(s.grade).withOpacity(0.6),
                                        ]),
                                      ),
                                      child: Center(
                                        child: Text(
                                          s.avatar,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [
                                      _gradeColor(s.grade),
                                      _gradeColor(s.grade).withOpacity(0.6),
                                    ]),
                                  ),
                                  child: Center(
                                    child: Text(
                                      s.avatar,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(
                              '${s.displayClassSection} • Roll #${s.rollNo}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.school_outlined, size: 12, color: AppTheme.grey),
                              const SizedBox(width: 4),
                              Text('GPA: ${s.gpa.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.grey)),
                              const SizedBox(width: 10),
                              const Icon(Icons.how_to_reg_outlined, size: 12, color: AppTheme.grey),
                              const SizedBox(width: 4),
                              Text('${(s.attendance * 100).toInt()}%',
                                  style: TextStyle(fontSize: 11,
                                      color: s.attendance >= 0.85 ? AppTheme.green
                                          : s.attendance >= 0.75 ? AppTheme.orange : AppTheme.red)),
                            ]),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            GradeBadge(grade: s.grade),
                            const SizedBox(height: 4),
                            Text('#${s.rank}', style: const TextStyle(
                                fontSize: 11, color: AppTheme.grey)),
                          ]),
                        ]),
                      ).animate().fadeIn(delay: (i * 50).ms);
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

class StudentDetailScreen extends StatelessWidget {
  final Student student;
  const StudentDetailScreen({super.key, required this.student});

  Color _gradeColor(String g) {
    if (g.startsWith('A')) return AppTheme.green;
    if (g.startsWith('B')) return AppTheme.blue;
    if (g.startsWith('C')) return AppTheme.orange;
    return AppTheme.red;
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.darkSubtext),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkSubtext),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditStudentModal(BuildContext context, Student student) {
    final nameCtrl = TextEditingController(text: student.name);
    final rollCtrl = TextEditingController(text: student.rollNo);
    final phoneCtrl = TextEditingController(text: student.phone ?? '');
    final emailCtrl = TextEditingController(text: student.email ?? '');
    final addressCtrl = TextEditingController(text: student.address ?? '');
    final parentCtrl = TextEditingController(text: student.parentName);
    final parentPhoneCtrl = TextEditingController(text: student.parentPhone);

    String selectedGender = (student.gender != null && student.gender!.isNotEmpty)
        ? student.gender!.toLowerCase()
        : 'male';
    if (selectedGender != 'male' && selectedGender != 'female' && selectedGender != 'other') {
      selectedGender = 'male';
    }

    Uint8List? pickedImageBytes;
    String? pickedBase64Data;
    String? pickedFileName;
    bool photoRemoved = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          Future<void> pickImage(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: source,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 85,
              );
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final ext = picked.name.split('.').last.toLowerCase();
                final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
                final b64 = 'data:$mime;base64,${base64Encode(bytes)}';

                setModalState(() {
                  pickedImageBytes = bytes;
                  pickedBase64Data = b64;
                  pickedFileName = picked.name;
                  photoRemoved = false;
                });
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.red,
                    content: Text('Failed to pick image: $e'),
                  ),
                );
              }
            }
          }

          void showImageSourcePicker() {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (pickerCtx) => Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const Text(
                      'Select Student Photo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
                      ),
                      title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Select existing photo from device album', style: TextStyle(fontSize: 11)),
                      onTap: () {
                        Navigator.pop(pickerCtx);
                        pickImage(ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: AppTheme.green),
                      ),
                      title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Capture new photo right now', style: TextStyle(fontSize: 11)),
                      onTap: () {
                        Navigator.pop(pickerCtx);
                        pickImage(ImageSource.camera);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.manage_accounts_rounded, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Student Details (विद्यार्थी सम्पादन)',
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Class In-Charge Authority',
                              style: TextStyle(fontSize: 11, color: AppTheme.darkSubtext, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Avatar & Image Picker Controls
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primary.withOpacity(0.35),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: pickedImageBytes != null
                                    ? Image.memory(
                                        pickedImageBytes!,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                      )
                                    : (!photoRemoved && student.photoUrl != null && student.photoUrl!.isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl: student.photoUrl!,
                                            width: 96,
                                            height: 96,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => const Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) => Container(
                                              color: AppTheme.primary.withOpacity(0.1),
                                              child: Center(
                                                child: Text(
                                                  student.avatar,
                                                  style: const TextStyle(
                                                    color: AppTheme.primary,
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [AppTheme.primary, AppTheme.accent],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                student.avatar,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: showImageSourcePicker,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? AppTheme.darkCard : Colors.white,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.photo_library_rounded, size: 15),
                              label: const Text('Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              onPressed: () => pickImage(ImageSource.gallery),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.camera_alt_rounded, size: 15),
                              label: const Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              onPressed: () => pickImage(ImageSource.camera),
                            ),
                            if (pickedImageBytes != null || (!photoRemoved && student.photoUrl != null && student.photoUrl!.isNotEmpty)) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.red, size: 20),
                                tooltip: 'Remove photo',
                                onPressed: () {
                                  setModalState(() {
                                    pickedImageBytes = null;
                                    pickedBase64Data = null;
                                    pickedFileName = null;
                                    photoRemoved = true;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.green.withOpacity(0.25)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: AppTheme.green, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Auto-converts to WebP for fast lightweight storage',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.green),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Roll No & Full Name
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: rollCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Roll No',
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            prefixIcon: const Icon(Icons.numbers_rounded, size: 16),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Student Full Name *',
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            prefixIcon: const Icon(Icons.person_rounded, size: 16),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Gender Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gender',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              avatar: const Icon(Icons.male_rounded, size: 16),
                              label: const Center(child: Text('Male')),
                              selected: selectedGender == 'male',
                              selectedColor: AppTheme.blue.withOpacity(0.2),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedGender = 'male');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              avatar: const Icon(Icons.female_rounded, size: 16),
                              label: const Center(child: Text('Female')),
                              selected: selectedGender == 'female',
                              selectedColor: AppTheme.pink.withOpacity(0.2),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedGender = 'female');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              avatar: const Icon(Icons.transgender_rounded, size: 16),
                              label: const Center(child: Text('Other')),
                              selected: selectedGender == 'other',
                              selectedColor: AppTheme.purple.withOpacity(0.2),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedGender = 'other');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Student Contact Information (Phone & Email)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Student Phone',
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            prefixIcon: const Icon(Icons.phone_android_rounded, size: 16),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Student Email',
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            prefixIcon: const Icon(Icons.email_outlined, size: 16),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Residential Address
                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Current Address / Residence',
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 16),
                      hintText: 'e.g. Ward No. 3, Siraha, Nepal',
                      hintStyle: const TextStyle(fontSize: 11, color: AppTheme.grey),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Parent / Guardian Section
                  Row(
                    children: [
                      Icon(Icons.family_restroom_rounded, size: 18, color: AppTheme.primary.withOpacity(0.8)),
                      const SizedBox(width: 6),
                      const Text(
                        'Parent / Guardian Details',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Parent Name
                  TextField(
                    controller: parentCtrl,
                    decoration: InputDecoration(
                      labelText: 'Parent / Guardian Full Name',
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 16),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Parent Phone
                  TextField(
                    controller: parentPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Parent Mobile Phone',
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      prefixIcon: const Icon(Icons.phone_rounded, size: 16),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newName = nameCtrl.text.trim();
                              final newRoll = rollCtrl.text.trim();
                              final newPhone = phoneCtrl.text.trim();
                              final newEmail = emailCtrl.text.trim();
                              final newAddress = addressCtrl.text.trim();
                              final newParent = parentCtrl.text.trim();
                              final newParentPhone = parentPhoneCtrl.text.trim();

                              if (newName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter student name')),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);

                              try {
                                if (student.id != null) {
                                  final updatePayload = <String, dynamic>{
                                    'name': newName,
                                    'roll_no': newRoll,
                                    'gender': selectedGender,
                                    'phone': newPhone,
                                    'email': newEmail,
                                    'address': newAddress,
                                    'parent_name': newParent,
                                    'parent_phone': newParentPhone,
                                    'father_name': newParent,
                                    'father_phone': newParentPhone,
                                  };

                                  if (pickedBase64Data != null) {
                                    updatePayload['photo'] = pickedBase64Data;
                                    updatePayload['image'] = pickedBase64Data;
                                  } else if (photoRemoved) {
                                    updatePayload['photo'] = '';
                                    updatePayload['photo_url'] = '';
                                  }

                                  final res = await ApiService().updateStudent(
                                    student.id.toString(),
                                    updatePayload,
                                  );

                                  if (!res.success) {
                                    if (context.mounted) {
                                      setModalState(() => isSaving = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppTheme.red,
                                          content: Text(res.message.isNotEmpty ? res.message : 'Failed to update student.'),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                }

                                if (context.mounted) {
                                  final teacher = Provider.of<TeacherProvider>(context, listen: false);
                                  await teacher.fetchStudents();
                                  Navigator.pop(sheetCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              pickedBase64Data != null
                                                  ? 'Student "$newName" details & WebP photo updated!'
                                                  : 'Student "$newName" details updated successfully!',
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setModalState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.red,
                                      content: Text('Error saving changes: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        isSaving ? 'Saving Changes...' : 'Save Student Details',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveStudent = Provider.of<TeacherProvider>(context).studentList.firstWhere(
          (s) => s.id != null && s.id == student.id,
          orElse: () => student,
        );
    final color = _gradeColor(liveStudent.grade);
    return Scaffold(
      appBar: AppBar(
        title: Text(liveStudent.name),
        leading: CircleIconButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.pop(context), size: 38),
        leadingWidth: 60,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 24, color: AppTheme.primary),
            tooltip: 'Edit Student Details',
            onPressed: () => _showEditStudentModal(context, liveStudent),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(children: [
          GradientCard(
            colors: [color, color.withOpacity(0.6)],
            child: Row(children: [
              liveStudent.photoUrl != null && liveStudent.photoUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: liveStudent.photoUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              liveStudent.avatar,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          liveStudent.avatar,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(liveStudent.name, style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Roll #${liveStudent.rollNo} • ${liveStudent.displayClassSection}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  _InfoChip(label: 'GPA', value: liveStudent.gpa.toStringAsFixed(2)),
                  const SizedBox(width: 8),
                  _InfoChip(label: 'Attendance',
                      value: '${(liveStudent.attendance * 100).toInt()}%'),
                  const SizedBox(width: 8),
                  _InfoChip(label: 'Grade', value: liveStudent.grade),
                ]),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // Student & Parent Details Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Student Information',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => _showEditStudentModal(context, liveStudent),
                      icon: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.primary),
                      label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                    ),
                  ],
                ),
                const Divider(height: 14),
                _detailRow(Icons.numbers_rounded, 'Roll Number', liveStudent.rollNo),
                if (liveStudent.gender != null && liveStudent.gender!.isNotEmpty)
                  _detailRow(Icons.person_pin_rounded, 'Gender', liveStudent.gender!.toUpperCase()),
                if (liveStudent.phone != null && liveStudent.phone!.isNotEmpty)
                  _detailRow(Icons.phone_android_rounded, 'Student Phone', liveStudent.phone!),
                if (liveStudent.email != null && liveStudent.email!.isNotEmpty)
                  _detailRow(Icons.email_outlined, 'Student Email', liveStudent.email!),
                if (liveStudent.address != null && liveStudent.address!.isNotEmpty)
                  _detailRow(Icons.location_on_outlined, 'Residence', liveStudent.address!),
                const SizedBox(height: 8),
                const Text(
                  'Parent / Guardian',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.darkSubtext),
                ),
                const SizedBox(height: 6),
                _detailRow(Icons.family_restroom_rounded, 'Guardian Name', liveStudent.parentName),
                _detailRow(Icons.phone_rounded, 'Guardian Phone', liveStudent.parentPhone),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Performance Overview'),
          const SizedBox(height: 12),
          AppCard(child: Column(children: [
            _ProgressRow(label: 'Mathematics', value: 0.88, color: AppTheme.blue),
            const SizedBox(height: 12),
            _ProgressRow(label: 'Advanced Calculus', value: 0.75, color: AppTheme.purple),
            const SizedBox(height: 12),
            _ProgressRow(label: 'Statistics', value: 0.92, color: AppTheme.green),
          ])),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Recent Assignments'),
          const SizedBox(height: 12),
          ...Provider.of<TeacherProvider>(context).assignmentList.take(3).map((a) => AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: Color(a.colorHex),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.assignment_outlined,
                    size: 20, color: AppTheme.dark),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
                Text(a.dueDate, style: const TextStyle(
                    fontSize: 11, color: AppTheme.grey)),
              ])),
              PillBadge(label: 'Submitted',
                  color: AppTheme.green.withOpacity(0.1),
                  textColor: AppTheme.green),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Text(value, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      ]),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ProgressRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text('${(value * 100).toInt()}%',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value,
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ),
    ]);
  }
}
