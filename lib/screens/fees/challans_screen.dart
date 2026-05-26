import 'package:flutter/material.dart';
import '../../services/local_db.dart';
import '../../services/print_service.dart';
import '../../widgets/common.dart';

class ChallansScreen extends StatefulWidget {
  const ChallansScreen({super.key});
  @override
  State<ChallansScreen> createState() => _ChallansScreenState();
}

class _ChallansScreenState extends State<ChallansScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _tuitionChallans = [], _transportChallans = [], _inventorySales = [], _years = [];
  String? _selectedYear;
  String _statusFilter = '';
  bool _loading = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); _loadYears(); }

  Future<void> _loadYears() async {
    final years = await LocalDb.getAcademicYears();
    _years = years;
    final current = years.firstWhere((y) => y['is_current'] == 1, orElse: () => <String, Object?>{});
    if (current.isNotEmpty) _selectedYear = current['id'].toString();
    await _load();
  }

  Future<void> _load() async {
    if (_selectedYear == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    final yearId = int.tryParse(_selectedYear!);
    final status = _statusFilter.isEmpty ? null : _statusFilter;
    // Fetch all challans then split by category
    final all = await LocalDb.getChallans(yearId: yearId, status: status);
    final sales = await LocalDb.getInventorySales();
    setState(() {
      _tuitionChallans = all.where((c) {
        final cat = (c['fee_category'] ?? '').toString().toLowerCase().trim();
        return cat != 'transport';
      }).toList();
      _transportChallans = all.where((c) {
        final cat = (c['fee_category'] ?? '').toString().toLowerCase().trim();
        return cat == 'transport';
      }).toList();
      _inventorySales = sales;
      _loading = false;
    });
  }

  // Opens full challan detail modal (clickable for ALL challans)
  void _openChallanDetail(Map challan) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ChallanDetailModal(
        challan: challan,
        onPaymentSuccess: _load,
      ),
    );
  }

  Future<void> _printChallan(Map challan) async {
    final full = await LocalDb.getChallanWithStudent(challan['id'] as int);
    if (full == null) {
      if (mounted) showSnack(context, 'Could not load challan details', error: true);
      return;
    }
    await PrintService.printChallan(Map<String, dynamic>.from(full));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        PageHeader('Challans', subtitle: '${_tuitionChallans.length + _transportChallans.length} challans found'),

        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            const Text('Status:', style: AppTextStyles.bodySmall),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _statusFilter.isEmpty ? null : _statusFilter,
              hint: const Text('All', style: AppTextStyles.bodySmall),
              style: AppTextStyles.body,
              items: ['pending', 'paid', 'partial', 'waived']
                .map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1))))
                .toList(),
              onChanged: (v) { _statusFilter = v ?? ''; _load(); },
            )),
            if (_statusFilter.isNotEmpty) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () { _statusFilter = ''; _load(); },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),

        // 3 Tabs
        Container(
          decoration: cardDecoration(),
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.school_rounded, size: 15),
                const SizedBox(width: 6),
                Text('Tuition Fee (${_tuitionChallans.length})'),
              ])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.directions_bus_rounded, size: 15),
                const SizedBox(width: 6),
                Text('Transport (${_transportChallans.length})'),
              ])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.inventory_2_rounded, size: 15),
                const SizedBox(width: 6),
                Text('Inventory (${_inventorySales.length})'),
              ])),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _groupedChallanList(_tuitionChallans, Icons.school_rounded),
                _groupedByStudent(_transportChallans, Icons.directions_bus_rounded),
                _groupedInventoryList(),
              ],
            ),
        ),
      ]),
    ),
  );

  // Transport: group by student directly
  Widget _groupedByStudent(List challans, IconData icon) {
    if (challans.isEmpty) return const EmptyState(icon: Icons.directions_bus_outlined, message: 'No transport challans found.\nGenerate challans for students with transport fee type.');
    final Map<int, List> studentMap = {};
    for (final c in challans) {
      final sid = c['student_id'] as int;
      studentMap.putIfAbsent(sid, () => []).add(c);
    }
    final entries = studentMap.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final challansForStudent = entries[i].value;
        final first = challansForStudent.first;
        final name = first['student_name'] as String? ?? '?';
        final cls = first['class'] as String? ?? '';
        final sec = first['section'] as String? ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        return _StudentChallanCard(
          name: name,
          initial: initial,
          subtitle: [if (cls.isNotEmpty) 'Class $cls', if (sec.isNotEmpty) 'Sec $sec'].join(' • '),
          admissionNo: first['admission_no'] as String? ?? '',
          parentName: first['parent_name'] as String? ?? '',
          phone: first['parent_phone'] as String? ?? '',
          icon: icon,
          challans: challansForStudent,
          onTap: (c) => _openChallanDetail(c),
          onPrint: (c) => _printChallan(c),
          onWaive: (c) async {
            if (await confirmDialog(context, 'Waive this challan?', danger: true)) {
              await LocalDb.waiveChallan(c['id'] as int); _load();
            }
          },
          onUnwaive: (c) async {
            if (await confirmDialog(context, 'Unwaive this challan? It will be set back to pending.')) {
              await LocalDb.unwaiveChallan(c['id'] as int); _load();
            }
          },
        );
      },
    );
  }

  Widget _groupedChallanList(List challans, IconData sectionIcon) {
    if (challans.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, message: 'No challans found');
    final Map<String, List> groups = {};
    for (final c in challans) {
      final key = 'Class ${c['class'] ?? ''} - ${c['section'] ?? ''}';
      groups.putIfAbsent(key, () => []).add(c);
    }
    final keys = groups.keys.toList()..sort();
    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final key = keys[i];
        final groupChallans = groups[key]!;
        final Map<int, Map> studentMap = {};
        for (final c in groupChallans) {
          studentMap[c['student_id'] as int] = c;
        }
        return _ClassSectionCard(
          classLabel: key,
          sectionIcon: sectionIcon,
          students: studentMap.values.toList(),
          challans: groupChallans,
          onTap: (c) => _openChallanDetail(c),
          onPrint: (c) => _printChallan(c),
          onWaive: (c) async {
            if (await confirmDialog(context, 'Waive this challan?', danger: true)) {
              await LocalDb.waiveChallan(c['id'] as int); _load();
            }
          },
          onUnwaive: (c) async {
            if (await confirmDialog(context, 'Unwaive this challan? It will be set back to pending.')) {
              await LocalDb.unwaiveChallan(c['id'] as int); _load();
            }
          },
        );
      },
    );
  }

  Widget _groupedInventoryList() {
    if (_inventorySales.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, message: 'No inventory sales found');
    final Map<String, List> groups = {};
    for (final s in _inventorySales) {
      final key = 'Class ${s['student_class'] ?? ''} - ${s['student_section'] ?? ''}';
      groups.putIfAbsent(key, () => []).add(s);
    }
    final keys = groups.keys.toList()..sort();
    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final key = keys[i];
        final sales = groups[key]!;
        return _InventoryClassCard(classLabel: key, sales: sales);
      },
    );
  }
}

