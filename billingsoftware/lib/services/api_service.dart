import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';
  static String? _token;
  static String? userRole;
  static String? userName;
  static int? userId;

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    userRole = prefs.getString('role');
    userName = prefs.getString('userName');
    userId = prefs.getInt('userId');
  }

  static Future<bool> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _token = data['token'];
      userRole = data['role'];
      userName = data['name'];
      userId = data['id'] as int?;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('role', userRole!);
      await prefs.setString('userName', userName!);
      if (userId != null) await prefs.setInt('userId', userId!);
      return true;
    }
    return false;
  }

  static Future<void> logout() async {
    _token = null;
    userRole = null;
    userName = null;
    userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  static Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['error'] ?? 'Request failed');
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body));
    if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['error'] ?? 'Request failed');
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['error'] ?? 'Request failed');
  }

  static Future<dynamic> delete(String path) async {
    final res = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['error'] ?? 'Request failed');
  }
}
