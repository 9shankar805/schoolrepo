import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'visitor_manager_screen.dart';

class CrisisSosScreen extends StatefulWidget {
  const CrisisSosScreen({Key? key}) : super(key: key);

  @override
  State<CrisisSosScreen> createState() => _CrisisSosScreenState();
}

class _CrisisSosScreenState extends State<CrisisSosScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isDispatching = false;

  // Active Crisis State
  bool _isCrisisActive = false;
  Map<String, dynamic>? _activeCrisis;
  int _activeVisitorsCount = 0;

  // Templates
  List<dynamic> _templates = [];
  Map<String, dynamic>? _selectedTemplate;

  // Form Controllers
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _instructionsCtrl = TextEditingController();
  String _audience = 'all'; // all, parents, teachers, students
  String _severity = 'critical'; // critical, high, medium
  bool _channelPush = true;
  bool _channelSms = true;
  bool _channelNotice = true;

  // Crisis History
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadStatus(),
      _loadTemplates(),
      _loadHistory(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStatus() async {
    final res = await _api.getCrisisStatus();
    if (res.success && res.data != null && mounted) {
      setState(() {
        _isCrisisActive = res.data!['is_active'] == true;
        _activeCrisis = res.data!['active_crisis'] as Map<String, dynamic>?;
        _activeVisitorsCount = (res.data!['active_visitors_count'] as int?) ?? 0;
      });
    }
  }

  Future<void> _loadTemplates() async {
    final res = await _api.getCrisisTemplates();
    if (res.success && res.data != null && mounted) {
      setState(() {
        _templates = res.data!;
        if (_templates.isNotEmpty && _selectedTemplate == null) {
          _selectTemplate(_templates.first);
        }
      });
    }
  }

  Future<void> _loadHistory() async {
    final res = await _api.getCrisisHistory();
    if (res.success && res.data != null && mounted) {
      setState(() {
        _history = res.data!;
      });
    }
  }

  void _selectTemplate(dynamic tmpl) {
    setState(() {
      _selectedTemplate = tmpl;
      _titleCtrl.text = tmpl['title'] ?? '';
      _instructionsCtrl.text = tmpl['instructions'] ?? '';
      _audience = tmpl['default_audience'] ?? 'all';
      _severity = tmpl['severity'] ?? 'critical';
      final channels = (tmpl['channels'] as List<dynamic>?) ?? ['push', 'sms', 'notice'];
      _channelPush = channels.contains('push');
      _channelSms = channels.contains('sms');
      _channelNotice = channels.contains('notice');
    });
  }

  Future<void> _dispatchEmergencySos() async {
    final title = _titleCtrl.text.trim();
    final instructions = _instructionsCtrl.text.trim();

    if (title.isEmpty || instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an emergency title and instructions.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppTheme.crimson, size: 28),
            const SizedBox(width: 10),
            Text(
              'Confirm Crisis SOS',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.crimson),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are about to declare a HIGH-PRIORITY EMERGENCY CRISIS.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'This will instantly bypass background queues and broadcast loud push alerts and SMS messages to all selected recipients immediately.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.roseLight, borderRadius: BorderRadius.circular(10)),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.crimson, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimson,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DISPATCH SOS NOW', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDispatching = true);

    final List<String> activeChannels = [];
    if (_channelPush) activeChannels.add('push');
    if (_channelSms) activeChannels.add('sms');
    if (_channelNotice) activeChannels.add('notice');

    final res = await _api.dispatchCrisisSos({
      'template_id': _selectedTemplate?['id'] ?? 'custom',
      'title': title,
      'instructions': instructions,
      'audience': _audience,
      'severity': _severity,
      'channels': activeChannels,
    });

    setState(() => _isDispatching = false);

    if (mounted) {
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppTheme.crimson,
            duration: const Duration(seconds: 4),
          ),
        );
        _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: AppTheme.crimson),
        );
      }
    }
  }

  Future<void> _declareAllClear() async {
    final notesCtrl = TextEditingController(
      text: 'The campus emergency situation has safely resolved. All premises, transit routes, and operations have returned to normal standing. Thank you for your cooperation.',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 28),
            const SizedBox(width: 10),
            Text('Declare All-Clear', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will end the active lockdown and send an official All-Clear notification to all parents and staff.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'All-Clear Resolution Remarks'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Broadcast All-Clear', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final res = await _api.declareCrisisAllClear(notes: notesCtrl.text.trim());
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Crisis SOS & Lockdown Protocol',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.crimson,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.crimson,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'SOS Dispatch Command'),
            Tab(text: 'Alert Logs & History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.crimson))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDispatchTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: SOS DISPATCH COMMAND
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildDispatchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Lockdown Alert Banner (if active)
          if (_isCrisisActive && _activeCrisis != null) ...[
            _buildActiveCrisisBanner(),
            const SizedBox(height: 20),
          ],

          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ONE-TAP CRISIS TEMPLATES',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.crimson, letterSpacing: 0.5),
              ),
              Text(
                'Instant Pre-Fill',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Template Carousel / Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _templates.map((tmpl) {
                final isSelected = _selectedTemplate?['id'] == tmpl['id'];
                return GestureDetector(
                  onTap: () => _selectTemplate(tmpl),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.crimson : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.crimson : AppTheme.borderLight,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: AppTheme.crimson.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getTemplateIcon(tmpl['id']),
                              size: 18,
                              color: isSelected ? Colors.white : AppTheme.crimson,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tmpl['badge'] ?? 'ALERT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? Colors.white : AppTheme.crimson,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tmpl['name'] ?? 'Template',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppTheme.dark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Recommended Immediate Actions Box
          if (_selectedTemplate?['recommended_actions'] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist_rounded, size: 16, color: AppTheme.royalBlue),
                      const SizedBox(width: 6),
                      Text(
                        'CRISIS PROTOCOL CHECKLIST',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.royalBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...((_selectedTemplate!['recommended_actions'] as List<dynamic>)).map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.emerald),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              action.toString(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Broadcast Content Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BROADCAST MESSAGE SPECIFICATION',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),

                // Title
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Title *',
                    hintText: 'e.g. 🚨 RED ALERT: Full Campus Lockdown Protocol Active',
                  ),
                ),
                const SizedBox(height: 14),

                // Instructions
                TextField(
                  controller: _instructionsCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Crisis Instructions & Directive *',
                    hintText: 'Detail shelter-in-place instructions, gate closures, or bus route status...',
                  ),
                ),
                const SizedBox(height: 16),

                // Target Audience
                const Text('Target Audience', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _audience,
                  decoration: const InputDecoration(isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Campus (Parents, Staff & Students)')),
                    DropdownMenuItem(value: 'parents', child: Text('Parents & Guardians Only')),
                    DropdownMenuItem(value: 'teachers', child: Text('Faculty & Staff Only')),
                    DropdownMenuItem(value: 'students', child: Text('Students Only')),
                  ],
                  onChanged: (val) => setState(() => _audience = val ?? 'all'),
                ),
                const SizedBox(height: 16),

                // Multi-Channel Dispatch Toggles
                const Text('Immediate High-Priority Delivery Channels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppTheme.crimson,
                  title: const Text('High-Priority Push Notification (Alarm Sound Override)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Bypasses silent mode on parent & teacher devices', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  value: _channelPush,
                  onChanged: (val) => setState(() => _channelPush = val ?? true),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppTheme.crimson,
                  title: const Text('Instant SMS Gateway Broadcast', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: const Text('High-throughput SMS to all verified phone numbers', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  value: _channelSms,
                  onChanged: (val) => setState(() => _channelSms = val ?? true),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppTheme.crimson,
                  title: const Text('Urgent Notice Board Pin (Top Banner in Parent App)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Persistent red emergency banner on parent home screens', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  value: _channelNotice,
                  onChanged: (val) => setState(() => _channelNotice = val ?? true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Dispatch Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.crimson,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: AppTheme.crimson.withOpacity(0.5),
              ),
              icon: _isDispatching
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.campaign_rounded, size: 24, color: Colors.white),
              label: Text(
                _isDispatching ? 'DISPATCHING SOS TO CAMPUS...' : '🚨 DISPATCH CRISIS ALERT NOW',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              onPressed: _isDispatching ? null : _dispatchEmergencySos,
            ),
          ),
          const SizedBox(height: 20),

          // Quick Campus Roll Call Link
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.royalBlue.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.people_alt_rounded, color: AppTheme.royalBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Campus Roll Call',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      Text(
                        '$_activeVisitorsCount active visitors currently inside school premises',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.royalBlue,
                    side: const BorderSide(color: AppTheme.royalBlue),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VisitorManagerScreen()),
                    );
                  },
                  child: const Text('View Roster', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildActiveCrisisBanner() {
    final c = _activeCrisis!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.crimson,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.crimson.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.warning_rounded, color: AppTheme.crimson, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACTIVE CAMPUS CRISIS IN EFFECT',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                    Text(
                      c['title'] ?? 'Emergency Protocol Active',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            c['instructions'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dispatched: ${c['dispatched_at']}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                'SMS: ${c['sms_delivered'] ?? 0} • Push: ${c['push_delivered'] ?? 0}',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.white30),

          // 1-Tap All-Clear Declaration Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.emerald,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 20),
              label: const Text(
                'DECLARE ALL-CLEAR / RESOLVE CRISIS',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.3),
              ),
              onPressed: _declareAllClear,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTemplateIcon(String? id) {
    switch (id) {
      case 'severe_weather':
        return Icons.cloudy_snowing;
      case 'campus_lockdown':
        return Icons.shield_rounded;
      case 'bus_breakdown':
        return Icons.directions_bus_rounded;
      case 'power_hazard':
        return Icons.bolt_rounded;
      case 'medical_quarantine':
        return Icons.local_hospital_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: ALERT LOGS & HISTORY
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No past crisis declarations logged.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final alert = _history[i];
        final isAllClear = (alert['title'] ?? '').toString().contains('ALL CLEAR');
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAllClear ? AppTheme.emerald.withOpacity(0.4) : AppTheme.crimson.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAllClear ? AppTheme.emeraldLight : AppTheme.roseLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isAllClear ? 'RESOLVED' : 'EMERGENCY DISPATCH',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isAllClear ? AppTheme.emerald : AppTheme.crimson,
                      ),
                    ),
                  ),
                  Text(
                    alert['created_at'] ?? '',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                alert['title'] ?? '',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                alert['message'] ?? '',
                style: const TextStyle(fontSize: 12, color: AppTheme.dark, height: 1.3),
              ),
              const SizedBox(height: 8),
              Text(
                'Audience: ${alert['audience']}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}