// ── Student Challan Card (Transport tab) ─────────────────────────────────────
class _StudentChallanCard extends StatefulWidget {
  final String name, initial, subtitle, admissionNo, parentName, phone;
  final IconData icon;
  final List challans;
  final void Function(Map) onTap, onPrint, onWaive, onUnwaive;
  const _StudentChallanCard({
    required this.name, required this.initial, required this.subtitle,
    required this.admissionNo, required this.parentName, required this.phone,
    required this.icon, required this.challans,
    required this.onTap, required this.onPrint,
    required this.onWaive, required this.onUnwaive,
  });
  @override
  State<_StudentChallanCard> createState() => _StudentChallanCardState();
}

class _StudentChallanCardState extends State<_StudentChallanCard> {
  bool _expanded = true;

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 13, color: AppColors.primary),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardDecoration(),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: _expanded ? Radius.zero : const Radius.circular(14),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: _expanded ? Radius.zero : const Radius.circular(14),
              ),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.85), AppColors.primaryLight,
                  ]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(widget.initial,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                if (widget.subtitle.isNotEmpty)
                  Text(widget.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${widget.challans.length} challan(s)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary, size: 20),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryFaded,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                _detailRow(Icons.person_outline_rounded, 'Name', widget.name),
                if (widget.subtitle.isNotEmpty)
                  _detailRow(Icons.class_outlined, 'Class', widget.subtitle),
                if (widget.admissionNo.isNotEmpty)
                  _detailRow(Icons.badge_outlined, 'Admission No', widget.admissionNo),
                if (widget.parentName.isNotEmpty)
                  _detailRow(Icons.people_outline_rounded, 'Parent', widget.parentName),
                if (widget.phone.isNotEmpty)
                  _detailRow(Icons.phone_outlined, 'Phone', widget.phone),
              ]),
            ),
          ),
          ...widget.challans.asMap().entries.map((e) {
            final c = e.value;
            final status = c['status'] as String? ?? 'pending';
            return Column(children: [
              if (e.key > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c['fee_type_name'] ?? '', style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 2),
                    Text(c['period_label'] ?? '', style: AppTextStyles.caption),
                  ])),
                  Text('₹${c['net_amount']}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(width: 8),
                  StatusBadge(status),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.print_outlined, size: 16),
                    color: AppColors.textMuted,
                    onPressed: () => widget.onPrint(c),
                    tooltip: 'Print',
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'detail', child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                        SizedBox(width: 10), Text('View Details'),
                      ])),
                      if (status != 'paid' && status != 'waived')
                        const PopupMenuItem(value: 'waive', child: Row(children: [
                          Icon(Icons.block_outlined, size: 16, color: AppColors.danger),
                          SizedBox(width: 10), Text('Waive', style: TextStyle(color: AppColors.danger)),
                        ])),
                      if (status == 'waived')
                        const PopupMenuItem(value: 'unwaive', child: Row(children: [
                          Icon(Icons.undo_rounded, size: 16, color: AppColors.success),
                          SizedBox(width: 10), Text('Unwaive', style: TextStyle(color: AppColors.success)),
                        ])),
                    ],
                    onSelected: (v) {
                      if (v == 'detail') widget.onTap(c);
                      if (v == 'waive') widget.onWaive(c);
                      if (v == 'unwaive') widget.onUnwaive(c);
                    },
                  ),
                ]),
              ),
            ]);
          }),
        ],
      ]),
    );
  }
}

