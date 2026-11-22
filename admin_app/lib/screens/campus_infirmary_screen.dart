import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CampusInfirmaryScreen extends StatefulWidget {
  const CampusInfirmaryScreen({Key? key}) : super(key: key);

  @override
  State<CampusInfirmaryScreen> createState() => _CampusInfirmaryScreenState();
}

class _CampusInfirmaryScreenState extends State<CampusInfirmaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  // Tab 1: Sick Bay State
  bool _sickBayLoading = true;
  String _sickBayFilter = 'active'; // 'active' (resting), 'today', 'all'
  final TextEditingController _sickBaySearchCtrl = TextEditingController();
  List<dynamic> _visits = [];

  // Tab 2: Critical Alerts State
  bool _alertsLoading = true;
  final TextEditingController _alertSearchCtrl = TextEditingController();
  List<dynamic> _criticalAlerts = [];

  Map<String, dynamic> _kpis = {
    'resting_in_sick_bay': 0,
    'today_total_visits': 0,
    'today_discharged': 0,
    'critical_alerts': 0,
  };

  static const List<String> _symptomPresets = [
    'High Fever / Chills',
    'Headache / Migraine',
    'Nausea / Vomiting',
    'Stomach Cramps / Abdominal Pain',
    'Sports Injury / Sprain',
    'Asthma / Breathing Distress',
    'Allergic Reaction / Rash',
    'Dizziness / Fainting Episode',
  ];

  static const List<String> _treatmentPresets = [
    'Paracetamol 500mg & Rest',
    'ORS Hydration & Bed Rest',
    'Ice Pack & Compression Bandage',
    'Salbutamol Inhaler Nebulization',
    'Antacid & Warm Water',
    'Antihistamine / Cetirizine',
    'Wound Cleaning & Dressing',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadOverview();
    _loadSickBay();
    _loadCriticalAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sickBaySearchCtrl.dispose();
    _alertSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    final res = await _api.getHealthOverview();
    if (res.success && res.data != null) {
      if (mounted) {
        setState(() {
          _kpis = (res.data!['kpis'] as Map<String, dynamic>?) ?? _kpis;
        });
      }
    }
  }

  Future<void> _loadSickBay() async {
    setState(() => _sickBayLoading = true);
    final res = await _api.getSickBayRoster(
      status: _sickBayFilter,
      search: _sickBaySearchCtrl.text.trim().isEmpty ? null : _sickBaySearchCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _sickBayLoading = false;
        _visits = res.success ? (res.data ?? []) : [];
      });
    }
  }

  Future<void> _loadCriticalAlerts() async {
    setState(() => _alertsLoading = true);
    final res = await _api.getCriticalHealthAlerts();
    if (mounted) {
      setState(() {
        _alertsLoading = false;
        _criticalAlerts = res.success ? (res.data ?? []) : [];
      });
    }
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No emergency contact number recorded.')));
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restingCount = (_kpis['resting_in_sick_bay'] as int?) ?? 0;
    final criticalCount = (_kpis['critical_alerts'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Campus Infirmary & Clinic',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.dark),
            ),
            Text(
              'Sick Bay Roster, Medical Records & Allergy Alerts',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: () {
              _loadOverview();
              _loadSickBay();
              _loadCriticalAlerts();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hotel_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('Sick Bay Roster'),
                  if (restingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.amber, borderRadius: BorderRadius.circular(10)),
                      child: Text('$restingCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.medical_services_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('Critical Alerts'),
                  if (criticalCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.crimson, borderRadius: BorderRadius.circular(10)),
                      child: Text('$criticalCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSickBayTab(),
          _buildCriticalAlertsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.crimson,
        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
        label: Text('Admit to Sick Bay', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
        onPressed: _showCheckInSheet,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: SICK BAY ROSTER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSickBayTab() {
    final resting = (_kpis['resting_in_sick_bay'] as int?) ?? 0;
    final totalToday = (_kpis['today_total_visits'] as int?) ?? 0;
    final discharged = (_kpis['today_discharged'] as int?) ?? 0;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadOverview();
        await _loadSickBay();
      },
      child: CustomScrollView(
        slivers: [
          // Telemetry Ribbon
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: resting > 0 ? AppTheme.amber : Colors.grey.shade200, width: resting > 0 ? 1.5 : 1.0),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Resting in Clinic', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                        Text('$resting Beds', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: resting > 0 ? AppTheme.amber : AppTheme.dark)),
                        Text('Currently in sick bay', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.grey)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Today Clinic Visits', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                        Text('$totalToday', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                        Text('$discharged Discharged', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filters & Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: TextField(
                      controller: _sickBaySearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search student, bed number, or symptom...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.grey),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.grey, size: 20),
                        suffixIcon: _sickBaySearchCtrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _sickBaySearchCtrl.clear(); _loadSickBay(); })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _loadSickBay(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChoiceChip('Resting Now', 'active', _sickBayFilter, (v) { setState(() => _sickBayFilter = v); _loadSickBay(); }),
                        const SizedBox(width: 6),
                        _buildChoiceChip('All Today Visits', 'today', _sickBayFilter, (v) { setState(() => _sickBayFilter = v); _loadSickBay(); }),
                        const SizedBox(width: 6),
                        _buildChoiceChip('Historical Logs', 'all', _sickBayFilter, (v) { setState(() => _sickBayFilter = v); _loadSickBay(); }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Visits List
          if (_sickBayLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_visits.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.health_and_safety_outlined, size: 56, color: AppTheme.emerald.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('Infirmary is Empty', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('No students currently resting in the school sick bay.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _visits[index];
                    return _buildVisitCard(item);
                  },
                  childCount: _visits.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(dynamic item) {
    final int id = item['id'] ?? 0;
    final String sName = item['student_name'] ?? 'Student';
    final String classSec = item['class_section'] ?? 'Class';
    final String bed = item['bed_number'] ?? 'Bed 1';
    final String symptoms = item['symptoms'] ?? 'Symptoms';
    final String tempLabel = item['temperature_label'] ?? 'Normal';
    final String treatment = item['treatment_administered'] ?? 'Resting';
    final String entryTime = item['entry_time_label'] ?? 'N/A';
    final String duration = item['duration_label'] ?? '0m';
    final bool isResting = (item['is_resting'] as bool?) ?? false;
    final String? guardianPhone = item['guardian_phone'];
    final bool guardianNotified = (item['guardian_notified'] as bool?) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isResting ? AppTheme.amber.withOpacity(0.4) : Colors.grey.shade200, width: isResting ? 1.5 : 1.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isResting ? AppTheme.amber.withOpacity(0.12) : AppTheme.emerald.withOpacity(0.12),
                  child: Icon(Icons.hotel_rounded, color: isResting ? AppTheme.amber : AppTheme.emerald, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.dark)),
                      Text('$classSec • $bed', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isResting ? AppTheme.amber.withOpacity(0.12) : AppTheme.emerald.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isResting ? 'IN SICK BAY ($duration)' : 'DISCHARGED',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isResting ? AppTheme.amber : AppTheme.emerald),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Symptoms: $symptoms', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.dark)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(tempLabel, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.crimson)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Treatment: $treatment', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.dark)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(guardianNotified ? Icons.check_circle_rounded : Icons.pending_actions_rounded, size: 14, color: guardianNotified ? AppTheme.emerald : AppTheme.amber),
                    const SizedBox(width: 4),
                    Text(
                      guardianNotified ? 'Guardian Notified' : 'Guardian Pending Contact',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: guardianNotified ? AppTheme.emerald : AppTheme.amber, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text('Admitted $entryTime', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (guardianPhone != null && guardianPhone.isNotEmpty)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 14, color: AppTheme.primary),
                        label: const Text('Call Parent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        onPressed: () {
                          _makePhoneCall(guardianPhone);
                          _api.notifySickBayGuardian(id);
                        },
                      ),
                    if (isResting) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                        label: const Text('Discharge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _showDischargeDialog(id, sName),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDischargeDialog(int id, String studentName) {
    String actionTaken = 'returned_to_class';
    final TextEditingController notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Discharge from Sick Bay', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resolution for $studentName:', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: actionTaken,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: const [
                  DropdownMenuItem(value: 'returned_to_class', child: Text('Returned to Classroom')),
                  DropdownMenuItem(value: 'sent_home', child: Text('Sent Home with Guardian')),
                  DropdownMenuItem(value: 'hospital_referral', child: Text('Hospital / Clinic Referral')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => actionTaken = val);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(hintText: 'Discharge remarks / nurse instructions', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.dischargeSickBay(id, {
                  'action_taken': actionTaken,
                  'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                });
                if (res.success) {
                  _loadOverview();
                  _loadSickBay();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student discharged from infirmary.')));
                }
              },
              child: const Text('Confirm Discharge'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: CRITICAL HEALTH & ALLERGY REGISTRY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCriticalAlertsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadOverview();
        await _loadCriticalAlerts();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emergency_rounded, color: AppTheme.crimson, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Critical Medical & Emergency Radar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.crimson)),
                          Text('High-risk chronic conditions (Asthma, Severe Allergies, Diabetes, Epilepsy)', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.dark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_alertsLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_criticalAlerts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.health_and_safety_rounded, size: 56, color: AppTheme.emerald.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No Critical Health Alerts', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('No students with flagged severe medical conditions on campus.', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _criticalAlerts[index];
                    return _buildCriticalCard(item);
                  },
                  childCount: _criticalAlerts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCriticalCard(dynamic item) {
    final String name = item['student_name'] ?? 'Student';
    final String classSec = item['class_section'] ?? 'Class';
    final String blood = item['blood_type'] ?? 'Unknown';
    final String? allergies = item['allergies'];
    final String? chronic = item['chronic_conditions'];
    final String? emergencyNotes = item['emergency_medical_notes'];
    final String? docName = item['doctor_name'];
    final String? docPhone = item['doctor_phone'];
    final String? parentPhone = item['guardian_phone'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.crimson.withOpacity(0.12),
                  child: Text(blood, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 11, color: AppTheme.crimson)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.dark)),
                      Text(classSec, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.crimson, borderRadius: BorderRadius.circular(8)),
                  child: const Text('CRITICAL ALERT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (chronic != null && chronic.isNotEmpty) ...[
              Text('Condition: $chronic', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.crimson)),
            ],
            if (allergies != null && allergies.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Severe Allergies: $allergies', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.dark)),
            ],
            if (emergencyNotes != null && emergencyNotes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Emergency Protocol: $emergencyNotes', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (docPhone != null && docPhone.isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.crimson)),
                    icon: const Icon(Icons.local_hospital_rounded, size: 14, color: AppTheme.crimson),
                    label: Text(docName ?? 'Doctor Call', style: const TextStyle(fontSize: 11, color: AppTheme.crimson, fontWeight: FontWeight.bold)),
                    onPressed: () => _makePhoneCall(docPhone),
                  ),
                const Spacer(),
                if (parentPhone != null && parentPhone.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                    label: const Text('Call Parents', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _makePhoneCall(parentPhone),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Admit Student Sheet
  void _showCheckInSheet() {
    int? selectedStudentId;
    String? selectedStudentName;
    List<dynamic> studentSearchResults = [];
    bool isSearching = false;

    String symptoms = _symptomPresets.first;
    final TextEditingController tempCtrl = TextEditingController(text: '37.8');
    String treatment = _treatmentPresets.first;
    String bed = 'Bed 1';
    final TextEditingController notesCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Admit Student to Sick Bay / Clinic', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Text('Student *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (selectedStudentName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppTheme.crimson.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.crimson, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(selectedStudentName!, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.crimson))),
                        IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setModalState(() { selectedStudentId = null; selectedStudentName = null; })),
                      ],
                    ),
                  ),
                ] else ...[
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Type 2+ letters of student name...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: isSearching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) async {
                      if (val.trim().length >= 2) {
                        setModalState(() => isSearching = true);
                        final res = await _api.searchStudents(val.trim());
                        setModalState(() {
                          isSearching = false;
                          studentSearchResults = res.success ? (res.data ?? []) : [];
                        });
                      }
                    },
                  ),
                  if (studentSearchResults.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 130),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: studentSearchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final st = studentSearchResults[i];
                          final stName = st['name'] ?? '${st['first_name'] ?? ''} ${st['last_name'] ?? ''}'.trim();
                          final stClass = st['class_name'] ?? st['class'] ?? '';
                          return ListTile(
                            dense: true,
                            title: Text(stName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                            subtitle: Text(stClass, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                            onTap: () {
                              setModalState(() {
                                selectedStudentId = st['id'];
                                selectedStudentName = '$stName ($stClass)';
                                studentSearchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Symptoms Reported *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: symptoms,
                          isExpanded: true,
                          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          items: _symptomPresets.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) { if (v != null) setModalState(() => symptoms = v); },
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Temp (°C)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(controller: tempCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Initial Treatment Given', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: treatment,
                          isExpanded: true,
                          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          items: _treatmentPresets.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) { if (v != null) setModalState(() => treatment = v); },
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Bed Slot', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: bed,
                          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          items: const [
                            DropdownMenuItem(value: 'Bed 1', child: Text('Bed 1')),
                            DropdownMenuItem(value: 'Bed 2', child: Text('Bed 2')),
                            DropdownMenuItem(value: 'Bed 3', child: Text('Bed 3')),
                            DropdownMenuItem(value: 'Isolation', child: Text('Isolation')),
                          ],
                          onChanged: (v) { if (v != null) setModalState(() => bed = v); },
                        ),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isSaving ? null : () async {
                      if (selectedStudentId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student')));
                        return;
                      }
                      setModalState(() => isSaving = true);
                      final res = await _api.checkInSickBay({
                        'student_id': selectedStudentId,
                        'symptoms': symptoms,
                        'temperature_c': double.tryParse(tempCtrl.text),
                        'treatment_administered': treatment,
                        'bed_number': bed,
                      });
                      setModalState(() => isSaving = false);
                      if (res.success) {
                        Navigator.pop(ctx);
                        _loadOverview();
                        _loadSickBay();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student admitted to sick bay!')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                      }
                    },
                    child: Text(isSaving ? 'Admitting...' : 'Admit to Clinic', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value, String selectedValue, ValueChanged<String> onSelected) {
    final isSel = selectedValue == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: AppTheme.primary,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.dark),
      onSelected: (_) => onSelected(value),
    );
  }
}
