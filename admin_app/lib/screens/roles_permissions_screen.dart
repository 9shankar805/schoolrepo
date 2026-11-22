import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RolesPermissionsScreen extends StatefulWidget {
  const RolesPermissionsScreen({Key? key}) : super(key: key);

  @override
  State<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends State<RolesPermissionsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  List<dynamic> _roles = [];
  List<dynamic> _staffUsers = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getRoles(),
      _api.getStaffUsers(),
    ]);

    setState(() {
      _isLoading = false;
      if (results[0].success) _roles = results[0].data as List<dynamic>;
      if (results[1].success) _staffUsers = results[1].data as List<dynamic>;
    });
  }

  void _showRolePermissionsSheet(Map<String, dynamic> role) {
    final List<dynamic> perms = role['permissions'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role['display_name'] ?? role['name'],
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              Text(
                '${perms.length} Permissions Active • ${role['users_count']} Users Assigned',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const Divider(height: 24),
              Expanded(
                child: perms.isEmpty
                    ? const Center(child: Text('No explicit permissions granted to this role.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: perms.length,
                        itemBuilder: (c, i) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.emerald),
                          title: Text(perms[i].toString(), style: const TextStyle(fontSize: 13)),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignRoleDialog(Map<String, dynamic> staff) {
    String selectedRole = staff['role'] ?? 'teacher';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Assign Role for ${staff['name']}',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Primary Role: ${staff['role']}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              const Text('Select New Role:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRole,
                    isExpanded: true,
                    items: _roles.map<DropdownMenuItem<String>>((r) {
                      return DropdownMenuItem<String>(
                        value: r['name'].toString(),
                        child: Text(r['display_name'].toString(), style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.assignUserRoles(staff['id'], [selectedRole]);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res.message),
                      backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                    ),
                  );
                  if (res.success) _loadData();
                }
              },
              child: const Text('Confirm Role'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Roles & Permissions',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          tabs: [
            Tab(text: 'Defined Roles (${_roles.length})'),
            Tab(text: 'Staff Members (${_staffUsers.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Roles
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _roles.length,
                  itemBuilder: (ctx, idx) {
                    final r = _roles[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _showRolePermissionsSheet(r),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.royalBlue.withOpacity(0.1),
                          child: const Icon(Icons.shield_outlined, color: AppTheme.royalBlue, size: 20),
                        ),
                        title: Text(
                          r['display_name'] ?? r['name'],
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${r['permissions_count']} permissions granted',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${r['users_count']} Users',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalBlue, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Tab 2: Staff Assignment
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) async {
                          final res = await _api.getStaffUsers(query: val);
                          if (res.success) {
                            setState(() => _staffUsers = res.data as List<dynamic>);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Search staff by name or email...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _staffUsers.length,
                        itemBuilder: (ctx, idx) {
                          final s = _staffUsers[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => _showAssignRoleDialog(s),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryLight,
                                child: Text(
                                  s['name']?[0] ?? 'S',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
                                ),
                              ),
                              title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(s['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              trailing: Chip(
                                label: Text(
                                  (s['role'] ?? 'staff').toString().toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
                                ),
                                backgroundColor: AppTheme.primaryLight,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
