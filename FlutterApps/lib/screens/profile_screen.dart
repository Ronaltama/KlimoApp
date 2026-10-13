import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/local_data_service.dart';
import '../services/ble_simulator_service.dart';
import 'setup/skin_type_screen.dart';
import 'setup/device_pairing_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  String _skinType = 'Tipe IV';
  String _deviceName = 'Klimo Wearth Gen 1';
  bool _isDemoMode = true;

  int _activeDays = 127;
  int _protectionScore = 89;
  int _alertCount = 14;
  final _ble = BleSimulatorService();

  @override
  void initState() {
    super.initState();
    _loadDemoMode();
    _fetchProfile();
    _ble.statusStream.listen((_) {
      if (mounted) setState(() {});
    });
    _ble.recordStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDemoMode = prefs.getBool('demo_system_mode') ?? true;
      });
    }
  }

  Future<void> _toggleDemoMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('demo_system_mode', value);
    setState(() {
      _isDemoMode = value;
    });

    if (value) {
      _ble.startSimulation(mode: _ble.currentMode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode Demo diaktifkan. Data simulasi lingkungan aktif.'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } else {
      _ble.stop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode Demo dimatikan. Beralih ke data riil Bluetooth.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _fetchProfile() async {
    final data = await ApiService.getProfile();
    final skinType = await ApiService.getSkinType();
    final deviceName = await ApiService.getConnectedDevice();

    // Hitung metrik dinamis dari telemetri aktual (Lokal SQLite & API)
    final localHistory = await LocalDataService.getHistory(limit: 500);
    List<dynamic> telemetryRecords = [];

    if (localHistory.isNotEmpty) {
      telemetryRecords = localHistory.map((r) => {
        'uv_index': r.uvIndex,
        'temperature': r.temperature,
        'humidity': r.humidity,
        'voc': r.voc,
        'created_at': r.timestamp.toIso8601String(),
      }).toList();
    } else {
      telemetryRecords = await ApiService.getHistoryData();
    }

    int activeDays = 127;
    int protectionScore = 89;
    int alerts = 14;

    if (telemetryRecords.isNotEmpty) {
      final daysSet = <String>{};
      int safeCount = 0;

      for (var item in telemetryRecords) {
        final uv = (item['uv_index'] as num?)?.toDouble() ?? 0.0;
        final temp = (item['temperature'] as num?)?.toDouble() ?? 0.0;
        final voc = (item['voc'] as num?)?.toInt() ?? 0;

        if (item['created_at'] != null) {
          final dt = DateTime.tryParse(item['created_at'].toString())?.toLocal();
          if (dt != null) {
            daysSet.add('${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}');
          }
        }

        if (uv < 6.0 && temp < 33.0) {
          safeCount++;
        }

        if (uv >= 8.0 || temp >= 35.0 || voc >= 250) {
          alerts++;
        }
      }

      if (daysSet.isNotEmpty) {
        activeDays = daysSet.length;
      }
      protectionScore = ((safeCount / telemetryRecords.length) * 100).round();
    } else if (data?['created_at'] != null) {
      final userCreated = DateTime.tryParse(data!['created_at'].toString())?.toLocal();
      if (userCreated != null) {
        final diff = DateTime.now().difference(userCreated).inDays + 1;
        if (diff > 0) activeDays = diff;
      }
    }

    if (!mounted) return;

    setState(() {
      _userProfile = data;
      _skinType = skinType;
      if (deviceName.isNotEmpty) {
        _deviceName = deviceName;
      }
      _activeDays = activeDays;
      _protectionScore = protectionScore;
      _alertCount = alerts;
    });
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Keluar dari Akun?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari KlimoApp? Sesi token di server akan dicabut.',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await ApiService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    final currentName = _userProfile?['name'] ?? 'Budi Santoso';
    final controller = TextEditingController(text: currentName);

    final bool? updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Ubah Nama Pengguna',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  hintText: 'Masukkan nama baru',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  final res = await ApiService.updateProfile(newName);
                  if (res['success'] && context.mounted) {
                    Navigator.pop(context, true);
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (updated == true && mounted) {
      _fetchProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama profil berhasil diperbarui di server.'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  Future<void> _handleChangeSkinType() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const SkinTypeScreen(isEditMode: true),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _skinType = result;
      });
    }
  }

  Future<void> _handleChangeDevice() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const DevicePairingScreen(isEditMode: true),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _deviceName = result;
      });
    }
  }

  Future<void> _resetOnboarding() async {
    await ApiService.setOnboardingCompleted(false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Status setup awal direset. Saat login berikutnya, onboarding akan dimulai kembali.'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchProfile,
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 20),
                _buildProfileCard(isDark),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        '$_activeDays',
                        'Hari Aktif',
                        isDark ? Colors.white : AppTheme.textDark,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        '$_protectionScore%',
                        'Skor Proteksi',
                        const Color(0xFF00B074),
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        '$_alertCount',
                        'Peringatan',
                        isDark ? Colors.white : AppTheme.textDark,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bagian Perangkat Saya (Sesuai mockup)
                Text(
                  'Perangkat Saya',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMyDeviceCard(isDark),

                const SizedBox(height: 24),

                // Bagian Tipe Kulit (Sesuai permintaan)
                Text(
                  'Tipe Kulit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSkinTypeCard(isDark),

                const SizedBox(height: 24),

                // Bagian Pengaturan Tampilan & Tema
                Text(
                  'Pengaturan Tampilan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _buildThemeSettingsCard(isDark),

                const SizedBox(height: 24),

                // Bagian Mode Demo Sistem & Simulator
                Text(
                  'Mode Demo Sistem',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDemoModeCard(isDark),

                const SizedBox(height: 20),

                // Tombol Keluar (Sesuai mockup)
                _buildLogoutButton(isDark),

                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: _resetOnboarding,
                    icon: const Icon(Icons.restart_alt, size: 14, color: AppTheme.textLight),
                    label: const Text(
                      'Reset Setup Awal',
                      style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header bersih: Teks 'Profil' di tengah tanpa tombol duplikat di kanan atas
  Widget _buildHeader(bool isDark) {
    return Center(
      child: Text(
        'Profil',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppTheme.textDark,
        ),
      ),
    );
  }

  /// Card Profil pengguna (Sesuai mockup Image 0)
  Widget _buildProfileCard(bool isDark) {
    String name = _userProfile?['name'] ?? 'Budi Santoso';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFD1FAE5),
            child: const Icon(Icons.person, size: 38, color: AppTheme.primary),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _showEditProfileDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'Edit Profil',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color valueColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Card Tipe Kulit (Ringkas tanpa paragraf penjelasan panjang)
  Widget _buildSkinTypeCard(bool isDark) {
    const skinMeta = {
      'Tipe I': {'desc': 'Sangat terang · selalu terbakar', 'color': Color(0xFFF1D4B3), 'spf': 'SPF 50+'},
      'Tipe II': {'desc': 'Terang · mudah terbakar', 'color': Color(0xFFDFAB87), 'spf': 'SPF 50'},
      'Tipe III': {'desc': 'Sedang · kadang terbakar', 'color': Color(0xFFC78B60), 'spf': 'SPF 30-50'},
      'Tipe IV': {'desc': 'Sawo matang · jarang terbakar', 'color': Color(0xFFA56637), 'spf': 'SPF 30+'},
      'Tipe V': {'desc': 'Cokelat · sangat jarang terbakar', 'color': Color(0xFF703D1A), 'spf': 'SPF 30'},
      'Tipe VI': {'desc': 'Gelap · hampir tidak terbakar', 'color': Color(0xFF3B1E0D), 'spf': 'SPF 30'},
    };

    final meta = skinMeta[_skinType] ?? skinMeta['Tipe IV']!;
    final Color skinColor = meta['color'] as Color;
    final String skinDesc = meta['desc'] as String;
    final String spfRec = (meta['spf'] as String?) ?? 'SPF 30+';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: skinColor.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wb_sunny_outlined, color: skinColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _skinType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      skinDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _handleChangeSkinType,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                child: const Text('Ubah'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rekomendasi Sunscreen: $spfRec',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card Perangkat Saya (Persis sesuai gambar Image 0)
  Widget _buildMyDeviceCard(bool isDark) {
    final bool isBleActive = _ble.isActive;
    final int battery = isBleActive ? _ble.batteryPercentage : 68;
    final isConnected = _ble.isActive;

    return InkWell(
      onTap: _handleChangeDevice,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132D27) : const Color(0xFFE8F8F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stay_current_portrait_outlined, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _deviceName.isNotEmpty ? _deviceName : 'Klimo Wearth Gen 1',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.battery_std_rounded,
                        color: AppTheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$battery%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sinkron 2 mnt lalu',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected
                    ? (isDark ? const Color(0xFF132D27) : const Color(0xFFE8F8F0))
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                isConnected ? 'Terhubung' : 'Terputus',
                style: TextStyle(
                  color: isConnected ? const Color(0xFF00B074) : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card Pilihan Tema (3 Pilihan: Terang, Gelap, Sistem)
  Widget _buildThemeSettingsCard(bool isDark) {
    final currentThemeMode = AppTheme.themeModeNotifier.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema Aplikasi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sesuaikan tampilan visual aplikasi',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildThemeOption(
                  label: 'Terang',
                  mode: ThemeMode.light,
                  icon: Icons.light_mode_outlined,
                  isSelected: currentThemeMode == ThemeMode.light,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThemeOption(
                  label: 'Gelap',
                  mode: ThemeMode.dark,
                  icon: Icons.dark_mode_outlined,
                  isSelected: currentThemeMode == ThemeMode.dark,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThemeOption(
                  label: 'Sistem',
                  mode: ThemeMode.system,
                  icon: Icons.brightness_auto_outlined,
                  isSelected: currentThemeMode == ThemeMode.system,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String label,
    required ThemeMode mode,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () async {
        await AppTheme.setTheme(mode);
        if (mounted) setState(() {});
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? const Color(0xFF101B2B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? AppTheme.darkCardBorder : AppTheme.greyLight),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primary
                    : (isDark ? Colors.white : AppTheme.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoModeCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isDemoMode
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isDemoMode ? Icons.science_outlined : Icons.bluetooth_searching,
                      color: _isDemoMode ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Simulasi Lingkungan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isDemoMode ? 'Aktif (Data demo)' : 'Nonaktif (Data asli)',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isDemoMode ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                          fontWeight: _isDemoMode ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch.adaptive(
                value: _isDemoMode,
                onChanged: _toggleDemoMode,
                activeTrackColor: AppTheme.primary,
                activeThumbColor: Colors.white,
              ),
            ],
          ),
          if (_isDemoMode) ...[
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 14),
            Text(
              'Pilih Skenario Cuaca Simulasi:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            ..._buildSimOptions(isDark),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSimOptions(bool isDark) {
    final options = [
      (
        BleSimMode.auto,
        'Otomatis (Fluktuatif)',
        'UV 1.5–7.5 · Suhu 27–34°C · Gas 45–180',
        AppTheme.primary,
        Icons.autorenew_rounded,
      ),
      (
        BleSimMode.normal,
        'Normal / Sejuk',
        'UV 1.2–2.5 · Suhu 26–28°C · Gas 40–85',
        const Color(0xFF10B981),
        Icons.wb_sunny_outlined,
      ),
      (
        BleSimMode.uvExtreme,
        'Panas Ekstrem',
        'UV 9.8–11.6 · Suhu 36–39°C · Gas 105–155',
        const Color(0xFFEF4444),
        Icons.warning_amber_rounded,
      ),
      (
        BleSimMode.pollution,
        'Polusi Udara',
        'UV 2.5–3.8 · Suhu 29–32°C · Gas 395–475',
        const Color(0xFFF59E0B),
        Icons.air_rounded,
      ),
    ];

    return options.map((opt) {
      final (mode, title, desc, color, icon) = opt;
      final isSelected = _ble.currentMode == mode;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF102826) : const Color(0xFFECFDF5))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.6) : (isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            _ble.changeMode(mode);
            setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Tombol Keluar (Sesuai mockup Image 0)
  Widget _buildLogoutButton(bool isDark) {
    return InkWell(
      onTap: _handleLogout,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
          ),
        ),
        child: Row(
          children: const [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 14),
            Text(
              'Keluar',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
