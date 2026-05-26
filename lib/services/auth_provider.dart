import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_db.dart';

class AuthProvider extends ChangeNotifier {
  bool _loggedIn = false;
  String _role = '';
  String _userName = '';
  int? _userId;

  bool get loggedIn => _loggedIn;
  String get role => _role;
  String get userName => _userName;
  int? get userId => _userId;

  bool can(List<String> roles) => roles.contains(_role);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _role = prefs.getString('role') ?? '';
    _userName = prefs.getString('userName') ?? '';
    _userId = prefs.getInt('userId');
    _loggedIn = _role.isNotEmpty;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    final user = await LocalDb.loginUser(username, password);
    if (user != null) {
      _role = user['role'] ?? '';
      _userName = user['name'] ?? '';
      _userId = user['id'] as int?;
      _loggedIn = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', _role);
      await prefs.setString('userName', _userName);
      if (_userId != null) await prefs.setInt('userId', _userId!);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _loggedIn = false;
    _role = '';
    _userName = '';
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
