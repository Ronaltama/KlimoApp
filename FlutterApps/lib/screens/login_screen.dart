import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.login(email, password);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

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
                  const Text(
                    'Pantau UV, panas, dan udara dari alat\ndi bajumu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 4. White Card Form Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
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
                              hintText: 'Kata sandi',
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

                        // Tombol Masuk Hijau
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
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
                                : const Text(
                                    'Masuk',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 22),

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
                        const SizedBox(height: 22),

                        // Tombol 'Lanjut dengan Google'
                        InkWell(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/pairing');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _GoogleLogo(size: 20),
                                const SizedBox(width: 10),
                                const Text(
                                  'Lanjut dengan Google',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Belum punya akun? Daftar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Belum punya akun? ',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Halaman pendaftaran akun Klimo Wearth.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Text(
                                'Daftar',
                                style: TextStyle(
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

/// Widget Logo Resmi Google (4 Warna: Biru, Merah, Kuning, Hijau)
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;
    final strokeWidth = w * 0.22;

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final yellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final green = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Busur Merah (Atas)
    canvas.drawArc(rect, -3.14159 * 0.75, 3.14159 * 0.55, false, red);
    // Busur Kuning (Kiri)
    canvas.drawArc(rect, -3.14159 * 1.3, 3.14159 * 0.55, false, yellow);
    // Busur Hijau (Bawah)
    canvas.drawArc(rect, 3.14159 * 0.25, 3.14159 * 0.55, false, green);
    // Busur Biru (Kanan)
    canvas.drawArc(rect, -3.14159 * 0.2, 3.14159 * 0.45, false, blue);

    // Garis horizontal biru ke tengah
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx - strokeWidth * 0.2, center.dy - strokeWidth / 2, radius * 0.9, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
