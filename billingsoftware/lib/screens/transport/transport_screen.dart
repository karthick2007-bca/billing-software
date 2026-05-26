import 'package:flutter/material.dart';
import '../../services/local_db.dart';
import '../../widgets/common.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});
  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  List _locations = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await LocalDb.getTransportLocations();
    setState(() { _locations = data; _loading = false; });
  }

  void _showForm({Map? existing}) {
    final locationCtrl = TextEditingController(text: existing?['location'] ?? '');
    String locationType = existing?['location_type'] as String? ?? 'Town';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text(existing == null ? 'Add Location' : 'Edit Location', style: AppTextStyles.h3),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: locationCtrl,
            style: AppTextStyles.body,
            decoration: styledInput('Location name', icon: Icons.location_on_rounded),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: locationType,
            decoration: styledInput('Location Type', icon: Icons.category_rounded),
            items: ['Town', 'Village', 'City', 'Panchayat', 'Term', 'Other']
              .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => ss(() => locationType = v!),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: primaryBtn(),
            onPressed: () async {
              final loc = locationCtrl.text.trim();
              if (loc.isEmpty) { showSnack(context, 'Enter location name', error: true); return; }
              if (existing == null) {
                await LocalDb.insertTransportLocation(loc, 0, locationType: locationType);
              } else {
                await LocalDb.updateTransportLocation(existing['id'] as int, loc, 0, locationType: locationType);
              }
              if (mounted) Navigator.pop(context);
              _load();
            },
            child: Text(existing == null ? 'Add' : 'Update'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        PageHeader('Transport', actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Location'),
            style: primaryBtn(),
            onPressed: () => _showForm(),
          ),
        ]),
        const SizedBox(height: 20),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _locations.isEmpty
            ? const EmptyState(icon: Icons.directions_bus_rounded, message: 'No locations added yet')
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisExtent: 120,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _locations.length,
                itemBuilder: (_, i) {
                  final loc = _locations[i];
                  return _LocationCard(
                    location: loc,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => _LocationDetailPage(location: loc),
                      ));
                      _load();
                    },
                    onEdit: () => _showForm(existing: loc),
                    onDelete: () async {
                      if (await confirmDialog(context, 'Delete "${loc['location']}"?', danger: true)) {
                        await LocalDb.deleteTransportLocation(loc['id'] as int);
                        _load();
                      }
                    },
                  );
                },
              ),
        ),
      ]),
    ),
  );
}

