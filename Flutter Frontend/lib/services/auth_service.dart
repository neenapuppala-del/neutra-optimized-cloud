import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  // Base URL for backend
  static String get baseUrl => '${ApiService.baseUrl}/auth';

  // SIGN UP
  Future<Map<String, dynamic>?> signup(String email, String password, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          if (data['user'] != null && data['user']['userId'] != null) {
            await prefs.setString('userId', data['user']['userId']);
          }
        }
        return data['user'];
      } else {
        print("Signup error: ${response.body}");
        try {
          final data = jsonDecode(response.body);
          final errorMsg = data['error'] ?? 'Signup failed';
          throw Exception(errorMsg);
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Signup failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Signup Exception: $e');
      rethrow;
    }
  }

  // LOGIN
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          if (data['user'] != null && data['user']['userId'] != null) {
            await prefs.setString('userId', data['user']['userId']);
          }
        }
        return data['user'];
      } else {
        print("Login error: ${response.body}");
        try {
          final data = jsonDecode(response.body);
          final errorMsg = data['error'] ?? 'Login failed';
          throw Exception(errorMsg);
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Login failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Login Exception: $e');
      rethrow;
    }
  }

  // LOGOUT
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('userId');
  }

  // GET TOKEN
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
}