// ── Class Section Card (shared by Tuition & Transport tabs) ─────────────────
class _ClassSectionCard extends StatefulWidget {
  final String classLabel;
  final IconData sectionIcon;
  final List students;
  final List challans;
  final void Function(Map) onTap;
  final void Function(Map) onPrint;
  final void Function(Map) onWaive;
  final void Function(Map) onUnwaive;
  const _ClassSectionCard({
    required this.classLabel, required this.sectionIcon,
    required this.students, required this.challans,
    required this.onTap, required this.onPrint,
    required this.onWaive, required this.onUnwaive,
  });
  @override
  State<_ClassSectionCard> createState() => _ClassSectionCardState();
}

class _ClassSectionCardState extends State<_ClassSectionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardDecoration(),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: _expanded ? Radius.zero : const Radius.circular(14),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: _expanded ? Radius.zero : const Radius.circular(14),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.sectionIcon, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.classLabel,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${widget.students.length} students',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary, size: 20),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          ...widget.students.asMap().entries.map((e) {
            final s = e.value;
            final sid = s['student_id'] as int;
            final studentChallans = widget.challans.where((c) => c['student_id'] == sid).toList();
            return _StudentChallanRow(
              student: s,
              challans: studentChallans,
              onTap: widget.onTap,
              onPrint: widget.onPrint,
              onWaive: widget.onWaive,
              onUnwaive: widget.onUnwaive,
              showDivider: e.key > 0,
            );
          }),
        ],
      ]),
    );
  }
}

// ── Student Challan Row ───────────────────────────────────────────────────────
class _StudentChallanRow extends StatefulWidget {
  final Map student;
  final List challans;
  final void Function(Map) onTap;
  final void Function(Map) onPrint;
  final void Function(Map) onWaive;
  final void Function(Map) onUnwaive;
  final bool showDivider;
  const _StudentChallanRow({
    required this.student, required this.challans,
    required this.onTap, required this.onPrint,
    required this.onWaive, required this.onUnwaive,
    required this.showDivider,
  });
  @override
  State<_StudentChallanRow> createState() => _StudentChallanRowState();
}

