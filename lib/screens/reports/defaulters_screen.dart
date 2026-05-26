import 'package:flutter/material.dart';
import '../../services/local_db.dart';
import '../../services/print_service.dart';
import '../../widgets/common.dart';

class DefaultersScreen extends StatefulWidget {
  const DefaultersScreen({super.key});
  @override
  State<DefaultersScreen> createState() => _DefaultersScreenState();
}

class _DefaultersScreenState extends State<DefaultersScreen> {
  List _defaulters = [], _allStudents = [], _years = [];
  String? _selectedYear;
  bool _loading = true;
  final Set<String> _selectedSections = {};

  @override
  void initState() { super.initState(); _loadYears(); }

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
    final results = await Future.wait([
      LocalDb.getDefaulters(yid),
      LocalDb.getStudentsWithBalance(yearId: yid),
    ]);
    setState(() {
      _defaulters = results[0] as List;
      _allStudents = results[1] as List;
      _loading = false;
      _selectedSections.clear();
    });
  }

  // All class/sections from all students
  Map<String, List<Map>> _groupedAll() {
    final Map<String, List<Map>> map = {};
    for (final s in _allStudents) {
      final key = 'Class ${s['class'] ?? ''} - Section ${s['section'] ?? ''}';
      map.putIfAbsent(key, () => []);
    }
    // Add defaulters into their groups
    for (final d in _defaulters) {
      final key = 'Class ${d['class'] ?? ''} - Section ${d['section'] ?? ''}';
      map.putIfAbsent(key, () => []).add(d);
    }
    // Remove duplicates in each group
    for (final key in map.keys) {
      final seen = <dynamic>{};
      map[key] = map[key]!.where((d) => seen.add(d['id'])).toList();
    }
    final sorted = map.keys.toList()..sort();
    return { for (final k in sorted) k: map[k]! };
  }

  void _toggleSection(String key) {
    setState(() {
      if (_selectedSections.contains(key)) {
        _selectedSections.remove(key);
      } else {
        _selectedSections.add(key);
      }
    });
  }

  void _printSelected() {
    final grouped = _groupedAll();
    // print only sections that have defaulters
    final defaulterGroups = { for (final e in grouped.entries) if (e.value.isNotEmpty) e.key: e.value };
    List<Map<String, dynamic>> rows = [];
    final sections = _selectedSections.isEmpty
        ? defaulterGroups.keys.toList()
        : _selectedSections.where((k) => defaulterGroups.containsKey(k)).toList();
    for (final key in sections) {
      rows.addAll(defaulterGroups[key]!.map((r) => Map<String, dynamic>.from(r)));
    }
    if (rows.isEmpty) { showSnack(context, 'No defaulters to print', error: true); return; }
    PrintService.printReport(
      _selectedSections.isEmpty ? 'Defaulter List' : 'Defaulters — ${_selectedSections.join(', ')}',
      rows,
      ['admission_no', 'name', 'class', 'section', 'parent_name', 'parent_phone', 'total_due', 'total_paid', 'balance'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedAll();
    final hasSelection = _selectedSections.isNotEmpty;
    final totalDefaulters = _defaulters.length;
    final totalBalance = _defaulters.fold<double>(0, (sum, d) => sum + (d['balance'] as num).toDouble());

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          PageHeader(
            'Defaulters',
            subtitle: '$totalDefaulters students with pending dues • Total Due: ₹${totalBalance.toStringAsFixed(0)} • ${grouped.length} sections${hasSelection ? ' • ${_selectedSections.length} selected' : ''}',
          ),

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
              if (hasSelection) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${_selectedSections.length} selected', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedSections.clear()),
                  child: const Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.print_outlined, size: 15),
                label: Text(hasSelection ? 'Print Selected' : 'Print All'),
                style: primaryBtn(),
                onPressed: _printSelected,
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // Summary strip
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: cardDecoration(),
            child: Row(children: [
              StatChip('Total Defaulters', '$totalDefaulters', AppColors.danger, Icons.warning_amber_rounded),
              const SizedBox(width: 16),
              StatChip('Total Due', '\u20b9${totalBalance.toStringAsFixed(0)}', AppColors.warning, Icons.currency_rupee_rounded),
              const SizedBox(width: 16),
              StatChip('Sections', '${grouped.length}', AppColors.primary, Icons.class_rounded),
            ]),
          ),

          if (hasSelection)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('Long press a section to select/deselect for printing', style: AppTextStyles.caption),
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.touch_app_rounded, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('Long press a section header to select it for printing', style: AppTextStyles.caption),
              ]),
            ),

          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : grouped.isEmpty
              ? const EmptyState(icon: Icons.people_outline_rounded, message: 'No students found')
              : ListView.builder(
                  itemCount: grouped.length,
                  itemBuilder: (_, i) {
                    final key = grouped.keys.elementAt(i);
                    final students = grouped[key]!;
                    final isSelected = _selectedSections.contains(key);
                    final hasDefaulters = students.isNotEmpty;
                    final totalBalance = students.fold<double>(0, (sum, d) => sum + (d['balance'] as num).toDouble());
                    final headerColor = hasDefaulters ? AppColors.danger : AppColors.success;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Section header — long press to select
                        GestureDetector(
                          onLongPress: () => _toggleSection(key),
                          onTap: isSelected ? () => _toggleSection(key) : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (hasDefaulters ? AppColors.primary : AppColors.success)
                                  : (hasDefaulters ? AppColors.primary.withValues(alpha: 0.08) : AppColors.success.withValues(alpha: 0.06)),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              border: Border.all(
                                color: isSelected ? headerColor : headerColor.withValues(alpha: 0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(children: [
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                ),
                              Icon(
                                Icons.class_rounded,
                                size: 16,
                                color: isSelected ? Colors.white : (hasDefaulters ? AppColors.primary : AppColors.success),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                key,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isSelected ? Colors.white : (hasDefaulters ? AppColors.primary : AppColors.success),
                                ),
                              ),
                              const Spacer(),
                              if (!hasDefaulters)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.check_circle_rounded, size: 12,
                                      color: isSelected ? Colors.white : AppColors.success),
                                    const SizedBox(width: 4),
                                    Text('All Clear',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                        color: isSelected ? Colors.white : AppColors.success)),
                                  ]),
                                )
                              else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${students.length} defaulter${students.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : AppColors.danger,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Due: ₹${totalBalance.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : AppColors.danger,
                                  ),
                                ),
                              ),
                              ],
                            ]),
                          ),
                        ),

                        // Students list — only show if has defaulters
                        if (hasDefaulters)
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            child: Column(
                              children: students.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final d = entry.value;
                                return Column(children: [
                                  if (idx > 0) const Divider(height: 1),
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    leading: Container(
                                      width: 38, height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                                    ),
                                    title: Text(d['name'] ?? '', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      '${d['admission_no'] ?? ''} • ${d['parent_name'] ?? ''} • ${d['parent_phone'] ?? ''}',
                                      style: AppTextStyles.caption,
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Due: ₹${d['balance']}',
                                            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Paid: ₹${d['total_paid']}',
                                          style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
          ),
        ]),
      ),
    );
  }
}
