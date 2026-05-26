import 'package:flutter/material.dart';
import '../../services/local_db.dart';
import '../../services/print_service.dart';
import '../../widgets/common.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _years = [], _classSummary = [], _incomeRows = [];
  Map<String, dynamic>? _incomeTotals;
  String? _selectedYear;
  bool _loading = true;
  final Set<int> _selectedIndices = {};
  bool get _isSelecting => _selectedIndices.isNotEmpty;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _loadYears(); }

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
    final yid = int.parse(_selectedYear!);
    final results = await Future.wait([LocalDb.getClassSummary(yid), LocalDb.getAnnualIncome(yid)]);
    final income = results[1] as Map<String, dynamic>;
    setState(() { _classSummary = results[0] as List; _incomeRows = income['rows'] as List; _incomeTotals = income; _loading = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        PageHeader('Reports', actions: [
          if (_years.isNotEmpty) ...[
            const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _selectedYear,
              style: AppTextStyles.body,
              items: _years.map<DropdownMenuItem<String>>((y) => DropdownMenuItem(value: y['id'].toString(), child: Text(y['label']))).toList(),
              onChanged: (v) { _selectedYear = v; _load(); },
            )),
          ],
        ]),
        Container(
          decoration: cardDecoration(),
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Class-wise Summary'), Tab(text: 'Annual Income')],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [_classSummaryTab(), _annualIncomeTab()])),
      ]),
    ),
  );

  Widget _classSummaryTab() {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        if (_isSelecting) ...([
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Text('${_selectedIndices.length} selected',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.deselect_rounded, size: 14),
            label: const Text('Clear'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() => _selectedIndices.clear()),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 14),
            label: const Text('Print Selected'),
            style: primaryBtn(),
            onPressed: () {
              final selected = _selectedIndices.map((i) => Map<String, dynamic>.from(_classSummary[i])).toList();
              PrintService.printReport('Class-wise Fee Summary', selected,
                ['class', 'section', 'student_count', 'total_billed', 'total_collected', 'pending']);
            },
          ),
        ])
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 15),
            label: const Text('Print All'),
            style: primaryBtn(),
            onPressed: () => PrintService.printReport('Class-wise Fee Summary',
              _classSummary.map((r) => Map<String, dynamic>.from(r)).toList(),
              ['class', 'section', 'student_count', 'total_billed', 'total_collected', 'pending']),
          ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _isSelecting ? 'Tap to toggle selection' : 'Long press a card to start selecting',
            style: AppTextStyles.caption,
          ),
        ),
      ),
      const SizedBox(height: 12),
    Expanded(child: _classSummary.isEmpty
      ? const EmptyState(icon: Icons.bar_chart_rounded, message: 'No class data available')
      : GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 280,
            mainAxisExtent: 190,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _classSummary.length,
          itemBuilder: (_, i) {
            final r = _classSummary[i];
            final billed    = (r['total_billed']    as num).toDouble();
            final collected = (r['total_collected'] as num).toDouble();
            final pending   = (r['pending']         as num).toDouble();
            final rate      = billed > 0 ? (collected / billed * 100) : 0.0;
            final rateColor = rate >= 75 ? AppColors.success : rate >= 50 ? AppColors.warning : AppColors.danger;

            const palette = [
              AppColors.primary, Color(0xFF7C3AED), Color(0xFF0891B2),
              Color(0xFFDB2777), AppColors.success, Color(0xFFD97706),
            ];
            final c = palette['${r['class']}${r['section']}'.hashCode.abs() % palette.length];

            return GestureDetector(
              onLongPress: () => setState(() {
                if (_selectedIndices.contains(i)) _selectedIndices.remove(i);
                else _selectedIndices.add(i);
              }),
              onTap: () {
                if (_isSelecting) {
                  setState(() {
                    if (_selectedIndices.contains(i)) _selectedIndices.remove(i);
                    else _selectedIndices.add(i);
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _selectedIndices.contains(i) ? c.withValues(alpha: 0.08) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedIndices.contains(i) ? c : AppColors.border,
                    width: _selectedIndices.contains(i) ? 2 : 1,
                  ),
                  boxShadow: _selectedIndices.contains(i) ? [
                    BoxShadow(color: c.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
                  ] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Class + Section badges
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
                          child: Text('Class ${r['class'] ?? ''}',
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
                          child: Text('Sec ${r['section'] ?? ''}',
                            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        const Spacer(),
                        Row(children: [
                          const Icon(Icons.people_rounded, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text('${r['student_count']}', style: AppTextStyles.caption),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      _feeRow('Billed',    '₹${_fmtNum(billed)}',    AppColors.primary),
                      const SizedBox(height: 6),
                      _feeRow('Collected', '₹${_fmtNum(collected)}', AppColors.success),
                      const SizedBox(height: 6),
                      _feeRow('Pending',   '₹${_fmtNum(pending)}',   AppColors.warning),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: rate / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(rateColor),
                          ),
                        )),
                        const SizedBox(width: 8),
                        Text('${rate.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: rateColor)),
                      ]),
                    ]),
                    // Selected checkmark
                    if (_selectedIndices.contains(i))
                      Positioned(
                        top: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
    ),
    ]);
  }

  Widget _feeRow(String label, String value, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: AppTextStyles.caption),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ],
  );

  String _fmtNum(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _annualIncomeTab() => Column(children: [
    if (_incomeTotals != null) ...[
      Wrap(spacing: 12, runSpacing: 12, children: [
        StatChip('Total Billed', '₹${_incomeTotals!['grand_total_billed']}', AppColors.primary, Icons.receipt_long_rounded),
        StatChip('Collected', '₹${_incomeTotals!['grand_total_collected']}', AppColors.success, Icons.check_circle_rounded),
        StatChip('Pending', '₹${_incomeTotals!['pending']}', AppColors.warning, Icons.pending_actions_rounded),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.print_outlined, size: 15),
          label: const Text('Print'),
          style: primaryBtn(),
          onPressed: () => PrintService.printReport('Annual Income Statement', _incomeRows.map((r) => Map<String, dynamic>.from(r)).toList(), ['fee_type', 'category', 'total_billed', 'total_collected']),
        ),
      ]),
      const SizedBox(height: 12),
    ],
    Expanded(child: StyledCard(child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.05)),
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 12, letterSpacing: 0.3),
        dataTextStyle: AppTextStyles.body,
        columns: const [
          DataColumn(label: Text('Fee Type')), DataColumn(label: Text('Category')),
          DataColumn(label: Text('Total Billed')), DataColumn(label: Text('Collected')),
        ],
        rows: _incomeRows.map((r) => DataRow(cells: [
          DataCell(Text(r['fee_type'] ?? '')), DataCell(Text(r['category'] ?? '')),
          DataCell(Text('₹${r['total_billed']}')),
          DataCell(Text('₹${r['total_collected']}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))),
        ])).toList(),
      )),
    ))),
  ]);
}
