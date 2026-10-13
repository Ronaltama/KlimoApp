import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class DevicePairingScreen extends StatelessWidget {
  final bool isEditMode;
  const DevicePairingScreen({super.key, this.isEditMode = false});

  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppTheme.textDark;
    final subColor = isDark ? AppTheme.darkTextSecondary : AppTheme.textLight;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 26, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditMode ? 'Sambungkan Alat' : 'Langkah 2 dari 3',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _statusPill(isDark, 'Bluetooth aktif')),
          ),
        ],
        bottom: isEditMode
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: 0.5,
                  minHeight: 4,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : AppTheme.greyLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kartu identitas alat
            _card(
              isDark: isDark,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight,
                      ),
                    ),
                    child: const Icon(Icons.watch_outlined, color: AppTheme.primary, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Klimo Wearth',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Alat pintar UV & Polusi',
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'Nyalakan alatmu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tahan tombol 3 detik sampai lampu berkedip biru.',
              style: TextStyle(fontSize: 14, color: subColor),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Text(
                  'Alat terdekat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const Spacer(),
                _statusPill(isDark, 'Mencari...', color: _amber),
              ],
            ),
            const SizedBox(height: 12),

            _deviceCard(
              context: context,
              isDark: isDark,
              name: 'Klimo-A3F2',
              signal: 'Sinyal kuat',
              signalColor: AppTheme.primary,
            ),
            const SizedBox(height: 10),
            _deviceCard(
              context: context,
              isDark: isDark,
              name: 'Klimo-7B10',
              signal: 'Sinyal sedang',
              signalColor: _amber,
            ),
            const SizedBox(height: 14),

            // Status izin
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                _permission(isDark, 'Bluetooth', granted: true),
                Text('·', style: TextStyle(color: subColor)),
                _permission(isDark, 'Lokasi', granted: true),
                Text('·', style: TextStyle(color: subColor)),
                _permission(isDark, 'Notifikasi', granted: false),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Tidak ketemu? ', style: TextStyle(fontSize: 13, color: subColor)),
                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Memindai ulang perangkat Bluetooth di sekitar...'),
                        duration: Duration(seconds: 2),
                      ),
                    ),
                    child: const Text(
                      'Coba lagi',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => _finish(context, null),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark ? AppTheme.darkCardBorder : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isEditMode ? 'Batal' : 'Lewati dulu (tanpa alat)',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

  // ---------- Navigasi ----------

  void _finish(BuildContext context, String? deviceName) {
    if (isEditMode && Navigator.canPop(context)) {
      Navigator.pop(context, deviceName);
    } else {
      Navigator.pushReplacementNamed(context, '/skin_type');
    }
  }

  Future<void> _connect(BuildContext context, String name) async {
    await ApiService.saveConnectedDevice(name);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Terhubung ke $name via BLE!'),
        backgroundColor: AppTheme.primary,
        duration: const Duration(milliseconds: 1500),
      ),
    );
    _finish(context, name);
  }

  // ---------- Komponen ----------

  Widget _card({
    required bool isDark,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _deviceCard({
    required BuildContext context,
    required bool isDark,
    required String name,
    required String signal,
    required Color signalColor,

  }) {
    return _card(
      isDark: isDark,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  signal,
                  style: TextStyle(fontSize: 12, color: signalColor),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: () => _connect(context, name),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(110, 38),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Hubungkan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(bool isDark, String label, {Color color = AppTheme.primary}) {
    final bg = color == AppTheme.primary
        ? (isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5))
        : (isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.15));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color == AppTheme.primary)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _permission(bool isDark, String label, {required bool granted}) {
    final color = isDark ? AppTheme.darkTextSecondary : AppTheme.textLight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: color)),
        const SizedBox(width: 4),
        granted
            ? const Icon(Icons.check, size: 14, color: AppTheme.primary)
            : Icon(Icons.radio_button_unchecked, size: 12, color: color),
      ],
    );
  }
}