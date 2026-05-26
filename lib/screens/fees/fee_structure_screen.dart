import 'package:flutter/material.dart';
import '../../services/local_db.dart';
import '../../widgets/common.dart';

class FeeStructureScreen extends StatefulWidget {
  const FeeStructureScreen({super.key});
  @override
  State<FeeStructureScreen> createState() => _FeeStructureScreenState();
}

class _FeeStructureScreenState extends State<FeeStructureScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _years = [], _types = [], _structures = [];
  String? _selectedYear;
  bool _loading = true;
  final Set<String> _selectedStructureKeys = {};

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _loadYears(); }

  Future<void> _loadYears() async {
    final years = await LocalDb.getAcademicYears();
    _years = years;
    final current = years.firstWhere((y) => y['is_current'] == 1, orElse: () => <String, Object?>{});
    if (current.isNotEmpty) _selectedYear = current['id'].toString();
    await _loadAll();
  }

  Future<void> _loadAll() async {
    if (_selectedYear == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    final yid = int.parse(_selectedYear!);
    final results = await Future.wait([LocalDb.getFeeTypes(yid), LocalDb.getFeeStructures(yid)]);
    setState(() { _types = results[0]; _structures = results[1]; _loading = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        PageHeader('Fee Structure', subtitle: 'Manage fee types, structures & discounts', actions: [
          if (_years.isNotEmpty) ...[
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey), const SizedBox(width: 6),
            DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _selectedYear,
              style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 14),
              items: _years.map<DropdownMenuItem<String>>((y) => DropdownMenuItem(value: y['id'].toString(), child: Text(y['label']))).toList(),
              onChanged: (v) { _selectedYear = v; _loadAll(); },
            )),
          ],
        ]),
        Container(decoration: cardDecoration(), child: TabBar(controller: _tabs, labelColor: AppColors.primary, unselectedLabelColor: AppColors.textMuted, indicatorColor: AppColors.primary, indicatorSize: TabBarIndicatorSize.label, labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Fee Types'), Tab(text: 'Structures')])),
        const SizedBox(height: 16),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [_typesTab(), _structuresTab()])),
      ]),
    ),
  );

  Widget _typesTab() => Column(children: [
    _tabHeader('Fee Types', Icons.category_outlined, 'Add Fee Type', _showAddTypeDialog),
    const SizedBox(height: 12),
    Expanded(child: _types.isEmpty ? _empty('No fee types added') : StyledCard(child: ClipRRect(borderRadius: BorderRadius.circular(14),
      child: ListView.separated(itemCount: _types.length, separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
        itemBuilder: (_, i) { final t = _types[i]; return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: const Icon(Icons.receipt_outlined, color: AppColors.primary, size: 18)),
          title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(t['category'].toString().toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20), onPressed: () async {
            if (await confirmDialog(context, 'Delete fee type "${t['name']}"?')) { await LocalDb.deleteFeeType(t['id'] as int); _loadAll(); }
          }),
        ); },
      )))),
  ]);

  Widget _structuresTab() {
    // Separate transport vs non-transport structures
    final List<Map> transportStructures = [];
    final Map<String, List<Map>> grouped = {};
    final List<Map> nonTerm = [];

    for (final s in _structures) {
      final cat = (s['fee_category'] ?? '').toString().toLowerCase();
      if (cat == 'transport') {
        transportStructures.add(s);
      } else if (s['period_type'] == 'term') {
        final key = '${s['fee_type_id']}_${s['class'] ?? ''}_${s['section'] ?? ''}';
        grouped.putIfAbsent(key, () => []).add(s);
      } else {
        nonTerm.add(s);
      }
    }

    final Map<String, Map<String, List<Map>>> transportByLocation = {};
    for (final s in transportStructures) {
      final loc  = (s['class']   as String? ?? 'Unknown Location');
      final stop = (s['section'] as String? ?? (s['period_label'] as String? ?? ''));
      transportByLocation.putIfAbsent(loc, () => {});
      transportByLocation[loc]!.putIfAbsent(stop, () => []).add(s);
    }
    final transportLocKeys = transportByLocation.keys.toList()..sort();
    final groupedList = grouped.values.toList();

    // Build all selectable item keys
    // transport: key = 'transport_$loc'
    // term group: key = 'term_$groupKey'
    // nonTerm: key = 'nterm_${s['id']}'

    final bool isSelecting = _selectedStructureKeys.isNotEmpty;

    return Column(children: [
      Row(children: [
        const Icon(Icons.table_chart_outlined, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        const Text('Fee Structures', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const Spacer(),
        if (isSelecting) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${_selectedStructureKeys.length} selected',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: AppColors.danger),
            tooltip: 'Delete selected',
            onPressed: () async {
              if (!await confirmDialog(context, 'Delete ${_selectedStructureKeys.length} selected structure(s)?', danger: true)) return;
              for (final key in _selectedStructureKeys) {
                if (key.startsWith('transport_')) {
                  final loc = key.substring('transport_'.length);
                  final stops = transportByLocation[loc];
                  if (stops != null) {
                    for (final stopList in stops.values) {
                      for (final s in stopList) { await LocalDb.deleteFeeStructure(s['id'] as int); }
                    }
                  }
                } else if (key.startsWith('term_')) {
                  final gKey = key.substring('term_'.length);
                  final grp = grouped[gKey];
                  if (grp != null) { for (final s in grp) { await LocalDb.deleteFeeStructure(s['id'] as int); } }
                } else if (key.startsWith('nterm_')) {
                  final id = int.tryParse(key.substring('nterm_'.length));
                  if (id != null) await LocalDb.deleteFeeStructure(id);
                }
              }
              setState(() => _selectedStructureKeys.clear());
              _loadAll();
            },
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
            onPressed: () => setState(() => _selectedStructureKeys.clear()),
          ),
        ] else
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Structure'),
            style: primaryBtn(),
            onPressed: _showAddStructureDialog,
          ),
      ]),
      if (isSelecting)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Long press to select • Tap to toggle',
              style: AppTextStyles.caption),
          ),
        ),
      const SizedBox(height: 12),
      Expanded(child: _structures.isEmpty ? _empty('No structures added') :
        ListView(children: [
          // Transport
          if (transportByLocation.isNotEmpty)
            ...transportLocKeys.map((locKey) {
              final itemKey = 'transport_$locKey';
              final isSelected = _selectedStructureKeys.contains(itemKey);
              final stopMap = transportByLocation[locKey]!;
              return GestureDetector(
                onLongPress: () => setState(() {
                  if (isSelected) _selectedStructureKeys.remove(itemKey);
                  else _selectedStructureKeys.add(itemKey);
                }),
                onTap: () {
                  if (isSelecting) {
                    setState(() {
                      if (isSelected) _selectedStructureKeys.remove(itemKey);
                      else _selectedStructureKeys.add(itemKey);
                    });
                  } else {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _LocationStructureDetailPage(
                        locationName: locKey,
                        stopMap: stopMap,
                        onRefresh: _loadAll,
                      ),
                    )).then((_) => _loadAll());
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      if (isSelecting)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(
                            isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            color: isSelected ? AppColors.primary : AppColors.textMuted, size: 20,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(locKey, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('${stopMap.length} stop(s)', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ])),
                      if (!isSelecting)
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ]),
                  ),
                ),
              );
            }),

          // Term groups
          if (groupedList.isNotEmpty)
            ...grouped.entries.map((entry) {
              final gKey = entry.key;
              final group = entry.value;
              final itemKey = 'term_$gKey';
              final isSelected = _selectedStructureKeys.contains(itemKey);
              final first = group.first;
              final cls = first['class'] as String? ?? '';
              final sec = first['section'] as String? ?? '';
              final typeName = first['fee_type_name'] as String? ?? '';
              return GestureDetector(
                onLongPress: () => setState(() {
                  if (isSelected) _selectedStructureKeys.remove(itemKey);
                  else _selectedStructureKeys.add(itemKey);
                }),
                onTap: () {
                  if (isSelecting) {
                    setState(() {
                      if (isSelected) _selectedStructureKeys.remove(itemKey);
                      else _selectedStructureKeys.add(itemKey);
                    });
                  } else {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _TermStructureDetailPage(group: group, onRefresh: _loadAll),
                    )).then((_) => _loadAll());
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: isSelecting
                      ? Icon(isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isSelected ? AppColors.primary : AppColors.textMuted, size: 20)
                      : CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.bookmark_rounded, color: AppColors.primary, size: 18)),
                    title: Text(typeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [if (cls.isNotEmpty) 'Class $cls', if (sec.isNotEmpty) 'Sec $sec', 'Term'].join(' • '),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: isSelecting ? null : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ),
                ),
              );
            }),

          // Non-term
          if (nonTerm.isNotEmpty)
            ...nonTerm.map((s) {
              final itemKey = 'nterm_${s['id']}';
              final isSelected = _selectedStructureKeys.contains(itemKey);
              return GestureDetector(
                onLongPress: () => setState(() {
                  if (isSelected) _selectedStructureKeys.remove(itemKey);
                  else _selectedStructureKeys.add(itemKey);
                }),
                onTap: () {
                  if (isSelecting) {
                    setState(() {
                      if (isSelected) _selectedStructureKeys.remove(itemKey);
                      else _selectedStructureKeys.add(itemKey);
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: isSelecting
                      ? Icon(isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isSelected ? AppColors.accent : AppColors.textMuted, size: 20)
                      : CircleAvatar(backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                          child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.accent, size: 18)),
                    title: Text('${s['fee_type_name']} — ${s['period_label']}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(s['period_type'].toString().toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: isSelecting ? null : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('₹${s['amount']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success))),
                  ),
                ),
              );
            }),
        ]),
      ),
    ]);
  }

  Widget _tabHeader(String title, IconData icon, String btnLabel, VoidCallback onTap) => Row(children: [
    Icon(icon, color: AppColors.primary, size: 18), const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), const Spacer(),
    ElevatedButton.icon(icon: const Icon(Icons.add, size: 16), label: Text(btnLabel), style: primaryBtn(), onPressed: onTap),
  ]);

  Widget _empty(String msg) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300), const SizedBox(height: 10), Text(msg, style: const TextStyle(color: Colors.grey))]));

  void _showAddTypeDialog() {
    String category = 'tuition';
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Add Fee Type'),
      content: DropdownButtonFormField<String>(value: category, decoration: styledInput('Category', icon: Icons.category_outlined),
        items: ['tuition', 'transport', 'library', 'sports', 'miscellaneous'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => ss(() => category = v!)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(style: primaryBtn(), onPressed: () async {
          await LocalDb.insertFeeType({'name': category, 'category': category, 'academic_year_id': int.parse(_selectedYear!)});
          if (mounted) Navigator.pop(ctx); _loadAll();
        }, child: const Text('Add'))],
    )));
  }

  void _showAddStructureDialog() {
    if (_types.isEmpty) { showSnack(context, 'Add fee types first', error: true); return; }
    int? typeId = _types.first['id'] as int;
    String selectedCategory = (_types.first['category'] ?? '').toString().toLowerCase();
    final amount = TextEditingController();
    final cls = TextEditingController();
    final section = TextEditingController();
    String selectedPeriodType = 'monthly';

    List<Map> locations = [];
    int? selectedLocationId;
    final locationTextCtrl = TextEditingController();
    List<Map> filteredLocations = [];
    bool showLocationSuggestions = false;
    List<Map<String, TextEditingController>> stopRows = [
      {'stop': TextEditingController(), 'amount': TextEditingController()}
    ];
    String? selectedTransportTerm;
    final Set<String> selectedTransportTerms = {};
    final termAmounts = {
      'Term 1': TextEditingController(),
      'Term 2': TextEditingController(),
      'Term 3': TextEditingController(),
    };

    Future<void> loadLocations(StateSetter ss) async {
      final data = await LocalDb.getTransportLocations();
      ss(() {
        locations = data;
        filteredLocations = data;
        selectedLocationId = data.isNotEmpty ? data.first['id'] as int : null;
        if (selectedLocationId != null) {
          locationTextCtrl.text = data.first['location'] as String;
          LocalDb.getTransportStops(selectedLocationId!).then((stops) {
            ss(() {
              stopRows = stops.isEmpty
                ? [{'stop': TextEditingController(), 'amount': TextEditingController()}]
                : stops.map((s) => {
                    'stop': TextEditingController(text: s['stop_name'] as String),
                    'amount': TextEditingController(text: (s['amount'] as num).toStringAsFixed(0)),
                  }).toList();
            });
          });
        }
      });
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {
        final isTransport = selectedCategory == 'transport';

        if (isTransport && locations.isEmpty) {
          Future.microtask(() => loadLocations(ss));
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Fee Structure'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [

              // Fee Type
              DropdownButtonFormField<int>(
                value: typeId,
                decoration: styledInput('Fee Type', icon: Icons.receipt_outlined),
                items: _types.map<DropdownMenuItem<int>>((t) =>
                  DropdownMenuItem(value: t['id'] as int, child: Text(t['name']))).toList(),
                onChanged: (v) {
                  ss(() {
                    typeId = v;
                    selectedCategory = (_types.firstWhere((t) => t['id'] == v)['category'] ?? '').toString().toLowerCase();
                    if (selectedCategory == 'transport') loadLocations(ss);
                  });
                },
              ),
              const SizedBox(height: 10),

              // ── Transport ──
              if (isTransport) ...[
                // Location field — type new or pick existing
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(
                    controller: locationTextCtrl,
                    style: AppTextStyles.body,
                    decoration: styledInput('Location (type new or pick existing)', icon: Icons.location_on_rounded),
                    onChanged: (val) {
                      ss(() {
                        filteredLocations = locations.where((l) =>
                          (l['location'] as String).toLowerCase().contains(val.toLowerCase())).toList();
                        showLocationSuggestions = val.isNotEmpty;
                        final match = locations.firstWhere(
                          (l) => (l['location'] as String).toLowerCase() == val.toLowerCase(),
                          orElse: () => <String, Object?>{},
                        );
                        if (match.isNotEmpty) {
                          selectedLocationId = match['id'] as int;
                          LocalDb.getTransportStops(selectedLocationId!).then((stops) {
                            ss(() {
                              stopRows = stops.isEmpty
                                ? [{'stop': TextEditingController(), 'amount': TextEditingController()}]
                                : stops.map((s) => {
                                    'stop': TextEditingController(text: s['stop_name'] as String),
                                    'amount': TextEditingController(text: (s['amount'] as num).toStringAsFixed(0)),
                                  }).toList();
                            });
                          });
                        } else {
                          selectedLocationId = null;
                          stopRows = [{'stop': TextEditingController(), 'amount': TextEditingController()}];
                        }
                      });
                    },
                  ),
                  // Suggestions dropdown
                  if (showLocationSuggestions && filteredLocations.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                      ),
                      child: Column(
                        children: filteredLocations.map((l) => InkWell(
                          onTap: () {
                            ss(() {
                              selectedLocationId = l['id'] as int;
                              locationTextCtrl.text = l['location'] as String;
                              showLocationSuggestions = false;
                            });
                            LocalDb.getTransportStops(l['id'] as int).then((stops) {
                              ss(() {
                                stopRows = stops.isEmpty
                                  ? [{'stop': TextEditingController(), 'amount': TextEditingController()}]
                                  : stops.map((s) => {
                                      'stop': TextEditingController(text: s['stop_name'] as String),
                                      'amount': TextEditingController(text: (s['amount'] as num).toStringAsFixed(0)),
                                    }).toList();
                              });
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(l['location'] as String, style: AppTextStyles.body),
                            ]),
                          ),
                        )).toList(),
                      ),
                    ),
                  // New location hint
                  if (locationTextCtrl.text.trim().isNotEmpty && selectedLocationId == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        const Icon(Icons.add_location_alt_rounded, size: 13, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text('New location "${locationTextCtrl.text.trim()}" will be created',
                          style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Left — Stops
                  Expanded(child: Container(
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      ...stopRows.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: TextField(controller: e.value['stop'], style: AppTextStyles.body, decoration: styledInput('Stop ${e.key + 1}', icon: Icons.place_outlined)),
                      )),
                    ]),
                  )),
                  const SizedBox(width: 10),
                  // Right — Amounts + Add Stop
                  Expanded(child: Container(
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      ...stopRows.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: TextField(controller: e.value['amount'], style: AppTextStyles.body, keyboardType: TextInputType.number, decoration: styledInput('₹ Amount', icon: Icons.currency_rupee_rounded)),
                      )),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Stop', style: TextStyle(fontSize: 12)),
                          style: outlineBtn(),
                          onPressed: () => ss(() => stopRows.add({'stop': TextEditingController(), 'amount': TextEditingController()})),
                        )),
                      ),
                    ]),
                  )),
                ]),
                const SizedBox(height: 10),
                // Term selection buttons
                Row(children: ['Term 1', 'Term 2', 'Term 3'].map((t) {
                  final selected = selectedTransportTerms.contains(t);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => ss(() {
                        if (selected) {
                          selectedTransportTerms.remove(t);
                        } else {
                          selectedTransportTerms.add(t);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 0 : 1),
                        ),
                        child: Text(t, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.textSecondary,
                        )),
                      ),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 10),
              ],

              // Amount for non-transport
              if (!isTransport) ...[
                DropdownButtonFormField<String>(
                  value: selectedPeriodType,
                  decoration: styledInput('Period Type', icon: Icons.date_range_outlined),
                  items: ['monthly', 'term', 'annual'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => ss(() => selectedPeriodType = v!),
                ),
                const SizedBox(height: 10),
                if (selectedPeriodType == 'term') ...[
                  Row(children: [
                    Expanded(child: TextFormField(controller: cls, decoration: styledInput('Class', icon: Icons.class_outlined))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: section, decoration: styledInput('Section', icon: Icons.group_outlined))),
                  ]),
                  const SizedBox(height: 10),
                  ...['Term 1', 'Term 2', 'Term 3'].map((t) {
                    final selected = selectedTransportTerms.contains(t);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => ss(() {
                            if (selected) selectedTransportTerms.remove(t);
                            else selectedTransportTerms.add(t);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 76,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                            ),
                            child: Text(t, textAlign: TextAlign.center, style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : AppColors.textSecondary,
                            )),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(
                          controller: termAmounts[t],
                          keyboardType: TextInputType.number,
                          style: AppTextStyles.body,
                          decoration: styledInput('₹ Amount', icon: Icons.currency_rupee_rounded),
                        )),
                      ]),
                    );
                  }),
                ] else
                  TextFormField(controller: amount, decoration: styledInput('Amount (₹)', icon: Icons.currency_rupee), keyboardType: TextInputType.number),
              ],
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: primaryBtn(),
              onPressed: () async {
                if (isTransport) {
                  final locationName = locationTextCtrl.text.trim();
                  if (locationName.isEmpty) {
                    showSnack(context, 'Enter a location name', error: true);
                    return;
                  }
                  // Create new location if not existing
                  if (selectedLocationId == null) {
                    selectedLocationId = await LocalDb.insertTransportLocation(locationName, 0);
                  }
                  for (final row in stopRows) {
                    final stopName = row['stop']!.text.trim();
                    final stopAmt  = double.tryParse(row['amount']!.text.trim()) ?? 0;
                    if (stopName.isEmpty) continue;
                    final locationName = locationTextCtrl.text.trim();
                    if (selectedTransportTerms.isNotEmpty) {
                      for (final term in selectedTransportTerms) {
                        await LocalDb.insertFeeStructure({
                          'fee_type_id': typeId, 'class': locationName, 'section': stopName,
                          'period_type': 'term',
                          'period_label': '$term - $stopName',
                          'amount': stopAmt, 'due_date': null,
                          'academic_year_id': int.parse(_selectedYear!),
                        });
                      }
                    } else {
                      await LocalDb.insertFeeStructure({
                        'fee_type_id': typeId, 'class': locationName, 'section': stopName,
                        'period_type': 'monthly',
                        'period_label': stopName,
                        'amount': stopAmt, 'due_date': null,
                        'academic_year_id': int.parse(_selectedYear!),
                      });
                    }
                  }
                } else if (selectedPeriodType == 'term') {
                  for (final t in ['Term 1', 'Term 2', 'Term 3']) {
                    final amt = double.tryParse(termAmounts[t]!.text.trim()) ?? 0;
                    if (amt == 0) continue;
                    await LocalDb.insertFeeStructure({
                      'fee_type_id': typeId,
                      'class': cls.text.trim().isEmpty ? null : cls.text.trim(),
                      'section': section.text.trim().isEmpty ? null : section.text.trim(),
                      'period_type': 'term', 'period_label': t,
                      'amount': amt,
                      'due_date': null,
                      'academic_year_id': int.parse(_selectedYear!),
                    });
                  }
                } else {
                  await LocalDb.insertFeeStructure({
                    'fee_type_id': typeId, 'class': null, 'section': null,
                    'period_type': selectedPeriodType, 'period_label': '',
                    'amount': double.tryParse(amount.text) ?? 0,
                    'due_date': null,
                    'academic_year_id': int.parse(_selectedYear!),
                  });
                }
                if (mounted) Navigator.pop(ctx);
                _loadAll();
              },
              child: const Text('Add'),
            ),
          ],
        );
      }),
    );
  }

}

