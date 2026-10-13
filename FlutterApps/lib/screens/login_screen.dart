import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/ble_simulator_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Default placeholder agar user bisa langsung tes atau ketik sendiri
    _emailController.text = 'test@example.com';
    _passwordController.text = 'password';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email dan kata sandi wajib diisi.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.login(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      final isSetupDone = await ApiService.isOnboardingCompleted();
      if (!mounted) return;
      if (isSetupDone) {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        Navigator.pushReplacementNamed(context, '/pairing');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Login gagal. Periksa kembali akun atau backend.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Lewati',
            textColor: Colors.white,
            onPressed: () async {
              final isSetupDone = await ApiService.isOnboardingCompleted();
              if (!mounted) return;
              if (isSetupDone) {
                Navigator.pushReplacementNamed(context, '/main');
              } else {
                Navigator.pushReplacementNamed(context, '/pairing');
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua kolom (Nama, Email, dan Sandi) wajib diisi.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata sandi minimal 6 karakter.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.register(name, email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Akun "$name" berhasil didaftarkan! Selamat datang.'),
          backgroundColor: const Color(0xFF00A86B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final isSetupDone = await ApiService.isOnboardingCompleted();
      if (!mounted) return;
      if (isSetupDone) {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        Navigator.pushReplacementNamed(context, '/pairing');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Pendaftaran gagal. Periksa koneksi backend.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _enterDirectDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('demo_system_mode', true);
    BleSimulatorService().startSimulation(mode: BleSimMode.auto);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mode Demo Langsung aktif! Sensor beroperasi tanpa alat fisik.'),
        backgroundColor: Color(0xFF00A86B),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    final isSetupDone = await ApiService.isOnboardingCompleted();
    if (!mounted) return;
    if (isSetupDone) {
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      Navigator.pushReplacementNamed(context, '/pairing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Soft light background persis mockup
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Icon Logo 'K' Hijau
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B), // Hijau emerald persis mockup
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text(
                        'K',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Judul Aplikasi
                  const Text(
                    'Klimo Wearth',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 3. Subjudul
                  Text(
                    _isRegisterMode
                        ? 'Daftarkan akun barumu untuk mulai\nmemantau lingkungan sekitar.'
                        : 'Pantau UV, panas, dan udara dari alat\ndi bajumu.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. White Card Form Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tab Switcher: Masuk / Daftar
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isRegisterMode = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: !_isRegisterMode ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(11),
                                      boxShadow: !_isRegisterMode
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Masuk',
                                        style: TextStyle(
                                          color: !_isRegisterMode ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                          fontWeight: !_isRegisterMode ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isRegisterMode = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: _isRegisterMode ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(11),
                                      boxShadow: _isRegisterMode
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Daftar',
                                        style: TextStyle(
                                          color: _isRegisterMode ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                          fontWeight: _isRegisterMode ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Input Field Nama Lengkap (Khusus Mode Daftar)
                        if (_isRegisterMode) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                            ),
                            child: TextField(
                              controller: _nameController,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              cursorColor: const Color(0xFF00A86B),
                              decoration: const InputDecoration(
                                hintText: 'Nama lengkap kamu',
                                hintStyle: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 15,
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Input Field Email
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            cursorColor: const Color(0xFF00A86B),
                            decoration: const InputDecoration(
                              hintText: 'Email',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 15,
                                fontWeight: FontWeight.normal,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Input Field Kata Sandi
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            cursorColor: const Color(0xFF00A86B),
                            decoration: InputDecoration(
                              hintText: _isRegisterMode ? 'Kata sandi (min. 6 karakter)' : 'Kata sandi',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 15,
                                fontWeight: FontWeight.normal,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Tombol Aksi Utama (Masuk / Daftar)
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : (_isRegisterMode ? _handleRegister : _handleLogin),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A86B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    _isRegisterMode ? 'Daftar Akun Baru' : 'Masuk',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Divider 'atau'
                        Row(
                          children: [
                            Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'atau',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Tombol 'Masuk Mode Demo Langsung' (Fitur Demo Juri / Lomba)
                        InkWell(
                          onTap: _enterDirectDemoMode,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00A86B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Masuk Mode Demo Langsung',
                                        style: TextStyle(
                                          color: Color(0xFF065F46),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Simulasi sensor virtual tanpa login & tanpa alat',
                                        style: TextStyle(
                                          color: const Color(0xFF047857).withValues(alpha: 0.8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF00A86B), size: 14),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Switcher Bawah (Belum punya akun? / Sudah punya akun?)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isRegisterMode ? 'Sudah punya akun? ' : 'Belum punya akun? ',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isRegisterMode = !_isRegisterMode;
                                });
                              },
                              child: Text(
                                _isRegisterMode ? 'Masuk' : 'Daftar',
                                style: const TextStyle(
                                  color: Color(0xFF00A86B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ),
        ),
      ),
    );
  }
}
