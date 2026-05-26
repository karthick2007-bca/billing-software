import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/local_db.dart';
import '../services/auth_provider.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _years = [], _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([LocalDb.getAcademicYears(), LocalDb.getUsers()]);
    setState(() { _years = results[0]; _users = results[1]; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          const PageHeader('Settings'),
          Container(
            decoration: cardDecoration(),
            child: TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [Tab(text: 'Academic Years'), Tab(text: 'Users')],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tabs, children: [
                _yearsTab(),
                auth.can(['admin']) ? _usersTab() : const Center(child: Text('Admin access required', style: AppTextStyles.bodySmall)),
              ])),
        ]),
      ),
    );
  }

  Widget _yearsTab() => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      ElevatedButton.icon(icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add Academic Year'), style: primaryBtn(), onPressed: _showAddYearDialog),
    ]),
    const SizedBox(height: 12),
    Expanded(child: _years.isEmpty
      ? const EmptyState(icon: Icons.calendar_today_outlined, message: 'No academic years added')
      : StyledCard(child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ListView.separated(
            itemCount: _years.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final y = _years[i];
              final isCurrent = y['is_current'] == 1;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: (isCurrent ? AppColors.success : AppColors.primary).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month_rounded, color: isCurrent ? AppColors.success : AppColors.primary, size: 18),
                ),
                title: Text(y['label'], style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('${y['start_date']} → ${y['end_date']}', style: AppTextStyles.caption),
                trailing: isCurrent
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Text('CURRENT', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.3)),
                    )
                  : TextButton(
                      onPressed: () async { await LocalDb.setCurrentYear(y['id'] as int); _load(); },
                      child: const Text('Set Current', style: TextStyle(fontSize: 12)),
                    ),
              );
            },
          ),
        )),
    ),
  ]);

  Widget _usersTab() => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      ElevatedButton.icon(icon: const Icon(Icons.person_add_rounded, size: 16), label: const Text('Add User'), style: primaryBtn(), onPressed: _showAddUserDialog),
    ]),
    const SizedBox(height: 12),
    Expanded(child: _users.isEmpty
      ? const EmptyState(icon: Icons.people_outline_rounded, message: 'No users added')
      : StyledCard(child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ListView.separated(
            itemCount: _users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final u = _users[i];
              final active = u['active'] == 1;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primaryLight]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text((u['name'] as String)[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
                ),
                title: Text(u['name'], style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Row(children: [
                  Text('${u['username']}', style: AppTextStyles.caption),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                    child: Text(u['role'].toString().toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.3)),
                  ),
                ]),
                trailing: Switch(
                  value: active,
                  activeColor: AppColors.success,
                  onChanged: (v) async {
                    await LocalDb.updateUser(u['id'] as int, {'name': u['name'], 'role': u['role'], 'active': v ? 1 : 0});
                    _load();
                  },
                ),
              );
            },
          ),
        )),
    ),
  ]);

  void _showAddYearDialog() {
    final label = TextEditingController(), start = TextEditingController(), end = TextEditingController();
    bool isCurrent = false;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: const Row(children: [Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20), SizedBox(width: 10), Text('Add Academic Year', style: AppTextStyles.h3)]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: label, style: AppTextStyles.body, decoration: styledInput('Label (e.g. 2024-25)', icon: Icons.label_outline)),
        const SizedBox(height: 10),
        TextFormField(controller: start, style: AppTextStyles.body, decoration: styledInput('Start Date (YYYY-MM-DD)', icon: Icons.event_outlined)),
        const SizedBox(height: 10),
        TextFormField(controller: end, style: AppTextStyles.body, decoration: styledInput('End Date (YYYY-MM-DD)', icon: Icons.event_outlined)),
        const SizedBox(height: 8),
        Row(children: [
          Checkbox(value: isCurrent, activeColor: AppColors.primary, onChanged: (v) => ss(() => isCurrent = v!)),
          const Text('Set as current year', style: AppTextStyles.bodySmall),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
        ElevatedButton(style: primaryBtn(), onPressed: () async {
          await LocalDb.insertAcademicYear({'label': label.text, 'start_date': start.text, 'end_date': end.text, 'is_current': isCurrent ? 1 : 0});
          if (isCurrent) { final years = await LocalDb.getAcademicYears(); if (years.isNotEmpty) await LocalDb.setCurrentYear(years.first['id'] as int); }
          if (mounted) Navigator.pop(ctx);
          _load();
        }, child: const Text('Add')),
      ],
    )));
  }

  void _showAddUserDialog() {
    final name = TextEditingController(), username = TextEditingController(), password = TextEditingController();
    String role = 'frontdesk';
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: const Row(children: [Icon(Icons.person_add_rounded, color: AppColors.primary, size: 20), SizedBox(width: 10), Text('Add User', style: AppTextStyles.h3)]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, style: AppTextStyles.body, decoration: styledInput('Full Name', icon: Icons.person_outline_rounded)),
        const SizedBox(height: 10),
        TextFormField(controller: username, style: AppTextStyles.body, decoration: styledInput('Username', icon: Icons.account_circle_outlined)),
        const SizedBox(height: 10),
        TextFormField(controller: password, obscureText: true, style: AppTextStyles.body, decoration: styledInput('Password', icon: Icons.lock_outline_rounded)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: role,
          style: AppTextStyles.body,
          decoration: styledInput('Role', icon: Icons.badge_outlined),
          items: ['admin', 'accountant', 'frontdesk'].map((r) => DropdownMenuItem(value: r, child: Text(r[0].toUpperCase() + r.substring(1)))).toList(),
          onChanged: (v) => ss(() => role = v!),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
        ElevatedButton(style: primaryBtn(), onPressed: () async {
          await LocalDb.insertUser({'name': name.text, 'username': username.text, 'password': password.text, 'role': role, 'active': 1});
          if (mounted) Navigator.pop(ctx);
          _load();
        }, child: const Text('Add')),
      ],
    )));
  }
}