// ── Location Structure Detail Page ───────────────────────────────────────────────
class _LocationStructureDetailPage extends StatefulWidget {
  final String locationName;
  final Map<String, List<Map>> stopMap;
  final VoidCallback onRefresh;
  const _LocationStructureDetailPage({
    required this.locationName,
    required this.stopMap,
    required this.onRefresh,
  });
  @override
  State<_LocationStructureDetailPage> createState() => _LocationStructureDetailPageState();
}

class _LocationStructureDetailPageState extends State<_LocationStructureDetailPage> {
  late Map<String, List<Map>> _stopMap;

  @override
  void initState() {
    super.initState();
    _stopMap = Map.from(widget.stopMap);
  }

  Future<void> _addStop() async {
    final stopCtrl = TextEditingController();
    final termCtrls = {
      'Term 1': TextEditingController(),
      'Term 2': TextEditingController(),
      'Term 3': TextEditingController(),
    };
    // Get fee type id for transport
    final years = await LocalDb.getAcademicYears();
    final current = years.firstWhere((y) => y['is_current'] == 1, orElse: () => <String, Object?>{});
    if (current.isEmpty) return;
    final yid = current['id'] as int;
    final feeTypes = await LocalDb.getFeeTypes(yid);
    final transportType = feeTypes.firstWhere(
      (t) => (t['category'] ?? '').toString().toLowerCase() == 'transport',
      orElse: () => <String, Object?>{},
    );
    if (transportType.isEmpty) {
      if (mounted) showSnack(context, 'No transport fee type found', error: true);
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.place_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text('Add Stop — ${widget.locationName}', style: AppTextStyles.h3),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: stopCtrl,
            style: AppTextStyles.body,
            decoration: styledInput('Stop name', icon: Icons.place_outlined),
          ),
          const SizedBox(height: 12),
          ...['Term 1', 'Term 2', 'Term 3'].map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(t, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: termCtrls[t],
                keyboardType: TextInputType.number,
                style: AppTextStyles.body,
                decoration: styledInput('₹ Amount', icon: Icons.currency_rupee_rounded),
              )),
            ]),
          )),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: primaryBtn(),
            onPressed: () async {
              final stopName = stopCtrl.text.trim();
              if (stopName.isEmpty) { showSnack(context, 'Enter stop name', error: true); return; }
              final newEntries = <Map>[];
              for (final t in ['Term 1', 'Term 2', 'Term 3']) {
                final amt = double.tryParse(termCtrls[t]!.text.trim()) ?? 0;
                if (amt <= 0) continue;
                final id = await LocalDb.insertFeeStructure({
                  'fee_type_id': transportType['id'],
                  'class': widget.locationName,
                  'section': stopName,
                  'period_type': 'term',
                  'period_label': '$t - $stopName',
                  'amount': amt,
                  'due_date': null,
                  'academic_year_id': yid,
                });
                newEntries.add({
                  'id': id, 'fee_type_id': transportType['id'],
                  'fee_type_name': transportType['name'],
                  'class': widget.locationName, 'section': stopName,
                  'period_type': 'term', 'period_label': '$t - $stopName',
                  'amount': amt, 'academic_year_id': yid,
                });
              }
              setState(() => _stopMap[stopName] = newEntries);
              widget.onRefresh();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editEntry(Map s) async {
    final amtCtrl = TextEditingController(text: (s['amount'] as num).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text(s['period_label'] as String? ?? '', style: AppTextStyles.h3),
        ]),
        content: TextField(
          controller: amtCtrl,
          keyboardType: TextInputType.number,
          style: AppTextStyles.body,
          decoration: styledInput('Amount (₹)', icon: Icons.currency_rupee_rounded),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: primaryBtn(),
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
              await LocalDb.updateFeeStructure(s['id'] as int, amt);
              setState(() {
                for (final key in _stopMap.keys) {
                  final idx = _stopMap[key]!.indexWhere((e) => e['id'] == s['id']);
                  if (idx != -1) {
                    _stopMap[key]![idx] = Map<String, dynamic>.from(_stopMap[key]![idx])..['amount'] = amt;
                    break;
                  }
                }
              });
              if (mounted) Navigator.pop(context);
              widget.onRefresh();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntry(int id) async {
    if (!await confirmDialog(context, 'Delete this entry?')) return;
    await LocalDb.deleteFeeStructure(id);
    setState(() {
      for (final key in _stopMap.keys.toList()) {
        _stopMap[key]!.removeWhere((s) => s['id'] == id);
        if (_stopMap[key]!.isEmpty) _stopMap.remove(key);
      }
    });
    widget.onRefresh();
  }

  Future<void> _deleteStop(String stopName) async {
    if (!await confirmDialog(context, 'Delete all entries for "$stopName"?', danger: true)) return;
    for (final s in _stopMap[stopName]!) { await LocalDb.deleteFeeStructure(s['id'] as int); }
    setState(() => _stopMap.remove(stopName));
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final stopKeys = _stopMap.keys.toList()..sort();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.locationName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text('${stopKeys.length} stop(s)', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Stop',
            onPressed: _addStop,
          ),
        ],
      ),
      body: _stopMap.isEmpty
        ? const EmptyState(icon: Icons.place_outlined, message: 'No stops found')
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: stopKeys.length,
            itemBuilder: (_, i) {
              final stopName = stopKeys[i];
              final terms = _stopMap[stopName]!;
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: cardDecoration(),
                child: Column(children: [
                  // Stop header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.07),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.place_outlined, color: AppColors.accent, size: 15),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(stopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.accent))),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                        tooltip: 'Delete stop',
                        onPressed: () => _deleteStop(stopName),
                      ),
                    ]),
                  ),
                  // Term rows
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.primary.withValues(alpha: 0.04),
                    child: Row(children: [
                      Expanded(child: Text('Term', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                      Text('Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                      const SizedBox(width: 40),
                    ]),
                  ),
                  ...terms.asMap().entries.map((e) {
                    final s = e.value;
                    final amt = (s['amount'] as num).toDouble();
                    return Column(children: [
                      if (e.key > 0) Divider(height: 1, color: Colors.grey.shade100),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(children: [
                          Expanded(child: Text(s['period_label'] as String? ?? '',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text('₹${amt.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 13)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 16),
                            onPressed: () => _editEntry(s),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 16),
                            onPressed: () => _deleteEntry(s['id'] as int),
                          ),
                        ]),
                      ),
                    ]);
                  }),
                ]),
              );
            },
          ),
    );
  }
}

