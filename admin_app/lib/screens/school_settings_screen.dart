import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/common_widgets.dart';

class SchoolSettingsScreen extends StatefulWidget {
  const SchoolSettingsScreen({super.key});

  @override
  State<SchoolSettingsScreen> createState() => _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends State<SchoolSettingsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  int _activeTab = 0; // 0=General, 1=Academic Sessions, 2=Payment QRs, 3=Branding

  // School data
  Map<String, dynamic> _school = {};
  Map<String, dynamic> _media = {};
  Map<String, dynamic> _academic = {};
  Map<String, dynamic> _stats = {};

  // Form Controllers
  final _nameCtrl = TextEditingController();
  final _iemisCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();

  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  final _missionCtrl = TextEditingController();
  final _visionCtrl = TextEditingController();
  final _aboutUsCtrl = TextEditingController();
  final _principalMsgCtrl = TextEditingController();

  final _paymentInstructionsCtrl = TextEditingController();

  String _primaryColor = '#1E3A8A';
  String _secondaryColor = '#3B82F6';

  // Academic sessions
  List<dynamic> _sessions = [];
  int? _currentSessionId;
  String _currentSessionName = '';

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iemisCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _contactPersonCtrl.dispose();
    _contactEmailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _provinceCtrl.dispose();
    _countryCtrl.dispose();
    _missionCtrl.dispose();
    _visionCtrl.dispose();
    _aboutUsCtrl.dispose();
    _principalMsgCtrl.dispose();
    _paymentInstructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    final res = await _api.getSchoolSettings();
    if (!mounted) return;

