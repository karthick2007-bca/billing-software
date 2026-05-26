import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/inv_export_service.dart';
import '../../widgets/common.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _items = [], _txns = [];
  String _search = '', _catFilter = '';
  bool _lowStockOnly = false, _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      String path = '/inventory/store/items?';
      if (_search.isNotEmpty) path += 'search=$_search&';
      if (_catFilter.isNotEmpty) path += 'category=$_catFilter&';
      if (_lowStockOnly) path += 'low_stock=1';
      final results = await Future.wait([
        ApiService.get(path),
        ApiService.get('/inventory/store/transactions'),
      ]);
      setState(() {
        _items = results[0] as List;
        _txns = results[1] as List;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          const Expanded(child: SectionHeader('Inventory / Store')),
          ElevatedButton.icon(
            icon: const Icon(Icons.add), label: const Text('Add Item'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => _showItemDialog(),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF'),
            onPressed: _exportPdf,
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(width: 200, child: TextField(
            decoration: const InputDecoration(hintText: 'Search name/code', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
            onChanged: (v) { _search = v; _load(); },
          )),
          const SizedBox(width: 8),
          SizedBox(width: 140, child: TextField(
            decoration: const InputDecoration(hintText: 'Category', isDense: true, border: OutlineInputBorder()),
            onChanged: (v) { _catFilter = v; _load(); },
          )),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Low Stock'),
            selected: _lowStockOnly,
            selectedColor: AppColors.danger.withValues(alpha: 0.15),
            onSelected: (v) { _lowStockOnly = v; _load(); },
          ),
        ]),
        const SizedBox(height: 8),
        TabBar(controller: _tabs, labelColor: AppColors.primary, tabs: const [
          Tab(text: 'Items'), Tab(text: 'Transactions'), Tab(text: 'Report'),
        ]),
        const SizedBox(height: 8),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [_itemsTab(), _txnsTab(), _reportTab()]),
        ),
      ]),
    ),
  );

  Widget _itemsTab() => _items.isEmpty
    ? const Center(child: Text('No items found'))
    : Card(child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final it = _items[i];
          final isLow = (it['current_stock'] as num) <= (it['reorder_level'] as num);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isLow ? AppColors.danger.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1),
              child: Icon(Icons.inventory_2, color: isLow ? AppColors.danger : AppColors.primary, size: 18),
            ),
            title: Row(children: [
              Text(it['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              if (isLow) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(8)),
                child: const Text('LOW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
            subtitle: Text('Code: ${it['item_code']} | Cat: ${it['category']} | Unit: ${it['unit']}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Stock: ${it['current_stock']}', style: TextStyle(fontWeight: FontWeight.bold, color: isLow ? AppColors.danger : AppColors.success)),
                Text('Reorder: ${it['reorder_level']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              const SizedBox(width: 4),
              PopupMenuButton(itemBuilder: (_) => [
                const PopupMenuItem(value: 'in', child: Text('Stock In')),
                const PopupMenuItem(value: 'out', child: Text('Stock Out')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ], onSelected: (v) async {
                if (v == 'in') _showStockDialog(it, 'in');
                if (v == 'out') _showStockDialog(it, 'out');
                if (v == 'edit') _showItemDialog(item: it);
                if (v == 'delete') {
                  if (await confirmDialog(context, 'Delete "${it['name']}"?')) {
                    await ApiService.delete('/inventory/store/items/${it['id']}');
                    _load();
                  }
                }
              }),
            ]),
          );
        },
      ));

  Widget _txnsTab() => _txns.isEmpty
    ? const Center(child: Text('No transactions yet'))
    : Card(child: ListView.separated(
        itemCount: _txns.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final t = _txns[i];
          final isIn = t['txn_type'] == 'stock_in';
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isIn ? AppColors.success.withValues(alpha: 0.15) : AppColors.danger.withValues(alpha: 0.15),
              child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? AppColors.success : AppColors.danger, size: 18),
            ),
            title: Text('${t['item_name']} (${t['item_code']})'),
            subtitle: Text('${t['txn_date']} | ${t['remarks'] ?? '-'}'),
            trailing: Text('${isIn ? '+' : '-'}${t['quantity']} ${t['unit']}',
              style: TextStyle(fontWeight: FontWeight.bold, color: isIn ? AppColors.success : AppColors.danger)),
          );
        },
      ));

  Widget _reportTab() {
    final low = _items.where((i) => (i['current_stock'] as num) <= (i['reorder_level'] as num)).toList();
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total Items: ${_items.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Low Stock Alerts: ${low.length}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
      ]))),
      if (low.isNotEmpty) ...[
        const Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('Low Stock Items', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger))),
        Card(child: Column(children: low.map((i) => ListTile(
          dense: true,
          leading: const Icon(Icons.warning, color: AppColors.danger, size: 18),
          title: Text(i['name']),
          subtitle: Text('Current: ${i['current_stock']} | Reorder: ${i['reorder_level']}'),
          trailing: const SizedBox.shrink(),
        )).toList())),
      ],
    ]));
  }

  void _showItemDialog({Map? item}) {
    final code = TextEditingController(text: item?['item_code'] ?? '');
    final name = TextEditingController(text: item?['name'] ?? '');
    final cat = TextEditingController(text: item?['category'] ?? '');
    final unit = TextEditingController(text: item?['unit'] ?? 'nos');
    final opening = TextEditingController(text: item?['opening_stock']?.toString() ?? '0');
    final reorder = TextEditingController(text: item?['reorder_level']?.toString() ?? '0');

    final fk = GlobalKey<FormState>();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(item == null ? 'Add Store Item' : 'Edit Item'),
      content: SizedBox(width: 400, child: Form(key: fk, child: SingleChildScrollView(child: Wrap(spacing: 10, runSpacing: 10, children: [
        _tf(code, 'Item Code', req: item == null),
        _tf(name, 'Item Name', req: true),
        _tf(cat, 'Category', req: true),
        _tf(unit, 'Unit (nos/kg/litre)'),
        if (item == null) _tf(opening, 'Opening Stock', num: true),
        _tf(reorder, 'Reorder Level', num: true),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (!fk.currentState!.validate()) return;
          final body = {
            'item_code': code.text, 'name': name.text, 'category': cat.text,
            'unit': unit.text, 'opening_stock': double.tryParse(opening.text) ?? 0,
            'reorder_level': double.tryParse(reorder.text) ?? 0,
          };
          if (item == null) {
            await ApiService.post('/inventory/store/items', body);
          } else {
            await ApiService.put('/inventory/store/items/${item['id']}', body);
          }
          if (ctx.mounted) Navigator.pop(ctx);
          _load();
        }, child: const Text('Save')),
      ],
    ));
  }

  void _showStockDialog(Map item, String type) {
    final qty = TextEditingController();
    final remarks = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('${type == 'in' ? 'Stock In' : 'Stock Out'}: ${item['name']}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Current Stock: ${item['current_stock']} ${item['unit']}', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: remarks, decoration: const InputDecoration(labelText: 'Remarks (optional)', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: type == 'in' ? AppColors.success : AppColors.danger, foregroundColor: Colors.white),
          onPressed: () async {
            final q = double.tryParse(qty.text);
            if (q == null || q <= 0) { showSnack(context, 'Enter valid quantity', error: true); return; }
            try {
              await ApiService.post('/inventory/store/items/${item['id']}/stock-$type', {'quantity': q, 'remarks': remarks.text});
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
              if (mounted) showSnack(context, 'Stock updated');
            } catch (e) {
              if (mounted) showSnack(context, e.toString(), error: true);
            }
          },
          child: Text(type == 'in' ? 'Add Stock' : 'Remove Stock'),
        ),
      ],
    ));
  }

  Future<void> _exportPdf() async {
    final headers = ['Code', 'Name', 'Category', 'Unit', 'Stock', 'Reorder'];
    final rows = _items.map((i) => [
      i['item_code'].toString(), i['name'].toString(), i['category'].toString(),
      i['unit'].toString(), i['current_stock'].toString(), i['reorder_level'].toString(),
    ]).toList();
    await InvExportService.exportPdf('Store Inventory Report', headers, rows);
  }

  Future<void> _exportExcel() async {
    final headers = ['Code', 'Name', 'Category', 'Unit', 'Stock', 'Reorder'];
    final rows = _items.map((i) => [
      i['item_code'].toString(), i['name'].toString(), i['category'].toString(),
      i['unit'].toString(), i['current_stock'].toString(), i['reorder_level'].toString(),
    ]).toList();
    final path = await InvExportService.exportExcel('Store Inventory Report', headers, rows);
    if (mounted) showSnack(context, 'Saved: $path');
  }

  Widget _tf(TextEditingController c, String label, {bool req = false, bool num = false}) => SizedBox(
    width: 180,
    child: TextFormField(
      controller: c,
      keyboardType: num ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      validator: req ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    ),
  );
}