// ── Location Card ─────────────────────────────────────────────────────────────
class _LocationCard extends StatefulWidget {
  final Map location;
  final VoidCallback onTap, onEdit, onDelete;
  const _LocationCard({required this.location, required this.onTap, required this.onEdit, required this.onDelete});
  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? AppColors.primary : AppColors.border, width: _hovered ? 2 : 1),
            boxShadow: [BoxShadow(
              color: _hovered ? AppColors.primary.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05),
              blurRadius: _hovered ? 14 : 6, offset: const Offset(0, 3),
            )],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
              ),
              const Spacer(),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Row(children: [
                    const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 10), const Text('Edit'),
                  ])),
                  PopupMenuItem(value: 'delete', child: Row(children: [
                    const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                    const SizedBox(width: 10), const Text('Delete', style: TextStyle(color: AppColors.danger)),
                  ])),
                ],
                onSelected: (v) {
                  if (v == 'edit') widget.onEdit();
                  if (v == 'delete') widget.onDelete();
                },
              ),
            ]),
            const SizedBox(height: 10),
            Text(loc['location'] as String,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
              child: Text(loc['location_type'] as String? ?? 'Town',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Location Detail Page ──────────────────────────────────────────────────────
class _LocationDetailPage extends StatefulWidget {
  final Map location;
  const _LocationDetailPage({required this.location});
  @override
  State<_LocationDetailPage> createState() => _LocationDetailPageState();
}

class _LocationDetailPageState extends State<_LocationDetailPage> {
  // stops with their term amounts: each stop has id, stop_name, t1, t2, t3 amounts
  List<Map<String, dynamic>> _stopTerms = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stops = await LocalDb.getTransportStops(widget.location['id'] as int);
    // For each stop, load term amounts from fee_structures linked to this stop
    final result = <Map<String, dynamic>>[];
    for (final stop in stops) {
      final termAmounts = await LocalDb.getStopTermAmounts(stop['id'] as int);
      result.add({
        'stop': stop,
        'terms': termAmounts, // list of {id, period_label, amount}
      });
    }
    setState(() { _stopTerms = result; _loading = false; });
  }

  void _editTermAmount(Map term, String stopName) {
    final amtCtrl = TextEditingController(text: (term['amount'] as num).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('$stopName — ${term['period_label']}', style: AppTextStyles.h3)),
        ]),
        content: TextField(
          controller: amtCtrl,
          keyboardType: TextInputType.number,
          style: AppTextStyles.body,
          decoration: styledInput('Amount (₹)', icon: Icons.currency_rupee_rounded),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: primaryBtn(),
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
              await LocalDb.updateStopTermAmount(term['id'] as int, amt);
              if (mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addStop() {
    final stopCtrl = TextEditingController();
    final t1 = TextEditingController();
    final t2 = TextEditingController();
    final t3 = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.place_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text('Add Stop', style: AppTextStyles.h3),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: stopCtrl, style: AppTextStyles.body,
            decoration: styledInput('Stop name', icon: Icons.place_outlined)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.07), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                child: Row(children: [
                  Expanded(child: Text('Term', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
                  Text('Amount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                ]),
              ),
              _termInputRow('Term 1', t1),
              const Divider(height: 1),
              _termInputRow('Term 2', t2),
              const Divider(height: 1),
              _termInputRow('Term 3', t3),
            ]),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: primaryBtn(),
            onPressed: () async {
              final name = stopCtrl.text.trim();
              if (name.isEmpty) { showSnack(context, 'Enter stop name', error: true); return; }
              final stopId = await LocalDb.insertTransportStop(widget.location['id'] as int, name, 0);
              // Insert term amounts
              final terms = [
                {'label': 'Term 1', 'amt': double.tryParse(t1.text.trim()) ?? 0},
                {'label': 'Term 2', 'amt': double.tryParse(t2.text.trim()) ?? 0},
                {'label': 'Term 3', 'amt': double.tryParse(t3.text.trim()) ?? 0},
              ];
              for (final t in terms) {
                await LocalDb.insertStopTermAmount(stopId, t['label'] as String, t['amt'] as double);
              }
              if (mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _termInputRow(String label, TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      Expanded(child: TextField(controller: ctrl, keyboardType: TextInputType.number, style: AppTextStyles.body,
        decoration: styledInput('₹', icon: Icons.currency_rupee_rounded), textAlign: TextAlign.right)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.location['location'] as String,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(widget.location['location_type'] as String? ?? '',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'Add Stop', onPressed: _addStop),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _stopTerms.isEmpty
          ? const EmptyState(icon: Icons.place_outlined, message: 'No stops added yet.\nTap + to add a stop.')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _stopTerms.length,
              itemBuilder: (_, i) {
                final entry  = _stopTerms[i];
                final stop   = entry['stop'] as Map;
                final terms  = entry['terms'] as List<Map<String, dynamic>>;
                final stopName = stop['stop_name'] as String;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: cardDecoration(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Stop header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                          child: Center(child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(stopName,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700))),
                      ]),
                    ),
                    // Term header row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(children: [
                        Expanded(child: Text('Term', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                        Text('Amount (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                        const SizedBox(width: 40),
                      ]),
                    ),
                    const Divider(height: 1),
                    // Term rows
                    ...terms.asMap().entries.map((e) {
                      final t   = e.value;
                      final amt = (t['amount'] as num).toDouble();
                      return Column(mainAxisSize: MainAxisSize.min, children: [
                        if (e.key > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(children: [
                            Expanded(child: Text(t['period_label'] as String? ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                            Text('₹${amt.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success)),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                              onPressed: () => _editTermAmount(t, stopName),
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
