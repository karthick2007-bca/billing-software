import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/local_db.dart';
import '../widgets/common.dart';
import 'students/students_screen.dart';
import 'fees/fee_structure_screen.dart';
import 'fees/challans_screen.dart';

import 'reports/reports_screen.dart';
import 'reports/defaulters_screen.dart';
import 'inventory/inventory_screen.dart';
import 'transport/transport_screen.dart';
import 'settings_screen.dart';
import 'backup_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int initialIndex;
  const DashboardScreen({super.key, this.initialIndex = 0});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late final List<NavItem> _items;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _items = [
      NavItem('Dashboard', Icons.grid_view_rounded, null), // rendered separately
      NavItem('Students', Icons.people_alt_rounded, const StudentsScreen()),
      if (auth.can(['admin', 'accountant']))
        NavItem('Fee Structure', Icons.account_balance_wallet_rounded, const FeeStructureScreen()),
      NavItem('Challans', Icons.receipt_long_rounded, const ChallansScreen()),
  
      if (auth.can(['admin', 'accountant']))
        NavItem('Reports', Icons.bar_chart_rounded, const ReportsScreen()),
      if (auth.can(['admin', 'accountant']))
        NavItem('Defaulters', Icons.warning_amber_rounded, const DefaultersScreen()),
      NavItem('Inventory', Icons.inventory_2_rounded, const InventoryScreen()),
      if (auth.can(['admin'])) ...[
        NavItem.label('Backup'),
        NavItem('Backup', Icons.backup_rounded, const BackupScreen()),
        NavItem('Settings', Icons.settings_rounded, const SettingsScreen()),
      ],
    ];
    _selectedIndex = widget.initialIndex.clamp(0, _items.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wide = MediaQuery.of(context).size.width > 1000;
    // Determine which screen to show
    final Widget body = _selectedIndex == 0
        ? _DashboardHome(key: UniqueKey())
        : (_items[_selectedIndex].isLabel || _items[_selectedIndex].screen == null)
            ? _DashboardHome(key: UniqueKey())
            : _items[_selectedIndex].screen!;
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            items: _items,
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
            userName: auth.userName,
            role: auth.role,
            extended: wide,
            onLogout: auth.logout,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String userName, role;
  final bool extended;
  final VoidCallback onLogout;
  const AppSidebar({required this.items, required this.selectedIndex, required this.onSelect, required this.userName, required this.role, required this.extended, required this.onLogout, super.key});

  @override
  Widget build(BuildContext context) {
    final w = extended ? 220.0 : 68.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: w,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2744), Color(0xFF1E3A5F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(4, 0))],
      ),
      child: Column(
        children: [
          // Brand header
          Container(
            padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 12, vertical: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                ),
                if (extended) ...[
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('SchoolBill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.3)),
                    Text('Management', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                  ])),
                ],
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                if (item.isLabel) {
                  return extended
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                          child: Text(
                            item.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.35),
                              letterSpacing: 1.2,
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                        );
                }
                return _NavTile(
                  item: item,
                  selected: selectedIndex == i,
                  extended: extended,
                  onTap: () => onSelect(i),
                );
              },
            ),
          ),

          // User profile + logout
          Container(
            padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: extended
                ? Row(children: [
                    _Avatar(name: userName),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(userName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text(role.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                    ])),
                    IconButton(
                      icon: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
                      onPressed: onLogout,
                      tooltip: 'Logout',
                    ),
                  ])
                : Column(children: [
                    _Avatar(name: userName),
                    const SizedBox(height: 6),
                    IconButton(
                      icon: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
                      onPressed: onLogout,
                    ),
                  ]),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty ? '?' : name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF2D5F9E)]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
    );
  }
}

class _NavTile extends StatefulWidget {
  final NavItem item;
  final bool selected, extended;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.selected, required this.extended, required this.onTap});

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: widget.extended ? 12 : 0, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.15)
                : _hovered
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: Colors.white.withValues(alpha: 0.15)) : null,
          ),
          child: widget.extended
              ? Row(children: [
                  Icon(widget.item.icon, color: active ? Colors.white : Colors.white.withValues(alpha: 0.55), size: 18),
                  const SizedBox(width: 10),
                  Text(widget.item.label, style: TextStyle(color: active ? Colors.white : Colors.white.withValues(alpha: 0.65), fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
                  if (active) ...[const Spacer(), Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF0EA5E9), shape: BoxShape.circle))],
                ])
              : Center(child: Tooltip(
                  message: widget.item.label,
                  child: Icon(widget.item.icon, color: active ? Colors.white : Colors.white.withValues(alpha: 0.55), size: 20),
                )),
        ),
      ),
    );
  }
}