class _StudentChallanRowState extends State<_StudentChallanRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final initial = (s['student_name'] as String? ?? '?')[0].toUpperCase();
    return Column(children: [
      if (widget.showDivider) const Divider(height: 1),
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.primary.withValues(alpha: 0.85), AppColors.primaryLight,
                ]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(initial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['student_name'] ?? '', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${widget.challans.length} challan(s)', style: AppTextStyles.caption),
            ])),
            Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted, size: 18),
          ]),
        ),
      ),
      if (_expanded)
        Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: widget.challans.asMap().entries.map((e) {
              final c = e.value;
              final status = c['status'] as String? ?? 'pending';
              return Column(children: [
                if (e.key > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c['fee_type_name'] ?? '', style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 2),
                      Text(c['period_label'] ?? '', style: AppTextStyles.caption),
                    ])),
                    Text('₹${c['net_amount']}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    StatusBadge(status),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.print_outlined, size: 16),
                      color: AppColors.textMuted,
                      onPressed: () => widget.onPrint(c),
                      tooltip: 'Print',
                    ),
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'detail', child: Row(children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 10), Text('View Details'),
                        ])),
                        if (status != 'paid' && status != 'waived')
                          const PopupMenuItem(value: 'waive', child: Row(children: [
                            Icon(Icons.block_outlined, size: 16, color: AppColors.danger),
                            SizedBox(width: 10), Text('Waive', style: TextStyle(color: AppColors.danger)),
                          ])),
                        if (status == 'waived')
                          const PopupMenuItem(value: 'unwaive', child: Row(children: [
                            Icon(Icons.undo_rounded, size: 16, color: AppColors.success),
                            SizedBox(width: 10), Text('Unwaive', style: TextStyle(color: AppColors.success)),
                          ])),
                      ],
                      onSelected: (v) {
                        if (v == 'detail') widget.onTap(c);
                        if (v == 'waive') widget.onWaive(c);
                        if (v == 'unwaive') widget.onUnwaive(c);
                      },
                    ),
                  ]),
                ),
              ]);
            }).toList(),
          ),
        ),
    ]);
  }
}

// ── Inventory Class Card ──────────────────────────────────────────────────────
class _InventoryClassCard extends StatefulWidget {
  final String classLabel;
  final List sales;
  const _InventoryClassCard({required this.classLabel, required this.sales});
  @override
  State<_InventoryClassCard> createState() => _InventoryClassCardState();
}

class _InventoryClassCardState extends State<_InventoryClassCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardDecoration(),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: _expanded ? Radius.zero : const Radius.circular(14),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: _expanded ? Radius.zero : const Radius.circular(14),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: AppColors.accent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.classLabel,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.accent))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${widget.sales.length} sale(s)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
              ),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AppColors.accent, size: 20),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          ...widget.sales.asMap().entries.map((e) {
            final s = e.value;
            final name = s['student_name'] as String? ?? 'Walk-in';
            final initial = name.isNotEmpty ? name[0].toUpperCase() : 'W';
            return Column(children: [
              if (e.key > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(initial,
                      style: const TextStyle(color: AppColors.accentDark, fontWeight: FontWeight.w700, fontSize: 14))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${s['bill_no'] ?? ''} • ${s['sale_date'] ?? ''}', style: AppTextStyles.caption),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹${s['grand_total'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.successFaded,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(s['payment_mode']?.toString().toUpperCase() ?? 'CASH',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.success)),
                    ),
                  ]),
                ]),
              ),
            ]);
          }),
        ],
      ]),
    );
  }
}


class _ChallanDetailModal extends StatefulWidget {
  final Map challan;
  final VoidCallback onPaymentSuccess;
  const _ChallanDetailModal({required this.challan, required this.onPaymentSuccess});
  @override
  State<_ChallanDetailModal> createState() => _ChallanDetailModalState();
}

class _ChallanDetailModalState extends State<_ChallanDetailModal> {
  Map<String, dynamic>? _full;
  bool _loadingFull = true;
  bool _showPaymentForm = false;