// ── Term Structure Detail Page ────────────────────────────────────────────────
class _TermStructureDetailPage extends StatefulWidget {
  final List<Map> group;
  final VoidCallback onRefresh;
  const _TermStructureDetailPage({required this.group, required this.onRefresh});
  @override
  State<_TermStructureDetailPage> createState() => _TermStructureDetailPageState();
}

class _TermStructureDetailPageState extends State<_TermStructureDetailPage> {
  late List<Map> _terms;

  @override
  void initState() {
    super.initState();
    _terms = List<Map>.from(widget.group);
    _terms.sort((a, b) => (a['period_label'] as String).compareTo(b['period_label'] as String));
  }

  void _editTerm(Map term) {
    final amtCtrl = TextEditingController(text: (term['amount'] as num).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text('Edit ${term['period_label']}', style: AppTextStyles.h3),
        ]),
        content: TextField(
          controller: amtCtrl,
          keyboardType: TextInputType.number,
          style: AppTextStyles.body,
          decoration: styledInput('Amount (₹)', icon: Icons.currency_rupee_rounded),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: primaryBtn(),
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
              await LocalDb.updateFeeStructure(term['id'] as int, amt);
              setState(() {
                final idx = _terms.indexWhere((t) => t['id'] == term['id']);
                if (idx != -1) {
                  _terms[idx] = Map<String, dynamic>.from(_terms[idx])..['amount'] = amt;
                }
              });
              if (mounted) Navigator.pop(context);
              widget.onRefresh();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = _terms.isNotEmpty ? _terms.first : {};
    final cls = first['class'] as String? ?? '';
    final sec = first['section'] as String? ?? '';
    final typeName = first['fee_type_name'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(typeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(
            [if (cls.isNotEmpty) 'Class $cls', if (sec.isNotEmpty) 'Sec $sec'].join(' • '),
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ]),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: StyledCard(child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppColors.primary.withValues(alpha: 0.07),
              child: Row(children: [
                Expanded(child: Text('Term', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
                Text('Amount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                const SizedBox(width: 48),
              ]),
            ),
            ..._terms.asMap().entries.map((e) {
              final t = e.value;
              final amt = (t['amount'] as num).toDouble();
              return Column(mainAxisSize: MainAxisSize.min, children: [
                if (e.key > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(children: [
                    Expanded(child: Text(t['period_label'] as String? ?? '',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    Text('₹${amt.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      onPressed: () => _editTerm(t),
                    ),
                  ]),
                ),
              ]);
            }),
          ]),
        )),
      ),
    );
  }
}
