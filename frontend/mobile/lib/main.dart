import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/chat_screen.dart';
import 'providers/chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NexusApp());
}

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'Nexus AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0B1E),
          fontFamily: GoogleFonts.cairo().fontFamily,
        ),
        home: const AuthScreen(),
        routes: {
          '/chat': (context) => const ChatScreen(),
        },
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignup = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  Future<void> _handleEmailPassword() async {
    try {
      if (_isSignup) {
        // تسجيل حساب جديد (مؤقت، هيحفظ في الذاكرة بس)
        _isSignup = false;
        Navigator.pushReplacementNamed(context, '/chat');
      } else {
        // تسجيل دخول مؤقت (هيدخل عادي من غير Firebase)
        Navigator.pushReplacementNamed(context, '/chat');
      }
    } catch (e) {
      print("Auth Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0A0B1E), Color(0xFF14173D), Color(0xFF2A134D)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.psychology, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  'Nexus AI',
                  style: GoogleFonts.cairo(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 40),
                _buildTextField(_emailController, 'البريد الإلكتروني', Icons.email),
                const SizedBox(height: 16),
                _buildTextField(_passController, 'كلمة المرور', Icons.lock, isPassword: true),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => setState(() => _isSignup = !_isSignup),
                  child: Text(
                    _isSignup ? 'لديك حساب بالفعل؟ سجل دخولك' : 'ليس لديك حساب؟ قم بإنشاء واحد',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 30),
                InkWell(
                  onTap: _handleEmailPassword,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6A5ACD), Color(0xFF4A6CF7)]),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: const Color(0xFF4A6CF7).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 4))],
                    ),
                    child: Center(
                      child: Text(
                        _isSignup ? 'إنشاء حساب' : 'تسجيل الدخول',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('أو', style: TextStyle(color: Colors.white.withOpacity(0.6)))),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _socialButton(Icons.g_mobiledata, 'Google', () {}),
                    _socialButton(Icons.code, 'GitHub', () {}),
                    _socialButton(Icons.alternate_email, 'X (Twitter)', () {}),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white70),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
