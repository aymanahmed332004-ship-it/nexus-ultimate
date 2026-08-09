import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audioplayers/audioplayers.dart';

class ChatProvider extends ChangeNotifier {
  List<Map<String, String>> messages = [];
  String? _apiUrl;
  int? _userId;
  String? _token;
  int _messageCount = 0;
  int _dailyQuota = 10;
  bool _isMasterMode = false;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? get apiUrl => _apiUrl;
  String? get token => _token;

  ChatProvider() {
    _loadSettings();
    _loadAds();
    _checkDailyReset();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiUrl = prefs.getString('api_url') ?? 'https://nexus-ultimate-1-aymanahmed33200.replit.app';
    _userId = prefs.getInt('user_id');
    _token = prefs.getString('token');
    _isMasterMode = prefs.getBool('master_mode') ?? false;
    _dailyQuota = prefs.getInt('daily_quota') ?? 10;
    notifyListeners();
  }

  void _checkDailyReset() async {
    final prefs = await SharedPreferences.getInstance();
    String today = DateTime.now().toIso8601String().split('T')[0];
    String lastDate = prefs.getString('last_reset_date') ?? "";
    if (today != lastDate) {
      _dailyQuota = 10;
      await prefs.setInt('daily_quota', 10);
      await prefs.setString('last_reset_date', today);
      notifyListeners();
    }
  }

  void _loadAds() {
    // إعلان بيني (بعد كل 10 رسائل)
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-7903719438517437/5645960338',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) { _interstitialAd = ad; notifyListeners(); },
        onAdFailedToLoad: (error) { _interstitialAd = null; },
      ),
    );

    // إعلان فيديو مكافأة (عند نفاذ النقاط)
    RewardedAd.load(
      adUnitId: 'ca-app-pub-7903719438517437/5645960338',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { _rewardedAd = ad; notifyListeners(); },
        onAdFailedToLoad: (error) { _rewardedAd = null; },
      ),
    );
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

  Future<void> sendMessage(String query, {bool isFile = false}) async {
    if (_token == null) {
      messages.add({'role': 'assistant', 'content': '⚠️ يرجى تسجيل الدخول أولاً.'});
      notifyListeners();
      return;
    }

    // نظام الحصص (للصور والملفات)
    if (isFile) {
      if (_dailyQuota <= 0) {
        // عرض إعلان فيديو مكافأة
        if (_rewardedAd != null) {
          _rewardedAd?.show(onUserEarnedReward: (ad, reward) {
            _dailyQuota += 3;
            final prefs = await SharedPreferences.getInstance();
            prefs.setInt('daily_quota', _dailyQuota);
            notifyListeners();
          });
          _rewardedAd = null;
          _loadAds();
          return;
        } else {
          messages.add({'role': 'assistant', 'content': '⚠️ جارٍ تحميل الإعلان، حاول مرة أخرى.'});
          notifyListeners();
          return;
        }
      } else {
        _dailyQuota--;
        final prefs = await SharedPreferences.getInstance();
        prefs.setInt('daily_quota', _dailyQuota);
        notifyListeners();
      }
    }

    messages.add({'role': 'user', 'content': query});
    _messageCount++;
    notifyListeners();

    // إعلان بيني بعد كل 10 رسائل (مع تجاهل الماستر)
    if (!_isMasterMode && _messageCount % 10 == 0 && _interstitialAd != null) {
      _interstitialAd?.show();
      _interstitialAd = null;
      _loadAds();
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/ask'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode({'query': query, 'language': 'auto'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botResponse = data['response'] ?? '⚠️ لا يوجد رد';
        messages.add({'role': 'assistant', 'content': botResponse});
        notifyListeners();

        // ===== تشغيل الصوت (TTS) =====
        try {
          final ttsResponse = await http.post(
            Uri.parse('$_apiUrl/text_to_speech'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': botResponse, 'language': 'ar'}),
          );
          if (ttsResponse.statusCode == 200) {
            final ttsData = jsonDecode(ttsResponse.body);
            final audioBase64 = ttsData['audio'];
            final bytes = base64Decode(audioBase64);
            await _audioPlayer.play(BytesSource(bytes));
          }
        } catch (e) {
          // لو الصوت فشل، الشات يكمل عادي
        }
        // =================================

      } else if (response.statusCode == 401) {
        messages.add({'role': 'assistant', 'content': '⚠️ انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى.'});
        _token = null;
        final prefs = await SharedPreferences.getInstance();
        prefs.remove('token');
      } else {
        messages.add({'role': 'assistant', 'content': '⚠️ خطأ في الخادم: ${response.statusCode}'});
      }
    } catch (e) {
      messages.add({'role': 'assistant', 'content': '⚠️ فشل الاتصال بالسيرفر: $e'});
    }
    notifyListeners();
  }

  // وضع الماستر
  Future<bool> activateMasterMode(String password) async {
    if (password == "I am your master, I want you to turn off the ads for me") {
      _isMasterMode = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('master_mode', true);
      notifyListeners();
      return true;
    }
    return false;
  }

  void deactivateMasterMode() async {
    _isMasterMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('master_mode', false);
    notifyListeners();
  }
}