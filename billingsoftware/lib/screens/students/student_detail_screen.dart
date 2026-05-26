import 'package:flutter/material.dart';
import '../../services/local_db.dart';
import '../../services/print_service.dart';
import '../../widgets/common.dart';
import 'student_form_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId, academicYearId;
  final int initialTab;
  const StudentDetailScreen({required this.studentId, required this.academicYearId, this.initialTab = 0, super.key});
  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _student;
  List _challans = [], _payments = [], _discounts = [], _inventorySales = [];
  Map<int, List<Map>> _saleItemsMap = {};
  bool _loading = true;
  final Set<int> _selectedChallanIds = {};
  bool get _isSelecting => _selectedChallanIds.isNotEmpty;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sid = int.parse(widget.studentId);
    final yid = int.parse(widget.academicYearId);
    final results = await Future.wait([
      LocalDb.getStudent(sid),
      LocalDb.getChallans(studentId: sid, yearId: yid),
      LocalDb.getPayments(studentId: sid),
      LocalDb.getStudentDiscounts(sid),
    ]);
    final student = results[0] != null ? Map<String, dynamic>.from(results[0] as Map) : null;
    List invSales = [];
    final itemsMap = <int, List<Map>>{};
    if (student != null) {
      final name = student['name'] as String? ?? '';
      final cls = student['class'] as String? ?? '';
      final sec = student['section'] as String? ?? '';
      invSales = await LocalDb.getInventorySalesByStudentAll(name, cls, sec);
      for (final s in invSales) {
        final id = s['id'] as int;
        itemsMap[id] = await LocalDb.getInventorySaleItems(id);
      }
    }
    final rawChallans = results[1] as List;
    final sortedChallans = List.from(rawChallans)..sort((a, b) {
      final pa = (a['period_label'] as String? ?? '');
      final pb = (b['period_label'] as String? ?? '');
      final termA = RegExp(r'\d+').firstMatch(pa);
      final termB = RegExp(r'\d+').firstMatch(pb);
      if (termA != null && termB != null) {
        return int.parse(termA.group(0)!).compareTo(int.parse(termB.group(0)!));
      }
      return pa.compareTo(pb);
    });
    setState(() {
      _student = student;
      _challans = sortedChallans;
      _payments = results[2] as List;
      _discounts = results[3] as List;
      _inventorySales = invSales;
      _saleItemsMap = itemsMap;
      _loading = false;
    });
  }

  Future<void> _showApplyDiscountDialog() async {
    final years = await LocalDb.getAcademicYears();
    final current = years.firstWhere((y) => y['is_current'] == 1, orElse: () => <String, Object?>{});
    if (current == null) return;
    final discountOptions = await LocalDb.getDiscounts(current['id'] as int);
    if (discountOptions.isEmpty) { if (mounted) showSnack(context, 'No discounts defined. Add in Fee Structure first.', error: true); return; }
    int? selectedDiscount = discountOptions.first['id'] as int;
    if (!mounted) return;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: const Row(children: [Icon(Icons.discount_outlined, color: AppColors.primary, size: 20), SizedBox(width: 10), Text('Apply Discount', style: AppTextStyles.h3)]),
      content: DropdownButtonFormField<int>(
        value: selectedDiscount,
        style: AppTextStyles.body,
        decoration: styledInput('Select Discount', icon: Icons.discount_outlined),
        items: discountOptions.map<DropdownMenuItem<int>>((d) => DropdownMenuItem(value: d['id'] as int, child: Text('${d['name']} (${d['type'] == 'percentage' ? '${d['value']}%' : '₹${d['value']}'}) - ${d['scope']}'))).toList(),
        onChanged: (v) => ss(() => selectedDiscount = v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
        ElevatedButton(style: primaryBtn(), onPressed: () async {
          await LocalDb.applyStudentDiscount(int.parse(widget.studentId), selectedDiscount!);
          if (mounted) Navigator.pop(ctx);
          _load();
        }, child: const Text('Apply')),
      ],
    )));
  }

  Future<void> _generateChallans() async {
    final yid = int.parse(widget.academicYearId);
    final structures = await LocalDb.getFeeStructures(yid);

    // Separate term (non-transport) and transport structures for this student's class
    final studentClass = _student!['class'] as String? ?? '';
    final termStructures = structures.where((s) {
      final cat = (s['fee_category'] ?? '').toString().toLowerCase();
      final cls = (s['class'] ?? '').toString().trim().toUpperCase();
      return cat != 'transport' && cls == studentClass.trim().toUpperCase();
    }).toList();

    final transportStructures = structures.where((s) =>
      (s['fee_category'] ?? '').toString().toLowerCase() == 'transport').toList();

    // Unique period labels from term structures
    final allPeriods = termStructures
        .map((s) => s['period_label'] as String? ?? '')
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()..sort();

    // Transport: group location -> stops
    final Map<String, Set<String>> locationStops = {};
    for (final s in transportStructures) {
      final loc  = (s['class']   as String? ?? '').trim();
      final stop = (s['section'] as String? ?? '').trim();
      if (loc.isEmpty || stop.isEmpty) continue;
      locationStops.putIfAbsent(loc, () => {}).add(stop);
    }
    final hasTransport = locationStops.isNotEmpty;
    final locationList = locationStops.keys.toList()..sort();

    // State for dialog
    final Set<String> selectedPeriods = {};
    bool includeTransport = false;
    String selectedLocation = locationList.isNotEmpty ? locationList.first : '';
    List<String> stopList = locationList.isNotEmpty
        ? (locationStops[locationList.first]!.toList()..sort())
        : [];
    String? selectedStop = stopList.isNotEmpty ? stopList.first : null;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Text('Generate Challans'),
        ]),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

              // â”€â”€ Term selection â”€â”€
              if (allPeriods.isNotEmpty) ...[
                const Text('Select Terms', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                ...allPeriods.map((period) => InkWell(
                  onTap: () => ss(() {
                    if (selectedPeriods.contains(period)) selectedPeriods.remove(period);
                    else selectedPeriods.add(period);
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedPeriods.contains(period)
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedPeriods.contains(period) ? AppColors.primary : AppColors.border,
                        width: selectedPeriods.contains(period) ? 2 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        selectedPeriods.contains(period)
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: selectedPeriods.contains(period) ? AppColors.primary : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(period, style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selectedPeriods.contains(period) ? AppColors.primary : AppColors.textPrimary,
                      )),
                    ]),
                  ),
                )),
                const SizedBox(height: 14),
              ],

              // â”€â”€ Transport selection â”€â”€
              if (hasTransport) ...[
                const Divider(),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => ss(() => includeTransport = !includeTransport),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: includeTransport
                          ? AppColors.accent.withValues(alpha: 0.08)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: includeTransport ? AppColors.accent : AppColors.border,
                        width: includeTransport ? 2 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        includeTransport ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: includeTransport ? AppColors.accent : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.directions_bus_rounded, size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      const Text('Include Transport', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent,
                      )),
                    ]),
                  ),
                ),
                if (includeTransport) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedLocation,
                    decoration: styledInput('Location', icon: Icons.location_on_rounded),
                    items: locationList.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      ss(() {
                        selectedLocation = v;
                        stopList = locationStops[v]!.toList()..sort();
                        selectedStop = stopList.isNotEmpty ? stopList.first : null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (stopList.isEmpty)
                    const Text('No stops for this location',
                        style: TextStyle(color: AppColors.danger, fontSize: 12))
                  else
                    DropdownButtonFormField<String>(
                      value: selectedStop,
                      decoration: styledInput('Stop', icon: Icons.place_outlined),
                      items: stopList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => ss(() => selectedStop = v),
                    ),
                ],
              ],

              if (allPeriods.isEmpty && !hasTransport)
                const Text('No fee structures found for this student.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: primaryBtn(),
            onPressed: (selectedPeriods.isEmpty && !includeTransport)
                ? null
                : () async {
                    Navigator.pop(ctx);
                    final sid = int.parse(widget.studentId);
                    int count = 0;
                    if (selectedPeriods.isNotEmpty) {
                      final c1 = await LocalDb.generateChallansForPeriods(sid, yid, selectedPeriods.toList());
                      count += c1;
                    }
                    if (includeTransport && selectedStop != null) {
                      final c2 = await LocalDb.generateChallansWithLocationStop(sid, yid, selectedLocation, selectedStop!);
                      count += c2;
                    }
                    if (mounted) showSnack(context, '$count challan(s) generated');
                    _load();
                  },
            child: const Text('Generate'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_student == null) return const Scaffold(body: Center(child: Text('Student not found', style: AppTextStyles.body)));
    final s = _student!;
    final initials = (s['name'] as String).split(' ').take(2).map((w) => w[0].toUpperCase()).join();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF2D5F9E)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('Class ${s['class']}-${s['section']} • ${s['admission_no']}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
          ]),
        ]),
        actions: [
          if (_isSelecting) ...[
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.white),
              tooltip: 'Delete selected',
              onPressed: () async {
                if (!await confirmDialog(context, 'Delete ${_selectedChallanIds.length} challan(s)?', danger: true)) return;
                for (final id in _selectedChallanIds) {
                  await LocalDb.deleteChallan(id);
                }
                setState(() => _selectedChallanIds.clear());
                _load();
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => setState(() => _selectedChallanIds.clear()),
            ),
          ] else
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => StudentFormScreen(academicYearId: widget.academicYearId, student: s)));
              _load();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Profile'), Tab(text: 'Challans'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [_profileTab(s), _challansTab(), _historyTab()]),
    );
  }

  Widget _profileTab(Map s) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      StyledCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Student Info', Icons.school_rounded),
        const SizedBox(height: 14),
        InfoRow('Admission No', s['admission_no'] ?? ''),
        InfoRow('Full Name', s['name'] ?? ''),
        InfoRow('Class', '${s['class']}-${s['section']}'),
        InfoRow('Roll No', s['roll_no'] ?? ''),
        InfoRow('Date of Birth', s['dob'] ?? ''),
        InfoRow('Gender', s['gender'] ?? ''),
      ])),
      const SizedBox(height: 14),
      StyledCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Parent / Guardian', Icons.family_restroom_rounded),
        const SizedBox(height: 14),
        InfoRow('Name', s['parent_name'] ?? ''),
        InfoRow('Phone', s['parent_phone'] ?? ''),
        InfoRow('Email', s['parent_email'] ?? ''),
        InfoRow('Address', s['address'] ?? ''),
      ])),
      const SizedBox(height: 14),
      StyledCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _sectionTitle('Discounts Applied', Icons.discount_outlined),
          TextButton.icon(
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Apply', style: TextStyle(fontSize: 12)),
            onPressed: _showApplyDiscountDialog,
          ),
        ]),
        const SizedBox(height: 8),
        if (_discounts.isEmpty)
          const Text('No discounts applied', style: AppTextStyles.bodySmall)
        else
          ..._discounts.map((d) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${d['discount_name']} – ${d['discount_type'] == 'percentage' ? '${d['discount_value']}%' : '₹${d['discount_value']}'} (${d['discount_scope']})',
                style: AppTextStyles.bodySmall,
              )),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 15, color: AppColors.danger),
                onPressed: () async { await LocalDb.removeStudentDiscount(d['id'] as int); _load(); },
              ),
            ]),
          )),
      ])),
    ]),
  );

  Widget _challansTab() => Column(children: [
    Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.auto_awesome_rounded, size: 15),
          label: const Text('Generate Challans'),
          style: primaryBtn(),
          onPressed: _generateChallans,
        ),
        if (_isSelecting) ...[
          const SizedBox(width: 10),
          Text('${_selectedChallanIds.length} selected',
            style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ],
      ]),
    ),
    Expanded(child: _challans.isEmpty
      ? const EmptyState(icon: Icons.receipt_long_outlined, message: 'No challans found')
      : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _challans.length,
          itemBuilder: (_, i) {
            final c = _challans[i];
            final id = c['id'] as int;
            final isSelected = _selectedChallanIds.contains(id);
            return GestureDetector(
              onLongPress: () => setState(() {
                if (isSelected) _selectedChallanIds.remove(id);
                else _selectedChallanIds.add(id);
              }),
              onTap: () {
                if (_isSelecting) {
                  setState(() {
                    if (isSelected) _selectedChallanIds.remove(id);
                    else _selectedChallanIds.add(id);
                  });
                } else {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StudentChallanDetailPage(
                      challan: Map<String, dynamic>.from(c),
                      studentName: _student!['name'] as String,
                    ),
                  )).then((_) => _load());
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    if (_isSelecting)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 2),
                          ),
                          child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                        ),
                      ),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${c['fee_type_name']} – ${c['period_label']}',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Challan: ${c['challan_no']} • Due: ${c['due_date'] ?? 'N/A'}',
                        style: AppTextStyles.caption),
                    ])),
                    const SizedBox(width: 12),
                    Text('\u20b9${c['net_amount']}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    StatusBadge(c['status']),
                    if (!_isSelecting) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                    ],
                  ]),
                ),
              ),
            );
          },
        ),
    ),
  ]);



  Widget _historyTab() {
    final paidChallans = _challans.where((c) => c['status'] == 'paid').toList();
    final Map<int, Map> paymentByChallan = {};
    for (final p in _payments) {
      final cid = p['challan_id'];
      if (cid != null) paymentByChallan[cid as int] = p;
    }
    if (paidChallans.isEmpty && _inventorySales.isEmpty)
      return const EmptyState(icon: Icons.payments_outlined, message: 'No payment history found');
    final totalPaid = paidChallans.fold<double>(0, (sum, c) => sum + (c['net_amount'] as num).toDouble());
    final totalUniform = _inventorySales.fold<double>(0, (sum, s) => sum + (s['grand_total'] as num).toDouble());
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.success.withValues(alpha: 0.12), AppColors.success.withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            '${paidChallans.length} challan(s) paid  •  ${_inventorySales.length} uniform sale(s)',
            style: const TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600),
          )),
          Text('₹${(totalPaid + totalUniform).toStringAsFixed(0)} total',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success)),
        ]),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
        if (paidChallans.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Fee Payments', style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
            ]),
          ),
          ...paidChallans.map((c) {
            final payment = paymentByChallan[c['id'] as int];
            final payDate = payment?['payment_date'] as String? ?? '';
            final receiptNo = payment?['receipt_no'] as String? ?? '';
            final mode = (payment?['payment_mode'] ?? '').toString();
            final isCash = mode == 'cash';
            final color = isCash ? AppColors.success : AppColors.accent;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: cardDecoration(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.07),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c['fee_type_name'] ?? '', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                      Text(c['period_label'] ?? '', style: AppTextStyles.caption),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${c['net_amount']}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.success)),
                      if (mode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(mode.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                        ),
                    ]),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(children: [
                    _historyRow(Icons.calendar_today_rounded, 'Paid Date', payDate.isEmpty ? 'N/A' : payDate),
                    _historyRow(Icons.event_outlined, 'Due Date', c['due_date'] ?? 'N/A'),
                    _historyRow(Icons.receipt_long_rounded, 'Challan No', c['challan_no'] ?? ''),
                    if (receiptNo.isNotEmpty) _historyRow(Icons.receipt_outlined, 'Receipt No', receiptNo),
                    if ((payment?['cheque_no'] ?? '').toString().isNotEmpty) ...[
                      _historyRow(Icons.confirmation_number_outlined, 'Cheque No', payment!['cheque_no'].toString()),
                      _historyRow(Icons.account_balance_outlined, 'Bank', payment['bank_name']?.toString() ?? ''),
                    ],
                    if ((payment?['remarks'] ?? '').toString().isNotEmpty)
                      _historyRow(Icons.notes_outlined, 'Remarks', payment!['remarks'].toString()),
                    if (payment != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.print_outlined, size: 14),
                          label: const Text('Print Receipt'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => PrintService.printReceipt(Map<String, dynamic>.from(payment)),
                        ),
                      ),
                    ],
                  ]),
                ),
              ]),
            );
          }),
        ],
        if (_inventorySales.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Icon(Icons.shopping_bag_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('Inventory Purchases', style: AppTextStyles.h4.copyWith(color: AppColors.accent)),
            ]),
          ),
          ..._inventorySales.map((s) {
          final isBook = s['sale_type'] == 'book';
          return _inventorySaleCard(s,
            isBook ? AppColors.warning : AppColors.accent,
            isBook ? Icons.menu_book_rounded : Icons.checkroom_rounded,
            isBook ? Icons.menu_book_outlined : Icons.checkroom_outlined,
            showSize: !isBook);
        }),
        ],
      ])),
    ]);
  }

  Widget _inventorySaleCard(Map s, Color color, IconData headerIcon, IconData itemIcon, {required bool showSize}) {
    final items = _saleItemsMap[s['id'] as int] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(headerIcon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(
              (s['sale_type'] == 'book') ? 'Book / Stationery Purchase' : 'Uniform Purchase',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\u20b9${s['grand_total'] ?? 0}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text((s['payment_mode'] ?? '').toString().toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(children: [
            _historyRow(Icons.receipt_outlined, 'Bill No', s['bill_no'] ?? ''),
            _historyRow(Icons.calendar_today_rounded, 'Sale Date', s['sale_date'] ?? ''),
            if ((s['remarks'] ?? '').toString().isNotEmpty)
              _historyRow(Icons.notes_outlined, 'Remarks', s['remarks'].toString()),
          ]),
        ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryFaded,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: items.asMap().entries.map((ie) {
                  final it = ie.value;
                  final label = showSize
                    ? '${it['item_name'] ?? ''}${(it['size'] ?? '').toString().isNotEmpty ? ' (${it['size']})' : ''}'
                    : (it['item_name'] ?? '');
                  return Column(children: [
                    if (ie.key > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(children: [
                        Icon(itemIcon, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                        Text('x${it['quantity']}  \u20b9${it['total_price'] ?? 0}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ]),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          )
        else
          const SizedBox(height: 6),
      ]),
    );
  }

  Widget _historyRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 13, color: AppColors.textMuted),
      const SizedBox(width: 6),
      SizedBox(width: 110, child: Text(label, style: AppTextStyles.caption)),
      Expanded(child: Text(value.isEmpty ? '–' : value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
    ]),
  );

  Widget _sectionTitle(String title, IconData icon) => Row(children: [
    Icon(icon, color: AppColors.primary, size: 17),
    const SizedBox(width: 8),
    Text(title, style: AppTextStyles.h3),
  ]);
}

// â”€â”€ Student Challan Detail Page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class StudentChallanDetailPage extends StatefulWidget {
  final Map<String, dynamic> challan;
  final String studentName;
  const StudentChallanDetailPage({required this.challan, required this.studentName, super.key});
  @override
  State<StudentChallanDetailPage> createState() => _StudentChallanDetailPageState();
}

class _StudentChallanDetailPageState extends State<StudentChallanDetailPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _full;
  List _payments = [];
  bool _loading = true;
  late String _status;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _status = widget.challan['status'] as String? ?? 'pending';
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    final data = await LocalDb.getChallanWithStudent(widget.challan['id'] as int);
    final pays = await LocalDb.getPayments(studentId: widget.challan['student_id'] as int);
    setState(() { _full = data; _payments = pays; _loading = false; });
  }

  Future<void> _changeStatus(String newStatus) async {
    await LocalDb.updateChallanStatus(widget.challan['id'] as int, newStatus);
    setState(() => _status = newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challan;
    final status = _status;
    final initials = widget.studentName.trim().isEmpty ? '?'
        : widget.studentName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF2D5F9E)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(initials,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Text(widget.studentName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        actions: const [],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Details'), Tab(text: 'History')],
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [_detailsTab(), _historyTab()]),
    );
  }

  Widget _detailsTab() {
    final c = widget.challan;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('Student Information', Icons.person_rounded),
        const SizedBox(height: 10),
        StyledCard(padding: const EdgeInsets.all(16), child: Column(children: [
          InfoRow('Student Name', _full?['student_name'] ?? widget.studentName),
          InfoRow('Class / Section', 'Class ${c['class'] ?? ''} - ${c['section'] ?? ''}'),
          InfoRow('Admission No', _full?['admission_no'] ?? ''),
          InfoRow('Parent Name', _full?['parent_name'] ?? ''),
          InfoRow('Phone', _full?['parent_phone'] ?? ''),
        ])),
        const SizedBox(height: 16),
        _sectionHeader('Challan Details', Icons.receipt_long_rounded),
        const SizedBox(height: 10),
        StyledCard(padding: const EdgeInsets.all(16), child: Column(children: [
          InfoRow('Fee Type', c['fee_type_name'] ?? ''),
          InfoRow('Period', c['period_label'] ?? ''),
          InfoRow('Due Date', c['due_date'] ?? 'N/A'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 120, child: Text('Status', style: AppTextStyles.bodySmall)),
              _statusToggle('Paid', 'paid', AppColors.success),
              const SizedBox(width: 8),
              _statusToggle('Pending', 'pending', AppColors.warning),
            ]),
          ),
        ])),
        const SizedBox(height: 16),
        _sectionHeader('Fee Breakdown', Icons.account_balance_wallet_rounded),
        const SizedBox(height: 10),
        StyledCard(child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Expanded(child: Text('Fee Type', style: AppTextStyles.label)),
              Text('Amount', style: AppTextStyles.label),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(child: Text(c['fee_type_name'] ?? '', style: AppTextStyles.bodyMedium)),
              Text('₹${c['gross_amount'] ?? c['net_amount']}', style: AppTextStyles.bodyMedium),
            ]),
          ),
          if ((c['discount_amount'] ?? 0) != 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Expanded(child: Text('Discount', style: AppTextStyles.body.copyWith(color: AppColors.success))),
                Text('- ₹${c['discount_amount']}', style: AppTextStyles.body.copyWith(color: AppColors.success)),
              ]),
            ),
          ],
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(children: [
              Expanded(child: Text('Total Amount Due', style: AppTextStyles.h4.copyWith(color: AppColors.primary))),
              Text('₹${c['net_amount']}', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
            ]),
          ),
        ])),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print Challan'),
            style: outlineBtn(),
            onPressed: () async {
              final full = _full ?? await LocalDb.getChallanWithStudent(c['id'] as int);
              if (full != null) await PrintService.printChallan(Map<String, dynamic>.from(full));
            },
          ),
        ),
      ]),
    );
  }

  Widget _historyTab() {
    if (_payments.isEmpty) return const EmptyState(icon: Icons.payments_outlined, message: 'No payment history found');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (_, i) {
        final p = _payments[i];
        final isCash = p['payment_mode'] == 'cash';
        final color = isCash ? AppColors.success : AppColors.accent;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: cardDecoration(),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(isCash ? Icons.money_rounded : Icons.account_balance_rounded, color: color, size: 18),
            ),
            title: Text('₹${p['amount_paid']} – ${p['fee_type_name'] ?? ''}',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Receipt: ${p['receipt_no'] ?? ''}', style: AppTextStyles.caption),
              Text('Date: ${p['payment_date'] ?? ''}  •  Mode: ${(p['payment_mode'] ?? '').toString().toUpperCase()}',
                style: AppTextStyles.caption),
              if ((p['cheque_no'] ?? '').toString().isNotEmpty)
                Text('Cheque: ${p['cheque_no']}  •  Bank: ${p['bank_name'] ?? ''}', style: AppTextStyles.caption),
              if ((p['remarks'] ?? '').toString().isNotEmpty)
                Text('Remarks: ${p['remarks']}', style: AppTextStyles.caption),
            ]),
            trailing: IconButton(
              icon: const Icon(Icons.print_outlined, color: AppColors.primary, size: 18),
              onPressed: () => PrintService.printReceipt(Map<String, dynamic>.from(p)),
            ),
          ),
        );
      },
    );
  }

  Widget _statusToggle(String label, String value, Color color) {
    final selected = _status == value;
    return GestureDetector(
      onTap: () => _changeStatus(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: selected ? 0 : 1),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : color,
          )),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Row(children: [
    Icon(icon, size: 16, color: AppColors.primary),
    const SizedBox(width: 8),
    Text(title, style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
  ]);
}
