import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatProvider extends ChangeNotifier {
  List<Map<String, String>> messages = [];
  String? _apiUrl;
  int? _userId;
  String? _token;

  ChatProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiUrl = prefs.getString('api_url') ?? 'https://nexus-ultimate-1-aymanahmed33200.replit.app';
    _userId = prefs.getInt('user_id');
    _token = prefs.getString('token');
  }

  Future<void> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _userId = data['user_id'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setInt('user_id', _userId!);
        notifyListeners();
      } else {
        throw Exception('Login failed');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> sendMessage(String query) async {
    if (_token == null) {
      messages.add({'role': 'assistant', 'content': '⚠️ يرجى تسجيل الدخول أولاً.'});
      notifyListeners();
      return;
    }

    messages.add({'role': 'user', 'content': query});
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/ask'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'query': query,
          'language': 'auto',
          'deep_thinking': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        messages.add({
          'role': 'assistant',
          'content': data['response'] ?? '⚠️ لا يوجد رد',
        });
      } else if (response.statusCode == 401) {
        messages.add({
          'role': 'assistant',
          'content': '⚠️ انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى.',
        });
        _token = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
      } else {
        messages.add({
          'role': 'assistant',
          'content': '⚠️ خطأ في الخادم: ${response.statusCode}',
        });
      }
    } catch (e) {
      messages.add({
        'role': 'assistant',
        'content': '⚠️ فشل الاتصال بالسيرفر: $e',
      });
    }
    notifyListeners();
  }

  Future<void> setApiUrl(String url) async {
    _apiUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', url);
    notifyListeners();
  }
}