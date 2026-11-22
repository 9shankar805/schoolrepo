import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({Key? key}) : super(key: key);

  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  List<dynamic> _events = [];
  Map<String, dynamic> _kpis = {
    'upcoming_events': 0,
    'holidays_this_month': 0,
    'exams_scheduled': 0,
    'ptm_scheduled': 0,
  };

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _selectedCategory = 'all';
  bool _onlyHolidays = false;
  String _selectedAudience = 'all';
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<Map<String, String>> _categories = [
    {'key': 'all', 'label': 'All Categories'},
    {'key': 'holiday', 'label': 'Holidays'},
    {'key': 'exam', 'label': 'Exams & Tests'},
    {'key': 'meeting', 'label': 'PTM & Meetings'},
    {'key': 'academic', 'label': 'Academic Terms'},
    {'key': 'sports', 'label': 'Sports & Athletics'},
    {'key': 'celebration', 'label': 'Celebrations'},
    {'key': 'vacation', 'label': 'Vacations'},
  ];

  static const List<String> _audiences = [
    'all',
    'students',
    'teachers',
    'staff',
    'parents',
  ];

  @override
  void initState() {
    super.initState();
    _loadOverview();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    final res = await _api.getEventsOverview();
    if (res.success && res.data != null) {
      if (mounted) {
        setState(() {
          _kpis = (res.data!['kpis'] as Map<String, dynamic>?) ?? _kpis;
        });
      }
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final res = await _api.getEvents(
      month: _selectedMonth,
      year: _selectedYear,
      category: _onlyHolidays ? 'holiday' : (_selectedCategory == 'all' ? null : _selectedCategory),
      isHoliday: _onlyHolidays ? true : null,
      audience: _selectedAudience == 'all' ? null : _selectedAudience,
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _events = res.success ? (res.data ?? []) : [];
      });
    }
  }

  Color _parseEventColor(String? hexString, String category) {
    if (hexString != null && hexString.startsWith('#') && hexString.length == 7) {
      final colorInt = int.tryParse(hexString.substring(1), radix: 16);
      if (colorInt != null) return Color(0xFF000000 | colorInt);
    }
    return switch (category) {
      'holiday' => AppTheme.crimson,
      'vacation' => AppTheme.orange,
      'exam' => AppTheme.secondary,
      'sports' => AppTheme.emerald,
      'meeting' => AppTheme.amber,
      'celebration' => Colors.pinkAccent,
      _ => AppTheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic Calendar & Events',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.dark),
            ),
            Text(
              'Term Schedules, Holidays & Campus Agenda',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            tooltip: 'Refresh Calendar',
            onPressed: () {
              _loadOverview();
              _loadEvents();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadOverview();
          await _loadEvents();
        },
        child: CustomScrollView(
          slivers: [
            // Telemetry Ribbon
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTelemetryCard(
                            title: 'Upcoming Events',
                            count: '${_kpis['upcoming_events'] ?? 0}',
                            subtitle: 'Campus Agenda',
                            color: AppTheme.primary,
                            icon: Icons.event_available_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTelemetryCard(
                            title: 'Holidays This Month',
                            count: '${_kpis['holidays_this_month'] ?? 0}',
                            subtitle: 'School Closures',
                            color: AppTheme.crimson,
                            icon: Icons.beach_access_rounded,
                            isAlert: (_kpis['holidays_this_month'] ?? 0) > 0,
                            onTap: () {
                              setState(() {
                                _onlyHolidays = !_onlyHolidays;
                              });
                              _loadEvents();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTelemetryCard(
                            title: 'Exams Scheduled',
                            count: '${_kpis['exams_scheduled'] ?? 0}',
                            subtitle: 'Assessment Periods',
                            color: AppTheme.secondary,
                            icon: Icons.history_edu_rounded,
                            onTap: () {
                              setState(() {
                                _selectedCategory = 'exam';
                                _onlyHolidays = false;
                              });
                              _loadEvents();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTelemetryCard(
                            title: 'PTM & Conferences',
                            count: '${_kpis['ptm_scheduled'] ?? 0}',
                            subtitle: 'Parent Interactions',
                            color: AppTheme.amber,
                            icon: Icons.groups_rounded,
                            onTap: () {
                              setState(() {
                                _selectedCategory = 'meeting';
                                _onlyHolidays = false;
                              });
                              _loadEvents();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Month / Year Navigation Strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                        onPressed: () {
                          setState(() {
                            if (_selectedMonth == 1) {
                              _selectedMonth = 12;
                              _selectedYear--;
                            } else {
                              _selectedMonth--;
                            }
                          });
                          _loadEvents();
                        },
                      ),
                      Expanded(
                        child: Text(
                          DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth)),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.dark,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onPressed: () {
                          setState(() {
                            if (_selectedMonth == 12) {
                              _selectedMonth = 1;
                              _selectedYear++;
                            } else {
                              _selectedMonth++;
                            }
                          });
                          _loadEvents();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Search Bar & Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search event, holiday, or venue...',
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.grey),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.grey, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _loadEvents();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _loadEvents(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Holiday quick toggle chip
                          InkWell(
                            onTap: () {
                              setState(() => _onlyHolidays = !_onlyHolidays);
                              _loadEvents();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _onlyHolidays ? AppTheme.crimson : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _onlyHolidays ? AppTheme.crimson : Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.beach_access_rounded, size: 14, color: _onlyHolidays ? Colors.white : AppTheme.crimson),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Holidays Only',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _onlyHolidays ? Colors.white : AppTheme.dark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ..._categories.map((c) {
                            final isSel = !_onlyHolidays && _selectedCategory == c['key'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(c['label']!),
                                selected: isSel,
                                selectedColor: AppTheme.primary,
                                labelStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel ? Colors.white : AppTheme.dark,
                                ),
                                onSelected: (val) {
                                  setState(() {
                                    _onlyHolidays = false;
                                    _selectedCategory = c['key']!;
                                  });
                                  _loadEvents();
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Events List
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_events.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 56, color: AppTheme.grey.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No Events Scheduled',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.dark),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No school events or holidays recorded for this period.\nTap "+ Add Event" to publish an event.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.grey),
                        ),
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
                      final item = _events[index];
                      return _buildEventCard(item);
                    },
                    childCount: _events.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Event',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        onPressed: _showAddEventSheet,
      ),
    );
  }

  Widget _buildEventCard(dynamic item) {
    final int id = item['id'] ?? 0;
    final String title = item['title'] ?? 'Event';
    final String category = (item['category'] ?? 'academic').toString().toLowerCase();
    final String categoryName = item['category_name'] ?? ucfirst(category);
    final bool isHoliday = (item['is_holiday'] as bool?) ?? false;
    final String dateLabel = item['date_label'] ?? 'N/A';
    final String timeLabel = item['time_label'] ?? '';
    final String audienceName = item['audience_name'] ?? 'All';
    final String venue = item['venue'] ?? 'Campus';
    final String? description = item['description'];
    final Color eventColor = _parseEventColor(item['color'], category);
    final bool isOngoing = (item['is_ongoing'] as bool?) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHoliday ? AppTheme.crimson.withOpacity(0.3) : Colors.grey.shade200,
          width: isHoliday ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: eventColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: eventColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  categoryName.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: eventColor,
                  ),
                ),
                if (isHoliday) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.crimson,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'HOLIDAY / CLOSED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (isOngoing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'HAPPENING NOW',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.grey),
                  onSelected: (val) {
                    if (val == 'delete') {
                      _confirmDeleteEvent(id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.crimson),
                          SizedBox(width: 8),
                          Text('Remove Event', style: TextStyle(color: AppTheme.crimson)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Event Body
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.dark,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.grey),
                    const SizedBox(width: 5),
                    Text(
                      dateLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.dark,
                      ),
                    ),
                    if (timeLabel.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.access_time_rounded, size: 13, color: AppTheme.grey),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.grey,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.grey),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        venue,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Target: $audienceName',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.dark),
                      ),
                    ),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Add Event Modal
  void _showAddEventSheet() {
    final TextEditingController titleCtrl = TextEditingController();
    String category = 'academic';
    bool isHoliday = false;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    String audience = 'all';
    final TextEditingController venueCtrl = TextEditingController(text: 'School Campus');
    final TextEditingController descCtrl = TextEditingController();
    bool sendNotification = true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Schedule Campus Event',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.dark,
                                ),
                              ),
                              Text(
                                'Publish to school calendar with instant push alert',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text('Event Title *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Annual Sports Meet 2026, Dashain Vacation, Mid-Term Exam',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category & Holiday Toggle
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Category *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: category,
                                    isExpanded: true,
                                    items: _categories
                                        .where((c) => c['key'] != 'all')
                                        .map((c) => DropdownMenuItem(value: c['key']!, child: Text(c['label']!, style: GoogleFonts.plusJakartaSans(fontSize: 13))))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          category = val;
                                          if (category == 'holiday' || category == 'vacation') {
                                            isHoliday = true;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Audience *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: audience,
                                    isExpanded: true,
                                    items: _audiences
                                        .map((a) => DropdownMenuItem(value: a, child: Text(a.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 12))))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => audience = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Date Pickers (Start & End)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final p = await showDatePicker(
                                    context: context,
                                    initialDate: startDate,
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now().add(const Duration(days: 730)),
                                  );
                                  if (p != null) {
                                    setModalState(() {
                                      startDate = p;
                                      if (endDate.isBefore(startDate)) endDate = startDate;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.grey),
                                      const SizedBox(width: 6),
                                      Text(DateFormat('yyyy-MM-dd').format(startDate), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Date *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final p = await showDatePicker(
                                    context: context,
                                    initialDate: endDate,
                                    firstDate: startDate,
                                    lastDate: DateTime.now().add(const Duration(days: 730)),
                                  );
                                  if (p != null) {
                                    setModalState(() => endDate = p);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.grey),
                                      const SizedBox(width: 6),
                                      Text(DateFormat('yyyy-MM-dd').format(endDate), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Venue & Location
                    Text('Venue / Location', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: venueCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Main Auditorium, School Ground, Lab 2',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    Text('Event Description & Details', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add agenda, schedule breakdown, or parent instructions...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Holiday switch
                    SwitchListTile(
                      value: isHoliday,
                      contentPadding: EdgeInsets.zero,
                      title: Text('Official School Closure / Holiday', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: Text('Classes suspended on these dates', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                      onChanged: (val) => setModalState(() => isHoliday = val),
                    ),

                    // Send push notification alert switch
                    SwitchListTile(
                      value: sendNotification,
                      contentPadding: EdgeInsets.zero,
                      title: Text('Broadcast Push Notification & Notice', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: Text('Dispatches real-time alert to $audience', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.grey)),
                      onChanged: (val) => setModalState(() => sendNotification = val),
                    ),
                    const SizedBox(height: 16),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          isSubmitting ? 'Scheduling...' : 'Publish to Calendar',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (titleCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an event title')));
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final res = await _api.createEvent({
                                  'title': titleCtrl.text.trim(),
                                  'category': category,
                                  'is_holiday': isHoliday,
                                  'start': DateFormat('yyyy-MM-dd').format(startDate),
                                  'end': DateFormat('yyyy-MM-dd').format(endDate),
                                  'audience': audience,
                                  'venue': venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim(),
                                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                                  'send_notification': sendNotification,
                                });

                                setModalState(() => isSubmitting = false);

                                if (res.success) {
                                  Navigator.pop(ctx);
                                  _loadOverview();
                                  _loadEvents();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Campus event scheduled successfully!')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message)),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteEvent(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Event?'),
        content: const Text('This will remove the event from the institutional calendar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.deleteEvent(id);
              if (res.success) {
                _loadOverview();
                _loadEvents();
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard({
    required String title,
    required String count,
    required String subtitle,
    required Color color,
    required IconData icon,
    bool isAlert = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAlert ? color : Colors.grey.shade200,
            width: isAlert ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Spacer(),
                if (isAlert)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              count,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.dark),
            ),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.grey),
            ),
          ],
        ),
      ),
    );
  }

  static String ucfirst(String str) {
    if (str.isEmpty) return str;
    return str[0].toUpperCase() + str.substring(1);
  }
}
