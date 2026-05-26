import 'package:flutter/material.dart';
import '../services/local_db.dart';
import '../services/print_service.dart';
import '../widgets/common.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List _students = [], _years = [];
  String? _selectedYear;
  String _search = '';
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadYears(); }

  Future<void> _loadYears() async {
    final years = await LocalDb.getAcademicYears();
    _years = years;
    Map current;
    try { current = years.firstWhere((y) => y['is_current'] == 1); }
    catch (_) { current = years.isNotEmpty ? years.first : {}; }
    if (current.isNotEmpty) _selectedYear = current['id'].toString();
    await _load();
  }

  Future<void> _load() async {
    if (_selectedYear == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    final yid = int.parse(_selectedYear!);
    final results = await Future.wait([
      LocalDb.getStudents(yearId: yid, search: _search.isEmpty ? null : _search),
      LocalDb.getStudentsWithBalance(yearId: yid, search: _search.isEmpty ? null : _search),
    ]);
    final allStudents = results[0] as List;
    final withBalance = results[1] as List;
    final balanceMap = { for (final s in withBalance) s['id']: s };
    final merged = allStudents.map((s) {
      final b = balanceMap[s['id']];
      return b ?? {...Map<String, dynamic>.from(s), 'total_billed': 0, 'total_paid': 0, 'balance': 0, 'fee_status': 'no_challan'};
    }).toList();
    setState(() { _students = merged; _loading = false; });
  }

  Map<String, List<Map>> _grouped() {
    final Map<String, List<Map>> map = {};
    for (final s in _students) {
      final cls = (s['class'] ?? '').toString().trim().toUpperCase();
      final sec = (s['section'] ?? '').toString().trim().toUpperCase();
      final key = '$cls|$sec';
      map.putIfAbsent(key, () => []).add(s);
    }
    final sorted = map.keys.toList()
      ..sort((a, b) {
        final ap = a.split('|'); final bp = b.split('|');
        final c = ap[0].compareTo(bp[0]);
        return c != 0 ? c : ap[1].compareTo(bp[1]);
      });
    return { for (final k in sorted) k: map[k]! };
  }

  void _printAll() {
    if (_students.isEmpty) { showSnack(context, 'No students to print', error: true); return; }
    PrintService.printBackup(
      'Student Backup Report',
      _students.map((s) => Map<String, dynamic>.from(s)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [

          // ── Header ──
          PageHeader(
            'Backup',
            subtitle: '${_students.length} students • ${grouped.length} sections',
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Print All'),
                style: primaryBtn(),
                onPressed: _printAll,
              ),
            ],
          ),

          // ── Filter bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: cardDecoration(),
            child: Row(children: [
              if (_years.isNotEmpty) ...[
                const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: _selectedYear,
                  style: AppTextStyles.body,
                  items: _years.map<DropdownMenuItem<String>>((y) =>
                    DropdownMenuItem(value: y['id'].toString(), child: Text(y['label']))).toList(),
                  onChanged: (v) { _selectedYear = v; _load(); },
                )),
                const SizedBox(width: 12),
                Container(width: 1, height: 20, color: AppColors.border),
                const SizedBox(width: 12),
              ],
              Expanded(child: TextField(
                style: AppTextStyles.body,
                decoration: styledInput('Search by name or admission no', icon: Icons.search_rounded),
                onChanged: (v) { _search = v; _load(); },
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Class/Section Grid ──
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : grouped.isEmpty
              ? const EmptyState(icon: Icons.people_outline_rounded, message: 'No students found')
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 150,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: grouped.length,
                  itemBuilder: (_, i) {
                    final key = grouped.keys.elementAt(i);
                    final parts = key.split('|');
                    final cls = parts[0];
                    final sec = parts.length > 1 ? parts[1] : '';
                    final students = grouped[key]!;
                    final pendingCount = students.where((s) => s['fee_status'] == 'pending').length;
                    final paidCount = students.where((s) => s['fee_status'] == 'paid').length;

                    return _BackupClassCard(
                      cls: cls,
                      section: sec,
                      totalStudents: students.length,
                      pendingCount: pendingCount,
                      paidCount: paidCount,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => _BackupSectionPage(
                          cls: cls,
                          section: sec,
                          students: students,
                        ),
                      )),
                      onPrint: () => PrintService.printBackup(
                        'Class $cls - Section $sec',
                        students.map((s) => Map<String, dynamic>.from(s)).toList(),
                      ),
                    );
                  },
                ),
          ),
        ]),
      ),
    );
  }
}

// ── Backup Class Card ─────────────────────────────────────────────────────────
class _BackupClassCard extends StatefulWidget {
  final String cls, section;
  final int totalStudents, pendingCount, paidCount;
  final VoidCallback onTap, onPrint;
  const _BackupClassCard({
    required this.cls, required this.section,
    required this.totalStudents, required this.pendingCount,
    required this.paidCount, required this.onTap, required this.onPrint,
  });
  @override
  State<_BackupClassCard> createState() => _BackupClassCardState();
}

class _BackupClassCardState extends State<_BackupClassCard> {
  bool _hovered = false;

