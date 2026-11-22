import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'discipline_pastoral_screen.dart';
import 'certificate_manager_screen.dart';
import 'campus_infirmary_screen.dart';
import 'student_id_card_screen.dart';
import '../providers/student_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class StudentSearchScreen extends StatefulWidget {
  const StudentSearchScreen({Key? key}) : super(key: key);

  @override
  State<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _api = ApiService();
  int? _activeClassId;

  String? _resolveStudentPhoto(dynamic s) {
    if (s == null) return null;
    String? raw = (s is Map) ? (s['photo_url']?.toString() ?? s['photo']?.toString()) : null;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final base = _api.baseUrl.replaceAll(RegExp(r'/api(/.*)?$'), '');
    return '$base/storage/${raw.replaceFirst(RegExp(r'^/?storage/'), '').replaceFirst(RegExp(r'^/'), '')}';
  }

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<StudentProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prov.fetchClasses();
      prov.search('');
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        prov.loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onClassFilterSelected(int? classId) {
    setState(() => _activeClassId = classId);
    Provider.of<StudentProvider>(context, listen: false).search(
      _searchController.text.trim(),
      classId: classId,
      reset: true,
    );
  }

  void _showAddStudentModal() {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final admCtrl = TextEditingController();
    final fatherCtrl = TextEditingController();
    final fatherPhoneCtrl = TextEditingController();
    final motherCtrl = TextEditingController();
    final addressCtrl = TextEditingController(text: 'Kathmandu, Nepal');
    String gender = 'Male';
    String bloodGroup = 'O+';
    int? selectedClassId = _activeClassId;
    int? selectedSectionId;

    final prov = Provider.of<StudentProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedClassObj = prov.classes.firstWhere(
            (c) => c['id'] == selectedClassId,
            orElse: () => null,
          );
          final availableSections = (selectedClassObj?['sections'] as List<dynamic>?) ?? [];

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'New Student Admission',
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section 1: Student Information
                  Text('STUDENT INFORMATION', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.royalBlue, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstCtrl,
                          decoration: const InputDecoration(labelText: 'First Name *', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lastCtrl,
                          decoration: const InputDecoration(labelText: 'Last Name *', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: gender,
                          decoration: const InputDecoration(labelText: 'Gender *', isDense: true),
                          items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (val) => setModalState(() => gender = val ?? 'Male'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: bloodGroup,
                          decoration: const InputDecoration(labelText: 'Blood Group', isDense: true),
                          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                          onChanged: (val) => setModalState(() => bloodGroup = val ?? 'O+'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 2: Academic Enrollment
                  Text('ACADEMIC ENROLLMENT', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.royalBlue, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: (() {
                          final uniqueClasses = <int, Map<String, dynamic>>{};
                          for (final c in prov.classes) {
                            if (c is Map && c['id'] != null) {
                              uniqueClasses[c['id'] as int] = Map<String, dynamic>.from(c);
                            }
                          }
                          final items = uniqueClasses.values.map<DropdownMenuItem<int>>((c) {
                            return DropdownMenuItem<int>(
                              value: c['id'],
                              child: Text(c['class_name'] ?? 'Class'),
                            );
                          }).toList();
                          final safeValue = uniqueClasses.containsKey(selectedClassId)
                              ? selectedClassId
                              : null;

                          return DropdownButtonFormField<int>(
                            value: safeValue,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Class / Grade *', isDense: true),
                            hint: const Text('Select Class'),
                            items: items,
                            onChanged: (val) {
                              setModalState(() {
                                selectedClassId = val;
                                selectedSectionId = null;
                              });
                            },
                          );
                        })(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: (() {
                          final uniqueSections = <int, Map<String, dynamic>>{};
                          for (final s in availableSections) {
                            if (s is Map && s['id'] != null) {
                              uniqueSections[s['id'] as int] = Map<String, dynamic>.from(s);
                            }
                          }
                          final items = uniqueSections.values.map<DropdownMenuItem<int>>((s) {
                            return DropdownMenuItem<int>(
                              value: s['id'],
                              child: Text('Sec ${s['name']}'),
                            );
                          }).toList();
                          final safeValue = uniqueSections.containsKey(selectedSectionId)
                              ? selectedSectionId
                              : null;

                          return DropdownButtonFormField<int>(
                            value: safeValue,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Section', isDense: true),
                            hint: const Text('Section'),
                            items: items,
                            onChanged: (val) => setModalState(() => selectedSectionId = val),
                          );
                        })(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rollCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Roll Number', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: admCtrl,
                          decoration: const InputDecoration(labelText: 'Admission No (Auto if blank)', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Parent & Contact Details
                  Text('GUARDIAN & EMERGENCY CONTACTS', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.royalBlue, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fatherCtrl,
                          decoration: const InputDecoration(labelText: 'Father / Guardian Name *', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: fatherPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Guardian Phone *', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: motherCtrl,
                          decoration: const InputDecoration(labelText: 'Mother Name', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: addressCtrl,
                          decoration: const InputDecoration(labelText: 'Residential Address', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Confirm & Enroll Student', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (firstCtrl.text.trim().isEmpty || lastCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter student first and last name.')));
                          return;
                        }
                        if (selectedClassId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an enrollment class.')));
                          return;
                        }
                        if (fatherCtrl.text.trim().isEmpty || fatherPhoneCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Father or guardian contact details are required.')));
                          return;
                        }

                        Navigator.pop(ctx);

                        final res = await prov.createStudent(
                          firstName: firstCtrl.text.trim(),
                          lastName: lastCtrl.text.trim(),
                          gender: gender,
                          bloodType: bloodGroup,
                          classId: selectedClassId!,
                          sectionId: selectedSectionId,
                          rollNo: rollCtrl.text.trim().isNotEmpty ? rollCtrl.text.trim() : null,
                          admissionNo: admCtrl.text.trim().isNotEmpty ? admCtrl.text.trim() : null,
                          fatherName: fatherCtrl.text.trim(),
                          fatherPhone: fatherPhoneCtrl.text.trim(),
                          motherName: motherCtrl.text.trim().isNotEmpty ? motherCtrl.text.trim() : null,
                          address: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                          ),
                        );
                      },
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

  void _showStudentProfile(BuildContext context, int studentId) {
    final studentProv = Provider.of<StudentProvider>(context, listen: false);
    studentProv.loadStudentDetails(studentId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer<StudentProvider>(
        builder: (context, prov, _) {
          if (prov.isLoadingDetails || prov.selectedStudent == null) {
            return const SizedBox(
              height: 350,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final s = prov.selectedStudent!;
          final finance = s['finance'] ?? {};
          final attendance = s['attendance'] ?? {};
          final guardians = s['guardians'] ?? {};
          final transport = s['transport'] as Map<String, dynamic>?;
          final hostel = s['hostel'] as Map<String, dynamic>?;
          final library = s['library'] as Map<String, dynamic>?;
          final marks = (s['marks'] as List<dynamic>?) ?? [];
          final invoices = (s['invoices'] as List<dynamic>?) ?? [];
          final phone = guardians['father_phone'] ?? guardians['guardian_phone'] ?? s['phone'];
          final totalDues = (finance['total_dues'] ?? 0).toDouble();
          final medicalAlert = s['medical_alert'];
          final disciplinary = (s['disciplinary_records'] as List<dynamic>?) ?? [];

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with Digital ID badge button
                  Row(
                    children: [
                      Builder(
                        builder: (_) {
                          final photoUrl = _resolveStudentPhoto(s);
                          return CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
                            backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                            child: photoUrl == null
                                ? Text(
                                    (s['first_name'] ?? 'S')[0],
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['name'] ?? 'Student',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${s['class_section']} • Roll #${s['roll_no']}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                            Text(
                              'Adm: ${s['admission_no']} • Blood: ${s['blood_type'] ?? "O+"}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                            if (medicalAlert != null && medicalAlert.toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.roseLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.crimson.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.emergency_rounded, size: 12, color: AppTheme.crimson),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'CRITICAL: ${medicalAlert.toString().toUpperCase()}',
                                        style: const TextStyle(
                                          color: AppTheme.crimson,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Digital ID Card Action Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.royalBlue,
                        side: const BorderSide(color: AppTheme.royalBlue),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.badge_outlined, size: 18),
                      label: const Text('View Official Digital ID Badge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _showIdCardDialog(context, s),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Speed Contacts (Call / WhatsApp)
                  if (phone != null && phone.toString().isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                            icon: const Icon(Icons.phone, size: 16),
                            label: const Text('Call Guardian', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final cleanPhone = phone.toString().replaceAll(RegExp(r'\D'), '');
                              launchUrl(Uri.parse('https://wa.me/$cleanPhone'));
                            },
                            icon: const Icon(Icons.chat, size: 16),
                            label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Attendance & Fee Health Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Attendance Rate', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              const SizedBox(height: 4),
                              Text(
                                '${attendance['rate'] ?? 100}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.royalBlue,
                                ),
                              ),
                              Text(
                                '${attendance['present_days'] ?? 0}/${attendance['total_days'] ?? 0} days present',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: totalDues > 0 ? AppTheme.roseLight : AppTheme.emeraldLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Financial Dues', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              const SizedBox(height: 4),
                              Text(
                                totalDues > 0 ? 'NPR ${totalDues.toInt()}' : 'Cleared (NPR 0)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: totalDues > 0 ? AppTheme.crimson : AppTheme.emerald,
                                ),
                              ),
                              Text(
                                totalDues > 0 ? '${finance['unpaid_bills'] ?? 1} unpaid invoice' : 'All fees paid',
                                style: TextStyle(fontSize: 10, color: totalDues > 0 ? AppTheme.crimson : AppTheme.emerald),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Collect Fee Shortcut
                  if (totalDues > 0) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: Text('Collect Fee (NPR ${totalDues.toInt()}) Now', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => _showCollectFeeModal(context, s),
                      ),
                    ),
                  ],

                  // Medical Alert Banner (if any)
                  if (medicalAlert != null && medicalAlert.toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.roseLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services_outlined, color: AppTheme.crimson, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('MEDICAL ALERT / ALLERGIES', style: TextStyle(color: AppTheme.crimson, fontSize: 10, fontWeight: FontWeight.bold)),
                                Text(medicalAlert.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Campus Facilities & Lifecycle Section
                  const SizedBox(height: 20),
                  _buildSectionTitle('CAMPUS FACILITIES & LIFECYCLE'),
                  const SizedBox(height: 10),

                  // Transport Card
                  if (transport != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppTheme.amberLight, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.directions_bus, color: Color(0xFFD97706), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(transport['route_name'] ?? 'Bus Route', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppTheme.emeraldLight, borderRadius: BorderRadius.circular(8)),
                                      child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Stop: ${transport['stop_name']} • ${transport['direction']}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Text('Pickup: ${transport['morning_pickup']} | Drop: ${transport['afternoon_dropoff']}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Hostel Card
                  if (hostel != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.bed, color: AppTheme.royalBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(hostel['hostel_name'] ?? 'Hostel Boarding', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
                                      child: Text(hostel['room_type'] ?? 'Standard', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.royalBlue)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Room #${hostel['room_number']} • Bed: ${hostel['bed_name']}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Library Card
                  if (library != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppTheme.emeraldLight, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.menu_book, color: AppTheme.emerald, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Library Card: ${library['card_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('${library['active_loans_count'] ?? 0} active loans • Max: ${library['max_books'] ?? 3} books', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (((library['active_loans'] as List<dynamic>?) ?? []).isNotEmpty) ...[
                            const Divider(height: 16),
                            ...((library['active_loans'] as List<dynamic>)).map((book) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '• ${book['title']}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    'Due: ${book['due_date']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: book['status'] == 'overdue' ? AppTheme.crimson : AppTheme.textMuted,
                                      fontWeight: book['status'] == 'overdue' ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),

                  if (transport == null && hostel == null && library == null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text(
                          'No campus boarding or bus transit assigned to this student.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ),
                    ),

                  // Recent Academic Marks Section
                  if (marks.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('TERMINAL EXAMINATION MARKS'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        children: marks.map<Widget>((m) {
                          final grade = m['grade']?.toString() ?? 'N/A';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m['course_name'] ?? 'Subject',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        m['exam_name'] ?? 'Exam',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${m['score']} pts',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _getGradeColor(grade).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        grade,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _getGradeColor(grade),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Invoices & Billing Breakdown
                  if (invoices.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('RECENT FEE STATEMENTS'),
                    const SizedBox(height: 10),
                    ...invoices.map((inv) {
                      final isPaid = inv['status'] == 'paid';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inv['title'] ?? 'Fee Statement', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text('${inv['invoice_number']} • Due: ${inv['due_date'] ?? "N/A"}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('NPR ${inv['total_amount']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPaid ? AppTheme.emeraldLight : AppTheme.roseLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    inv['status'].toString().toUpperCase(),
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isPaid ? AppTheme.emerald : AppTheme.crimson),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Disciplinary Records (if any)
                  if (disciplinary.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('DISCIPLINARY INCIDENTS'),
                    const SizedBox(height: 10),
                    ...disciplinary.map((d) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(d['title'] ?? 'Incident', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.crimson)),
                              Text(d['date'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(d['description'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    )),
                  ],

                  // Guardian details
                  const SizedBox(height: 20),
                  _buildSectionTitle('GUARDIAN & EMERGENCY CONTACTS'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppTheme.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildContactRow('Father', guardians['father_name'] ?? 'N/A', guardians['father_phone']),
                        const Divider(height: 16),
                        _buildContactRow('Mother', guardians['mother_name'] ?? 'N/A', guardians['mother_phone']),
                        const Divider(height: 16),
                        _buildContactRow('Address', s['address'] ?? 'N/A', null),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.shield_outlined, color: AppTheme.amber, size: 18),
                      label: const Text('Pastoral Care, Incidents & Merits', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dark)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppTheme.amber.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DisciplinePastoralScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.verified_user_rounded, color: AppTheme.secondary, size: 18),
                      label: const Text('Issue Transfer, Character or Bonafide Certificate', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dark)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppTheme.secondary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CertificateManagerScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.local_hospital_rounded, color: AppTheme.rose, size: 18),
                      label: const Text('Campus Infirmary & Medical Health Profile', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dark)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppTheme.rose.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CampusInfirmaryScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showIdCardDialog(BuildContext context, Map<String, dynamic> s) {
    final idCardNumber = s['id_card_number'] ?? 'ID-${1000 + (s['id'] as int? ?? 0)}';
    final bloodGroup = s['blood_type'] ?? 'O+';
    final rollNo = s['roll_no'] ?? '-';
    final admNo = s['admission_no'] ?? '-';
    final classSection = s['class_section'] ?? 'Class';
    final studentName = s['name'] ?? 'Student';
    final guardians = s['guardians'] ?? {};
    final phone = guardians['father_phone'] ?? guardians['guardian_phone'] ?? s['phone'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withOpacity(0.90),
          blur: 25.0,
          border: Border.all(color: Colors.white.withOpacity(0.95), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header School Ribbon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'NEPAL SCHOOL HUB',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'OFFICIAL STUDENT IDENTITY CARD',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              // Student Photo & Core Identity
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Column(
                  children: [
                    // Photo avatar with gold frame
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Builder(
                          builder: (_) {
                            final photoUrl = _resolveStudentPhoto(s);
                            return Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFD97706), width: 3),
                                color: AppTheme.primaryLight,
                              ),
                              child: photoUrl != null
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: photoUrl,
                                        width: 84,
                                        height: 84,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Center(
                                          child: Text(
                                            (s['first_name'] ?? 'S')[0],
                                            style: const TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.royalBlue,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        (s['first_name'] ?? 'S')[0],
                                        style: const TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.royalBlue,
                                        ),
                                      ),
                                    ),
                            );
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      studentName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.royalBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ID: $idCardNumber',
                        style: const TextStyle(
                          color: AppTheme.royalBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Grid of Credentials
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildIdCell('CLASS / GRADE', classSection),
                              _buildIdCell('ROLL NUMBER', rollNo),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            children: [
                              _buildIdCell('ADMISSION NO', admNo),
                              _buildIdCell('BLOOD GROUP', bloodGroup, isBlood: true),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            children: [
                              _buildIdCell('GUARDIAN PHONE', phone.toString()),
                              _buildIdCell('VALIDITY', '2026 - 2027'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Barcode graphic
                    Column(
                      children: [
                        Container(
                          height: 30,
                          width: 200,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(32, (index) {
                              final isThick = index % 3 == 0;
                              return Container(
                                width: isThick ? 3.5 : 1.5,
                                color: Colors.black,
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '*$idCardNumber*',
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentIdCardScreen(initialStudentId: s['id'] as int?),
                            ),
                          );
                        },
                        icon: const Icon(Icons.badge_rounded, size: 16),
                        label: const Text('Open Card Studio'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCollectFeeModal(BuildContext context, Map<String, dynamic> s) {
    final finance = s['finance'] ?? {};
    final totalDues = (finance['total_dues'] ?? 0).toDouble();
    final amountCtrl = TextEditingController(text: totalDues > 0 ? totalDues.toInt().toString() : '1000');
    final notesCtrl = TextEditingController(text: 'Counter payment for ${s['name']}');
    String selectedMethod = 'Cash';
    int? selectedInvoiceId;

    final invoices = (s['invoices'] as List<dynamic>?) ?? [];
    final unpaidInvoices = invoices.where((i) => i['status'] != 'paid').toList();
    if (unpaidInvoices.isNotEmpty) {
      selectedInvoiceId = unpaidInvoices.first['id'] as int?;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Collect Student Fee',
                      style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Student: ${s['name']} (${s['class_section']})',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),

                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Collection Amount (NPR) *',
                    prefixText: 'NPR ',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Payment Method
                const Text('Payment Channel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Cash', 'eSewa', 'Khalti', 'Bank Transfer', 'Cheque'].map((method) {
                    final isSel = selectedMethod == method;
                    return ChoiceChip(
                      label: Text(method, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.black87)),
                      selected: isSel,
                      selectedColor: AppTheme.royalBlue,
                      onSelected: (val) {
                        if (val) setSheetState(() => selectedMethod = method);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Invoice selection if any
                if (unpaidInvoices.isNotEmpty) ...[
                  (() {
                    final uniqueInvs = <int, Map<String, dynamic>>{};
                    for (final inv in unpaidInvoices) {
                      if (inv is Map && inv['id'] != null) {
                        uniqueInvs[inv['id'] as int] = Map<String, dynamic>.from(inv);
                      }
                    }
                    final items = uniqueInvs.values.map<DropdownMenuItem<int>>((inv) {
                      return DropdownMenuItem<int>(
                        value: inv['id'] as int,
                        child: Text('${inv['invoice_number']} - ${inv['title']} (Due: NPR ${inv['due_amount']})'),
                      );
                    }).toList();
                    final safeVal = uniqueInvs.containsKey(selectedInvoiceId) ? selectedInvoiceId : (uniqueInvs.isNotEmpty ? uniqueInvs.keys.first : null);

                    return DropdownButtonFormField<int>(
                      value: safeVal,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Apply to Bill / Invoice', isDense: true),
                      items: items,
                      onChanged: (val) => setSheetState(() => selectedInvoiceId = val),
                    );
                  })(),
                  const SizedBox(height: 14),
                ],

                // Notes
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Receipt Notes / Remarks',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 20),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Record Counter Payment & Print', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final parsedAmount = double.tryParse(amountCtrl.text.trim());
                      if (parsedAmount == null || parsedAmount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid payment amount.')),
                        );
                        return;
                      }

                      Navigator.pop(ctx);

                      final res = await _api.collectFee(
                        studentId: s['id'] as int,
                        amount: parsedAmount,
                        paymentMethod: selectedMethod,
                        invoiceId: selectedInvoiceId,
                        notes: notesCtrl.text.trim(),
                      );

                      if (res.success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message.isNotEmpty ? res.message : 'NPR $parsedAmount collected successfully!'),
                            backgroundColor: AppTheme.emerald,
                          ),
                        );
                        // Reload student profile
                        Provider.of<StudentProvider>(context, listen: false).loadStudentDetails(s['id'] as int);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppTheme.royalBlue,
        letterSpacing: 0.6,
      ),
    );
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return AppTheme.emerald;
    if (grade.startsWith('B')) return AppTheme.royalBlue;
    if (grade.startsWith('C')) return const Color(0xFFD97706);
    if (grade.startsWith('D')) return Colors.orange;
    return AppTheme.crimson;
  }

  Widget _buildIdCell(String label, String value, {bool isBlood = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Row(
            children: [
              if (isBlood) const Icon(Icons.water_drop, size: 12, color: AppTheme.crimson),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isBlood ? AppTheme.crimson : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(String label, String value, String? phone) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        if (phone != null && phone.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.phone, size: 16, color: AppTheme.royalBlue),
            onPressed: () => launchUrl(Uri.parse('tel:$phone')),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<StudentProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.72),
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student 360° Directory',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${prov.totalEnrolled} Enrolled • ${prov.totalFiltered} Matching',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Enroll New Student',
            onPressed: _showAddStudentModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              prov.fetchClasses();
              prov.search(_searchController.text.trim(), classId: _activeClassId, reset: true);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.royalBlue,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddStudentModal,
      ),
      body: Column(
        children: [
          // Frosted Glass Search & Filter Header
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.76),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.85), width: 1.0),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA).withOpacity(0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (val) => prov.search(val.trim(), classId: _activeClassId, reset: true),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search student name, roll, phone, admission...',
                          hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF8E8E93)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.cancel, size: 16, color: Color(0xFF8E8E93)),
                                  onPressed: () {
                                    _searchController.clear();
                                    prov.search('', classId: _activeClassId, reset: true);
                                  },
                                )
                              : null,
                          filled: false,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Class Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildClassPill(null, 'All (${prov.totalEnrolled})'),
                          const SizedBox(width: 8),
                          ...prov.classes.map((c) {
                            final id = c['id'] as int;
                            final name = c['class_name'] ?? 'Class';
                            final count = c['student_count'] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildClassPill(id, '$name ($count)'),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Results list with Infinite Scroll
          Expanded(
            child: prov.isSearching
                ? const Center(child: CircularProgressIndicator())
                : prov.students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('No student records found.', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => prov.search(_searchController.text.trim(), classId: _activeClassId, reset: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: prov.students.length + (prov.hasMore ? 1 : 0),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemBuilder: (ctx, idx) {
                            if (idx >= prov.students.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }

                            final s = prov.students[idx];
                            final phone = s['guardian_phone'];

                            return GlassContainer(
                              margin: const EdgeInsets.only(bottom: 8),
                              borderRadius: BorderRadius.circular(16),
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                onTap: () => _showStudentProfile(context, s['id']),
                                leading: Builder(
                                  builder: (_) {
                                    final photoUrl = _resolveStudentPhoto(s);
                                    return CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppTheme.royalBlue.withOpacity(0.08),
                                      backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                                      child: photoUrl == null
                                          ? Text(
                                              (s['first_name'] ?? 'S')[0],
                                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.royalBlue, fontSize: 16),
                                            )
                                          : null,
                                    );
                                  },
                                ),
                                title: Text(
                                  s['name'] ?? '',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textMain),
                                ),
                                subtitle: Text(
                                  '${s['class_section']} • Roll ${s['roll_no']}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (phone != null && phone.toString().isNotEmpty && phone != 'N/A')
                                      IconButton(
                                        icon: const Icon(Icons.phone, color: AppTheme.emerald, size: 18),
                                        onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                                      ),
                                    const Icon(Icons.chevron_right, size: 18, color: Color(0xFFC7C7CC)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassPill(int? classId, String label) {
    final isSelected = _activeClassId == classId;
    return GestureDetector(
      onTap: () => _onClassFilterSelected(classId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.royalBlue : const Color(0xFFE5E5EA).withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.royalBlue.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF3A3A3C),
          ),
        ),
      ),
    );
  }
}
