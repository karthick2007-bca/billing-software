import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false, _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); _user.dispose(); _pass.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().login(_user.text.trim(), _pass.text.trim());
    if (mounted) {
      setState(() => _loading = false);
      if (!ok) showSnack(context, 'Invalid username or password', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800;
    return Scaffold(
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  Widget _wideLayout() => Row(
    children: [
      Expanded(
        flex: 5,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F2744), Color(0xFF1E3A5F), Color(0xFF2D5F9E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(top: -60, left: -60, child: _Circle(200, Colors.white.withValues(alpha: 0.04))),
              Positioned(bottom: -80, right: -80, child: _Circle(300, Colors.white.withValues(alpha: 0.04))),
              Positioned(top: 100, right: -40, child: _Circle(150, Colors.white.withValues(alpha: 0.03))),
              SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('SchoolBill', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                          Text('SREE SOWDAMBIKA INTERNATIONAL SCHOOL (CBSE)', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                        ]),
                      ]),
                      const SizedBox(height: 80),
                      const Text('Manage your school\nfinances with ease.', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.5)),
                      const SizedBox(height: 16),
                      Text('Complete billing, fee management, and\nfinancial reporting in one place.', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14, height: 1.6)),
                      const SizedBox(height: 40),
                      ...[
                        ('Fee Management', Icons.account_balance_wallet_rounded),
                        ('Student Records', Icons.people_alt_rounded),
                        ('Financial Reports', Icons.bar_chart_rounded),
                      ].map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                            child: Icon(e.$2, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 10),
                          Text(e.$1, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                        ]),
                      )),
                      const SizedBox(height: 48),
                      Text('© 2025 School Billing System', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        flex: 4,
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: _formCard())),
        ),
      ),
    ],
  );

  Widget _narrowLayout() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F2744), Color(0xFF2D5F9E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _formCard(),
      ),
    ),
  );

  Widget _formCard() => FadeTransition(
    opacity: _fadeAnim,
    child: SlideTransition(
      position: _slideAnim,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 16)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Welcome back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              const Text('SREE SOWDAMBIKA INTERNATIONAL SCHOOL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5)),
              const Text('(CBSE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(height: 6),
              const Text('Sign in to your account to continue', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 28),

              // Username
              const Text('Username', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _user,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                decoration: InputDecoration(
                  hintText: 'Enter your username',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textMuted, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.danger)),
                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              const Text('Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _pass,
                obscureText: _obscure,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Password is required' : null,
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.danger)),
                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                  ),
                  child: _loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Sign In', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle(this.size, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
