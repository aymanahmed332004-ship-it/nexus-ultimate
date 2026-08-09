import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Nexus AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          IconButton(
            icon: const Icon(Icons.security, color: Colors.white),
            onPressed: () => _showMasterDialog(context, provider),
          ),
        ],
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0A0B1E), Color(0xFF14173D), Color(0xFF2A134D)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: provider.messages.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final msg = provider.messages[index];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF4A6CF7).withOpacity(0.8) : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(24),
                          topRight: const Radius.circular(24),
                          bottomLeft: isUser ? const Radius.circular(24) : Radius.zero,
                          bottomRight: isUser ? Radius.zero : const Radius.circular(24),
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Text(
                                  msg['content'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                                ),
                              ),
                              if (!isUser) Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: AnimatedWaveform(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (provider.messages.isNotEmpty && provider.messages.last['role'] == 'user')
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Dot(), Dot(), Dot()],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
                    onPressed: () => _toggleListening(provider),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'اسأل Nexus AI...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (v) => _sendMessage(provider),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 50, height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF6A5ACD), Color(0xFF4A6CF7)]),
                      boxShadow: [BoxShadow(color: Color(0xFF4A6CF7), blurRadius: 12, spreadRadius: 2)],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      color: Colors.white,
                      onPressed: () => _sendMessage(provider),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(ChatProvider provider) async {
    if (_controller.text.isEmpty) return;
    final query = _controller.text;
    _controller.clear();
    await provider.sendMessage(query);
    _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _toggleListening(ChatProvider provider) async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    bool available = await _speech.initialize();
    if (!available) return;
    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) => setState(() => _controller.text = result.recognizedWords),
    );
  }

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

class AnimatedWaveform extends StatefulWidget {
  const AnimatedWaveform({super.key});
  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}
class _AnimatedWaveformState extends State<AnimatedWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30, height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (i) {
          final h = 4.0 + (5.0 * (i % 2 == 0 ? 1 : 0.6));
          return AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final height = h * (0.5 + 0.5 * (sin(_controller.value * 2 * pi + i * 1.2)));
              return Container(width: 3, height: height, decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(2)));
            },
          );
        }),
      ),
    );
  }
}
class Dot extends StatelessWidget {
  const Dot({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle));
  }
}