import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/common_widgets.dart';

class StudentIdCardScreen extends StatefulWidget {
  final int? initialStudentId;
  final int? initialClassId;

  const StudentIdCardScreen({
    super.key,
    this.initialStudentId,
    this.initialClassId,
  });

  @override
  State<StudentIdCardScreen> createState() => _StudentIdCardScreenState();
}

class _StudentIdCardScreenState extends State<StudentIdCardScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isBulkGenerating = false;
  int _viewMode = 0; // 0 = Single Card Studio, 1 = Class Cards Grid
  bool _showBack = false;

  // Filters
  int? _selectedClassId;
  int? _selectedSectionId;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Data
  Map<String, dynamic> _school = {};
  Map<String, dynamic> _session = {};
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _students = [];

  // Card Studio state
  int _currentIndex = 0;
  String _cardTemplate = 'cr80_portrait_modern'; // cr80_portrait_modern, cr80_landscape_executive

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
    _fetchStudents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);

    final res = await _api.getIdCardStudents(
      classId: _selectedClassId,
      sectionId: _selectedSectionId,
      search: _searchQuery,
    );
    if (!mounted) return;

    if (res.success && res.data != null) {
      final data = res.data!;
      _school = Map<String, dynamic>.from(data['school'] ?? {});
      _session = Map<String, dynamic>.from(data['session'] ?? {});
      final rawClasses = (data['classes'] as List<dynamic>? ?? [])
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();
      final rawStudents = (data['students'] as List<dynamic>? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

      setState(() {
        _classes = rawClasses;
        _students = rawStudents;

        if (_selectedClassId == null && rawClasses.isNotEmpty) {
          _selectedClassId = rawClasses.first['id'];
        }

        // Focus on initial student if provided
        if (widget.initialStudentId != null) {
          final idx = rawStudents.indexWhere((s) => s['student_id'] == widget.initialStudentId);
          if (idx != -1) _currentIndex = idx;
        } else if (_currentIndex >= rawStudents.length) {
          _currentIndex = 0;
        }

        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _bulkGenerateForClass() async {
    if (_selectedClassId == null) return;

    setState(() => _isBulkGenerating = true);
    final res = await _api.bulkGenerateIdCards(
      classId: _selectedClassId!,
      sectionId: _selectedSectionId,
    );
    if (!mounted) return;

    setState(() => _isBulkGenerating = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.emerald,
        ),
      );
      _fetchStudents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, isDark),
            _buildClassFilterBar(isDark),
            _buildViewModeTabBar(isDark),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.royalBlue))
                  : _students.isEmpty
                      ? _buildEmptyState(isDark)
                      : _viewMode == 0
                          ? _buildCardStudio(isDark)
                          : _buildCardsGrid(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR & FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 38,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student ID Card Studio',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.dark,
                  ),
                ),
                const Text(
                  'Digital Badges, CR80 Format & QR Security Passes',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: _isBulkGenerating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.royalBlue),
            tooltip: 'Bulk Generate ID Numbers',
            onPressed: _isBulkGenerating ? null : _bulkGenerateForClass,
          ),
        ],
      ),
    );
  }

  Widget _buildClassFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 38,
              child: (() {
                final uniqueClasses = <int, Map<String, dynamic>>{};
                for (final c in _classes) {
                  if (c is Map && c['id'] != null) {
                    uniqueClasses[c['id'] as int] = Map<String, dynamic>.from(c);
                  }
                }
                final items = [
                  const DropdownMenuItem<int?>(value: null, child: Text('All Classes', style: TextStyle(fontSize: 12))),
                  ...uniqueClasses.values.map((c) => DropdownMenuItem<int?>(
                        value: c['id'] as int?,
                        child: Text(c['class_name'] ?? 'Class', style: const TextStyle(fontSize: 12)),
                      )),
                ];
                final safeVal = uniqueClasses.containsKey(_selectedClassId) ? _selectedClassId : null;

                return DropdownButtonFormField<int?>(
                  value: safeVal,
                  isExpanded: true,
                  hint: const Text('Select Class', style: TextStyle(fontSize: 12)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: items,
                  onChanged: (v) {
                    setState(() {
                      _selectedClassId = v;
                      _selectedSectionId = null;
                      _currentIndex = 0;
                    });
                    _fetchStudents();
                  },
                );
              })(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 38,
              child: (() {
                Map<String, dynamic>? matchingClass;
                for (final c in _classes) {
                  if (c is Map && c['id'] == _selectedClassId) {
                    matchingClass = Map<String, dynamic>.from(c);
                    break;
                  }
                }
                final rawSecs = (matchingClass?['sections'] as List<dynamic>? ?? []);
                final uniqueSecs = <int, Map<String, dynamic>>{};
                for (final s in rawSecs) {
                  if (s is Map && s['id'] != null) {
                    uniqueSecs[s['id'] as int] = Map<String, dynamic>.from(s);
                  }
                }
                final items = [
                  const DropdownMenuItem<int?>(value: null, child: Text('All Sec', style: TextStyle(fontSize: 12))),
                  ...uniqueSecs.values.map((s) => DropdownMenuItem<int?>(
                        value: s['id'] as int?,
                        child: Text('Sec ${s['section_name']}', style: const TextStyle(fontSize: 12)),
                      )),
                ];
                final safeVal = uniqueSecs.containsKey(_selectedSectionId) ? _selectedSectionId : null;

                return DropdownButtonFormField<int?>(
                  value: safeVal,
                  isExpanded: true,
                  hint: const Text('Section', style: TextStyle(fontSize: 12)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: items,
                  onChanged: (v) {
                    setState(() {
                      _selectedSectionId = v;
                      _currentIndex = 0;
                    });
                    _fetchStudents();
                  },
                );
              })(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton('Card Studio (Interactive)', Icons.badge_rounded, _viewMode == 0, () {
              setState(() => _viewMode = 0);
            }),
          ),
          Expanded(
            child: _tabButton('Class Cards Grid (${_students.length})', Icons.grid_view_rounded, _viewMode == 1, () {
              setState(() => _viewMode = 1);
            }),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, IconData icon, bool isSel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.royalBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSel ? Colors.white : AppTheme.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                color: isSel ? Colors.white : AppTheme.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW 0: INTERACTIVE CARD STUDIO
  // ---------------------------------------------------------------------------

  Widget _buildCardStudio(bool isDark) {
    final currentStudent = _students[_currentIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Student Selector Stepper Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                onPressed: _currentIndex > 0
                    ? () => setState(() {
                          _currentIndex--;
                          _showBack = false;
                        })
                    : null,
              ),
              Text(
                'Student ${_currentIndex + 1} of ${_students.length}',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                onPressed: _currentIndex + 1 < _students.length
                    ? () => setState(() {
                          _currentIndex++;
                          _showBack = false;
                        })
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // THE 3D FLIPPABLE ID CARD
          GestureDetector(
            onTap: () => setState(() => _showBack = !_showBack),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) {
                final rotate = Tween(begin: math.pi, end: 0.0).animate(animation);
                return AnimatedBuilder(
                  animation: rotate,
                  builder: (ctx, childWidget) {
                    final isUnder = (ValueKey(_showBack) != childWidget?.key);
                    var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                    tilt *= isUnder ? -1.0 : 1.0;
                    final value = isUnder ? math.min(rotate.value, math.pi / 2) : rotate.value;
                    return Transform(
                      transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                      alignment: Alignment.center,
                      child: childWidget,
                    );
                  },
                  child: child,
                );
              },
              child: _showBack
                  ? _buildCardBack(currentStudent, isDark, key: const ValueKey(true))
                  : _buildCardFront(currentStudent, isDark, key: const ValueKey(false)),
            ),
          ),
          const SizedBox(height: 14),

          // Flip Button
          OutlinedButton.icon(
            icon: const Icon(Icons.flip_camera_android_rounded, size: 16),
            label: Text(_showBack ? 'Flip to Front of Card' : 'Flip to Back of Card', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => setState(() => _showBack = !_showBack),
          ),
          const SizedBox(height: 20),

          // Quick Action Tools
          _buildCardToolsBar(currentStudent, isDark),
        ],
      ),
    );
  }

  // --- CARD FRONT DESIGN (CR80 Standard Dimensions) ---
  Widget _buildCardFront(Map<String, dynamic> s, bool isDark, {Key? key}) {
    final schoolName = _school['name'] ?? 'NEPAL SCHOOL HUB';
    final logoUrl = _school['logo_url'] as String?;
    final photoUrl = s['photo_url'];
    final name = s['name'] ?? 'Student Name';
    final roll = s['roll_no'] ?? '-';
    final adm = s['admission_no'] ?? '-';
    final blood = s['blood_type'] ?? 'O+';
    final className = s['class_name'] ?? 'Class';
    final secName = s['section_name'] ?? 'A';
    final idCardNo = s['id_card_number'] ?? '2083-0001';
    final qrUrl = s['qr_code_image_url'] as String?;

    return Container(
      key: key,
      width: 290,
      height: 440,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            // Top Header Ribbon with School Brand
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      image: logoUrl != null ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.contain) : null,
                    ),
                    child: logoUrl == null
                        ? const Icon(Icons.school, size: 20, color: AppTheme.royalBlue)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schoolName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'STUDENT IDENTITY CARD',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Body with Photo & Information
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // Student Photo Badge
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.royalBlue, width: 2),
                        image: photoUrl != null ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover) : null,
                      ),
                      child: photoUrl == null
                          ? const Icon(Icons.person, size: 48, color: AppTheme.royalBlue)
                          : null,
                    ),
                    const SizedBox(height: 8),

                    // Student Name
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppTheme.dark,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Class & Section Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.royalBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$className - Section $secName',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.royalBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Key Card Data Grid
                    _cardMetaRow('Roll Number', '#$roll', 'Admission No', '#$adm'),
                    const SizedBox(height: 6),
                    _cardMetaRow('Blood Group', blood, 'Validity', s['valid_until'] ?? '2083/84'),
                    const SizedBox(height: 10),

                    const Spacer(),

                    // QR Code & ID Card Barcode representation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CARD NUMBER',
                              style: TextStyle(fontSize: 8, color: AppTheme.grey, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              idCardNo,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.dark,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        if (qrUrl != null)
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Image.network(qrUrl, fit: BoxFit.contain),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Ribbon
            Container(
              height: 8,
              color: AppTheme.emerald,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardMetaRow(String l1, String v1, String l2, String v2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l1, style: const TextStyle(fontSize: 9, color: AppTheme.grey, fontWeight: FontWeight.w600)),
              Text(v1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.dark)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l2, style: const TextStyle(fontSize: 9, color: AppTheme.grey, fontWeight: FontWeight.w600)),
              Text(v2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.dark)),
            ],
          ),
        ),
      ],
    );
  }

  // --- CARD BACK DESIGN ---
  Widget _buildCardBack(Map<String, dynamic> s, bool isDark, {Key? key}) {
    final schoolName = _school['name'] ?? 'NEPAL SCHOOL HUB';
    final address = s['address'] ?? 'Kathmandu, Nepal';
    final guardianPhone = s['guardian_phone'] ?? 'N/A';
    final guardianName = s['guardian_name'] ?? 'Guardian';
    final schoolPhone = _school['phone'] ?? '+977-1-4412345';
    final idCardNo = s['id_card_number'] ?? '2083-0001';

    return Container(
      key: key,
      width: 290,
      height: 440,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EMERGENCY INSTRUCTIONS',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: AppTheme.royalBlue,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Emergency contacts
              _backRow(Icons.person_rounded, 'Guardian', guardianName),
              const SizedBox(height: 6),
              _backRow(Icons.phone_rounded, 'Emergency Contact', guardianPhone),
              const SizedBox(height: 6),
              _backRow(Icons.location_on_rounded, 'Residence', address),
              const SizedBox(height: 6),
              _backRow(Icons.local_hospital_rounded, 'Blood Group', s['blood_type'] ?? 'O+'),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Institutional Terms
              const Text(
                'INSTITUTIONAL TERMS',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.grey),
              ),
              const SizedBox(height: 4),
              const Text(
                '1. This badge must be carried by the student while on campus and school bus transport.\n'
                '2. Unauthorized use, alteration, or transfer of this badge is strictly prohibited.\n'
                '3. If lost or damaged, notify administrative reception immediately.\n'
                '4. If found, please return to the school administration address.',
                style: TextStyle(fontSize: 9, color: Color(0xFF64748B), height: 1.4),
              ),

              const Spacer(),

              // Seal & Signature
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Helpline:', style: TextStyle(fontSize: 8, color: AppTheme.grey)),
                      Text(schoolPhone, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 70,
                        height: 22,
                        alignment: Alignment.center,
                        child: const Text('Authorized', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: AppTheme.royalBlue, fontWeight: FontWeight.w700)),
                      ),
                      Container(width: 80, height: 1, color: AppTheme.dark),
                      const SizedBox(height: 2),
                      const Text('Principal Signature', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Barcode / Pass ID: $idCardNo',
                  style: const TextStyle(fontSize: 8, color: AppTheme.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.royalBlue),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 10, color: AppTheme.dark),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardToolsBar(Map<String, dynamic> s, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Share Digital Badge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.royalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Digital pass ready for ${s['name']}. QR link: ${s['qr_login_url']}'),
                  backgroundColor: AppTheme.emerald,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.print_rounded, color: AppTheme.royalBlue),
          tooltip: 'Print ID Badge',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ID Card PDF rendered in standard CR80 format.')),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW 1: CLASS CARDS GRID
  // ---------------------------------------------------------------------------

  Widget _buildCardsGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const dynamicDelegate(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _students.length,
      itemBuilder: (ctx, idx) {
        final s = _students[idx];
        final photoUrl = s['photo_url'];

        return InkWell(
          onTap: () {
            setState(() {
              _currentIndex = idx;
              _viewMode = 0;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top header bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.royalBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Roll #${s['roll_no']}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.royalBlue),
                  ),
                ),
                const SizedBox(height: 6),

                // Photo
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.royalBlue.withOpacity(0.12),
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          s['first_name'] != null ? s['first_name'][0].toUpperCase() : 'S',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.royalBlue, fontSize: 18),
                        )
                      : null,
                ),
                const SizedBox(height: 8),

                // Name
                Text(
                  s['name'] ?? 'Student',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: isDark ? Colors.white : AppTheme.dark,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Class
                Text(
                  '${s['class_name']} - Sec ${s['section_name']}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.grey),
                ),
                const SizedBox(height: 2),

                // ID Number
                Text(
                  s['id_card_number'] ?? '-',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.royalBlue),
                ),
                const Spacer(),

                // Blood Group & View action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.crimson.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s['blood_type'] ?? 'O+',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.crimson),
                      ),
                    ),
                    const Row(
                      children: [
                        Text('Preview', style: TextStyle(fontSize: 9, color: AppTheme.royalBlue, fontWeight: FontWeight.w700)),
                        Icon(Icons.arrow_forward_ios_rounded, size: 8, color: AppTheme.royalBlue),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.badge_outlined, size: 48, color: AppTheme.grey),
          const SizedBox(height: 12),
          Text(
            'No students found in selected class/section.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class dynamicDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  const dynamicDelegate({
    required super.crossAxisCount,
    super.mainAxisSpacing,
    super.crossAxisSpacing,
    super.childAspectRatio,
  });
}
