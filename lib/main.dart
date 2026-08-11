// main.dart - TANPA PERMISSION HANDLER
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'dashboard_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vyper Control',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1D6FFF),
        scaffoldBackgroundColor: const Color(0xFF020510),
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1D6FFF),
          secondary: Color(0xFF4d8fff),
          surface: Color(0xFF081428),
          background: Color(0xFF020510),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF050d1f),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF081428),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Color(0xFF8ab4e0)),
          bodySmall: TextStyle(color: Color(0xFF3d6080)),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 800));

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final username = prefs.getString('username');
    final displayName = prefs.getString('displayName');
    final baseUrl = prefs.getString('baseUrl');
    final deviceId = prefs.getString('deviceId');

    if (!mounted) return;

    if (token != null && username != null && baseUrl != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(
            token: token,
            username: username,
            displayName: displayName ?? username,
            baseUrl: baseUrl,
            deviceId: deviceId ?? 'flutter_device',
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020510),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1D6FFF), Color(0xFF00D4FF)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D6FFF).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.phone_android,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'VYPERFREE',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Remote Device Control',
              style: TextStyle(
                color: Color(0xFF3d6080),
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1D6FFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}