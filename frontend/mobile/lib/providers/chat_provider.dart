import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:start_io_sdk/start_io_sdk.dart'; // لـ Start.io
import 'package:google_mobile_ads/google_mobile_ads.dart'; // لـ AdMob

class ChatProvider extends ChangeNotifier {
  List<Map<String, String>> messages = [];
  String? _apiUrl;
  int? _userId;
  String? _token;
  
  int _messageCount = 0;
  int _dailyQuota = 10; 
  bool _isMasterMode = false;

  // إعلانات Start.io (البينية)
  StartIOInterstitialAd? _interstitialAd;
  
  // إعلانات AdMob (المكافأة)
  RewardedAd? _rewardedAd;

  // Getters للمتغيرات الخاصة (مهمة لزر رفع الصور)
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
    // تحميل إعلان Start.io (للبيني - بعد 10 رسائل)
    StartIOSDK.init(appId: "207683830");
    _interstitialAd = StartIOInterstitialAd();
    _interstitialAd?.load();

    // تحميل إعلان AdMob (للفيديو المكافأة)
    RewardedAd.load(
      adUnitId: 'ca-app-pub-7903719438517437/5645960338',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
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
    // التحقق من الرصيد قبل إرسال الملفات
    if (isFile) {
      if (_dailyQuota <= 0) {
        // عرض إعلان فيديو مكافأة من AdMob
        if (_rewardedAd != null) {
          _rewardedAd?.show(onUserEarnedReward: (ad, reward) {
            // المستخدم شاهد الإعلان، نزيد له 3 نقاط
            _dailyQuota += 3;
            final prefs = await SharedPreferences.getInstance();
            prefs.setInt('daily_quota', _dailyQuota);
            notifyListeners();
          });
          _rewardedAd = null;
          // إعادة تحميل إعلان جديد للمرة القادمة
          _loadAds();
          return; // ننتظر حتى ينتهي الإعلان
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

    if (_token == null) {
      messages.add({'role': 'assistant', 'content': '⚠️ يرجى تسجيل الدخول أولاً.'});
      notifyListeners();
      return;
    }

    messages.add({'role': 'user', 'content': query});
    _messageCount++;
    notifyListeners();

    // إعلان بني (Start.io) بعد كل 10 رسائل عادية (مع تجاهل وضع الماستر)
    if (!_isMasterMode && _messageCount % 10 == 0) {
      _interstitialAd?.show();
      _interstitialAd = null;
      // إعادة تحميل إعلان جديد للاستخدام التالي
      _interstitialAd = StartIOInterstitialAd();
      _interstitialAd?.load();
    }

    // إرسال الطلب إلى السيرفر
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
        prefs.remove('token');
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

  // وضع الماستر (تفعيل)
  Future<bool> activateMasterMode(String password) async {
    if (password == "I am your master, I want you to turn off the ads for me") {
      _isMasterMode = true;
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('master_mode', true);
      notifyListeners();
      return true;
    }
    return false;
  }

  // وضع الماستر (إلغاء)
  void deactivateMasterMode() async {
    _isMasterMode = false;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('master_mode', false);
    notifyListeners();
  }
}