class NavItem {
  final String label;
  final IconData icon;
  final Widget? screen;
  final bool isLabel;
  NavItem(this.label, this.icon, [this.screen]) : isLabel = false;
  NavItem.label(this.label) : icon = Icons.label, screen = null, isLabel = true;
}

// ─── Dashboard Home ───────────────────────────────────────────────────────────

class _DashboardHome extends StatefulWidget {
  const _DashboardHome({super.key});
  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  // data
  int _studentCount = 0;
  int _pendingStudentsCount = 0;
  double _collected = 0;
  double _pending = 0;
  double _billed = 0;
  List _recentPayments = [];
  List<Map<String, dynamic>> _lowStockItems = [];
  String _yearLabel = '';
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final years = await LocalDb.getAcademicYears();
      if (years.isEmpty) {
        setState(() { _loading = false; _error = 'No academic year configured. Go to Settings to add one.'; });
        return;
      }
      Map current;
      try {
        current = years.firstWhere((y) => y['is_current'] == 1);
      } catch (_) {
        current = years.first;
      }
      final ayId = current['id'] as int;

      final income   = await LocalDb.getAnnualIncome(ayId);
      final students = await LocalDb.getStudents(yearId: ayId);
      final pending  = await LocalDb.getPendingStudentsCount(ayId);
      final recent   = await LocalDb.getRecentPayments();
      final lowStock = await LocalDb.getLowStockItems();

      setState(() {
        _billed    = (income['grand_total_billed']    as num).toDouble();
        _collected = (income['grand_total_collected'] as num).toDouble();
        _pending   = (income['pending']               as num).toDouble();
        _studentCount         = students.length;
        _pendingStudentsCount = pending;
        _recentPayments       = recent;
        _lowStockItems        = lowStock;
        _yearLabel = current['label'] as String? ?? '';
        _loading   = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  String _fmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000)   return '${(v / 100000).toStringAsFixed(2)} L';
    if (v >= 1000)     return '${(v / 1000).toStringAsFixed(1)} K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 40),
            const SizedBox(height: 12),
            Text(_error, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: primaryBtn(),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
    }

    final rate = _billed > 0 ? (_collected / _billed * 100) : 0.0;
    final rateColor = rate >= 75 ? AppColors.success : rate >= 50 ? AppColors.warning : AppColors.danger;
    final rateFaded = rate >= 75 ? AppColors.successFaded : rate >= 50 ? AppColors.warningFaded : AppColors.dangerFaded;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Page header ──
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Dashboard', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFaded,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.calendar_month_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(_yearLabel,
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 4 Stat Cards ──
            Row(
              children: [
                Expanded(child: _StatCard(
                  label: 'Total Students',
                  value: '$_studentCount',
                  sub: 'Enrolled this year',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.primary,
                  bg: AppColors.primaryFaded,
                )),
                const SizedBox(width: 14),
                Expanded(child: _StatCard(
                  label: 'Fees Collected',
                  value: '₹${_fmt(_collected)}',
                  sub: 'Total received',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  bg: AppColors.successFaded,
                )),
                const SizedBox(width: 14),
                Expanded(child: _StatCard(
                  label: 'Pending Fees',
                  value: '₹${_fmt(_pending)}',
                  sub: '$_pendingStudentsCount students pending',
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.warning,
                  bg: AppColors.warningFaded,
                )),
                const SizedBox(width: 14),
                Expanded(child: _StatCard(
                  label: 'Collection Rate',
                  value: '${rate.toStringAsFixed(1)}%',
                  sub: 'Of total billed',
                  icon: Icons.donut_large_rounded,
                  color: rateColor,
                  bg: rateFaded,
                )),
              ],
            ),
            const SizedBox(height: 20),

            // ── Quick Actions ──
            const Text('Quick Actions', style: AppTextStyles.h3),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _QuickAction('Add Student',      Icons.person_add_rounded,    AppColors.primary),
              _QuickAction('Record Payment',   Icons.payments_rounded,      AppColors.success),
              _QuickAction('Generate Challan', Icons.receipt_long_rounded,  AppColors.accent),
              _QuickAction('View Reports',     Icons.bar_chart_rounded,     AppColors.warning),
            ]),
            const SizedBox(height: 24),

            // ── Two bottom frames ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _RecentPaymentsFrame(payments: _recentPayments)),
                const SizedBox(width: 16),
                Expanded(child: _LowStockFrame(items: _lowStockItems)),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color, bg;
  const _StatCard({
    required this.label, required this.value, required this.sub,
    required this.icon, required this.color, required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: cardDecoration(),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 26),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      )),
    ]),
  );
}


