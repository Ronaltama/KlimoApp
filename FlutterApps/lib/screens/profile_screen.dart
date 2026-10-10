import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
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
  String _deviceName = 'Klimo Wearth C3-4A1B';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
    });

    final data = await ApiService.getProfile();
    final skinType = await ApiService.getSkinType();
    final deviceName = await ApiService.getConnectedDevice();

    if (!mounted) return;

    setState(() {
      _userProfile = data;
      _skinType = skinType;
      _deviceName = deviceName;
      _isLoading = false;
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
                const SizedBox(height: 24),
                _buildProfileCard(isDark),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        '127',
                        'Hari Aktif',
                        isDark ? Colors.white : AppTheme.textDark,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        '89%',
                        'Skor Proteksi',
                        AppTheme.primary,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        '14',
                        'Peringatan',
                        isDark ? Colors.white : AppTheme.textDark,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Bagian Tipe Kulit & Proteksi
                Text(
                  'Preferensi Kulit & Proteksi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSkinTypeCard(isDark),

                const SizedBox(height: 24),
                // Bagian Perangkat Saya
                Text(
                  'Perangkat Saya',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMyDeviceCard(isDark),

                const SizedBox(height: 24),
                // Opsi Reset Onboarding (Untuk Pengujian & Evaluasi)
                Center(
                  child: TextButton.icon(
                    onPressed: _resetOnboarding,
                    icon: const Icon(Icons.restart_alt, size: 16, color: AppTheme.textLight),
                    label: const Text(
                      'Reset Status Setup Awal (Untuk Uji Coba)',
                      style: TextStyle(fontSize: 12, color: AppTheme.textLight),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _buildLogoutButton(isDark),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Text(
            'Profil Pengguna',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
        Positioned(
          right: 0,
          child: GestureDetector(
            onTap: () {
              AppTheme.toggleTheme();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    size: 15,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isDark ? 'Dark' : 'Light',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(bool isDark) {
    String name = _userProfile?['name'] ?? 'Test User';
    String email = _userProfile?['email'] ?? 'test@example.com';

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
            child: isDark
                ? const Text('🌿', style: TextStyle(fontSize: 32))
                : const Icon(Icons.person, size: 36, color: AppTheme.primary),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: AppTheme.primary, size: 16),
                    ],
                  ),
                if (!_isLoading) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showEditProfileDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    backgroundColor: isDark ? const Color(0xFF132D27) : Colors.transparent,
                    side: const BorderSide(color: AppTheme.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text(
                    'Ubah Profil',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
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

  Widget _buildSkinTypeCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFA56637).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFA56637), size: 22),
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
                    fontSize: 15,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Perhitungan ambang batas UV aktif',
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
    );
  }

  Widget _buildMyDeviceCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.watch_outlined, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _deviceName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.battery_std_rounded, color: AppTheme.primary, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      '85%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '· Aktif via BLE',
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
          TextButton(
            onPressed: _handleChangeDevice,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            child: const Text('Ganti Alat'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: TextButton.icon(
        onPressed: _handleLogout,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          foregroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        icon: const Icon(Icons.logout, size: 20),
        label: const Text(
          'Keluar dari Akun',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
