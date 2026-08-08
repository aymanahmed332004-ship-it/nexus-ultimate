import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isListening = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ChatProvider>(context);

    return Scaffold(
      // تصميم الـ AppBar الجديد مع زر الماستر
      appBar: AppBar(
        title: const Text('NEXUS AI', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black12,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: () => _showMasterDialog(context, provider),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: provider.messages.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final msg = provider.messages[index];
                final isUser = msg['role'] == 'user';

                // تصميم فقاعات الشات الجديدة
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueAccent : Colors.grey.shade800,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // مؤشر التحميل (النقاط الثلاث) - يظهر بعد رسالة المستخدم
          if (provider.messages.isNotEmpty && provider.messages.last['role'] == 'user')
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                  ],
                ),
              ),
            ),

          // شريط الإدخال الجديد (مع زر الصور)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  onPressed: _toggleListening,
                ),
                
                // زر رفع الصور
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      // إرسال الصورة للسيرفر عبر MultipartRequest
                      var request = http.MultipartRequest(
                        'POST', 
                        Uri.parse('${provider.apiUrl}/upload_file')
                      );
                      request.headers['Authorization'] = 'Bearer ${provider.token}';
                      var multipartFile = await http.MultipartFile.fromPath('file', image.path);
                      request.files.add(multipartFile);
                      
                      var response = await request.send();
                      if (response.statusCode == 200) {
                        final responseData = await response.stream.bytesToString();
                        final jsonData = jsonDecode(responseData);
                        provider.messages.add({
                          'role': 'assistant', 
                          'content': jsonData['summary'] ?? '✅ تم تحليل الصورة بنجاح'
                        });
                        provider.notifyListeners();
                      } else {
                        provider.messages.add({
                          'role': 'assistant', 
                          'content': '⚠️ فشل تحميل الصورة'
                        });
                        provider.notifyListeners();
                      }
                      // التمرير للأسفل بعد الإرسال
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),

                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'اسأل NEXUS...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white12,
                    ),
                    onSubmitted: (text) => _sendMessage(provider),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(provider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // دالة إرسال الرسالة
  void _sendMessage(ChatProvider provider) async {
    if (_controller.text.isEmpty) return;
    final query = _controller.text;
    _controller.clear();
    await provider.sendMessage(query);
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // دالة الميكروفون
  void _toggleListening() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    bool available = await _speech.initialize();
    if (!available) return;
    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        setState(() => _controller.text = result.recognizedWords);
      },
    );
  }

  // دالة مربع حوار وضع الماستر
  void _showMasterDialog(BuildContext context, ChatProvider provider) async {
    TextEditingController _passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🔐 وضع الماستر'),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'أدخل كلمة السر'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('تأكيد'),
              onPressed: () async {
                bool success = await provider.activateMasterMode(_passwordController.text);
                Navigator.of(context).pop();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ تم تفعيل وضع الماستر، الإعلانات معطلة!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ كلمة سر خاطئة')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}