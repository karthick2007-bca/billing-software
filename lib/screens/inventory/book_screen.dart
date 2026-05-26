import 'package:flutter/material.dart';
import '../../services/local_db.dart';
import '../../services/inv_export_service.dart';
import '../../widgets/common.dart';
import '../students/student_detail_screen.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});
  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _items = [], _sales = [];
  String _search = '', _classFilter = '', _catFilter = '';
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
      final items = await LocalDb.getBookItems();
      final sales = await LocalDb.getInventorySales(saleType: 'book');
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
          const Expanded(child: SectionHeader('Books / Stationery')),
          ElevatedButton.icon(
            icon: const Icon(Icons.add), label: const Text('Add Item'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
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
            decoration: const InputDecoration(hintText: 'Search name/author', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
            onChanged: (v) { _search = v; _load(); },
          )),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: TextField(
            decoration: const InputDecoration(hintText: 'Class', isDense: true, border: OutlineInputBorder()),
            onChanged: (v) { _classFilter = v; _load(); },
          )),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _catFilter.isEmpty ? null : _catFilter,
            hint: const Text('All Types'),
            items: ['book', 'stationery', 'notebook', 'other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) { _catFilter = v ?? ''; _load(); },
          ),
          if (_catFilter.isNotEmpty) TextButton(onPressed: () { _catFilter = ''; _load(); }, child: const Text('Clear')),
        ]),
        const SizedBox(height: 8),
        TabBar(controller: _tabs, labelColor: AppColors.warning, tabs: const [
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
    ? const Center(child: Text('No items found'))
    : Card(child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final it = _items[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFFFF8E1),
              child: Icon(it['category'] == 'book' ? Icons.menu_book : Icons.edit, color: AppColors.warning, size: 18),
            ),
            title: Text(it['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${it['author'] != null ? 'By ${it['author']} | ' : ''}${it['publisher'] ?? ''} | Class: ${it['class_applicable'] ?? 'All'} | ${it['category']}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${it['price']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Stock: ${it['stock']}', style: TextStyle(fontSize: 11, color: (it['stock'] as int) < 5 ? AppColors.danger : Colors.grey)),
              ]),
              PopupMenuButton(itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ], onSelected: (v) async {
                if (v == 'edit') _showItemDialog(item: it);
                if (v == 'delete') {
                  if (await confirmDialog(context, 'Delete "${it['name']}"?')) {
                    await LocalDb.deleteBookItem(it['id'] as int);
                    _load();
                  }
                }
              }),
            ]),
          );
        },
      ));

  Widget _salesTab() => _sales.isEmpty
    ? const Center(child: Text('No sales recorded'))
    : _BookSalesHistoryList(sales: _sales);

  Widget _reportTab() {
    final totalSales = _sales.fold<double>(0, (s, e) => s + ((e['grand_total'] ?? 0) as num).toDouble());
    final byClass = <String, List>{};
    for (final it in _items) {
      final cls = it['class_applicable']?.toString() ?? 'General';
      byClass.putIfAbsent(cls, () => []).add(it);
    }
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 24, children: [
        _stat('Total Items', '${_items.length}', AppColors.warning),
        _stat('Total Sales', '${_sales.length}', AppColors.success),
        _stat('Revenue', '₹${totalSales.toStringAsFixed(0)}', AppColors.primary),
      ]))),
      const SizedBox(height: 8),
      ...byClass.entries.map((e) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('Class: ${e.key}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning))),
        Card(child: Column(children: e.value.map<Widget>((i) => ListTile(
          dense: true,
          leading: Icon(i['category'] == 'book' ? Icons.menu_book : Icons.edit, color: AppColors.warning, size: 16),
          title: Text(i['name']),
          subtitle: Text('${i['author'] ?? ''} | ${i['publisher'] ?? ''}'),
          trailing: Text('₹${i['price']} | Stock: ${i['stock']}', style: const TextStyle(fontWeight: FontWeight.w500)),
        )).toList())),
      ])),
    ]));
  }

  Widget _stat(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)),
  ]);

  void _showItemDialog({Map? item}) {
    final name = TextEditingController(text: item?['name'] ?? '');
    final cls = TextEditingController(text: item?['class_applicable'] ?? '');
    final price = TextEditingController(text: item?['price']?.toString() ?? '');
    final stock = TextEditingController(text: item?['stock']?.toString() ?? '0');
    final fk = GlobalKey<FormState>();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(item == null ? 'Add Book / Stationery' : 'Edit Item'),
      content: SizedBox(width: 380, child: Form(key: fk, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
          controller: name,
          validator: (v) => v!.isEmpty ? 'Required' : null,
          decoration: styledInput('Item Name', icon: Icons.menu_book_outlined),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: cls,
          decoration: styledInput('Class (e.g. 5, 6, All)', icon: Icons.class_outlined),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: price,
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              decoration: styledInput('Price (₹)', icon: Icons.currency_rupee_rounded),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warningFaded,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Stock', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
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
                    prefixIcon: Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.warning),
                    prefixIconConstraints: BoxConstraints(minWidth: 28, minHeight: 0),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                ),
              ]),
            ),
          ),
        ]),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
          onPressed: () async {
            if (!fk.currentState!.validate()) return;
            final body = {
              'name': name.text.trim(),
              'class_applicable': cls.text.trim(),
              'price': double.tryParse(price.text.trim()) ?? 0,
              'stock': int.tryParse(stock.text.trim()) ?? 0,
              'category': item?['category'] ?? 'book',
              'author': item?['author'],
              'publisher': item?['publisher'],
            };
            if (item == null) await LocalDb.insertBookItem(body);
            else await LocalDb.updateBookItem(item['id'] as int, body);
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          },
          child: const Text('Save'),
        ),
      ],
    ));
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
            Icon(Icons.menu_book, color: AppColors.warning, size: 20),
            SizedBox(width: 8),
            Text('New Book / Stationery Sale'),
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
              const Text('Select Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              ..._items.map((it) {
                final id = it['id'] as int;
                final qty = cart[id] ?? 0;
                final price = (it['price'] ?? 0) as num;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: qty > 0 ? AppColors.warning.withValues(alpha: 0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: qty > 0 ? AppColors.warning.withValues(alpha: 0.3) : AppColors.border,
                    ),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('₹$price | Class: ${it['class_applicable'] ?? 'All'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                        color: AppColors.warning,
                        onPressed: () => ss(() => cart[id] = qty + 1),
                      ),
                    ]),
                  ]),
                );
              }),
              const Divider(),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.warning)),
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
                      'item_type': 'book',
                      'item_name': it['name'],
                      'size': null,
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
                  final sName = studentName.text.trim();
                  final sCls  = studentClass.text.trim();
                  final sSec  = studentSection.text.trim();
                  // 1. Save sale to DB
                  final billNo = await LocalDb.insertInventorySale(
                    sale: {
                      'student_name': sName.isEmpty ? null : sName,
                      'student_class': sCls,
                      'student_section': sSec,
                      'payment_mode': payMode,
                      'subtotal': grandTotal,
                      'grand_total': grandTotal,
                      'sale_type': 'book',
                    },
                    items: cartItems.map((e) => Map<String, dynamic>.from(e)).toList(),
                  );
                  // 2. Close dialog and reload
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) showSnack(context, 'Sale saved successfully');
                  // 3. Print receipt (separate try so print failure doesn't affect save)
                  try {
                    await InvExportService.printSaleReceipt(
                      receiptNo: billNo,
                      saleDate: DateTime.now().toIso8601String().split('T')[0],
                      studentName: sName.isEmpty ? 'Walk-in' : sName,
                      studentClass: sCls,
                      studentSection: sSec,
                      module: 'BOOKS/STATIONERY',
                      items: cartItems.map((e) => {
                        'name': (e['item_name'] ?? '').toString(),
                        'size': (e['size'] ?? '').toString(),
                        'quantity': e['quantity'],
                        'unit_price': (e['unit_price'] as num).toDouble(),
                      }).toList(),
                      total: grandTotal,
                      paymentMode: payMode,
                    );
                  } catch (_) {}
                  // 4. Navigate to student history if student found
                  if (sName.isNotEmpty && sCls.isNotEmpty && mounted) {
                    final years = await LocalDb.getAcademicYears();
                    final yr = years.firstWhere((y) => y['is_current'] == 1, orElse: () => years.isNotEmpty ? years.first : <String, dynamic>{});
                    if (yr.isNotEmpty) {
                      final students = await LocalDb.getStudents(search: sName, classFilter: sCls, yearId: yr['id'] as int);
                      final matched = students.where((s) =>
                        s['name'].toString().toLowerCase() == sName.toLowerCase() &&
                        (sSec.isEmpty || s['section'].toString().toLowerCase() == sSec.toLowerCase())
                      ).toList();
                      if (matched.isNotEmpty && mounted) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => _StudentHistoryRedirect(
                            studentId: matched.first['id'].toString(),
                            academicYearId: yr['id'].toString(),
                          ),
                        ));
                      }
                    }
                  }
                } catch (e) {
                  if (mounted) showSnack(context, 'Error: ${e.toString()}', error: true);
                }
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _exportPdf() async {
    final headers = ['Name', 'Author', 'Publisher', 'Class', 'Category', 'Price', 'Stock'];
    final rows = _items.map((i) => [
      i['name'].toString(), i['author']?.toString() ?? '-', i['publisher']?.toString() ?? '-',
      i['class_applicable']?.toString() ?? 'All', i['category'].toString(),
      '₹${i['price']}', i['stock'].toString(),
    ]).toList();
    await InvExportService.exportPdf('Books & Stationery Report', headers, rows);
  }

  Future<void> _exportExcel() async {
    final headers = ['Name', 'Author', 'Publisher', 'Class', 'Category', 'Price', 'Stock'];
    final rows = _items.map((i) => [
      i['name'].toString(), i['author']?.toString() ?? '-', i['publisher']?.toString() ?? '-',
      i['class_applicable']?.toString() ?? 'All', i['category'].toString(),
      i['price'].toString(), i['stock'].toString(),
    ]).toList();
    final path = await InvExportService.exportExcel('Books Stationery Report', headers, rows);
    if (mounted) showSnack(context, 'Saved: $path');
  }
}





