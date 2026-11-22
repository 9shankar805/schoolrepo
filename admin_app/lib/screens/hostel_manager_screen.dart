import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HostelManagerScreen extends StatefulWidget {
  const HostelManagerScreen({Key? key}) : super(key: key);

  @override
  State<HostelManagerScreen> createState() => _HostelManagerScreenState();
}

class _HostelManagerScreenState extends State<HostelManagerScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic>? _summary;
  List<dynamic> _boarders = [];
  List<dynamic> _rooms = [];
  List<dynamic> _availableSlots = [];
  List<dynamic> _rollCallList = [];
  List<dynamic> _visitors = [];

  // Local state for roll call edits: Map<studentId, {status, remarks}>
  final Map<int, String> _rollCallStatus = {};
  final Map<int, String> _rollCallRemarks = {};

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllHostelData();
  }

  Future<void> _loadAllHostelData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getHostelManagerOverview(),
      _api.getHostelAvailableSlots(),
      _api.getHostelRollCall(),
      _api.getHostelVisitors(),
    ]);

    setState(() {
      _isLoading = false;
      if (results[0].success && results[0].data != null) {
        final d = results[0].data as Map<String, dynamic>;
        _summary = d['summary'];
        _boarders = d['boarders'] ?? [];
        _rooms = d['rooms'] ?? [];
      }
      if (results[1].success && results[1].data != null) {
        _availableSlots = results[1].data as List<dynamic>;
      }
      if (results[2].success && results[2].data != null) {
        _rollCallList = results[2].data as List<dynamic>;
        for (var item in _rollCallList) {
          final sId = item['student_id'] as int;
          _rollCallStatus[sId] = item['status'] ?? 'Present';
          if (item['remarks'] != null) {
            _rollCallRemarks[sId] = item['remarks'];
          }
        }
      }
      if (results[3].success && results[3].data != null) {
        _visitors = results[3].data as List<dynamic>;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Action: Add Student to Hostel (Allocation)
  // ---------------------------------------------------------------------------
  void _showAllocateStudentModal() {
    int? selectedStudentId;
    String? selectedStudentName;
    int? selectedRoomId;
    int? selectedBedId;
    List<dynamic> availableBedsInRoom = [];

    // Controller for student search
    final searchCtrl = TextEditingController();
    List<dynamic> studentSearchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Allocate Bed (Add to Hostel)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Step 1: Student Search
                    Text('1. Select Student', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type student name or roll...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: isSearching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                      ),
                      onChanged: (val) async {
                        if (val.trim().length >= 2) {
                          setModalState(() => isSearching = true);
                          final res = await _api.searchStudents(val.trim());
                          setModalState(() {
                            isSearching = false;
                            if (res.success && res.data != null) {
                              studentSearchResults = res.data ?? [];
                            }
                          });
                        }
                      },
                    ),

                    if (selectedStudentName != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: AppTheme.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.emerald, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Selected: $selectedStudentName', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald))),
                          ],
                        ),
                      ),
                    ] else if (studentSearchResults.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 140),
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.borderLight), borderRadius: BorderRadius.circular(8)),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: studentSearchResults.length,
                          itemBuilder: (c, i) {
                            final s = studentSearchResults[i];
                            return ListTile(
                              dense: true,
                              title: Text(s['name'] ?? 'Student'),
                              subtitle: Text('${s['class_name'] ?? 'Class'} • Roll #${s['roll_number'] ?? 'N/A'}'),
                              onTap: () {
                                setModalState(() {
                                  selectedStudentId = s['id'];
                                  selectedStudentName = '${s['name']} (${s['class_name']})';
                                  studentSearchResults = [];
                                  searchCtrl.clear();
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Step 2: Room selection
                    Text('2. Select Hostel Room', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    (() {
                      final uniqueRooms = <int, Map<String, dynamic>>{};
                      for (final r in _availableSlots) {
                        if (r is Map && r['room_id'] != null) {
                          uniqueRooms[r['room_id'] as int] = Map<String, dynamic>.from(r);
                        }
                      }
                      final items = uniqueRooms.values.map<DropdownMenuItem<int>>((r) {
                        final bedCount = (r['beds'] as List?)?.length ?? 0;
                        return DropdownMenuItem<int>(
                          value: r['room_id'] as int,
                          child: Text('Room ${r['room_number']} ($bedCount beds available)'),
                        );
                      }).toList();
                      final safeVal = uniqueRooms.containsKey(selectedRoomId) ? selectedRoomId : null;

                      return DropdownButtonFormField<int>(
                        decoration: const InputDecoration(hintText: 'Choose available room'),
                        value: safeVal,
                        items: items,
                        onChanged: (val) {
                          setModalState(() {
                            selectedRoomId = val;
                            selectedBedId = null;
                            final match = uniqueRooms[val];
                            availableBedsInRoom = match != null ? ((match['beds'] as List?) ?? []) : [];
                          });
                        },
                      );
                    })(),

                    const SizedBox(height: 16),

                    // Step 3: Bed selection
                    Text('3. Select Bed', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    (() {
                      final uniqueBeds = <int, Map<String, dynamic>>{};
                      for (final b in availableBedsInRoom) {
                        if (b is Map && b['bed_id'] != null) {
                          uniqueBeds[b['bed_id'] as int] = Map<String, dynamic>.from(b);
                        }
                      }
                      final items = uniqueBeds.values.map<DropdownMenuItem<int>>((b) {
                        return DropdownMenuItem<int>(
                          value: b['bed_id'] as int,
                          child: Text(b['bed_name'] ?? 'Bed'),
                        );
                      }).toList();
                      final safeVal = uniqueBeds.containsKey(selectedBedId) ? selectedBedId : null;

                      return DropdownButtonFormField<int>(
                        decoration: const InputDecoration(hintText: 'Choose vacant bed'),
                        value: safeVal,
                        items: items,
                        onChanged: (val) {
                          setModalState(() => selectedBedId = val);
                        },
                      );
                    })(),

                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.bed),
                        label: const Text('Confirm Bed Allocation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.royalBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: (selectedStudentId != null && selectedRoomId != null && selectedBedId != null)
                            ? () async {
                                Navigator.pop(ctx);
                                final res = await _api.allocateHostelBed(
                                  studentId: selectedStudentId!,
                                  hostelRoomId: selectedRoomId!,
                                  hostelBedId: selectedBedId!,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                                    ),
                                  );
                                  if (res.success) _loadAllHostelData();
                                }
                              }
                            : null,
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

  // ---------------------------------------------------------------------------
  // Action: Vacate Student Bed
  // ---------------------------------------------------------------------------
  void _confirmVacateBed(dynamic boarder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vacate Hostel Bed?'),
        content: Text(
          'Are you sure you want to check out ${boarder['student_name']} from Room ${boarder['room_number']} (${boarder['bed_name']})?\n\nThe bed will immediately be marked as Available for re-allocation.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.vacateHostelBed(boarder['allocation_id']);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.message),
                    backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                  ),
                );
                if (res.success) _loadAllHostelData();
              }
            },
            child: const Text('Vacate Bed'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action: Create New Room Modal
  // ---------------------------------------------------------------------------
  void _showCreateRoomModal() {
    final roomNumCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '4');
    final costCtrl = TextEditingController(text: '4000');
    final descCtrl = TextEditingController();
    String roomType = 'Non-AC';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Add Hostel Room', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: roomNumCtrl,
                      decoration: const InputDecoration(labelText: 'Room Number (e.g. 101, 202-A)', prefixIcon: Icon(Icons.meeting_room)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: capacityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Bed Capacity (1-10)', prefixIcon: Icon(Icons.people)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: roomType,
                            decoration: const InputDecoration(labelText: 'Type'),
                            items: const [
                              DropdownMenuItem(value: 'Non-AC', child: Text('Non-AC')),
                              DropdownMenuItem(value: 'AC', child: Text('AC Room')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => roomType = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cost Per Bed / Month (NPR)', prefixIcon: Icon(Icons.payments)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description / Amenities (Optional)', prefixIcon: Icon(Icons.info_outline)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Create Room & Auto-Generate Beds'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          final rNum = roomNumCtrl.text.trim();
                          final cap = int.tryParse(capacityCtrl.text.trim()) ?? 4;
                          final cost = double.tryParse(costCtrl.text.trim()) ?? 0;
                          if (rNum.isEmpty) return;

                          Navigator.pop(ctx);
                          final res = await _api.createHostelRoom(
                            roomNumber: rNum,
                            capacity: cap,
                            roomType: roomType,
                            costPerBed: cost,
                            description: descCtrl.text.trim(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                              ),
                            );
                            if (res.success) _loadAllHostelData();
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

  // ---------------------------------------------------------------------------
  // Action: Add Visitor Modal
  // ---------------------------------------------------------------------------
  void _showAddVisitorModal() {
    int? selectedStudentId;
    String? selectedStudentName;
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: 'Parent');
    final purpCtrl = TextEditingController();

    // Student search
    final searchCtrl = TextEditingController();
    List<dynamic> studentSearchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Log Hostel Visitor', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('1. Student Being Visited', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search boarder student...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: isSearching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                      ),
                      onChanged: (val) async {
                        if (val.trim().length >= 2) {
                          setModalState(() => isSearching = true);
                          final res = await _api.searchStudents(val.trim());
                          setModalState(() {
                            isSearching = false;
                            if (res.success && res.data != null) {
                              studentSearchResults = res.data ?? [];
                            }
                          });
                        }
                      },
                    ),
                    if (selectedStudentName != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: AppTheme.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.emerald, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Boarder: $selectedStudentName', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald))),
                          ],
                        ),
                      ),
                    ] else if (studentSearchResults.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.borderLight), borderRadius: BorderRadius.circular(8)),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: studentSearchResults.length,
                          itemBuilder: (c, i) {
                            final s = studentSearchResults[i];
                            return ListTile(
                              dense: true,
                              title: Text(s['name'] ?? 'Student'),
                              onTap: () {
                                setModalState(() {
                                  selectedStudentId = s['id'];
                                  selectedStudentName = s['name'];
                                  studentSearchResults = [];
                                  searchCtrl.clear();
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Visitor Full Name', prefixIcon: Icon(Icons.person_pin)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: relCtrl,
                      decoration: const InputDecoration(labelText: 'Relationship (Father, Mother, Brother)', prefixIcon: Icon(Icons.family_restroom)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: purpCtrl,
                      decoration: const InputDecoration(labelText: 'Purpose of Visit', prefixIcon: Icon(Icons.assignment)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.how_to_reg),
                        label: const Text('Record Visitor'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: (selectedStudentId != null && nameCtrl.text.trim().isNotEmpty)
                            ? () async {
                                Navigator.pop(ctx);
                                final res = await _api.recordHostelVisitor(
                                  studentId: selectedStudentId!,
                                  visitorName: nameCtrl.text.trim(),
                                  relation: relCtrl.text.trim(),
                                  purpose: purpCtrl.text.trim(),
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message), backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson),
                                  );
                                  if (res.success) _loadAllHostelData();
                                }
                              }
                            : null,
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

  // ---------------------------------------------------------------------------
  // Action: Save Evening Roll Call
  // ---------------------------------------------------------------------------
  Future<void> _submitRollCall() async {
    final records = _rollCallList.map((item) {
      final sId = item['student_id'] as int;
      return {
        'student_id': sId,
        'status': _rollCallStatus[sId] ?? 'Present',
        'remarks': _rollCallRemarks[sId],
      };
    }).toList();

    final res = await _api.saveHostelRollCall(records);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build Main Screen
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Hostel Operations Hub',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllHostelData,
            tooltip: 'Refresh data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: const [
            Tab(text: 'Boarders Roster'),
            Tab(text: 'Rooms & Beds'),
            Tab(text: 'Evening Roll Call'),
            Tab(text: 'Visitor Logs'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBoardersTab(),
                      _buildRoomsGridTab(),
                      _buildRollCallTab(),
                      _buildVisitorsTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildContextualFAB(),
    );
  }

  Widget? _buildContextualFAB() {
    return FloatingActionButton.extended(
        heroTag: null,
      backgroundColor: AppTheme.royalBlue,
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        _tabController.index == 1 ? 'Add Room' : (_tabController.index == 3 ? 'Log Visitor' : 'Add to Hostel'),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      onPressed: () {
        if (_tabController.index == 1) {
          _showCreateRoomModal();
        } else if (_tabController.index == 3) {
          _showAddVisitorModal();
        } else {
          _showAllocateStudentModal();
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Header: Quick KPIs
  // ---------------------------------------------------------------------------
  Widget _buildSummaryHeader() {
    if (_summary == null) return const SizedBox.shrink();

    final totalRooms = _summary!['total_rooms'] ?? 0;
    final totalBeds = _summary!['total_beds'] ?? 0;
    final occupied = _summary!['occupied_beds'] ?? 0;
    final available = _summary!['available_beds'] ?? 0;
    final occupancyPct = _summary!['occupancy_pct'] ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniKpi('Total Rooms', '$totalRooms', Icons.meeting_room, AppTheme.royalBlue),
          _buildMiniKpi('Total Beds', '$totalBeds', Icons.bed, Colors.indigo),
          _buildMiniKpi('Occupied', '$occupied', Icons.person, AppTheme.crimson),
          _buildMiniKpi('Vacant', '$available', Icons.check_circle_outline, AppTheme.emerald),
          _buildMiniKpi('Occupancy', '$occupancyPct%', Icons.pie_chart_outline, AppTheme.gold),
        ],
      ),
    );
  }

  Widget _buildMiniKpi(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Boarders Roster
  // ---------------------------------------------------------------------------
  Widget _buildBoardersTab() {
    final filtered = _boarders.where((b) {
      final name = (b['student_name'] ?? '').toString().toLowerCase();
      final room = (b['room_number'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || room.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search boarder name or room...',
              prefixIcon: const Icon(Icons.search),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bed_outlined, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('No boarders found.', style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Student to Hostel'),
                        onPressed: _showAllocateStudentModal,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final b = filtered[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
                              child: Text(
                                (b['student_name'] ?? 'S')[0],
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b['student_name'] ?? 'Student',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${b['class_name'] ?? 'Class'} • Admitted: ${b['start_date'] ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: AppTheme.royalBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text(
                                          'Room ${b['room_number']}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: AppTheme.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                        child: Text(
                                          b['bed_name'] ?? 'Bed',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, color: AppTheme.crimson),
                              tooltip: 'Vacate Bed',
                              onPressed: () => _confirmVacateBed(b),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Rooms & Beds Visual Grid
  // ---------------------------------------------------------------------------
  Widget _buildRoomsGridTab() {
    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.meeting_room_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('No hostel rooms created yet.'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create First Room'),
              onPressed: _showCreateRoomModal,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rooms.length,
      itemBuilder: (ctx, idx) {
        final r = _rooms[idx];
        final beds = (r['beds'] as List<dynamic>?) ?? [];
        final occupiedCount = r['occupied_beds'] ?? 0;
        final totalBeds = r['total_beds'] ?? beds.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.meeting_room, color: AppTheme.royalBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Room ${r['room_number']}',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            r['room_type'] ?? 'Standard',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$occupiedCount / $totalBeds Occupied',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: occupiedCount == totalBeds ? AppTheme.crimson : AppTheme.emerald,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Cost: NPR ${r['cost_per_bed']} / bed / month',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const Divider(height: 18),
                Text('Bed Status:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: beds.map<Widget>((b) {
                    final status = (b['status'] ?? 'Available').toString().toLowerCase();
                    final isOccupied = status == 'occupied';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOccupied ? AppTheme.crimson.withOpacity(0.1) : AppTheme.emerald.withOpacity(0.1),
                        border: Border.all(color: isOccupied ? AppTheme.crimson : AppTheme.emerald),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOccupied ? Icons.person : Icons.bed,
                            size: 14,
                            color: isOccupied ? AppTheme.crimson : AppTheme.emerald,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            b['name'] ?? 'Bed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isOccupied ? AppTheme.crimson : AppTheme.emerald,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOccupied ? '(Occ)' : '(Vacant)',
                            style: TextStyle(
                              fontSize: 10,
                              color: isOccupied ? AppTheme.crimson : AppTheme.emerald,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Evening Roll Call (Hostel Attendance)
  // ---------------------------------------------------------------------------
  Widget _buildRollCallTab() {
    if (_rollCallList.isEmpty) {
      return const Center(child: Text('No active boarders to take roll call.'));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Evening Roll Call (${_rollCallList.length} Boarders)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save Roll Call'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
                onPressed: _submitRollCall,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _rollCallList.length,
            itemBuilder: (ctx, idx) {
              final item = _rollCallList[idx];
              final sId = item['student_id'] as int;
              final currentStatus = _rollCallStatus[sId] ?? 'Present';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['student_name'] ?? 'Student',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Room ${item['room_number']} • ${item['bed_name']}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      // Segmented status buttons
                      Row(
                        children: [
                          _buildStatusChip(sId, 'Present', currentStatus == 'Present', AppTheme.emerald),
                          const SizedBox(width: 4),
                          _buildStatusChip(sId, 'Absent', currentStatus == 'Absent', AppTheme.crimson),
                          const SizedBox(width: 4),
                          _buildStatusChip(sId, 'Late', currentStatus == 'Late', Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(int studentId, String status, bool isSelected, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _rollCallStatus[studentId] = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Visitor Logs
  // ---------------------------------------------------------------------------
  Widget _buildVisitorsTab() {
    if (_visitors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('No recent hostel visitors logged.'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Log First Visitor'),
              onPressed: _showAddVisitorModal,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _visitors.length,
      itemBuilder: (ctx, idx) {
        final v = _visitors[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
              child: const Icon(Icons.person, color: AppTheme.royalBlue),
            ),
            title: Text(v['visitor_name'] ?? 'Visitor', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Visiting: ${v['student_name']} (${v['relation']})\nPurpose: ${v['purpose'] ?? 'General'} • In: ${v['in_time'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              v['date'] ?? '',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),
        );
      },
    );
  }
}
