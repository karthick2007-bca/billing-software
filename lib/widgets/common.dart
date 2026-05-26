import 'package:flutter/material.dart';

// ─── Color System ─────────────────────────────────────────────────────────────
class AppColors {
  // Primary palette
  static const primary       = Color(0xFF1E3A5F); // Deep navy
  static const primaryDark   = Color(0xFF142840); // Darker navy for sidebar top
  static const primaryLight  = Color(0xFF2A5298); // Medium navy
  static const primaryFaded  = Color(0xFFEBF0F8); // Very light navy tint

  // Accent — gold/amber for important actions & highlights
  static const accent        = Color(0xFFF5A623);
  static const accentDark    = Color(0xFFD4891A);
  static const accentFaded   = Color(0xFFFEF3DC);

  // Semantic status colors
  static const success       = Color(0xFF16A34A); // Green — Paid
  static const successFaded  = Color(0xFFDCFCE7);
  static const warning       = Color(0xFFEA580C); // Orange — Pending
  static const warningFaded  = Color(0xFFFFEDD5);
  static const danger        = Color(0xFFDC2626); // Red — Overdue / Error
  static const dangerFaded   = Color(0xFFFEE2E2);
  static const info          = Color(0xFF0284C7); // Blue — action buttons
  static const infoFaded     = Color(0xFFE0F2FE);
  static const muted         = Color(0xFF94A3B8); // Gray — disabled/cancelled
  static const mutedFaded    = Color(0xFFF1F5F9);

  // Backgrounds & surfaces
  static const bg            = Color(0xFFF4F6F9); // Soft gray page bg
  static const surface       = Color(0xFFFFFFFF);
  static const surfaceAlt    = Color(0xFFFAFBFC);
  static const border        = Color(0xFFE2E8F0);
  static const borderDark    = Color(0xFFCBD5E1);

  // Text
  static const textPrimary   = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted     = Color(0xFF94A3B8);
  static const textOnDark    = Color(0xFFFFFFFF);
  static const textOnAccent  = Color(0xFF7C3A00);
}

// ─── Typography ───────────────────────────────────────────────────────────────
class AppTextStyles {
  static const h1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3, height: 1.3);
  static const h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2, height: 1.3);
  static const h3 = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4);
  static const h4 = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5);
  static const bodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary, height: 1.5);
  static const bodySmall = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5);
  static const caption = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted, letterSpacing: 0.3, height: 1.4);
  static const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.4, height: 1.4);
  static const overline = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.0, height: 1.4);
}

// ─── Decorations ─────────────────────────────────────────────────────────────
BoxDecoration cardDecoration({double radius = 12, Color? color, bool border = true, bool shadow = true}) => BoxDecoration(
  color: color ?? AppColors.surface,
  borderRadius: BorderRadius.circular(radius),
  border: border ? Border.all(color: AppColors.border, width: 1) : null,
  boxShadow: shadow ? [
    BoxShadow(color: const Color(0xFF1E3A5F).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
    BoxShadow(color: const Color(0xFF1E3A5F).withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
  ] : null,
);

// ─── Input Decoration ─────────────────────────────────────────────────────────
/// Use this for forms — label is ABOVE the field (pass label as a separate Text widget)
InputDecoration fieldDecoration(String hint, {IconData? icon, Widget? suffix, String? errorText}) => InputDecoration(
  hintText: hint,
  hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
  prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted, size: 18) : null,
  suffixIcon: suffix,
  errorText: errorText,
  errorStyle: const TextStyle(fontSize: 12, color: AppColors.danger),
  filled: true,
  fillColor: AppColors.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.danger, width: 2)),
);

/// Legacy helper kept for backward compat
InputDecoration styledInput(String label, {IconData? icon, Widget? suffix}) => InputDecoration(
  labelText: label,
  labelStyle: AppTextStyles.bodySmall,
  prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted, size: 18) : null,
  suffixIcon: suffix,
  filled: true,
  fillColor: AppColors.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.danger, width: 2)),
);

// ─── Button Styles ────────────────────────────────────────────────────────────
ButtonStyle primaryBtn() => ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  elevation: 0,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
);

ButtonStyle accentBtn() => ElevatedButton.styleFrom(
  backgroundColor: AppColors.accent,
  foregroundColor: AppColors.textOnAccent,
  elevation: 0,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
);

ButtonStyle successBtn() => ElevatedButton.styleFrom(
  backgroundColor: AppColors.success,
  foregroundColor: Colors.white,
  elevation: 0,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
);

ButtonStyle dangerBtn() => ElevatedButton.styleFrom(
  backgroundColor: AppColors.danger,
  foregroundColor: Colors.white,
  elevation: 0,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
);

ButtonStyle outlineBtn({Color color = AppColors.primary}) => OutlinedButton.styleFrom(
  foregroundColor: color,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  side: BorderSide(color: color, width: 1.5),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
);

