import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // TODO: hapus sebelum rilis
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
    final p = AppPalette.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email dan kata sandi wajib diisi.'),
          backgroundColor: p.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await ApiService.login(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      await _goNext();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Login gagal. Periksa kembali akun atau backend.',
          ),
          backgroundColor: p.danger,
          action: SnackBarAction(
            label: 'Lewati',
            textColor: Colors.white,
            onPressed: _goNext,
          ),
        ),
      );
    }
  }

  /// Ke main jika setup sudah selesai, selain itu ke pairing.
  Future<void> _goNext() async {
    final isSetupDone = await ApiService.isOnboardingCompleted();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, isSetupDone ? '/main' : '/pairing');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                children: [
                  // Logo
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'K',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Klimo Wearth',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pantau UV, panas, dan udara dari alat\ndi bajumu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: p.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Form
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _field(
                          p,
                          controller: _emailController,
                          hint: 'Email',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          p,
                          controller: _passwordController,
                          hint: 'Kata sandi',
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: p.textMuted,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 18),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.primary,
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
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Masuk',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        Row(
                          children: [
                            Expanded(child: Divider(color: p.divider)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'atau',
                                style: TextStyle(color: p.textMuted, fontSize: 13),
                              ),
                            ),
                            Expanded(child: Divider(color: p.divider)),
                          ],
                        ),
                        const SizedBox(height: 22),

                        InkWell(
                          onTap: () => Navigator.pushReplacementNamed(context, '/pairing'),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _GoogleLogo(size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Lanjut dengan Google',
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Belum punya akun? ',
                              style: TextStyle(color: p.textSecondary, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Halaman pendaftaran akun Klimo Wearth.'),
                                  duration: Duration(seconds: 2),
                                ),
                              ),
                              child: Text(
                                'Daftar',
                                style: TextStyle(
                                  color: p.primary,
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

  Widget _field(
    AppPalette p, {
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.cardBorder, width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        cursorColor: p.primary,
        style: TextStyle(
          color: p.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: p.textMuted, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, size.height / 2);
    final stroke = w * 0.22;
    final rect = Rect.fromCircle(center: center, radius: w / 2 - stroke / 2);

    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawArc(rect, -math.pi * 0.75, math.pi * 0.55, false, arc(const Color(0xFFEA4335)));
    canvas.drawArc(rect, -math.pi * 1.3, math.pi * 0.55, false, arc(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, math.pi * 0.25, math.pi * 0.55, false, arc(const Color(0xFF34A853)));
    canvas.drawArc(rect, -math.pi * 0.2, math.pi * 0.45, false, arc(const Color(0xFF4285F4)));

    canvas.drawRect(
      Rect.fromLTWH(center.dx - stroke * 0.2, center.dy - stroke / 2, w / 2 * 0.9, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}