class _BookSalesHistoryList extends StatefulWidget {
  final List sales;
  const _BookSalesHistoryList({required this.sales});
  @override
  State<_BookSalesHistoryList> createState() => _BookSalesHistoryListState();
}

class _BookSalesHistoryListState extends State<_BookSalesHistoryList> {
  final Map<int, List<Map>> _itemsMap = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    for (final s in widget.sales) {
      final id = s['id'] as int;
      final items = await LocalDb.getInventorySaleItems(id);
      if (mounted) setState(() => _itemsMap[id] = items);
    }
  }

  Future<void> _print(Map s) async {
    final saleId = s['id'] as int;
    final items = _itemsMap[saleId] ?? await LocalDb.getInventorySaleItems(saleId);
    await InvExportService.printSaleReceipt(
      receiptNo: s['bill_no'] ?? '',
      saleDate: s['sale_date'] ?? '',
      studentName: s['student_name'] ?? 'Walk-in',
      studentClass: s['student_class'] ?? '',
      studentSection: s['student_section'] ?? '',
      module: 'BOOKS/STATIONERY',
      items: items.map((i) => {
        'name': (i['item_name'] ?? '').toString(),
        'size': (i['size'] ?? '').toString(),
        'quantity': i['quantity'] ?? 0,
        'unit_price': (i['unit_price'] ?? 0) as num,
      }).toList(),
      total: (s['grand_total'] as num).toDouble(),
      paymentMode: s['payment_mode'] ?? 'cash',
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ListView.separated(
      itemCount: widget.sales.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = widget.sales[i];
        final saleId = s['id'] as int;
        final sItems = _itemsMap[saleId] ?? [];
        return ExpansionTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFF8E1),
            child: Icon(Icons.receipt, color: AppColors.warning, size: 18),
          ),
          title: Text('${s['bill_no'] ?? ''} \u2013 ${s['student_name'] ?? 'Walk-in'}'),
          subtitle: Text('${s['sale_date'] ?? ''} | \u20b9${s['grand_total'] ?? 0} | ${(s['payment_mode'] ?? '').toUpperCase()}'),
          trailing: IconButton(
            icon: const Icon(Icons.print, color: AppColors.warning),
            onPressed: () => _print(s),
          ),
          children: sItems.isEmpty
            ? [const Padding(padding: EdgeInsets.all(12), child: Text('Loading...', style: TextStyle(color: AppColors.textMuted)))]
            : sItems.map<Widget>((it) => ListTile(
                dense: true,
                title: Text((it['item_name'] ?? '').toString()),
                trailing: Text(
                  'x${it['quantity']}  \u20b9${((it['quantity'] as num) * (it['unit_price'] as num)).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              )).toList(),
        );
      },
    ),
  );
}

class _StudentHistoryRedirect extends StatelessWidget {
  final String studentId, academicYearId;
  const _StudentHistoryRedirect({required this.studentId, required this.academicYearId});
  @override
  Widget build(BuildContext context) => StudentDetailScreen(
    studentId: studentId,
    academicYearId: academicYearId,
    initialTab: 2,
  );
}