import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class DevicePairingScreen extends StatelessWidget {
  final bool isEditMode;
  const DevicePairingScreen({super.key, this.isEditMode = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: 18,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditMode ? 'Sambungkan Alat' : 'Langkah 2 dari 3',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        titleSpacing: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Bluetooth aktif',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        ],
        bottom: isEditMode
            ? null
            : const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: 0.66,
                  backgroundColor: AppTheme.greyLight,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.card,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary, width: 1),
                    ),
                    child: const Icon(Icons.watch, color: AppTheme.primary, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Klimo Wearth',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Alat pintar UV & Polusi ESP32-C3',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Nyalakan alatmu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tahan tombol 3 detik sampai lampu berkedip biru.',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alat terdekat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warningBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Mencari...',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDeviceCard(context, 'Klimo-A3F2 (ESP32-C3)', 'Sinyal kuat', AppTheme.primary, isDark),
            const SizedBox(height: 12),
            _buildDeviceCard(context, 'Klimo-7B10 (Wearable)', 'Sinyal sedang', AppTheme.warning, isDark),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Izin  Bluetooth ',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    fontSize: 13,
                  ),
                ),
                const Icon(Icons.check, color: AppTheme.primary, size: 16),
                Text(
                  '  ·  Lokasi ',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    fontSize: 13,
                  ),
                ),
                const Icon(Icons.check, color: AppTheme.primary, size: 16),
                Text(
                  '  ·  Notifikasi ',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    fontSize: 13,
                  ),
                ),
                Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 16),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Tidak ketemu? ',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Memindai ulang perangkat Bluetooth di sekitar...')),
                      );
                    },
                    child: const Text(
                      'Coba lagi',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    if (isEditMode && Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/skin_type');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: isDark ? AppTheme.darkCardBorder : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEditMode ? 'Batal' : 'Lewati dulu (tanpa alat)',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, String name, String signalText, Color signalColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                signalText,
                style: TextStyle(
                  fontSize: 13,
                  color: signalColor,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.saveConnectedDevice(name);
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Terhubung ke $name via BLE!'),
                  backgroundColor: AppTheme.primary,
                  duration: const Duration(milliseconds: 1500),
                ),
              );

              if (isEditMode && Navigator.canPop(context)) {
                Navigator.pop(context, name);
              } else {
                Navigator.pushReplacementNamed(context, '/skin_type');
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Hubungkan'),
          ),
        ],
      ),
    );
  }
}
