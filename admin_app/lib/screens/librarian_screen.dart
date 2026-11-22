import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LibrarianScreen extends StatefulWidget {
  const LibrarianScreen({Key? key}) : super(key: key);

  @override
  State<LibrarianScreen> createState() => _LibrarianScreenState();
}

class _LibrarianScreenState extends State<LibrarianScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;

  // Tab 1: Circulation
  List<dynamic> _circulationList = [];
  Map<String, dynamic> _circulationCounts = {};
  String _circulationStatus = 'all'; // all, active, overdue, returned
  String _circulationSearch = '';

  // Tab 2: Books Catalog
  List<dynamic> _booksList = [];
  Map<String, dynamic> _bookCounts = {};
  String _bookSearch = '';
  String _bookAvailability = 'all'; // all, available, borrowed_out

  // Tab 3: Members & Defaulters
  List<dynamic> _membersList = [];
  String _memberSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchDashboard(),
      _fetchCirculation(),
      _fetchBooks(),
      _fetchMembers(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDashboard() async {
    final res = await _api.getLibrarianDashboard();
    if (res.success && res.data != null) {
      _dashboardData = res.data;
    }
  }

  Future<void> _fetchCirculation() async {
    final res = await _api.getLibrarianCirculation(
      status: _circulationStatus,
      search: _circulationSearch,
    );
    if (res.success && res.data != null) {
      _circulationList = res.data!['data'] ?? [];
      _circulationCounts = res.data!['counts'] ?? {};
    }
  }

  Future<void> _fetchBooks() async {
    final res = await _api.getLibrarianBooks(
      search: _bookSearch,
      availability: _bookAvailability,
    );
    if (res.success && res.data != null) {
      _booksList = res.data!['data'] ?? [];
      _bookCounts = res.data!['counts'] ?? {};
    }
  }

  Future<void> _fetchMembers() async {
    final res = await _api.getLibrarianMembers(search: _memberSearch);
    if (res.success && res.data != null) {
      _membersList = res.data!['data'] ?? [];
    }
  }

  // --- ACTIONS ---

  void _showIssueBookModal([int? preselectedBookId]) {
    int? selectedBookId = preselectedBookId;
    int? selectedMemberId;
    int loanDays = 14;
    double finePerDay = 10.0;
    final notesCtrl = TextEditingController();

    // Available books only
    final availableBooks = _booksList.where((b) => (b['available_qty'] ?? 0) > 0).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
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
                Text(
                  'Issue Book to Member',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),

                // Select Book
                Text('Select Book', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                (() {
                  final uniqueBooks = <int, Map<String, dynamic>>{};
                  for (final b in availableBooks) {
                    if (b is Map && b['id'] != null) {
                      uniqueBooks[b['id'] as int] = Map<String, dynamic>.from(b);
                    }
                  }
                  final items = uniqueBooks.values.map<DropdownMenuItem<int>>((b) {
                    return DropdownMenuItem<int>(
                      value: b['id'] as int,
                      child: Text(
                        '${b['title']} (${b['available_qty']} in stock)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList();
                  final safeVal = uniqueBooks.containsKey(selectedBookId) ? selectedBookId : null;

                  return DropdownButtonFormField<int>(
                    value: safeVal,
                    isExpanded: true,
                    hint: const Text('Choose a book in stock...'),
                    items: items,
                    onChanged: (val) => setModalState(() => selectedBookId = val),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  );
                })(),
                const SizedBox(height: 14),

                // Select Member
                Text('Borrower (Student / Staff)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                (() {
                  final uniqueMembers = <int, Map<String, dynamic>>{};
                  for (final m in _membersList) {
                    if (m is Map && m['id'] != null) {
                      uniqueMembers[m['id'] as int] = Map<String, dynamic>.from(m);
                    }
                  }
                  final items = uniqueMembers.values.map<DropdownMenuItem<int>>((m) {
                    final remaining = m['remaining_quota'] ?? 0;
                    return DropdownMenuItem<int>(
                      value: m['id'] as int,
                      child: Text(
                        '${m['name']} (${m['card_number']}) • Quota: $remaining',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: remaining <= 0 ? Colors.grey : Colors.black87,
                        ),
                      ),
                    );
                  }).toList();
                  final safeVal = uniqueMembers.containsKey(selectedMemberId) ? selectedMemberId : null;

                  return DropdownButtonFormField<int>(
                    value: safeVal,
                    isExpanded: true,
                    hint: const Text('Choose library member...'),
                    items: items,
                    onChanged: (val) => setModalState(() => selectedMemberId = val),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  );
                })(),
                const SizedBox(height: 14),

                // Loan Days & Fine Rate
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Loan Days', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: loanDays,
                            items: [7, 14, 21, 30].map((d) => DropdownMenuItem(value: d, child: Text('$d Days'))).toList(),
                            onChanged: (val) => setModalState(() => loanDays = val ?? 14),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fine / Day (NPR)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<double>(
                            value: finePerDay,
                            items: [5.0, 10.0, 20.0, 50.0].map((f) => DropdownMenuItem(value: f, child: Text('NPR ${f.toInt()}'))).toList(),
                            onChanged: (val) => setModalState(() => finePerDay = val ?? 10.0),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text('Notes (Optional)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Reference only or Semester project',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
                    onPressed: (selectedBookId != null && selectedMemberId != null)
                        ? () async {
                            Navigator.pop(ctx);
                            final res = await _api.issueLibrarianBook(
                              bookId: selectedBookId!,
                              memberId: selectedMemberId!,
                              loanDays: loanDays,
                              finePerDay: finePerDay,
                              notes: notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                              ),
                            );

                            if (res.success) {
                              _refreshAll();
                            }
                          }
                        : null,
                    child: const Text('Confirm Book Issue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReturnModal(Map<String, dynamic> issue) {
    final int issueId = issue['id'];
    final String bookTitle = issue['book_title'] ?? 'Book';
    final String borrower = issue['borrower_name'] ?? 'Borrower';
    final double fineAmount = (issue['fine_amount'] ?? 0).toDouble();
    bool collectFineNow = fineAmount > 0;
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
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
              Text(
                'Process Book Return',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bookTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Borrower: $borrower (${issue['card_number']})', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text('Due Date: ${issue['due_date']}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (fineAmount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.roseLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 20),
                              SizedBox(width: 8),
                              Text('Overdue Fine Assessed', style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Text('NPR ${fineAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.w900, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Collect Cash Fine Immediately', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Marks fine as PAID and issues digital receipt', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        value: collectFineNow,
                        activeColor: AppTheme.emerald,
                        onChanged: (val) => setModalState(() => collectFineNow = val ?? false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              Text('Return Condition Notes', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Good condition, normal wear and tear',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final res = await _api.returnLibrarianBook(
                      issueId,
                      notes: notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                      collectFineNow: collectFineNow,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                      ),
                    );

                    if (res.success) {
                      _refreshAll();
                    }
                  },
                  child: const Text('Confirm Return to Shelf'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddBookModal() {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final isbnCtrl = TextEditingController();
    final shelfCtrl = TextEditingController(text: 'Main Library - Rack 1');
    final qtyCtrl = TextEditingController(text: '5');
    final publisherCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '450');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
              Text(
                'Add New Title to Catalog',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Book Title *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: authorCtrl,
                decoration: const InputDecoration(labelText: 'Author Name *'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: isbnCtrl,
                      decoration: const InputDecoration(labelText: 'ISBN'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Copies (Qty) *'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shelfCtrl,
                decoration: const InputDecoration(labelText: 'Shelf Location'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: publisherCtrl,
                      decoration: const InputDecoration(labelText: 'Publisher'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price (NPR)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || authorCtrl.text.isEmpty) return;
                    Navigator.pop(ctx);
                    final res = await _api.createLibrarianBook(
                      title: titleCtrl.text,
                      author: authorCtrl.text,
                      isbn: isbnCtrl.text.isNotEmpty ? isbnCtrl.text : null,
                      shelfLocation: shelfCtrl.text.isNotEmpty ? shelfCtrl.text : null,
                      qty: int.tryParse(qtyCtrl.text) ?? 1,
                      publisher: publisherCtrl.text.isNotEmpty ? publisherCtrl.text : null,
                      price: double.tryParse(priceCtrl.text) ?? 0,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                      ),
                    );

                    if (res.success) {
                      _refreshAll();
                    }
                  },
                  child: const Text('Save to Catalog'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final summary = _dashboardData?['summary'] ?? {};

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Library Circulation Hub',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${auth.adminName} • Book Issue & Overdue Fines',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Issue Book to Member',
            onPressed: () => _showIssueBookModal(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
            tooltip: 'Refresh Library Catalog & Loans',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.royalBlue,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.sync_alt, size: 18), text: 'Circulation'),
            Tab(icon: Icon(Icons.menu_book, size: 18), text: 'Book Catalog'),
            Tab(icon: Icon(Icons.warning_amber_rounded, size: 18), text: 'Overdue Fines'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.royalBlue,
        icon: const Icon(Icons.post_add, color: Colors.white),
        label: const Text('Issue Book', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showIssueBookModal(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCirculationTab(summary),
                _buildBooksCatalogTab(),
                _buildOverdueFinesTab(summary),
              ],
            ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: CIRCULATION (ISSUE & RETURN)
  // -------------------------------------------------------------
  Widget _buildCirculationTab(Map<String, dynamic> summary) {
    final activeLoans = summary['active_loans'] ?? 0;
    final overdueCount = summary['overdue_count'] ?? 0;
    final pendingFines = (summary['total_pending_fines'] ?? 0).toDouble();

    return Column(
      children: [
        // Quick Pulse Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildMiniMetric('Active Loans', '$activeLoans', AppTheme.royalBlue, AppTheme.primaryLight),
              const SizedBox(width: 8),
              _buildMiniMetric('Overdue', '$overdueCount', AppTheme.crimson, AppTheme.roseLight),
              const SizedBox(width: 8),
              _buildMiniMetric('Pending Fines', 'NPR ${pendingFines.toInt()}', AppTheme.amber, AppTheme.amberLight),
            ],
          ),
        ),

        // Filter & Search
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search borrower, card #, or book...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _circulationSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() => _circulationSearch = '');
                            _fetchCirculation();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onSubmitted: (val) {
                  setState(() => _circulationSearch = val);
                  _fetchCirculation();
                },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCirculationFilterPill('All Loans', 'all'),
                    const SizedBox(width: 8),
                    _buildCirculationFilterPill('Active Loans', 'active'),
                    const SizedBox(width: 8),
                    _buildCirculationFilterPill('Overdue ($overdueCount)', 'overdue'),
                    const SizedBox(width: 8),
                    _buildCirculationFilterPill('Returned', 'returned'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Circulation List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchCirculation,
            child: _circulationList.isEmpty
                ? _buildEmptyState('No circulation records found.')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _circulationList.length,
                    itemBuilder: (ctx, idx) {
                      final item = _circulationList[idx];
                      final isReturned = item['status'] == 'returned';
                      final isOverdue = item['status'] == 'overdue';
                      final fineAmount = (item['fine_amount'] ?? 0).toDouble();
                      final finePending = item['fine_status'] == 'pending';
                      final phone = item['borrower_phone'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isOverdue ? AppTheme.crimson.withOpacity(0.4) : AppTheme.borderLight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isReturned
                                        ? AppTheme.emeraldLight
                                        : (isOverdue ? AppTheme.roseLight : AppTheme.primaryLight),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isReturned
                                        ? Icons.check_circle_outline
                                        : (isOverdue ? Icons.warning_amber_rounded : Icons.bookmark_added_outlined),
                                    color: isReturned
                                        ? AppTheme.emerald
                                        : (isOverdue ? AppTheme.crimson : AppTheme.royalBlue),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['book_title'] ?? 'Book Title',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '${item['borrower_name']} • ${item['card_number']}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                          ),
                                          if (phone != null && phone.toString().isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => launchUrl(Uri.parse('tel:$phone')),
                                              child: const Icon(Icons.phone_outlined, size: 12, color: AppTheme.royalBlue),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isReturned
                                        ? AppTheme.emeraldLight
                                        : (isOverdue ? AppTheme.roseLight : AppTheme.primaryLight),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isReturned ? 'RETURNED' : (isOverdue ? 'OVERDUE' : 'ACTIVE LOAN'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isReturned
                                          ? AppTheme.emerald
                                          : (isOverdue ? AppTheme.crimson : AppTheme.royalBlue),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Issued: ${item['issue_date']} • Due: ${item['due_date']}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                                if (fineAmount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: finePending ? AppTheme.roseLight : AppTheme.emeraldLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${finePending ? "FINE DUE" : "FINE PAID"}: NPR ${fineAmount.toInt()}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: finePending ? AppTheme.crimson : AppTheme.emerald,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (!isReturned) ...[
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      side: const BorderSide(color: AppTheme.emerald),
                                    ),
                                    icon: const Icon(Icons.assignment_return_outlined, size: 14, color: AppTheme.emerald),
                                    label: const Text('Process Return', style: TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                                    onPressed: () => _showReturnModal(item),
                                  ),
                                ],
                              ),
                            ] else if (finePending) ...[
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: AppTheme.amber,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.payments_outlined, size: 14),
                                    label: Text('Collect Fine (NPR ${fineAmount.toInt()})', style: const TextStyle(fontSize: 12)),
                                    onPressed: () async {
                                      final res = await _api.collectLibrarianFine(item['id']);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res.message),
                                          backgroundColor: res.success ? AppTheme.emerald : AppTheme.crimson,
                                        ),
                                      );
                                      if (res.success) _refreshAll();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 2: BOOK CATALOG & INVENTORY
  // -------------------------------------------------------------
  Widget _buildBooksCatalogTab() {
    final total = _bookCounts['total'] ?? _booksList.length;
    final available = _bookCounts['available'] ?? 0;
    final depleted = _bookCounts['depleted'] ?? 0;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search title, author, ISBN, shelf...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _bookSearch.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() => _bookSearch = '');
                                  _fetchBooks();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (val) {
                        setState(() => _bookSearch = val);
                        _fetchBooks();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.royalBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Title', style: TextStyle(fontSize: 12)),
                    onPressed: _showAddBookModal,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBookFilterPill('All Titles ($total)', 'all'),
                    const SizedBox(width: 8),
                    _buildBookFilterPill('Available ($available)', 'available'),
                    const SizedBox(width: 8),
                    _buildBookFilterPill('Depleted ($depleted)', 'borrowed_out'),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchBooks,
            child: _booksList.isEmpty
                ? _buildEmptyState('No books found in catalog matching search.')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _booksList.length,
                    itemBuilder: (ctx, idx) {
                      final b = _booksList[idx];
                      final isAvailable = b['is_available'] == true;
                      final availableQty = b['available_qty'] ?? 0;
                      final totalQty = b['qty'] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 58,
                              decoration: BoxDecoration(
                                color: isAvailable ? AppTheme.primaryLight : AppTheme.roseLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.menu_book,
                                color: isAvailable ? AppTheme.royalBlue : AppTheme.crimson,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b['title'] ?? 'Book Title',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'by ${b['author']} • ${b['shelf_location']}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ISBN: ${b['isbn']} • Copies: $availableQty / $totalQty Available',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isAvailable ? AppTheme.emerald : AppTheme.crimson,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isAvailable)
                              IconButton(
                                icon: const Icon(Icons.post_add, color: AppTheme.royalBlue),
                                tooltip: 'Issue this book',
                                onPressed: () => _showIssueBookModal(b['id']),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 3: OVERDUE FINES & DEFAULTERS
  // -------------------------------------------------------------
  Widget _buildOverdueFinesTab(Map<String, dynamic> summary) {
    final pendingFines = (summary['total_pending_fines'] ?? 0).toDouble();
    final urgentOverdues = (_dashboardData?['urgent_overdues'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total Pending Fines Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB45309), Color(0xFF92400E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Outstanding Overdue Fines',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NPR ${pendingFines.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Automatic rate: NPR 10.00 per day after due date',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Borrowers with Urgent Overdues',
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          if (urgentOverdues.isEmpty)
            _buildEmptyState('No overdue borrowers! All books returned on time.')
          else
            ...urgentOverdues.map((item) {
              final days = item['overdue_days'] ?? 0;
              final fine = (item['fine_amount'] ?? 0).toDouble();
              final phone = item['borrower_phone'];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.roseLight,
                      child: Text(
                        (item['borrower'] ?? 'M')[0],
                        style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['borrower'] ?? 'Member Name',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['book_title'] ?? 'Book Title',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Due: ${item['due_date']} ($days days late)',
                            style: const TextStyle(fontSize: 11, color: AppTheme.crimson, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'NPR ${fine.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.crimson,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (phone != null && phone.toString().isNotEmpty)
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse('tel:$phone')),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.phone, size: 11, color: AppTheme.royalBlue),
                                  SizedBox(width: 4),
                                  Text('Call', style: TextStyle(fontSize: 10, color: AppTheme.royalBlue, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- SUB WIDGET HELPERS ---

  Widget _buildMiniMetric(String label, String value, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildCirculationFilterPill(String label, String value) {
    final isSelected = _circulationStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() => _circulationStatus = value);
        _fetchCirculation();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.royalBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildBookFilterPill(String label, String value) {
    final isSelected = _bookAvailability == value;
    return GestureDetector(
      onTap: () {
        setState(() => _bookAvailability = value);
        _fetchBooks();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.royalBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
