import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TransportManagerScreen extends StatefulWidget {
  const TransportManagerScreen({Key? key}) : super(key: key);

  @override
  State<TransportManagerScreen> createState() => _TransportManagerScreenState();
}

class _TransportManagerScreenState extends State<TransportManagerScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic>? _summary;
  List<dynamic> _vehicles = [];
  List<dynamic> _routes = [];
  List<dynamic> _passengers = [];
  List<dynamic> _documentAlerts = [];
  List<dynamic> _fuelLogs = [];

  // Attendance state
  String _selectedTrip = 'morning'; // morning, afternoon
  List<dynamic> _attendanceList = [];
  final Map<int, String> _attendanceStatus = {};
  bool _isLoadingAttendance = false;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadTransportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransportData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getTransportDashboard(),
      _api.getTransportVehicles(),
      _api.getTransportRoutes(),
      _api.getTransportPassengers(),
      _api.getTransportFuelLogs(),
    ]);

    setState(() {
      _isLoading = false;
      if (results[0].success && results[0].data != null) {
        final d = results[0].data as Map<String, dynamic>;
        _summary = d['summary'];
        _documentAlerts = d['document_alerts'] ?? [];
      }
      if (results[1].success && results[1].data != null) {
        _vehicles = results[1].data as List<dynamic>;
      }
      if (results[2].success && results[2].data != null) {
        _routes = results[2].data as List<dynamic>;
      }
      if (results[3].success && results[3].data != null) {
        _passengers = results[3].data as List<dynamic>;
      }
      if (results[4].success && results[4].data != null) {
        _fuelLogs = results[4].data as List<dynamic>;
      }
    });

    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoadingAttendance = true);
    final res = await _api.getTransportAttendance(trip: _selectedTrip);
    setState(() {
      _isLoadingAttendance = false;
      if (res.success && res.data != null) {
        _attendanceList = res.data!;
        for (var item in _attendanceList) {
          final sId = item['student_id'] as int;
          _attendanceStatus[sId] = item['status'] ?? 'present';
        }
      }
    });
  }

  Future<void> _toggleVehicleStatus(int id, String currentStatus) async {
    final nextStatus = currentStatus == 'active' ? 'maintenance' : 'active';
    final res = await _api.updateTransportVehicleStatus(id, status: nextStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
      if (res.success) _loadTransportData();
    }
  }

  // ---------------------------------------------------------------------------
  // Action: Register Vehicle Modal
  // ---------------------------------------------------------------------------
  void _showAddVehicleModal() {
    final nameCtrl = TextEditingController();
    final regCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '32');
    final makeCtrl = TextEditingController(text: 'Tata');
    final modelCtrl = TextEditingController();
    String fuelType = 'Diesel';
    String type = 'bus';

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
                        Text('Register Fleet Vehicle', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Bus Name / Identifier (e.g. Bus #03 Suryodaya)', prefixIcon: Icon(Icons.directions_bus)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: regCtrl,
                      decoration: const InputDecoration(labelText: 'Registration / License Plate (e.g. BA-2-KHA-9901)', prefixIcon: Icon(Icons.confirmation_number)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: capCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Seating Capacity', prefixIcon: Icon(Icons.airline_seat_recline_normal)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: type,
                            decoration: const InputDecoration(labelText: 'Vehicle Type'),
                            items: const [
                              DropdownMenuItem(value: 'bus', child: Text('School Bus')),
                              DropdownMenuItem(value: 'van', child: Text('Mini Van')),
                              DropdownMenuItem(value: 'micro', child: Text('Microbus')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => type = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: makeCtrl,
                            decoration: const InputDecoration(labelText: 'Make (Tata, Mahindra)', prefixIcon: Icon(Icons.business)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: fuelType,
                            decoration: const InputDecoration(labelText: 'Fuel Type'),
                            items: const [
                              DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                              DropdownMenuItem(value: 'Petrol', child: Text('Petrol')),
                              DropdownMenuItem(value: 'Electric', child: Text('Electric (EV)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => fuelType = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Vehicle to Fleet'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final reg = regCtrl.text.trim();
                          final cap = int.tryParse(capCtrl.text.trim()) ?? 30;
                          if (name.isEmpty || reg.isEmpty) return;

                          Navigator.pop(ctx);
                          final res = await _api.createTransportVehicle(
                            name: name,
                            registrationNumber: reg,
                            capacity: cap,
                            type: type,
                            make: makeCtrl.text.trim(),
                            fuelType: fuelType,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message), backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson),
                            );
                            if (res.success) _loadTransportData();
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
  // Action: Log Fuel Modal
  // ---------------------------------------------------------------------------
  void _showAddFuelModal() {
    if (_vehicles.isEmpty) return;

    int selectedVehicleId = _vehicles.first['id'];
    final litresCtrl = TextEditingController(text: '40');
    final rateCtrl = TextEditingController(text: '165');
    final odoCtrl = TextEditingController();
    final stationCtrl = TextEditingController(text: 'Campus Central Fuel');

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
                        Text('Record Fuel Purchase', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    (() {
                      final uniqueVehicles = <int, Map<String, dynamic>>{};
                      for (final v in _vehicles) {
                        if (v is Map && v['id'] != null) {
                          uniqueVehicles[v['id'] as int] = Map<String, dynamic>.from(v);
                        }
                      }
                      final items = uniqueVehicles.values.map<DropdownMenuItem<int>>((v) {
                        return DropdownMenuItem<int>(
                          value: v['id'] as int,
                          child: Text('${v['name']} (${v['registration_number']})'),
                        );
                      }).toList();
                      final safeVal = uniqueVehicles.containsKey(selectedVehicleId) ? selectedVehicleId : null;

                      return DropdownButtonFormField<int>(
                        value: safeVal,
                        decoration: const InputDecoration(labelText: 'Select Vehicle', prefixIcon: Icon(Icons.directions_bus)),
                        items: items,
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedVehicleId = val);
                        },
                      );
                    })(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: litresCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Quantity (Litres) *', prefixIcon: Icon(Icons.local_gas_station)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: rateCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Price / Litre (NPR)', prefixIcon: Icon(Icons.payments)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: odoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Odometer (KM)', prefixIcon: Icon(Icons.speed)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: stationCtrl,
                            decoration: const InputDecoration(labelText: 'Fuel Station Name', prefixIcon: Icon(Icons.store)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Save Fuel Entry'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          final litres = double.tryParse(litresCtrl.text.trim()) ?? 0;
                          final rate = double.tryParse(rateCtrl.text.trim()) ?? 0;
                          final odo = int.tryParse(odoCtrl.text.trim());
                          if (litres <= 0 || rate <= 0) return;

                          Navigator.pop(ctx);
                          final res = await _api.createTransportFuelLog(
                            vehicleId: selectedVehicleId,
                            litres: litres,
                            costPerLitre: rate,
                            odometerReading: odo,
                            fuelStation: stationCtrl.text.trim(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message), backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson),
                            );
                            if (res.success) _loadTransportData();
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
  // Action: Assign Student Passenger Modal
  // ---------------------------------------------------------------------------
  void _showAssignPassengerModal() {
    int? selectedStudentId;
    String? selectedStudentName;
    int? selectedRouteId = _routes.isNotEmpty ? _routes.first['id'] : null;

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
                        Text('Issue Student Bus Pass', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('1. Select Student', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search student name or roll...',
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
                              subtitle: Text('${s['class_name']} • Roll #${s['roll_number']}'),
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
                    const SizedBox(height: 14),
                    Text('2. Assign Route', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    (() {
                      final uniqueRoutes = <int, Map<String, dynamic>>{};
                      for (final r in _routes) {
                        if (r is Map && r['id'] != null) {
                          uniqueRoutes[r['id'] as int] = Map<String, dynamic>.from(r);
                        }
                      }
                      final items = uniqueRoutes.values.map<DropdownMenuItem<int>>((r) {
                        return DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text('${r['name']} (Fee: NPR ${r['monthly_fee']})'),
                        );
                      }).toList();
                      final safeVal = uniqueRoutes.containsKey(selectedRouteId) ? selectedRouteId : null;

                      return DropdownButtonFormField<int>(
                        value: safeVal,
                        decoration: const InputDecoration(labelText: 'Select Route', prefixIcon: Icon(Icons.alt_route)),
                        items: items,
                        onChanged: (val) {
                          setModalState(() => selectedRouteId = val);
                        },
                      );
                    })(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.directions_bus),
                        label: const Text('Enroll in School Transport'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: (selectedStudentId != null && selectedRouteId != null)
                            ? () async {
                                Navigator.pop(ctx);
                                final res = await _api.assignTransportPassenger(
                                  studentId: selectedStudentId!,
                                  routeId: selectedRouteId!,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message), backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson),
                                  );
                                  if (res.success) _loadTransportData();
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
  // Action: Save Boarding Attendance
  // ---------------------------------------------------------------------------
  Future<void> _submitAttendance() async {
    final records = _attendanceList.map((item) {
      final sId = item['student_id'] as int;
      return {
        'student_id': sId,
        'route_id': item['route_id'],
        'status': _attendanceStatus[sId] ?? 'present',
        'remarks': item['remarks'],
      };
    }).toList();

    final res = await _api.saveTransportAttendance(trip: _selectedTrip, records: records);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
        ),
      );
      if (res.success) _loadAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Transport & Fleet Hub',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTransportData),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: const [
            Tab(text: 'Fleet & Buses'),
            Tab(text: 'Routes & Stops'),
            Tab(text: 'Passengers (Passes)'),
            Tab(text: 'Boarding Attendance'),
            Tab(text: 'Fuel & Maintenance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryBar(),
                if (_documentAlerts.isNotEmpty) _buildAlertsBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVehiclesTab(),
                      _buildRoutesTab(),
                      _buildPassengersTab(),
                      _buildAttendanceTab(),
                      _buildFuelLogsTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildContextualFAB(),
    );
  }

  Widget? _buildContextualFAB() {
    if (_tabController.index == 3) {
      // Tab 3 is Boarding Attendance which has dedicated action controls
      return null;
    }
    return FloatingActionButton.extended(
      heroTag: null,
      backgroundColor: AppTheme.royalBlue,
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        _tabController.index == 2
            ? 'Issue Bus Pass'
            : (_tabController.index == 4 ? 'Log Fuel' : 'Add Vehicle'),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      onPressed: () {
        if (_tabController.index == 2) {
          _showAssignPassengerModal();
        } else if (_tabController.index == 4) {
          _showAddFuelModal();
        } else {
          _showAddVehicleModal();
        }
      },
    );
  }

  Widget _buildSummaryBar() {
    if (_summary == null) return const SizedBox.shrink();

    final vehicles = _summary!['total_vehicles'] ?? 0;
    final active = _summary!['active_vehicles'] ?? 0;
    final routes = _summary!['total_routes'] ?? 0;
    final passengers = _summary!['total_passengers'] ?? 0;
    final fuelCost = (_summary!['mtd_fuel_cost'] ?? 0).toDouble();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 24,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniKpi('Fleet', '$vehicles', Icons.directions_bus, AppTheme.royalBlue),
              const SizedBox(width: 8),
              _buildMiniKpi('Active', '$active', Icons.check_circle_outline, AppTheme.emerald),
              const SizedBox(width: 8),
              _buildMiniKpi('Routes', '$routes', Icons.alt_route, Colors.indigo),
              const SizedBox(width: 8),
              _buildMiniKpi('Passengers', '$passengers', Icons.people_outline, Colors.orange),
              const SizedBox(width: 8),
              _buildMiniKpi('MTD Fuel', 'NPR ${(fuelCost / 1000).toStringAsFixed(1)}k', Icons.local_gas_station, AppTheme.crimson),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniKpi(String label, String val, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(val, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildAlertsBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gold),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_documentAlerts.length} vehicle(s) have Fitness/Insurance expiring within 45 days.',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Vehicles
  // ---------------------------------------------------------------------------
  Widget _buildVehiclesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _vehicles.length,
      itemBuilder: (ctx, idx) {
        final v = _vehicles[idx];
        final isActive = v['status'] == 'active';

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
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.royalBlue.withOpacity(0.1) : AppTheme.crimson.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.directions_bus, color: isActive ? AppTheme.royalBlue : AppTheme.crimson, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v['name'] ?? 'School Bus',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  v['registration_number'] ?? 'No Plate',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.royalBlue, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _toggleVehicleStatus(v['id'], v['status']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.emerald.withOpacity(0.15) : AppTheme.crimson.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (v['status'] ?? 'active').toString().toUpperCase(),
                          style: TextStyle(color: isActive ? AppTheme.emerald : AppTheme.crimson, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Capacity: ${v['capacity']} Seats', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    Text('Route: ${v['route_name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin, size: 16, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text('Driver: ${v['driver_name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (v['driver_phone'] != null)
                      IconButton(
                        icon: const Icon(Icons.phone, size: 18, color: AppTheme.emerald),
                        onPressed: () => launchUrl(Uri.parse('tel:${v['driver_phone']}')),
                        tooltip: 'Call Driver',
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

  // ---------------------------------------------------------------------------
  // Tab 2: Routes
  // ---------------------------------------------------------------------------
  Widget _buildRoutesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _routes.length,
      itemBuilder: (ctx, idx) {
        final r = _routes[idx];
        final stops = (r['stops'] as List<dynamic>?) ?? [];

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
                    Expanded(
                      child: Text(
                        r['name'] ?? 'Route',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.royalBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text('${r['passengers_count']} Students', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalBlue)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Vehicle: ${r['vehicle_name']} (${r['registration_number']}) • Driver: ${r['driver_name']}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppTheme.emerald),
                    const SizedBox(width: 4),
                    Text('Morning: ${r['morning_departure']} -> ${r['morning_arrival']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text('Evening: ${r['afternoon_departure']} -> ${r['afternoon_arrival']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (stops.isNotEmpty) ...[
                  const Divider(height: 18),
                  Text('Route Stops (${stops.length}):', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: stops.map((s) {
                      return Chip(
                        label: Text(s['name'] ?? 'Stop', style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Passengers (Student Bus Passes)
  // ---------------------------------------------------------------------------
  Widget _buildPassengersTab() {
    final filtered = _passengers.where((p) {
      final name = (p['student_name'] ?? '').toString().toLowerCase();
      final route = (p['route_name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || route.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search passenger name or route...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No student bus passengers found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final p = filtered[idx];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
                          child: Text((p['student_name'] ?? 'S')[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalBlue)),
                        ),
                        title: Text(p['student_name'] ?? 'Student', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                        subtitle: Text('${p['class_name']} • ${p['route_name']}\nStop: ${p['stop_name']} • NPR ${p['monthly_fee']}/mo'),
                        trailing: IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: AppTheme.crimson),
                          tooltip: 'Cancel Bus Pass',
                          onPressed: () async {
                            final res = await _api.removeTransportPassenger(p['id']);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                              if (res.success) _loadTransportData();
                            }
                          },
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
  // Tab 4: Boarding Attendance
  // ---------------------------------------------------------------------------
  Widget _buildAttendanceTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trip Selector - Full width to avoid tight Row overflow
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 'morning',
                      label: Text('Morning Pickup'),
                      icon: Icon(Icons.wb_sunny_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 'afternoon',
                      label: Text('Evening Drop'),
                      icon: Icon(Icons.nights_stay_outlined, size: 16),
                    ),
                  ],
                  selected: {_selectedTrip},
                  onSelectionChanged: (set) {
                    setState(() => _selectedTrip = set.first);
                    _loadAttendance();
                  },
                ),
              ),
              if (_attendanceList.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_attendanceList.length} Passengers Assigned',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      label: const Text(
                        'Save Boarding',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _submitAttendance,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _isLoadingAttendance
              ? const Center(child: CircularProgressIndicator())
              : _attendanceList.isEmpty
                  ? const Center(child: Text('No passengers assigned to roll call.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount: _attendanceList.length,
                      itemBuilder: (ctx, idx) {
                        final item = _attendanceList[idx];
                        final sId = item['student_id'] as int;
                        final currentStatus = _attendanceStatus[sId] ?? 'present';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${item['class_name']} • ${item['route_name']} (${item['stop_name']})',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildAttendanceChip(sId, 'present', currentStatus == 'present', AppTheme.emerald),
                                    const SizedBox(width: 4),
                                    _buildAttendanceChip(sId, 'absent', currentStatus == 'absent', AppTheme.crimson),
                                    const SizedBox(width: 4),
                                    _buildAttendanceChip(sId, 'late', currentStatus == 'late', Colors.orange),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        if (_attendanceList.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Save Boarding Attendance',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.royalBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _submitAttendance,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAttendanceChip(int studentId, String status, bool isSelected, Color color) {
    return GestureDetector(
      onTap: () => setState(() => _attendanceStatus[studentId] = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : color),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 5: Fuel & Maintenance
  // ---------------------------------------------------------------------------
  Widget _buildFuelLogsTab() {
    if (_fuelLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_gas_station_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('No fuel logs recorded yet.'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Log First Fuel Purchase'),
              onPressed: _showAddFuelModal,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _fuelLogs.length,
      itemBuilder: (ctx, idx) {
        final f = _fuelLogs[idx];
        final total = (f['total_cost'] as num).toDouble();
        final litres = (f['litres'] as num).toDouble();

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.crimson.withOpacity(0.1),
              child: const Icon(Icons.local_gas_station, color: AppTheme.crimson),
            ),
            title: Text('${f['vehicle_name']} (${f['registration']})', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Qty: ${litres}L @ NPR ${f['cost_per_litre']} • Station: ${f['fuel_station']}\nDate: ${f['date']} • Odometer: ${f['odometer_reading'] ?? 'N/A'} KM'),
            trailing: Text(
              'NPR ${total.toStringAsFixed(0)}',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.crimson),
            ),
          ),
        );
      },
    );
  }
}
