import 'package:flutter/material.dart';
import '../../services/local_db.dart';
import '../../widgets/common.dart';
import 'student_form_screen.dart';
import 'student_detail_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
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
    await _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (_selectedYear == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    final data = await LocalDb.getStudentsWithBalance(
      search: _search.isEmpty ? null : _search,
      yearId: int.tryParse(_selectedYear!),
    );
    setState(() { _students = data; _loading = false; });
  }

  // Group all students by "class|section"
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
        final aParts = a.split('|');
        final bParts = b.split('|');
        final cmp = (aParts[0]).compareTo(bParts[0]);
        return cmp != 0 ? cmp : (aParts[1]).compareTo(bParts[1]);
      });
    return { for (final k in sorted) k: map[k]! };
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
            'Students',
            subtitle: '${_students.length} students • ${grouped.length} sections',
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Student'),
                style: primaryBtn(),
                onPressed: () async {
                  if (_selectedYear == null) {
                    showSnack(context, 'Create an Academic Year in Settings first', error: true);
                    return;
                  }
                  final saved = await StudentFormScreen.show(context, academicYearId: _selectedYear!);
                  if (saved == true) _loadStudents();
                },
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
                  onChanged: (v) { _selectedYear = v; _loadStudents(); },
                )),
                const SizedBox(width: 12),
                Container(width: 1, height: 20, color: AppColors.border),
                const SizedBox(width: 12),
              ],
              Expanded(child: TextField(
                style: AppTextStyles.body,
                decoration: styledInput('Search by name or admission no', icon: Icons.search_rounded),
                onChanged: (v) { _search = v; _loadStudents(); },
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

                    return _ClassSectionCard(
                      cls: cls,
                      section: sec,
                      totalStudents: students.length,
                      pendingCount: pendingCount,
                      paidCount: paidCount,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _SectionStudentsPage(
                          cls: cls,
                          section: sec,
                          students: students,
                          academicYearId: _selectedYear!,
                          onRefresh: _loadStudents,
                        )),
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

// ── Class Section Card ────────────────────────────────────────────────────────
class _ClassSectionCard extends StatefulWidget {
  final String cls, section;
  final int totalStudents, pendingCount, paidCount;
  final VoidCallback onTap;
  const _ClassSectionCard({
    required this.cls, required this.section,
    required this.totalStudents, required this.pendingCount,
    required this.paidCount, required this.onTap,
  });
  @override
  State<_ClassSectionCard> createState() => _ClassSectionCardState();
}

class _ClassSectionCardState extends State<_ClassSectionCard> {
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
              // Class + Section badges
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
              ]),
              const SizedBox(height: 12),
              // Student count
              Row(children: [
                Icon(Icons.people_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Text('${widget.totalStudents} students', style: AppTextStyles.bodySmall),
              ]),
              const SizedBox(height: 8),
              // Paid / Pending mini chips
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
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

// ── Column width constants (header & row must match exactly) ─────────────────
const double _wRoll    = 60.0;
const double _wClass   = 70.0;
const double _wSec     = 60.0;
const double _wBalance = 100.0;
const double _wStatus  = 100.0;
const double _wArrow   = 36.0;
const double _colGap   = 16.0;

// ── Section Students Page ─────────────────────────────────────────────────────
class _SectionStudentsPage extends StatefulWidget {
  final String cls, section, academicYearId;
  final List<Map> students;
  final VoidCallback onRefresh;
  const _SectionStudentsPage({
    required this.cls, required this.section,
    required this.students, required this.academicYearId,
    required this.onRefresh,
  });
  @override
  State<_SectionStudentsPage> createState() => _SectionStudentsPageState();
}

class _SectionStudentsPageState extends State<_SectionStudentsPage> {
  late List<Map> _students;
  String _search = '';

  @override
  void initState() { super.initState(); _students = widget.students; }

  List<Map> get _filtered => _search.isEmpty
    ? _students
    : _students.where((s) =>
        (s['name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase()) ||
        (s['admission_no'] ?? '').toString().contains(_search) ||
        (s['roll_no'] ?? '').toString().contains(_search)).toList();

  Future<void> _refresh() async {
    final updated = await LocalDb.getStudentsWithBalance(
      classFilter: widget.cls,
      yearId: int.tryParse(widget.academicYearId),
    );
    if (mounted) {
      setState(() {
        _students = updated.where((s) => s['section'] == widget.section).toList();
      });
    }
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pendingCount = _students.where((s) => s['fee_status'] == 'pending').length;
    final paidCount = _students.where((s) => s['fee_status'] == 'paid').length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Class ${widget.cls} — Section ${widget.section}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text('${_students.length} students',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add Student',
            onPressed: () async {
              final saved = await StudentFormScreen.show(
                context,
                academicYearId: widget.academicYearId,
                initialClass: widget.cls,
                initialSection: widget.section,
              );
              if (saved == true) _refresh();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // ── Summary chips ──
          Row(children: [
            _summaryChip('Total', '${_students.length}', AppColors.primary, Icons.people_rounded),
            const SizedBox(width: 10),
            _summaryChip('Paid', '$paidCount', AppColors.success, Icons.check_circle_rounded),
            const SizedBox(width: 10),
            _summaryChip('Pending', '$pendingCount', AppColors.warning, Icons.pending_actions_rounded),
          ]),
          const SizedBox(height: 16),

          // ── Search ──
          TextField(
            style: AppTextStyles.body,
            decoration: styledInput('Search by name, admission no or roll no', icon: Icons.search_rounded),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 16),

          // ── Table ──
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
                      child: Row(children: [
                        SizedBox(width: _wRoll,    child: const Text('Roll No',  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                        const SizedBox(width: _colGap),
                        const Expanded(flex: 3,    child: Text('Name',          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                        SizedBox(width: _wClass,   child: const Text('Class',   style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                        const SizedBox(width: _colGap),
                        SizedBox(width: _wSec,     child: const Text('Sec',     style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                        const SizedBox(width: _colGap),
                        const Expanded(flex: 3,    child: Text('Parent',        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                        SizedBox(width: _wBalance, child: const Text('Balance', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                        const SizedBox(width: _colGap),
                        SizedBox(width: _wStatus,  child: const Text('Status',  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                        SizedBox(width: _wArrow),
                      ]),
                    ),
                    // Rows
                    Expanded(child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        return _StudentTableRow(
                          student: s,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => StudentDetailScreen(
                                studentId: s['id'].toString(),
                                academicYearId: widget.academicYearId,
                              )));
                            _refresh();
                          },
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

  Widget _summaryChip(String label, String value, Color color, IconData icon) => Container(
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

// ── Student Table Row ─────────────────────────────────────────────────────────
class _StudentTableRow extends StatefulWidget {
  final Map student;
  final VoidCallback onTap;
  const _StudentTableRow({required this.student, required this.onTap});
  @override
  State<_StudentTableRow> createState() => _StudentTableRowState();
}

class _StudentTableRowState extends State<_StudentTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final balance = (s['balance'] as num?)?.toDouble() ?? 0.0;
    final feeStatus = s['fee_status'] as String? ?? 'no_challan';
    final initials = (s['name'] as String? ?? '?')
        .split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered ? AppColors.primaryFaded : Colors.white,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(children: [

              // Roll No
              SizedBox(width: _wRoll,
                child: Text(s['roll_no']?.toString() ?? '-',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary))),
              const SizedBox(width: _colGap),

              // Name + admission no
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                  Text(s['admission_no'] ?? '', style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                ])),
              ])),

              // Class
              SizedBox(width: _wClass,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryFaded, borderRadius: BorderRadius.circular(6)),
                  child: Text(s['class'] ?? '-',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                )),
              const SizedBox(width: _colGap),

              // Section
              SizedBox(width: _wSec,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accentFaded, borderRadius: BorderRadius.circular(6)),
                  child: Text(s['section'] ?? '-',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accentDark)),
                )),
              const SizedBox(width: _colGap),

              // Parent
              Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['parent_name'] ?? '-', style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
                if ((s['parent_phone'] ?? '').isNotEmpty)
                  Text(s['parent_phone'], style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
              ])),

              // Balance
              SizedBox(width: _wBalance,
                child: Text(
                  balance > 0 ? '₹${balance.toStringAsFixed(0)}' : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: balance > 0 ? AppColors.danger : AppColors.success),
                )),
              const SizedBox(width: _colGap),

              // Status
              SizedBox(width: _wStatus, child: Center(child: _FeeStatusBadge(feeStatus))),

              // Arrow
              SizedBox(width: _wArrow,
                child: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Fee Status Badge ──────────────────────────────────────────────────────────
class _FeeStatusBadge extends StatelessWidget {
  final String status;
  const _FeeStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'paid'       => (AppColors.successFaded, AppColors.success, 'Paid'),
      'pending'    => (AppColors.warningFaded, AppColors.warning, 'Pending'),
      'no_challan' => (AppColors.mutedFaded,   AppColors.muted,   'No Challan'),
      _            => (AppColors.mutedFaded,   AppColors.muted,   status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
