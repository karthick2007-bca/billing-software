import 'package:flutter/material.dart';
import '../../services/local_db.dart';
import '../../services/inv_export_service.dart';
import '../../widgets/common.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _items = [], _sales = [];
  String _search = '', _sizeFilter = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await LocalDb.getShopItems();
      final sales = await LocalDb.getInventorySales(saleType: 'shop');
      setState(() {
        _items = items;
        _sales = sales;
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
          const Expanded(child: SectionHeader('Shop / Uniform')),
          ElevatedButton.icon(
            icon: const Icon(Icons.add), label: const Text('Add Item'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => _showItemDialog(),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.point_of_sale), label: const Text('New Sale'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            onPressed: () => _showSaleDialog(),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF'), onPressed: _exportPdf),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(width: 200, child: TextField(
            decoration: const InputDecoration(hintText: 'Search items', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
            onChanged: (v) { _search = v; _load(); },
          )),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _sizeFilter.isEmpty ? null : _sizeFilter,
            hint: const Text('All Sizes'),
            items: ['XS', 'S', 'M', 'L', 'XL', 'XXL'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) { _sizeFilter = v ?? ''; _load(); },
          ),
          if (_sizeFilter.isNotEmpty) TextButton(onPressed: () { _sizeFilter = ''; _load(); }, child: const Text('Clear')),
        ]),
        const SizedBox(height: 8),
        TabBar(controller: _tabs, labelColor: AppColors.primary, tabs: const [
          Tab(text: 'Items'), Tab(text: 'Sales History'), Tab(text: 'Report'),
        ]),
        const SizedBox(height: 8),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [_itemsTab(), _salesTab(), _reportTab()]),
        ),
      ]),
    ),
  );

  Widget _itemsTab() => _items.isEmpty
    ? const Center(child: Text('No uniform items found'))
    : Card(child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final it = _items[i];
          return ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.checkroom, color: AppColors.primary, size: 18)),
            title: Text('${it['name']} — Size: ${it['size']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Color: ${it['color'] ?? '-'} | Stock: ${it['stock']} | ₹${it['price']}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              PopupMenuButton(itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ], onSelected: (v) async {
                if (v == 'edit') _showItemDialog(item: it);
                if (v == 'delete') {
                  if (await confirmDialog(context, 'Delete "${it['name']}"?')) {
                    await LocalDb.deleteShopItem(it['id'] as int);
                    _load();
                  }
                }
              }),
            ]),
          );
        },
      ));

  Widget _salesTab() {
    if (_sales.isEmpty) return const Center(child: Text('No sales recorded'));

    // Group by class + section
    final Map<String, List> groups = {};
    for (final s in _sales) {
      final cls = (s['student_class'] ?? '').toString().trim();
      final sec = (s['student_section'] ?? '').toString().trim();
      final key = cls.isNotEmpty || sec.isNotEmpty
          ? 'Class $cls - Sec $sec'
          : 'Walk-in';
      groups.putIfAbsent(key, () => []).add(s);
    }
    final keys = groups.keys.toList()..sort();

    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final key = keys[i];
        final groupSales = groups[key]!;
        return _SalesGroupCard(groupLabel: key, sales: groupSales);
      },
    );
  }

  Widget _reportTab() {
    final totalSales = _sales.fold<double>(0, (s, e) => s + ((e['grand_total'] ?? 0) as num).toDouble());
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 24, children: [
        _stat('Total Items', '${_items.length}', AppColors.primary),
        _stat('Total Sales', '${_sales.length}', AppColors.success),
        _stat('Revenue', '\u20b9${totalSales.toStringAsFixed(0)}', AppColors.warning),
      ]))),
      const SizedBox(height: 8),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text('Stock Summary', style: TextStyle(fontWeight: FontWeight.bold))),
      Card(child: Column(children: _items.map((i) => ListTile(
        dense: true,
        title: Text('${i['name']} — ${i['size']}'),
        subtitle: Text('Color: ${i['color'] ?? '-'}'),
        trailing: Text('\u20b9${i['price']}', style: const TextStyle(fontWeight: FontWeight.w500)),
      )).toList())),
    ]));
  }

  Widget _stat(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)),
  ]);

  void _showItemDialog({Map? item}) {
    final name = TextEditingController(text: item?['name'] ?? '');
    final color = TextEditingController(text: item?['color'] ?? '');
    final stock = TextEditingController(text: item?['stock']?.toString() ?? '0');
    final fk = GlobalKey<FormState>();

    // Size + price pairs
    final List<Map<String, TextEditingController>> sizePrices = [];
    if (item != null) {
      sizePrices.add({
        'size': TextEditingController(text: item['size']?.toString() ?? ''),
        'price': TextEditingController(text: item['price']?.toString() ?? ''),
      });
    } else {
      sizePrices.add({
        'size': TextEditingController(),
        'price': TextEditingController(),
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(item == null ? 'Add Uniform Item' : 'Edit Item'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: fk,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextFormField(
                  controller: name,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  decoration: styledInput('Item Name', icon: Icons.checkroom_outlined),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: color,
                      decoration: styledInput('Color (optional)', icon: Icons.color_lens_outlined),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFaded,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Stock', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        TextFormField(
                          controller: stock,
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                            hintText: '0',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            prefixIcon: Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primary),
                            prefixIconConstraints: BoxConstraints(minWidth: 28, minHeight: 0),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        ),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  const Text('Size & Price', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  if (item == null)
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Add Size', style: TextStyle(fontSize: 12)),
                      onPressed: () => ss(() => sizePrices.add({
                        'size': TextEditingController(),
                        'price': TextEditingController(),
                      })),
                    ),
                ]),
                const SizedBox(height: 6),
                ...sizePrices.asMap().entries.map((e) {
                  final idx = e.key;
                  final sp = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFaded,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: sp['size'],
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                          decoration: styledInput('Size (e.g. S, M, 1m)', icon: Icons.straighten_outlined),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: sp['price'],
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                          decoration: styledInput('Amount (₹)', icon: Icons.currency_rupee_rounded),
                        ),
                      ),
                      if (sizePrices.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                          onPressed: () => ss(() => sizePrices.removeAt(idx)),
                        ),
                    ]),
                  );
                }),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: primaryBtn(),
            onPressed: () async {
              if (!fk.currentState!.validate()) return;
              if (item != null) {
                final sp = sizePrices.first;
                await LocalDb.updateShopItem(item['id'] as int, {
                  'name': name.text.trim(),
                  'size': sp['size']!.text.trim(),
                  'color': color.text.trim(),
                  'price': double.tryParse(sp['price']!.text.trim()) ?? 0,
                  'stock': int.tryParse(stock.text.trim()) ?? 0,
                });
              } else {
                for (final sp in sizePrices) {
                  if (sp['size']!.text.trim().isEmpty) continue;
                  await LocalDb.insertShopItem({
                    'name': name.text.trim(),
                    'size': sp['size']!.text.trim(),
                    'color': color.text.trim(),
                    'price': double.tryParse(sp['price']!.text.trim()) ?? 0,
                    'stock': int.tryParse(stock.text.trim()) ?? 0,
                  });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      )),
    );
  }

  void _showSaleDialog() {
    if (_items.isEmpty) { showSnack(context, 'No items available. Add items first.', error: true); return; }
    final studentName = TextEditingController();
    final studentClass = TextEditingController();
    final studentSection = TextEditingController();
    String payMode = 'cash';
    final Map<int, int> cart = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        double total = 0;
        for (final e in cart.entries) {
          final it = _items.firstWhere((i) => i['id'] == e.key, orElse: () => <String, dynamic>{});
          if (it.isNotEmpty) total += ((it['price'] ?? 0) as num) * e.value;
        }
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.point_of_sale, color: AppColors.success, size: 20),
            SizedBox(width: 8),
            Text('New Uniform Sale'),
          ]),
          content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Name
              TextField(
                controller: studentName,
                decoration: styledInput('Student Name', icon: Icons.person_outline),
              ),
              const SizedBox(height: 10),
              // 2. Class
              TextField(
                controller: studentClass,
                decoration: styledInput('Class', icon: Icons.class_outlined),
              ),
              const SizedBox(height: 10),
              // 3. Section
              TextField(
                controller: studentSection,
                decoration: styledInput('Section', icon: Icons.group_outlined),
              ),
              const SizedBox(height: 14),
              // 4. Cloth items
              const Text('Select Cloth Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              ..._items.map((it) {
                final id = it['id'] as int;
                final qty = cart[id] ?? 0;
                final price = (it['price'] ?? 0) as num;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: qty > 0 ? AppColors.success.withValues(alpha: 0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: qty > 0 ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
                    ),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '${it['name']}${it['size'] != null ? ' (${it['size']})' : ''}${it['color'] != null && it['color'].toString().isNotEmpty ? ' - ${it['color']}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text('₹$price', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ])),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        color: AppColors.danger,
                        onPressed: qty > 0 ? () => ss(() => cart[id] = qty - 1) : null,
                      ),
                      SizedBox(
                        width: 28,
                        child: Text('$qty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        color: AppColors.success,
                        onPressed: () => ss(() => cart[id] = qty + 1),
                      ),
                    ]),
                  ]),
                );
              }),
              const Divider(),
              // Payment mode
              DropdownButtonFormField<String>(
                value: payMode,
                decoration: styledInput('Payment Mode', icon: Icons.payment_rounded),
                items: ['cash', 'cheque'].map((m) => DropdownMenuItem(
                  value: m, child: Text(m.toUpperCase()),
                )).toList(),
                onChanged: (v) => ss(() => payMode = v!),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.success)),
              ]),
            ],
          ))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Print'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final cartItems = cart.entries
                  .where((e) => e.value > 0)
                  .map((e) {
                    final it = _items.firstWhere((i) => i['id'] == e.key);
                    return {
                      'item_id': e.key,
                      'item_type': 'shop',
                      'item_name': it['name'],
                      'size': it['size'],
                      'quantity': e.value,
                      'unit_price': (it['price'] ?? 0) as num,
                      'total_price': ((it['price'] ?? 0) as num) * e.value,
                    };
                  }).toList();
                if (cartItems.isEmpty) {
                  showSnack(context, 'Add at least one item to cart', error: true);
                  return;
                }
                try {
                  final double grandTotal = cartItems.fold(0, (s, i) => s + (i['total_price'] as num));
                  final billNo = await LocalDb.insertInventorySale(
                    sale: {
                      'student_name': studentName.text.trim().isEmpty ? null : studentName.text.trim(),
                      'student_class': studentClass.text.trim(),
                      'student_section': studentSection.text.trim(),
                      'payment_mode': payMode,
                      'subtotal': grandTotal,
                      'grand_total': grandTotal,
                      'sale_type': 'shop',
                    },
                    items: cartItems.map((e) => Map<String, dynamic>.from(e)).toList(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  // Auto print
                  await InvExportService.printSaleReceipt(
                    receiptNo: billNo,
                    saleDate: DateTime.now().toIso8601String().split('T')[0],
                    studentName: studentName.text.trim().isEmpty ? 'Walk-in' : studentName.text.trim(),
                    studentClass: studentClass.text.trim(),
                    studentSection: studentSection.text.trim(),
                    module: 'UNIFORM',
                    items: cartItems.map((e) => {
                      'name': e['item_name'],
                      'size': e['size'],
                      'quantity': e['quantity'],
                      'unit_price': e['unit_price'],
                    }).toList(),
                    total: grandTotal,
                    paymentMode: payMode,
                  );
                } catch (e) {
                  if (mounted) showSnack(context, e.toString(), error: true);
                }
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _exportPdf() async {
    final headers = ['Name', 'Size', 'Color', 'Price', 'Stock'];
    final rows = _items.map((i) => [i['name'].toString(), i['size'].toString(), i['color']?.toString() ?? '-', '₹${i['price']}', i['stock'].toString()]).toList();
    await InvExportService.exportPdf('Uniform Stock Report', headers, rows);
  }

  Future<void> _exportExcel() async {
    final headers = ['Name', 'Size', 'Color', 'Price', 'Stock'];
    final rows = _items.map((i) => [i['name'].toString(), i['size'].toString(), i['color']?.toString() ?? '-', i['price'].toString(), i['stock'].toString()]).toList();
    final path = await InvExportService.exportExcel('Uniform Stock Report', headers, rows);
    if (mounted) showSnack(context, 'Saved: $path');
  }
}

// ── Sales Group Card ──────────────────────────────────────────────────────────
class _SalesGroupCard extends StatefulWidget {
  final String groupLabel;
  final List sales;
  const _SalesGroupCard({required this.groupLabel, required this.sales});
  @override
  State<_SalesGroupCard> createState() => _SalesGroupCardState();
}

class _SalesGroupCardState extends State<_SalesGroupCard> {
  bool _expanded = true;
  Map<int, List<Map>> _itemsMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllItems();
  }

  Future<void> _loadAllItems() async {
    final map = <int, List<Map>>{};
    for (final s in widget.sales) {
      final id = s['id'] as int;
      map[id] = await LocalDb.getInventorySaleItems(id);
    }
    if (mounted) setState(() => _itemsMap = map);
  }

  Future<void> _printSale(Map s) async {
    final saleItems = await LocalDb.getInventorySaleItems(s['id'] as int);
    await InvExportService.printSaleReceipt(
      receiptNo: s['bill_no'] ?? '',
      saleDate: s['sale_date'] ?? '',
      studentName: s['student_name'] ?? 'Walk-in',
      studentClass: s['student_class'] ?? '',
      studentSection: s['student_section'] ?? '',
      module: 'UNIFORM',
      items: saleItems.map((i) => {
        'name': i['item_name'] ?? '',
        'size': i['size'] ?? '',
        'quantity': i['quantity'] ?? 0,
        'unit_price': i['unit_price'] ?? 0,
      }).toList(),
      total: (s['grand_total'] as num).toDouble(),
      paymentMode: s['payment_mode'] ?? 'cash',
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmt = widget.sales.fold<double>(0, (sum, s) => sum + (s['grand_total'] as num).toDouble());
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardDecoration(),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(12),
            bottom: _expanded ? Radius.zero : const Radius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: _expanded ? Radius.zero : const Radius.circular(12),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.class_rounded, color: AppColors.accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.groupLabel,
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
              Text('\u20b9${totalAmt.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AppColors.accent, size: 20),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          ...widget.sales.asMap().entries.map((e) {
            final idx = e.key;
            final s = e.value;
            return Column(children: [
              if (idx > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_rounded, color: AppColors.success, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['student_name'] ?? 'Walk-in',
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                    Text('${s['bill_no'] ?? ''} \u2022 ${s['sale_date'] ?? ''}',
                      style: AppTextStyles.caption),
                  ])),
                  Text('\u20b9${s['grand_total'] ?? 0}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successFaded,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text((s['payment_mode'] ?? 'cash').toString().toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.success)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.print_outlined, color: AppColors.primary, size: 18),
                    tooltip: 'Print',
                    onPressed: () => _printSale(s),
                  ),
                ]),
              ),
              Builder(builder: (_) {
                final saleId = s['id'] as int;
                final items = _itemsMap[saleId] ?? [];
                if (items.isEmpty) return const SizedBox(height: 6);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryFaded,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: items.asMap().entries.map((ie) {
                        final it = ie.value;
                        return Column(children: [
                          if (ie.key > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(children: [
                              const Icon(Icons.checkroom_outlined, size: 13, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Expanded(child: Text(
                                '${it['item_name'] ?? ''}${(it['size'] ?? '').toString().isNotEmpty ? ' (${it['size']})' : ''}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              )),
                              Text('x${it['quantity']}  \u20b9${it['total_price'] ?? 0}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ]),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              }),
            ]);
          }),
        ],
      ]),
    );
  }
}




