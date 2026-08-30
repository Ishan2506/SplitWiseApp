import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user_model.dart';

class ApiService {
  // Physical Android phone: use the PC's LAN IP (phone + PC on same Wi-Fi).
  // Emulator would use 10.0.2.2; web/desktop uses localhost.
  static const String baseUrl = kIsWeb
      ? 'http://localhost:5000/api'
      : 'http://192.168.31.106:5000/api';

  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static String? get token => _token;

  static Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Register user
  static Future<Map<String, dynamic>> register({
    required String name,
    String? email,
    String? mobileNumber,
    required String password,
  }) async {
    try {
      final body = {
        'name': name,
        'password': password,
      };
      if (email != null && email.isNotEmpty) {
        body['email'] = email;
      }
      if (mobileNumber != null && mobileNumber.isNotEmpty) {
        body['mobileNumber'] = mobileNumber;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        final token = data['token'];
        if (token != null) {
          await _saveToken(token);
        }
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final token = data['token'];
        if (token != null) {
          await _saveToken(token);
        }
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Login / sign up with Google.
  // Sends the Google idToken to the backend, which verifies it and returns our JWT.
  static Future<Map<String, dynamic>> googleLogin({
    required String idToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: _getHeaders(),
        body: jsonEncode({'idToken': idToken}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final token = data['token'];
        if (token != null) {
          await _saveToken(token);
        }
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Google login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get current user profile (verify token)
  static Future<Map<String, dynamic>> getMe() async {
    if (_token == null) {
      return {'success': false, 'message': 'No authentication token'};
    }
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        await clearToken(); // Token is invalid/expired
        return {'success': false, 'message': data['message'] ?? 'Session expired'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? mobileNumber,
    String? avatarUrl,
    String? preferredCurrency,
    String? language,
    bool? emailNotifications,
    bool? pushNotifications,
    String? password,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (mobileNumber != null) body['mobileNumber'] = mobileNumber;
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
      if (preferredCurrency != null) body['preferredCurrency'] = preferredCurrency;
      if (language != null) body['language'] = language;
      if (emailNotifications != null) body['emailNotifications'] = emailNotifications;
      if (pushNotifications != null) body['pushNotifications'] = pushNotifications;
      if (password != null && password.isNotEmpty) body['password'] = password;

      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Profile update failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