    if (res.success && res.data != null) {
      final data = res.data!;
      _school = Map<String, dynamic>.from(data['school'] ?? {});
      _media = Map<String, dynamic>.from(data['media'] ?? {});
      _academic = Map<String, dynamic>.from(data['academic'] ?? {});
      _stats = Map<String, dynamic>.from(data['stats'] ?? {});

      _nameCtrl.text = _school['name'] ?? '';
      _iemisCtrl.text = _school['iemis_code'] ?? '';
      _emailCtrl.text = _school['email'] ?? '';
      _phoneCtrl.text = _school['phone'] ?? '';
      _websiteCtrl.text = _school['website'] ?? '';
      _contactPersonCtrl.text = _school['contact_person'] ?? '';
      _contactEmailCtrl.text = _school['contact_email'] ?? '';

      _addressCtrl.text = _school['address'] ?? '';
      _cityCtrl.text = _school['city'] ?? '';
      _districtCtrl.text = _school['district'] ?? '';
      _provinceCtrl.text = _school['province'] ?? '';
      _countryCtrl.text = _school['country'] ?? 'Nepal';

      _missionCtrl.text = _school['mission'] ?? '';
      _visionCtrl.text = _school['vision'] ?? '';
      _aboutUsCtrl.text = _school['about_us'] ?? '';
      _principalMsgCtrl.text = _school['principal_message'] ?? '';

      _paymentInstructionsCtrl.text = _school['payment_instructions'] ?? '';

      _primaryColor = _school['primary_color'] ?? '#1E3A8A';
      _secondaryColor = _school['secondary_color'] ?? '#3B82F6';

      final curSess = _academic['current_session'] as Map<String, dynamic>?;
      _currentSessionId = curSess?['id'];
      _currentSessionName = curSess?['session_name'] ?? '';
      _sessions = _academic['sessions'] as List<dynamic>? ?? [];

      setState(() => _isLoading = false);
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final payload = {
      'name': _nameCtrl.text.trim(),
      'iemis_code': _iemisCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'website': _websiteCtrl.text.trim(),
      'contact_person': _contactPersonCtrl.text.trim(),
      'contact_email': _contactEmailCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'district': _districtCtrl.text.trim(),
      'province': _provinceCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'mission': _missionCtrl.text.trim(),
      'vision': _visionCtrl.text.trim(),
      'about_us': _aboutUsCtrl.text.trim(),
      'principal_message': _principalMsgCtrl.text.trim(),
      'payment_instructions': _paymentInstructionsCtrl.text.trim(),
      'primary_color': _primaryColor,
      'secondary_color': _secondaryColor,
    };

    final res = await _api.updateSchoolSettings(payload);
    if (!mounted) return;

    setState(() => _isSaving = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.crimson,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _switchSession(int sessionId) async {
    final res = await _api.switchSchoolSession(sessionId);
    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.emerald,
        ),
      );
      _fetchSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _promptNewSessionModal() async {
    final textCtrl = TextEditingController(text: '2083-2084');
    bool setAsActive = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: const Text('Add Academic Year / Session'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the academic session title (e.g. 2083-2084 or 2026-2027):',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  decoration: InputDecoration(
                    labelText: 'Session Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Set as current active session', style: TextStyle(fontSize: 13)),
                  value: setAsActive,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.royalBlue,
                  onChanged: (v) => setDlgState(() => setAsActive = v ?? true),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
                onPressed: () async {
                  final name = textCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);

                  final res = await _api.createSchoolSession(name, setAsActive: setAsActive);
                  if (mounted) {
                    if (res.success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res.message), backgroundColor: AppTheme.emerald),
                      );
                      _fetchSettings();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
                      );
                    }
                  }
                },
                child: const Text('Create Session', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
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
            _buildHeaderBrandingCard(isDark),
            _buildTabBar(isDark),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.royalBlue))
                  : RefreshIndicator(
                      color: AppTheme.royalBlue,
                      onRefresh: _fetchSettings,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        child: _buildActiveTabContent(isDark),
                      ),
                    ),
            ),
            if (!_isLoading) _buildBottomSaveBar(isDark),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR & HEADER
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
                  'School Settings & Profile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.dark,
                  ),
                ),
                const Text(
                  'Institution Branding, QR Codes & Academic Year',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.royalBlue),
            onPressed: _fetchSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBrandingCard(bool isDark) {
    final logoUrl = _media['logo_url'] as String?;
    final schoolName = _school['name'] ?? 'Nepal School Hub';
    final iemis = _school['iemis_code'] ?? '-';
    final plan = (_school['plan'] ?? 'Enterprise').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.royalBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              image: logoUrl != null ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover) : null,
            ),
            child: logoUrl == null
                ? const Icon(Icons.account_balance_rounded, color: AppTheme.royalBlue, size: 26)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schoolName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.dark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.royalBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'IEMIS: $iemis',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.royalBlue),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        plan,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.emerald),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    final tabs = [
      {'id': 0, 'label': 'General Info'},
      {'id': 1, 'label': 'Academic Year'},
      {'id': 2, 'label': 'Payment QRs'},
      {'id': 3, 'label': 'Theme & Brand'},
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        itemBuilder: (ctx, idx) {
          final t = tabs[idx];
          final isSelected = _activeTab == t['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(t['label'] as String),
              selected: isSelected,
              selectedColor: AppTheme.royalBlue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.grey,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() => _activeTab = t['id'] as int),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB CONTENTS
  // ---------------------------------------------------------------------------

  Widget _buildActiveTabContent(bool isDark) {
    switch (_activeTab) {
      case 0:
        return _buildGeneralTab(isDark);
      case 1:
        return _buildAcademicSessionsTab(isDark);
      case 2:
        return _buildPaymentQRsTab(isDark);
      case 3:
        return _buildBrandingTab(isDark);
      default:
        return const SizedBox();
    }
  }

  // --- TAB 0: GENERAL & PHYSICAL INFO ---
  Widget _buildGeneralTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Basic Identity & Contact'),
        const SizedBox(height: 10),
        _buildTextField(_nameCtrl, 'School Legal Name *', isDark, icon: Icons.school_rounded),
        const SizedBox(height: 10),
        _buildTextField(_iemisCtrl, 'Govt IEMIS Code / Affiliation No', isDark, icon: Icons.tag_rounded),
        const SizedBox(height: 10),
        _buildTextField(_emailCtrl, 'Official School Email *', isDark, icon: Icons.email_rounded),
        const SizedBox(height: 10),
        _buildTextField(_phoneCtrl, 'Reception Phone Number', isDark, icon: Icons.phone_rounded),
        const SizedBox(height: 10),
        _buildTextField(_websiteCtrl, 'Website (e.g. https://yourschool.edu.np)', isDark, icon: Icons.language_rounded),
        const SizedBox(height: 10),
        _buildTextField(_contactPersonCtrl, 'Head of Administration / Principal', isDark, icon: Icons.person_rounded),
        const SizedBox(height: 10),
        _buildTextField(_contactEmailCtrl, 'Direct Contact Email', isDark, icon: Icons.contact_mail_rounded),

        const SizedBox(height: 24),
        const SectionHeader(title: 'Physical Location & Address (Nepal)'),
        const SizedBox(height: 10),
        _buildTextField(_addressCtrl, 'Street Address / Ward No', isDark, icon: Icons.location_on_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildTextField(_cityCtrl, 'Municipality / City', isDark)),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField(_districtCtrl, 'District (e.g. Kathmandu)', isDark)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildTextField(_provinceCtrl, 'Province (e.g. Bagmati)', isDark)),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField(_countryCtrl, 'Country', isDark)),
          ],
        ),

        const SizedBox(height: 24),
        const SectionHeader(title: 'Institutional Statements'),
        const SizedBox(height: 10),
        _buildTextField(_missionCtrl, 'School Mission', isDark, maxLines: 2),
        const SizedBox(height: 10),
        _buildTextField(_visionCtrl, 'School Vision', isDark, maxLines: 2),
        const SizedBox(height: 10),
        _buildTextField(_principalMsgCtrl, 'Principal\'s Message to Students & Parents', isDark, maxLines: 3),
      ],
    );
  }

  // --- TAB 1: ACADEMIC SESSIONS & YEAR ---
  Widget _buildAcademicSessionsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Active Academic Session'),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Session', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _promptNewSessionModal,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Current Active Hero Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.royalBlue.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT ACTIVE YEAR',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentSessionName.isNotEmpty ? _currentSessionName : 'Session Not Set',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'All daily attendance, marks, and enrollments apply to this academic year.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const SectionHeader(title: 'All Recorded Academic Sessions'),
        const SizedBox(height: 10),

        if (_sessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: const Text('No academic sessions recorded.', style: TextStyle(color: AppTheme.grey)),
          )
        else
          ..._sessions.map((sess) {
            final sMap = Map<String, dynamic>.from(sess as Map);
            final sId = sMap['id'] as int;
            final sName = sMap['session_name'] ?? '';
            final isCurrent = _currentSessionId == sId;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? AppTheme.emerald
                      : (isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7)),
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCurrent ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isCurrent ? AppTheme.emerald : AppTheme.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sName,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppTheme.dark,
                          ),
                        ),
                        if (sMap['created_at'] != null)
                          Text('Created: ${sMap['created_at']}', style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.emerald),
                      ),
                    )
                  else
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _switchSession(sId),
                      child: const Text('Switch Here', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // --- TAB 2: PAYMENT QR CODES & BANKING ---
  Widget _buildPaymentQRsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Digital Wallets & Bank QR Codes'),
        const Text(
          'Parents can scan these QR codes directly from the Parent App to pay school fees.',
          style: TextStyle(fontSize: 11, color: AppTheme.grey),
        ),
        const SizedBox(height: 14),

        // Grid of 4 Payment QR Types
        Row(
          children: [
            Expanded(
              child: _buildQrCard(
                title: 'eSewa QR',
                color: const Color(0xFF60BB46),
                url: _media['payment_qr_esewa_url'] as String?,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQrCard(
                title: 'Khalti QR',
                color: const Color(0xFF5C2D91),
                url: _media['payment_qr_khalti_url'] as String?,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQrCard(
                title: 'Fonepay QR',
                color: const Color(0xFFED1C24),
                url: _media['payment_qr_fonepay_url'] as String?,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQrCard(
                title: 'Bank Direct QR',
                color: AppTheme.royalBlue,
                url: _media['payment_qr_bank_url'] as String?,
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const SectionHeader(title: 'Payment Instructions for Parents'),
        const SizedBox(height: 10),
        _buildTextField(
          _paymentInstructionsCtrl,
          'Payment Instructions / Bank Account Number / IFSC / Remarks Guide',
          isDark,
          maxLines: 4,
          icon: Icons.notes_rounded,
        ),
      ],
    );
  }

  Widget _buildQrCard({
    required String title,
    required Color color,
    required String? url,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: color,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: url != null ? AppTheme.emerald : AppTheme.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              image: url != null ? DecorationImage(image: NetworkImage(url), fit: BoxFit.contain) : null,
            ),
            child: url == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 36, color: color.withOpacity(0.5)),
                      const SizedBox(height: 4),
                      const Text('No QR Uploaded', style: TextStyle(fontSize: 10, color: AppTheme.grey)),
                    ],
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            url != null ? 'Active QR Configured' : 'Upload via Web / QR scanner',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: url != null ? AppTheme.emerald : AppTheme.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- TAB 3: THEME & BRANDING ---
  Widget _buildBrandingTab(bool isDark) {
    final colors = [
      {'name': 'Royal Blue', 'hex': '#1E3A8A'},
      {'name': 'Emerald Green', 'hex': '#059669'},
      {'name': 'Crimson Red', 'hex': '#DC2626'},
      {'name': 'Purple Indigo', 'hex': '#7C3AED'},
      {'name': 'Amber Gold', 'hex': '#D97706'},
      {'name': 'Dark Slate', 'hex': '#0F172A'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Brand Primary Color'),
        const Text(
          'Used for app headers, buttons, student ID cards, and official reports.',
          style: TextStyle(fontSize: 11, color: AppTheme.grey),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((c) {
            final hex = c['hex']!;
            final isSel = _primaryColor.toLowerCase() == hex.toLowerCase();
            final colorVal = Color(int.parse(hex.replaceFirst('#', '0xFF')));

            return InkWell(
              onTap: () => setState(() => _primaryColor = hex),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? colorVal : (isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7)),
                    width: isSel ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: colorVal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      c['name']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.dark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        const SectionHeader(title: 'School Summary Stats'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _statCard('Total Students', '${_stats['total_students'] ?? 0}', AppTheme.royalBlue, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Faculty Staff', '${_stats['total_teachers'] ?? 0}', AppTheme.emerald, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Active Classes', '${_stats['total_classes'] ?? 0}', AppTheme.amber, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.grey, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    bool isDark, {
    int maxLines = 1,
    IconData? icon,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppTheme.dark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: AppTheme.grey),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: AppTheme.royalBlue) : null,
        filled: true,
        fillColor: isDark ? AppTheme.darkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF2F7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.royalBlue, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildBottomSaveBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: Text(
              _isSaving ? 'Saving Settings...' : 'Save School Settings',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.royalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            onPressed: _isSaving ? null : _saveSettings,
          ),
        ),
      ),
    );
  }
}
