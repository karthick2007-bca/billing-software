import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/update_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthProvider();
  await auth.init();
  runApp(ChangeNotifierProvider.value(value: auth, child: const SchoolBillingApp()));
}

class SchoolBillingApp extends StatelessWidget {
  const SchoolBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Fee Billing System',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) => auth.loggedIn
            ? const _DashboardWithUpdateCheck()
            : const LoginScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const primary = Color(0xFF1E3A5F);
    const accent  = Color(0xFFF5A623);
    const bg      = Color(0xFFF4F6F9);
    const border  = Color(0xFFE2E8F0);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      // Use system font — closest to Inter/Poppins on Windows is Segoe UI
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: bg,

      // App bar
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Segoe UI'),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated buttons — default to primary navy
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Segoe UI'),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Segoe UI'),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Segoe UI'),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2)),
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontFamily: 'Segoe UI'),
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontFamily: 'Segoe UI'),
        errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontFamily: 'Segoe UI'),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFamily: 'Segoe UI'),
        contentTextStyle: const TextStyle(fontSize: 14, color: Color(0xFF475569), fontFamily: 'Segoe UI'),
      ),

      // Divider
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),

      // List tile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        minVerticalPadding: 8,
      ),

      // Tab bar
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: Color(0xFF94A3B8),
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Segoe UI'),
        unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, fontFamily: 'Segoe UI'),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : null),
      ),

      // Popup menu
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: border)),
        textStyle: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Segoe UI'),
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: const Color(0xFF1E3A5F), borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Segoe UI'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}

class _DashboardWithUpdateCheck extends StatefulWidget {
  const _DashboardWithUpdateCheck();
  @override
  State<_DashboardWithUpdateCheck> createState() => _DashboardWithUpdateCheckState();
}

class _DashboardWithUpdateCheckState extends State<_DashboardWithUpdateCheck> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) => const DashboardScreen();
}