// ─── Recent Payments Frame ─────────────────────────────────────────────────────────────────────────────────
class _RecentPaymentsFrame extends StatelessWidget {
  final List payments;
  const _RecentPaymentsFrame({required this.payments});

  @override
  Widget build(BuildContext context) => Container(
    decoration: cardDecoration(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: AppColors.successFaded, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.payments_rounded, color: AppColors.success, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Recent Payments', style: AppTextStyles.h3)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.successFaded, borderRadius: BorderRadius.circular(20)),
            child: Text('Last ${payments.length}', style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),

      // List
      if (payments.isEmpty)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No payments recorded yet', style: AppTextStyles.bodySmall)),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: payments.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = payments[i];
            final isCash = p['payment_mode'] == 'cash';
            final modeColor = isCash ? AppColors.success : AppColors.info;
            final initials = ((p['student_name'] ?? '?') as String)
                .split(' ').take(2).map((w) => w[0].toUpperCase()).join();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                // Avatar
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFaded,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(initials,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
                ),
                const SizedBox(width: 12),
                // Name + details
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['student_name'] ?? '-',
                    style: AppTextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${p['admission_no'] ?? ''} • Class ${p['class'] ?? ''}-${p['section'] ?? ''} • ${p['payment_date'] ?? ''}',
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ])),
                const SizedBox(width: 12),
                // Amount + mode
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${p['amount_paid']}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: modeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCash ? 'CASH' : 'CHEQUE',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: modeColor, letterSpacing: 0.3),
                    ),
                  ),
                ]),
              ]),
            );
          },
        ),
    ]),
  );
}

// ─── Low Stock Alert Frame ────────────────────────────────────────────────────────────────────────────────
class _LowStockFrame extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _LowStockFrame({required this.items});

  @override
  Widget build(BuildContext context) => Container(
    decoration: cardDecoration(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: AppColors.dangerFaded, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.inventory_2_rounded, color: AppColors.danger, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Low Stock Alert', style: AppTextStyles.h3)),
          if (items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.dangerFaded, borderRadius: BorderRadius.circular(20)),
              child: Text('${items.length} items', style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),

      // List
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 32),
            SizedBox(height: 8),
            Text('All items are well stocked', style: AppTextStyles.bodySmall),
          ])),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final item = items[i];
            final stock = item['stock'] as int? ?? 0;
            final isOut  = stock == 0;
            final stockColor = isOut ? AppColors.danger : AppColors.warning;
            final stockBg    = isOut ? AppColors.dangerFaded : AppColors.warningFaded;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                // Icon
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                    item['item_type'] == 'Book' ? Icons.menu_book_rounded : Icons.checkroom_rounded,
                    color: stockColor, size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // Name + category
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['name'] ?? '-',
                    style: AppTextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFaded,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(item['item_type'] ?? '',
                        style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                    if (item['size'] != null && (item['size'] as String).isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text('Size: ${item['size']}', style: AppTextStyles.caption),
                    ],
                  ]),
                ])),
                const SizedBox(width: 12),
                // Stock badge
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      isOut ? 'OUT OF STOCK' : 'Stock: $stock',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: stockColor),
                    ),
                  ),
                  if (!isOut) ...[const SizedBox(height: 3),
                    Text('Low stock', style: TextStyle(fontSize: 10, color: stockColor))],
                ]),
              ]),
            );
          },
        ),
    ]),
  );
}

// ─── Quick Action ─────────────────────────────────────────────────────────────────────────────────
class _QuickAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _QuickAction(this.label, this.icon, this.color);

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _hovered ? widget.color.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _hovered ? widget.color.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.icon, color: widget.color, size: 16),
        const SizedBox(width: 8),
        Text(widget.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _hovered ? widget.color : AppColors.textPrimary)),
      ]),
    ),
  );
}