  static const _palette = [
    AppColors.primary, Color(0xFF7C3AED), Color(0xFF0891B2),
    Color(0xFFDB2777), AppColors.success, Color(0xFFD97706),
    Color(0xFF059669), Color(0xFF2563EB),
  ];

  Color get _color => _palette[
    '${widget.cls}${widget.section}'.hashCode.abs() % _palette.length
  ];

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? c : AppColors.border, width: _hovered ? 2 : 1),
            boxShadow: [BoxShadow(
              color: _hovered ? c.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
              blurRadius: _hovered ? 16 : 6,
              offset: const Offset(0, 3),
            )],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
                  child: Text('Class ${widget.cls}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withValues(alpha: 0.3)),
                  ),
                  child: Text('Sec ${widget.section}',
                    style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const Spacer(),
                // Print icon
                GestureDetector(
                  onTap: widget.onPrint,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.print_outlined, size: 14, color: c),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.people_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Text('${widget.totalStudents} students', style: AppTextStyles.bodySmall),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _miniChip('${widget.paidCount} Paid', AppColors.success),
                if (widget.pendingCount > 0)
                  _miniChip('${widget.pendingCount} Pending', AppColors.warning),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

// ── Backup Section Detail Page ────────────────────────────────────────────────
class _BackupSectionPage extends StatefulWidget {
  final String cls, section;
  final List<Map> students;
  const _BackupSectionPage({required this.cls, required this.section, required this.students});
  @override
  State<_BackupSectionPage> createState() => _BackupSectionPageState();
}

class _BackupSectionPageState extends State<_BackupSectionPage> {
  String _search = '';

  List<Map> get _filtered => _search.isEmpty
    ? widget.students
    : widget.students.where((s) =>
        (s['name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase()) ||
        (s['admission_no'] ?? '').toString().contains(_search)).toList();

  void _print() => PrintService.printBackup(
    'Class ${widget.cls} - Section ${widget.section}',
    _filtered.map((s) => Map<String, dynamic>.from(s)).toList(),
  );

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final paidCount    = widget.students.where((s) => s['fee_status'] == 'paid').length;
    final pendingCount = widget.students.where((s) => s['fee_status'] == 'pending').length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Class ${widget.cls} — Section ${widget.section}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text('${widget.students.length} students',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: _print,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // Summary chips
          Row(children: [
            _chip('Total', '${widget.students.length}', AppColors.primary, Icons.people_rounded),
            const SizedBox(width: 10),
            _chip('Paid', '$paidCount', AppColors.success, Icons.check_circle_rounded),
            const SizedBox(width: 10),
            _chip('Pending', '$pendingCount', AppColors.warning, Icons.pending_actions_rounded),
          ]),
          const SizedBox(height: 16),

          // Search
          TextField(
            style: AppTextStyles.body,
            decoration: styledInput('Search by name or admission no', icon: Icons.search_rounded),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 16),

          // Table
          Expanded(child: filtered.isEmpty
            ? const EmptyState(icon: Icons.people_outline_rounded, message: 'No students found')
            : Container(
                decoration: cardDecoration(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(children: [
                    // Header
                    Container(
                      color: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      child: const Row(children: [
                        SizedBox(width: 60,  child: Text('Roll No',  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                        SizedBox(width: 16),
                        Expanded(flex: 3,    child: Text('Name',     style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                        Expanded(flex: 3,    child: Text('Parent',   style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                        SizedBox(width: 110, child: Text('Balance',  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                        SizedBox(width: 16),
                        SizedBox(width: 100, child: Text('Status',   style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                      ]),
                    ),
                    // Rows
                    Expanded(child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        final balance = (s['balance'] as num?)?.toDouble() ?? 0.0;
                        final status  = s['fee_status'] as String? ?? 'no_challan';
                        final initials = (s['name'] as String? ?? '?')
                            .split(' ').take(2).map((w) => w[0].toUpperCase()).join();
                        final (bg, fg, lbl) = switch (status) {
                          'paid'       => (AppColors.successFaded, AppColors.success, 'Paid'),
                          'pending'    => (AppColors.warningFaded, AppColors.warning, 'Pending'),
                          _            => (AppColors.mutedFaded,   AppColors.muted,   'No Challan'),
                        };
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(children: [
                            SizedBox(width: 60, child: Text(s['roll_no']?.toString() ?? '-',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary))),
                            const SizedBox(width: 16),
                            Expanded(flex: 3, child: Row(children: [
                              Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(color: AppColors.primaryFaded, borderRadius: BorderRadius.circular(8)),
                                child: Center(child: Text(initials,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s['name'] ?? '-',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                                Text(s['admission_no'] ?? '', style: AppTextStyles.caption),
                              ])),
                            ])),
                            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s['parent_name'] ?? '-', style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
                              if ((s['parent_phone'] ?? '').isNotEmpty)
                                Text(s['parent_phone'], style: AppTextStyles.caption),
                            ])),
                            SizedBox(width: 110, child: Text(
                              balance > 0 ? '₹${balance.toStringAsFixed(0)}' : '—',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                color: balance > 0 ? AppColors.danger : AppColors.success),
                            )),
                            const SizedBox(width: 16),
                            SizedBox(width: 100, child: Center(child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                              child: Text(lbl, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
                            ))),
                          ]),
                        );
                      },
                    )),
                  ]),
                ),
              ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}