// ─── Page Header ──────────────────────────────────────────────────────────────
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader(this.title, {this.subtitle, this.actions = const [], super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.h1),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: AppTextStyles.bodySmall),
            ],
          ]),
        ),
        ...actions.map((a) => Padding(padding: const EdgeInsets.only(left: 10), child: a)),
      ],
    ),
  );
}

// ─── Styled Card ──────────────────────────────────────────────────────────────
class StyledCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final bool border;
  const StyledCard({required this.child, this.padding, this.radius = 12, this.border = true, super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: cardDecoration(radius: radius, border: border),
    padding: padding,
    child: child,
  );
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.$2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.$1.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: cfg.$1, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(cfg.$3, style: TextStyle(fontSize: 11, color: cfg.$1, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      ]),
    );
  }

  static (Color, Color, String) _statusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'paid':    return (AppColors.success, AppColors.successFaded, 'PAID');
      case 'pending': return (AppColors.warning, AppColors.warningFaded, 'PENDING');
      case 'partial': return (AppColors.info,    AppColors.infoFaded,    'PARTIAL');
      case 'overdue': return (AppColors.danger,  AppColors.dangerFaded,  'OVERDUE');
      case 'waived':  return (AppColors.muted,   AppColors.mutedFaded,   'WAIVED');
      default:        return (AppColors.muted,   AppColors.mutedFaded,   status.toUpperCase());
    }
  }
}

// ─── Fee Status Badge (for students) ─────────────────────────────────────────
class FeeStatusBadge extends StatelessWidget {
  final String status; // 'paid' | 'pending' | 'overdue'
  const FeeStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = switch (status.toLowerCase()) {
      'paid'    => (AppColors.successFaded, AppColors.success, 'Paid',    Icons.check_circle_rounded),
      'overdue' => (AppColors.dangerFaded,  AppColors.danger,  'Overdue', Icons.error_rounded),
      _         => (AppColors.warningFaded, AppColors.warning, 'Pending', Icons.schedule_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────
class StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const StatChip(this.label, this.value, this.color, this.icon, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
    ]),
  );
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final String label, value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      SizedBox(width: 150, child: Text(label, style: AppTextStyles.bodySmall)),
      Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
    ]),
  );
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionHeader(this.title, {this.action, super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: AppTextStyles.h2),
      if (action != null) action!,
    ],
  );
}

// ─── Form Field Label ─────────────────────────────────────────────────────────
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const FieldLabel(this.text, {this.required = false, super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(text, style: AppTextStyles.label),
      if (required) const Text(' *', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({required this.icon, required this.message, this.actionLabel, this.onAction, super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.primaryFaded, shape: BoxShape.circle),
        child: Icon(icon, size: 40, color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      const SizedBox(height: 16),
      Text(message, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 16),
        ElevatedButton(style: primaryBtn(), onPressed: onAction, child: Text(actionLabel!)),
      ],
    ]),
  );
}

// ─── Loading Overlay ──────────────────────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  final bool loading;
  final Widget child;
  const LoadingOverlay({required this.loading, required this.child, super.key});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      if (loading) Positioned.fill(child: Container(
        color: Colors.white.withValues(alpha: 0.75),
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      )),
    ],
  );
}

// ─── Snackbar ─────────────────────────────────────────────────────────────────
void showSnack(BuildContext context, String msg, {bool error = false, bool warning = false}) {
  final color = error ? AppColors.danger : warning ? AppColors.warning : AppColors.success;
  final icon  = error ? Icons.error_outline_rounded : warning ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.only(top: 16, right: 16, left: 16),
      duration: const Duration(seconds: 3),
    ));
}

// ─── Confirm Dialog ───────────────────────────────────────────────────────────
Future<bool> confirmDialog(BuildContext context, String msg, {String? title, bool danger = false}) async {
  return await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (danger ? AppColors.dangerFaded : AppColors.warningFaded),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(danger ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
            color: danger ? AppColors.danger : AppColors.warning, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title ?? 'Confirm Action', style: AppTextStyles.h3),
      ]),
      content: Text(msg, style: AppTextStyles.body),
      actions: [
        OutlinedButton(
          style: outlineBtn(color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: danger ? dangerBtn() : primaryBtn(),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  ) ?? false;
}

// ─── Section Divider ──────────────────────────────────────────────────────────
class SectionDivider extends StatelessWidget {
  final String label;
  const SectionDivider(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
    ]),
  );
}

// ─── Avatar ───────────────────────────────────────────────────────────────────
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  const UserAvatar({required this.name, this.size = 36, super.key});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty ? '?'
        : name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(child: Text(initials,
        style: TextStyle(color: Colors.white, fontSize: size * 0.35, fontWeight: FontWeight.w700))),
    );
  }
}