  // Payment form controllers
  final _amount = TextEditingController();
  final _chequeNo = TextEditingController();
  final _chequeDate = TextEditingController();
  final _bankName = TextEditingController();
  final _remarks = TextEditingController();
  String _mode = 'cash';
  String _payDate = DateTime.now().toIso8601String().split('T')[0];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadFull();
    _amount.text = widget.challan['net_amount']?.toString() ?? '';
  }

  @override
  void dispose() {
    _amount.dispose(); _chequeNo.dispose();
    _chequeDate.dispose(); _bankName.dispose(); _remarks.dispose();
    super.dispose();
  }

  Future<void> _loadFull() async {
    final data = await LocalDb.getChallanWithStudent(widget.challan['id'] as int);
    setState(() { _full = data; _loadingFull = false; });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _payDate = picked.toIso8601String().split('T')[0]);
  }

  Future<void> _submitPayment() async {
    if (_amount.text.trim().isEmpty) { showSnack(context, 'Enter amount paid', error: true); return; }
    final amt = double.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) { showSnack(context, 'Enter a valid amount', error: true); return; }

    setState(() => _submitting = true);
    try {
      final paymentId = await LocalDb.insertPayment({
        'challan_id': widget.challan['id'],
        'student_id': widget.challan['student_id'],
        'fee_type_name': widget.challan['fee_type_name'],
        'amount_paid': amt,
        'payment_mode': _mode,
        'cheque_no': _chequeNo.text.isEmpty ? null : _chequeNo.text,
        'cheque_date': _chequeDate.text.isEmpty ? null : _chequeDate.text,
        'bank_name': _bankName.text.isEmpty ? null : _bankName.text,
        'payment_date': _payDate,
        'remarks': _remarks.text.isEmpty ? null : _remarks.text,
      });

      // Fetch saved payment for PDF
      final savedPayment = await LocalDb.getPayment(paymentId);
      final challanFull = _full ?? await LocalDb.getChallanWithStudent(widget.challan['id'] as int);

      if (mounted) {
        Navigator.pop(context);
        showSnack(context, '✅ Payment recorded! Receipt: ${savedPayment?['receipt_no'] ?? ''}');
        widget.onPaymentSuccess();

        // Auto-generate PDF receipt
        if (savedPayment != null && challanFull != null) {
          final receiptData = Map<String, dynamic>.from(savedPayment);
          receiptData['student_name'] = challanFull['student_name'];
          receiptData['admission_no'] = challanFull['admission_no'];
          receiptData['class'] = challanFull['class'];
          receiptData['section'] = challanFull['section'];
          receiptData['parent_name'] = challanFull['parent_name'];
          receiptData['challan_no'] = challanFull['challan_no'];
          receiptData['period_label'] = challanFull['period_label'];
          await PrintService.printReceipt(receiptData);
        }
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challan;
    final status = c['status'] as String? ?? 'pending';
    final canPay = status != 'paid' && status != 'waived';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Challan Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(c['challan_no'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                ])),
                StatusBadge(status),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _loadingFull
                  ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // Student info section
                      _sectionHeader('Student Information', Icons.person_rounded),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: cardDecoration(),
                        child: Column(children: [
                          _detailRow('Student Name', _full?['student_name'] ?? c['student_name'] ?? ''),
                          _detailRow('Class / Section', 'Class ${c['class'] ?? ''} - ${c['section'] ?? ''}'),
                          _detailRow('Admission No', _full?['admission_no'] ?? ''),
                          _detailRow('Parent Name', _full?['parent_name'] ?? ''),
                          _detailRow('Phone', _full?['parent_phone'] ?? ''),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      // Fee breakdown section
                      _sectionHeader('Fee Breakdown', Icons.account_balance_wallet_rounded),
                      const SizedBox(height: 10),
                      Container(
                        decoration: cardDecoration(),
                        child: Column(children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(children: [
                              Expanded(child: Text('Fee Type', style: AppTextStyles.label)),
                              Expanded(child: Text('Period', style: AppTextStyles.label)),
                              Text('Amount', style: AppTextStyles.label),
                            ]),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Expanded(child: Text(c['fee_type_name'] ?? '', style: AppTextStyles.bodyMedium)),
                              Expanded(child: Text(c['period_label'] ?? '', style: AppTextStyles.body)),
                              Text('₹${c['gross_amount'] ?? c['net_amount']}', style: AppTextStyles.bodyMedium),
                            ]),
                          ),
                          if ((c['discount_amount'] ?? 0) != 0) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(children: [
                                Expanded(child: Text('Discount Applied', style: AppTextStyles.body.copyWith(color: AppColors.success))),
                                Expanded(child: const SizedBox()),
                                Text('- ₹${c['discount_amount']}', style: AppTextStyles.body.copyWith(color: AppColors.success)),
                              ]),
                            ),
                          ],
                          const Divider(height: 1),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.04),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            ),
                            child: Row(children: [
                              Expanded(child: Text('Total Amount Due', style: AppTextStyles.h4.copyWith(color: AppColors.primary))),
                              Text('₹${c['net_amount']}', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      // Due date + status
                      Row(children: [
                        Expanded(child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: cardDecoration(),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Due Date', style: AppTextStyles.caption),
                            const SizedBox(height: 4),
                            Text(c['due_date'] ?? 'N/A', style: AppTextStyles.h4),
                          ]),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: cardDecoration(),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Status', style: AppTextStyles.caption),
                            const SizedBox(height: 6),
                            StatusBadge(status),
                          ]),
                        )),
                      ]),

                      // Payment form (shown when Record Payment is clicked)
                      if (_showPaymentForm && canPay) ...[
                        const SizedBox(height: 20),
                        _sectionHeader('Record Payment', Icons.payments_rounded),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: cardDecoration(),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                            // Payment date
                            Text('Payment Date', style: AppTextStyles.label),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
                                  const SizedBox(width: 10),
                                  Text(_payDate, style: AppTextStyles.body),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Payment mode
                            Text('Payment Mode', style: AppTextStyles.label),
                            const SizedBox(height: 6),
                            Row(children: [
                              _modeChip('cash', Icons.money_rounded, 'Cash'),
                              const SizedBox(width: 10),
                              _modeChip('cheque', Icons.account_balance_rounded, 'Cheque'),
                            ]),
                            const SizedBox(height: 12),

                            // Cheque fields
                            if (_mode == 'cheque') ...[
                              Text('Cheque Number', style: AppTextStyles.label),
                              const SizedBox(height: 6),
                              TextField(controller: _chequeNo, style: AppTextStyles.body,
                                decoration: styledInput('Enter cheque number', icon: Icons.confirmation_number_outlined)),
                              const SizedBox(height: 10),
                              Text('Bank Name', style: AppTextStyles.label),
                              const SizedBox(height: 6),
                              TextField(controller: _bankName, style: AppTextStyles.body,
                                decoration: styledInput('Enter bank name', icon: Icons.account_balance_outlined)),
                              const SizedBox(height: 10),
                              Text('Cheque Date', style: AppTextStyles.label),
                              const SizedBox(height: 6),
                              TextField(controller: _chequeDate, style: AppTextStyles.body,
                                decoration: styledInput('YYYY-MM-DD', icon: Icons.event_outlined)),
                              const SizedBox(height: 12),
                            ],

                            // Amount
                            Text('Amount Paid (₹)', style: AppTextStyles.label),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _amount,
                              style: AppTextStyles.body,
                              keyboardType: TextInputType.number,
                              decoration: styledInput('Enter amount', icon: Icons.currency_rupee_rounded),
                            ),
                            const SizedBox(height: 12),

                            // Remarks
                            Text('Remarks (optional)', style: AppTextStyles.label),
                            const SizedBox(height: 6),
                            TextField(controller: _remarks, style: AppTextStyles.body,
                              decoration: styledInput('Any notes...', icon: Icons.notes_outlined)),
                            const SizedBox(height: 16),

                            // Submit button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: _submitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_circle_rounded, size: 18),
                                label: Text(_submitting ? 'Processing...' : 'Confirm & Save Payment'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                onPressed: _submitting ? null : _submitPayment,
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ]),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(children: [
                // Print button
                OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print Challan'),
                  style: outlineBtn(),
                  onPressed: () async {
                    final full = _full ?? await LocalDb.getChallanWithStudent(widget.challan['id'] as int);
                    if (full != null) await PrintService.printChallan(Map<String, dynamic>.from(full));
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
                ),
                if (canPay) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: Icon(_showPaymentForm ? Icons.keyboard_arrow_up_rounded : Icons.payments_rounded, size: 16),
                    label: Text(_showPaymentForm ? 'Hide Form' : 'Record Payment'),
                    style: primaryBtn(),
                    onPressed: () => setState(() => _showPaymentForm = !_showPaymentForm),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String value, IconData icon, String label) {
    final selected = _mode == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? Colors.white : AppColors.textSecondary)),
        ]),
      ),
    ));
  }

  Widget _sectionHeader(String title, IconData icon) => Row(children: [
    Icon(icon, size: 16, color: AppColors.primary),
    const SizedBox(width: 8),
    Text(title, style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
  ]);

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: AppTextStyles.bodySmall)),
      Expanded(child: Text(value.isEmpty ? '—' : value, style: AppTextStyles.bodyMedium)),
    ]),
  );
}
