import 'package:flutter/material.dart';
import '../../services/local_db.dart';
import '../../widgets/common.dart';

class StudentFormScreen extends StatefulWidget {
  final String academicYearId;
  final Map<String, dynamic>? student;
  final String? initialClass;
  final String? initialSection;
  const StudentFormScreen({
    required this.academicYearId,
    this.student,
    this.initialClass,
    this.initialSection,
    super.key,
  });

  /// Show as popup dialog
  static Future<bool?> show(
    BuildContext context, {
    required String academicYearId,
    Map<String, dynamic>? student,
    String? initialClass,
    String? initialSection,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StudentFormScreen(
        academicYearId: academicYearId,
        student: student,
        initialClass: initialClass,
        initialSection: initialSection,
      ),
    );
  }

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};
  String _gender = 'Male';
  bool _loading = false;

  final _fields = ['admission_no', 'name', 'class', 'section', 'roll_no', 'dob',
    'parent_name', 'parent_phone', 'parent_email', 'address', 'sibling_group_id'];

  @override
  void initState() {
    super.initState();
    for (final f in _fields) _c[f] = TextEditingController(text: widget.student?[f]?.toString() ?? '');
    if (widget.student == null) {
      if (widget.initialClass != null) _c['class']!.text = widget.initialClass!;
      if (widget.initialSection != null) _c['section']!.text = widget.initialSection!;
    }
    _gender = widget.student?['gender'] ?? 'Male';
  }

  @override
  void dispose() { for (final c in _c.values) c.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{for (final f in _fields) f: _c[f]!.text.isEmpty ? null : _c[f]!.text.trim()};
      body['gender'] = _gender;
      if (body['class'] != null) body['class'] = (body['class'] as String).trim().toUpperCase();
      if (body['section'] != null) body['section'] = (body['section'] as String).trim().toUpperCase();
      body['academic_year_id'] = int.tryParse(widget.academicYearId);
      body['active'] = 1;
      if (widget.student != null) await LocalDb.updateStudent(widget.student!['id'] as int, body);
      else await LocalDb.insertStudent(body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.student != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: LoadingOverlay(
          loading: _loading,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                Icon(isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                  color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(isEdit ? 'Edit Student' : 'Add Student',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context, false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),

            // ── Form ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Academic Info
                    _sectionLabel('Academic Info', Icons.school_outlined),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field('admission_no', 'Admission No', icon: Icons.badge_outlined, required: true)),
                      const SizedBox(width: 14),
                      Expanded(child: _field('name', 'Full Name', icon: Icons.person_outline, required: true)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field('class', 'Class', icon: Icons.class_outlined, required: true)),
                      const SizedBox(width: 14),
                      Expanded(child: _field('section', 'Section', icon: Icons.group_outlined, required: true)),
                      const SizedBox(width: 14),
                      Expanded(child: _field('roll_no', 'Roll No', icon: Icons.format_list_numbered_outlined)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field('dob', 'Date of Birth (YYYY-MM-DD)', icon: Icons.cake_outlined)),
                      const SizedBox(width: 14),
                      Expanded(child: _genderField()),
                    ]),

                    const SizedBox(height: 20),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 12),

                    // Parent / Guardian
                    _sectionLabel('Parent / Guardian', Icons.family_restroom_outlined),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field('parent_name', 'Parent Name', icon: Icons.person_outline)),
                      const SizedBox(width: 14),
                      Expanded(child: _field('parent_phone', 'Phone', icon: Icons.phone_outlined)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field('parent_email', 'Email', icon: Icons.email_outlined)),
                      const SizedBox(width: 14),
                      Expanded(child: _field('address', 'Address', icon: Icons.location_on_outlined)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field('sibling_group_id', 'Sibling Group ID', icon: Icons.group_outlined)),
                      const Expanded(child: SizedBox()),
                    ]),
                  ]),
                ),
              ),
            ),

            // ── Footer buttons ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: Text(isEdit ? 'Update' : 'Save Student',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: primaryBtn(),
                  onPressed: _save,
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, IconData icon) => Row(children: [
    Icon(icon, color: AppColors.primary, size: 16),
    const SizedBox(width: 7),
    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
  ]);

  Widget _field(String key, String label, {IconData? icon, bool required = false}) =>
    TextFormField(
      controller: _c[key],
      decoration: styledInput(label, icon: icon),
      validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
    );

  Widget _genderField() => DropdownButtonFormField<String>(
    value: _gender,
    decoration: styledInput('Gender', icon: Icons.wc_outlined),
    items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
    onChanged: (v) => setState(() => _gender = v!),
  );
}
