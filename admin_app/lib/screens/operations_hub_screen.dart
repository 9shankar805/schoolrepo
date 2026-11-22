import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'hostel_manager_screen.dart';
import 'discipline_pastoral_screen.dart';
import 'visitor_manager_screen.dart';
import 'certificate_manager_screen.dart';
import 'academic_calendar_screen.dart';
import 'campus_infirmary_screen.dart';
import 'crisis_sos_screen.dart';

class OperationsHubScreen extends StatefulWidget {
  const OperationsHubScreen({Key? key}) : super(key: key);

  @override
  State<OperationsHubScreen> createState() => _OperationsHubScreenState();
}

class _OperationsHubScreenState extends State<OperationsHubScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  List<dynamic> _hostels = [];
  Map<String, dynamic>? _library;
  List<dynamic> _inventory = [];
  List<dynamic> _auditLogs = [];

  // AI Chat
  final _aiPromptController = TextEditingController();
  final ScrollController _aiScrollController = ScrollController();
  final List<Map<String, String>> _aiMessages = [];
  bool _isAiReplying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadOperations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aiPromptController.dispose();
    _aiScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOperations() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getHostelOverview(),
      _api.getLibraryOverview(),
      _api.getInventoryOverview(),
      _api.getAuditLogs(),
    ]);

    setState(() {
      _isLoading = false;
      if (results[0].success) _hostels = results[0].data as List<dynamic>;
      if (results[1].success) _library = results[1].data as Map<String, dynamic>;
      if (results[2].success) {
        final inv = results[2].data as Map<String, dynamic>;
        _inventory = inv['data'] ?? [];
      }
      if (results[3].success) _auditLogs = results[3].data as List<dynamic>;
    });
  }

  Future<void> _sendAiMessage([String? prefilledText]) async {
    final text = prefilledText ?? _aiPromptController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _aiMessages.add({'role': 'user', 'content': text});
      _aiPromptController.clear();
      _isAiReplying = true;
    });

    // Scroll to bottom after adding user message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_aiScrollController.hasClients) {
        _aiScrollController.animateTo(
          _aiScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    final res = await _api.sendAiPrompt(text);

    setState(() {
      _isAiReplying = false;
      _aiMessages.add({
        'role': 'assistant',
        'content': res.data ?? 'Could not retrieve AI analysis.',
      });
    });

    // Scroll to bottom after adding assistant reply
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_aiScrollController.hasClients) {
        _aiScrollController.animateTo(
          _aiScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Operations & Logistics',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note_rounded, color: AppTheme.royalBlue),
            tooltip: 'Campus Calendar & Events',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AcademicCalendarScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.verified_user_rounded, color: AppTheme.secondary),
            tooltip: 'Document & Certificate Issuance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CertificateManagerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: AppTheme.amber),
            tooltip: 'Pastoral Care & Discipline',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DisciplinePastoralScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.badge_outlined, color: AppTheme.royalBlue),
            tooltip: 'Campus Visitors & Security',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VisitorManagerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.local_hospital_rounded, color: AppTheme.rose),
            tooltip: 'Campus Infirmary & Medical Health',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CampusInfirmaryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shield_rounded, color: AppTheme.crimson),
            tooltip: 'Crisis Alert & Lockdown SOS',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CrisisSosScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: const [
            Tab(text: 'Hostel'),
            Tab(text: 'Library'),
            Tab(text: 'Inventory'),
            Tab(text: 'Security Logs'),
            Tab(text: 'AI Copilot'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHostelTab(),
                _buildLibraryTab(),
                _buildInventoryTab(),
                _buildAuditLogsTab(),
                _buildAiCopilotTab(),
              ],
            ),
    );
  }

  Widget _buildHostelTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Action Card to Open Detailed Hostel Management
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.35),
                blurRadius: 14,
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
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bed, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hostel Command Center',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bed allocations, roll call & visitor logs',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.meeting_room, size: 18),
                  label: const Text('Open Hostel Manager & Allocate Beds'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.royalBlue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HostelManagerScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Active Residence Wings',
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_hostels.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No active hostel wings found.')),
          )
        else
          ..._hostels.map((h) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            h['name'] ?? 'Hostel Wing',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.royalBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${h['occupancy_pct']}% Occupied',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalBlue, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${h['type']} • ${h['address'] ?? 'Main Campus'}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatCol(label: 'Total Rooms', val: '${h['total_rooms']}'),
                          _StatCol(label: 'Total Beds', val: '${h['total_beds']}'),
                          _StatCol(label: 'Occupied', val: '${h['occupied_beds']}', color: AppTheme.crimson),
                          _StatCol(label: 'Available', val: '${h['available_beds']}', color: AppTheme.emerald),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildLibraryTab() {
    final summary = _library?['summary'] ?? {};
    final recent = (_library?['recent_books'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Titles', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text('${summary['total_titles'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Borrowed Books', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text('${summary['borrowed_copies'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.gold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Book Catalog', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...recent.map((b) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.book, color: AppTheme.royalBlue),
                  title: Text(b['title'] ?? 'Book', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${b['author']} • Shelf: ${b['shelf']}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  trailing: Text('${b['available']} in stock', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    if (_inventory.isEmpty) {
      return const Center(child: Text('No inventory items logged.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inventory.length,
      itemBuilder: (ctx, idx) {
        final i = _inventory[idx];
        final isLow = i['is_low_stock'] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.inventory_2, color: isLow ? AppTheme.crimson : AppTheme.royalBlue),
            title: Text(i['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('Category: ${i['category']} • NPR ${(i['unit_price'] as num).toInt()} / ${i['unit']}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLow ? AppTheme.crimsonLight : AppTheme.emeraldLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${i['quantity']} ${i['unit']}',
                style: TextStyle(color: isLow ? AppTheme.crimson : AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditLogsTab() {
    if (_auditLogs.isEmpty) {
      return const Center(child: Text('No audit logs recorded.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      itemBuilder: (ctx, idx) {
        final l = _auditLogs[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.security, size: 20, color: AppTheme.royalBlue),
            title: Text(l['event'] ?? 'Action', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('${l['user_name']} • Model: ${l['model']}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            trailing: Text(l['created_at'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ),
        );
      },
    );
  }

  Widget _buildAiCopilotTab() {
    return Column(
      children: [
        Expanded(
          child: _aiMessages.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 40),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 48, color: AppTheme.gold),
                            const SizedBox(height: 12),
                            Text(
                              'Executive AI Copilot',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Ask about today\'s attendance, cash collection velocity, upcoming exam schedules, or draft official school notices.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            // Suggested prompts
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                "Today's attendance summary",
                                'Outstanding fee defaulters',
                                'Exam schedule this week',
                              ]
                                  .map((prompt) => ActionChip(
                                        label: Text(prompt,
                                            style: const TextStyle(
                                                fontSize: 12)),
                                        avatar: const Icon(
                                            Icons.auto_awesome_rounded,
                                            size: 14,
                                            color: AppTheme.gold),
                                        backgroundColor:
                                            AppTheme.goldLight,
                                        onPressed: () =>
                                            _sendAiMessage(prompt),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _aiScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _aiMessages.length,
                  itemBuilder: (ctx, idx) {
                    final m = _aiMessages[idx];
                    final isUser = m['role'] == 'user';
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        constraints: const BoxConstraints(maxWidth: 290),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppTheme.royalBlue
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: isUser
                              ? null
                              : Border.all(color: AppTheme.borderLight),
                        ),
                        child: Text(
                          m['content'] ?? '',
                          style: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : AppTheme.textMain,
                              fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_isAiReplying)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('AI Copilot analyzing ERP database...',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
        // Input bar — padding handles keyboard inset
        Container(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            12 + MediaQuery.of(context).viewInsets.bottom,
          ),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _aiPromptController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendAiMessage(),
                  decoration: InputDecoration(
                    hintText: 'Ask AI Copilot...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: AppTheme.royalBlue),
                onPressed: _isAiReplying ? null : () => _sendAiMessage(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String val;
  final Color? color;

  const _StatCol({required this.label, required this.val, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color ?? AppTheme.textMain)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }
}
