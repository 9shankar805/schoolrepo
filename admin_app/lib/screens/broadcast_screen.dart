import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({Key? key}) : super(key: key);

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  // ── Broadcast tab ──────────────────────────────────────────────────────────
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetGroup = 'all';
  bool _isEmergency = false;
  bool _isSending = false;

  // ── Notice Board tab ───────────────────────────────────────────────────────
  bool _isLoadingNotices = false;
  List<dynamic> _notices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        _fetchNotices();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotices() async {
    setState(() => _isLoadingNotices = true);
    final res = await _api.getNotices();
    setState(() {
      _isLoadingNotices = false;
      if (res.success && res.data != null) _notices = res.data!;
    });
  }

  Future<void> _handleSendBroadcast() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill both title and message.')),
      );
      return;
    }
    setState(() => _isSending = true);
    final res = await _api.sendBroadcast(
      title: title,
      message: message,
      targetGroup: _targetGroup,
      isEmergency: _isEmergency,
    );
    setState(() => _isSending = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
      ));
      if (res.success) {
        _titleController.clear();
        _messageController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Broadcast & Notice Board',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: const [
            Tab(text: 'Broadcast Alert'),
            Tab(text: 'Notice Board'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBroadcastTab(),
          _buildNoticeBoardTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Broadcast ─────────────────────────────────────────────────────────

  Widget _buildBroadcastTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emergency toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isEmergency ? AppTheme.crimsonLight : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _isEmergency
                      ? AppTheme.crimson
                      : AppTheme.borderLight),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.crimson,
              title: Text(
                'Mark as Emergency Alert',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: _isEmergency ? AppTheme.crimson : AppTheme.textMain,
                ),
              ),
              subtitle: const Text(
                'Triggers loud push notification override on parent and teacher phones.',
                style: TextStyle(fontSize: 12),
              ),
              value: _isEmergency,
              onChanged: (val) => setState(() => _isEmergency = val),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Audience Target',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _targetGroup,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                      value: 'all',
                      child: Text('All Campus (Parents, Teachers & Students)')),
                  DropdownMenuItem(
                      value: 'parents',
                      child: Text('Parents & Guardians Only')),
                  DropdownMenuItem(
                      value: 'teachers',
                      child: Text('Teaching Staff Only')),
                  DropdownMenuItem(
                      value: 'students', child: Text('Students Only')),
                ],
                onChanged: (val) => setState(() => _targetGroup = val!),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Broadcast Title',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'e.g. Weather Holiday Notice / Early Dismissal',
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Announcement Message',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText:
                  'Type your official message here. It will be published to the mobile app notices and sent as an immediate push alert.',
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _handleSendBroadcast,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: const Text('Dispatch School Broadcast'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isEmergency ? AppTheme.crimson : AppTheme.royalBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Notice Board ──────────────────────────────────────────────────────

  Widget _buildNoticeBoardTab() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.royalBlue,
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
        label: const Text('Post Notice',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showCreateNoticeSheet,
      ),
      body: _isLoadingNotices
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchNotices,
              child: _notices.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.campaign_outlined,
                                  size: 56, color: AppTheme.textMuted),
                              const SizedBox(height: 12),
                              Text('No notices published yet.',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textMuted,
                                      fontSize: 15)),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap + Post Notice to create a formal school notice.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _notices.length,
                      itemBuilder: (ctx, idx) {
                        final n = _notices[idx];
                        final audience =
                            n['audience'] ?? n['target_group'] ?? 'all';
                        final priority =
                            n['priority'] ?? 'normal';
                        final priorityColor = priority == 'urgent'
                            ? AppTheme.crimson
                            : (priority == 'important'
                                ? AppTheme.gold
                                : AppTheme.royalBlue);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n['title'] ?? 'Notice',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: priorityColor
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        priority.toUpperCase(),
                                        style: TextStyle(
                                            color: priorityColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.royalBlue
                                            .withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        audience.toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.royalBlue,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      n['created_at'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                                if ((n['notice'] ?? n['body'] ?? '')
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    n['notice'] ?? n['body'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  void _showCreateNoticeSheet() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String audience = 'all';
    String priority = 'normal';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: AppTheme.iosHandle()),
              const SizedBox(height: 16),
              Text('Post School Notice',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),

              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Notice Title *',
                    hintText:
                        'e.g. Annual Sports Day Announcement'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Notice Body *',
                    hintText:
                        'Write the full notice text here...'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: audience,
                      decoration:
                          const InputDecoration(labelText: 'Audience'),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All')),
                        DropdownMenuItem(
                            value: 'parents', child: Text('Parents')),
                        DropdownMenuItem(
                            value: 'teachers',
                            child: Text('Teachers')),
                        DropdownMenuItem(
                            value: 'students',
                            child: Text('Students')),
                      ],
                      onChanged: (val) =>
                          setS(() => audience = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: priority,
                      decoration:
                          const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(
                            value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(
                            value: 'important',
                            child: Text('Important')),
                        DropdownMenuItem(
                            value: 'urgent', child: Text('Urgent')),
                      ],
                      onChanged: (val) =>
                          setS(() => priority = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          final body = bodyCtrl.text.trim();
                          if (title.isEmpty || body.isEmpty) return;
                          setS(() => isSaving = true);
                          final res = await _api.createNotice(
                            title: title,
                            body: body,
                            audience: audience,
                            priority: priority,
                          );
                          setS(() => isSaving = false);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                              content: Text(res.message),
                              backgroundColor: res.success
                                  ? AppTheme.emerald
                                  : AppTheme.crimson,
                            ));
                            if (res.success) _fetchNotices();
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.publish_rounded),
                  label: const Text('Publish Notice'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
