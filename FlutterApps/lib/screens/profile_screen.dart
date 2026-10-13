import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'setup/skin_type_screen.dart';
import 'setup/device_pairing_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Ukuran huruf. Sama dengan layar Beranda.
  static const _fsCaption = 11.0;
  static const _fsSmall = 12.0;
  static const _fsBody = 13.0;
  static const _fsTitle = 15.0;
  static const _fsName = 18.0;
  static const _fsStat = 22.0;
  static const _fsHeader = 20.0;

  String _name = 'Budi Santoso';
  String _skin = 'Tipe IV';
  String _device = 'Klimo Wearth Gen 1';
  int? _battery;
  DateTime? _lastSync;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool manual = false}) async {
    setState(() => _loading = true);

    final profile = await ApiService.getProfile();
    final skin = await ApiService.getSkinType();
    final device = await ApiService.getConnectedDevice();
    final telemetry = await ApiService.getLatestTelemetry();
    if (!mounted) return;

    setState(() {
      if (profile != null && profile['name'] != null) {
        _name = profile['name'].toString();
      }
      _skin = skin;
      _device = device;
      if (telemetry != null) {
        _battery = _toInt(telemetry['battery']);
        _lastSync = _parse(telemetry['created_at']?.toString());
      }
      _loading = false;
    });

    if (manual) _notify('Profil diperbarui.');
  }

  // ---------- Aksi ----------

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final p = AppPalette.of(dialogContext);
        return AlertDialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Ubah nama',
            style: TextStyle(
              color: p.textPrimary,
              fontSize: _fsTitle,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: p.textPrimary, fontSize: _fsBody),
            decoration: InputDecoration(
              hintText: 'Tulis nama kamu',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (newName == null) return;
    if (newName.isEmpty) {
      _notify('Nama tidak boleh kosong.', error: true);
      return;
    }

    final res = await ApiService.updateProfile(newName);
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() => _name = newName);
      _notify('Nama kamu sudah diubah.');
    } else {
      _notify(res['message']?.toString() ?? 'Gagal mengubah nama.', error: true);
    }
  }

  Future<void> _changeSkin() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SkinTypeScreen(isEditMode: true)),
    );
    if (result != null && mounted) {
      setState(() => _skin = result);
      _notify('Tipe kulit diubah ke $result.');
    }
  }

  Future<void> _changeDevice() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const DevicePairingScreen(isEditMode: true)),
    );
    if (result != null && mounted) {
      setState(() => _device = result);
      _notify('Alat diganti ke $result.');
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final p = AppPalette.of(dialogContext);
        return AlertDialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Keluar dari akun?',
            style: TextStyle(
              color: p.textPrimary,
              fontSize: _fsTitle,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Kamu perlu masuk lagi untuk melihat data.',
            style: TextStyle(color: p.textSecondary, fontSize: _fsBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _resetOnboarding() async {
    await ApiService.setOnboardingCompleted(false);
    if (!mounted) return;
    _notify('Setup awal direset. Saat masuk lagi, setup akan dimulai dari awal.');
  }

  void _notify(String message, {bool error = false}) {
    if (!mounted) return;
    final p = AppPalette.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? p.danger : p.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => _load(manual: true),
              color: p.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  // Ruang di kiri untuk simetri dengan tombol di kanan
                  Row(
                    children: [
                      const SizedBox(width: 44),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Profil',
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: _fsHeader,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _profileCard(p),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          p,
                          value: '127',
                          label: 'Hari aktif',
                          valueColor: p.textPrimary,
                          onTap: () => _notify('Kamu sudah memakai aplikasi selama 127 hari.'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          p,
                          value: '89%',
                          label: 'Skor proteksi',
                          valueColor: p.primary,
                          onTap: () => _notify('Skor 89% menunjukkan kamu rutin melindungi diri.'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          p,
                          value: '14',
                          label: 'Peringatan',
                          valueColor: p.textPrimary,
                          onTap: () => _notify('Ada 14 peringatan sejak kamu mulai memakai aplikasi.'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Perangkat saya',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: _fsTitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _deviceCard(p),
                  const SizedBox(height: 14),
                  _skinCard(p),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(18),
                    child: AppCard(
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: p.danger, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Keluar',
                            style: TextStyle(
                              color: p.danger,
                              fontSize: _fsTitle,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _resetOnboarding,
                      child: Text(
                        'Atur ulang setup awal (uji coba)',
                        style: TextStyle(color: p.textMuted, fontSize: _fsCaption),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Tombol dark mode pojok kanan atas ──
            Positioned(
              top: 4,
              right: 12,
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: AppTheme.themeModeNotifier,
                builder: (context, mode, _) {
                  final isDark = mode == ThemeMode.dark;
                  return Tooltip(
                    message: isDark ? 'Mode terang' : 'Mode gelap',
                    child: InkWell(
                      onTap: () {
                        AppTheme.themeModeNotifier.value =
                            isDark ? ThemeMode.light : ThemeMode.dark;
                        _notify(isDark ? 'Mode terang aktif.' : 'Mode gelap aktif.');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: p.primary.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          color: p.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Bagian-bagian layar ----------

  Widget _profileCard(AppPalette p) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: p.primary.withValues(alpha: 0.12),
            child: Icon(Icons.person, size: 34, color: p.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: _fsName,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _editName,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.primary,
                    side: BorderSide(color: p.primary, width: 1.2),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Edit profil',
                    style: TextStyle(fontSize: _fsSmall, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    AppPalette p, {
    required String value,
    required String label,
    required Color valueColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: _fsStat,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textSecondary, fontSize: _fsCaption),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceCard(AppPalette p) {
    final batteryText = _battery == null ? '--%' : '$_battery%';

    return InkWell(
      onTap: _changeDevice,
      borderRadius: BorderRadius.circular(18),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.watch_outlined, color: p.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _device,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: _fsTitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.battery_std_rounded, size: 14, color: p.primary),
                      const SizedBox(width: 4),
                      Text(
                        batteryText,
                        style: TextStyle(
                          color: p.primary,
                          fontSize: _fsSmall,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _syncText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.textMuted, fontSize: _fsSmall),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.primary.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Terhubung',
                style: TextStyle(
                  color: p.primary,
                  fontSize: _fsCaption,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skinCard(AppPalette p) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wb_sunny_outlined, color: p.orange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipe kulit',
                  style: TextStyle(color: p.textMuted, fontSize: _fsCaption),
                ),
                const SizedBox(height: 2),
                Text(
                  _skin,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: _fsTitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _changeSkin,
            child: Text(
              'Ubah',
              style: TextStyle(
                color: p.primary,
                fontSize: _fsBody,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ---------- Helper ----------

  String get _syncText {
    if (_lastSync == null) return 'Belum tersambung';
    final diff = DateTime.now().difference(_lastSync!);
    if (diff.inSeconds < 10) return 'Sinkron baru saja';
    if (diff.inSeconds < 60) return 'Sinkron ${diff.inSeconds} detik lalu';
    if (diff.inMinutes < 60) return 'Sinkron ${diff.inMinutes} menit lalu';
    return 'Sinkron ${diff.inHours} jam lalu';
  }

  DateTime? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  int? _toInt(dynamic v) {
    if (v is num) return v.round();
    return int.tryParse('$v');
  }
}