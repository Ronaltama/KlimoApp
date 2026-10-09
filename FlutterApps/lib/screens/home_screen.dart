import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import 'uv_detail_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? telemetryData;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Tarik data setiap 3 detik
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final data = await ApiService.getLatestTelemetry();
    if (data != null && mounted) {
      setState(() {
        telemetryData = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, isDark),
              const SizedBox(height: 20),
              _buildWaspadaCard(isDark),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildUVCard(context, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGasCard(isDark)),
                ],
              ),
              const SizedBox(height: 16),
              _buildWarningBanner(isDark),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildSunscreenCard(isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMinumCard(isDark)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFD1FAE5),
              child: isDark
                  ? const Text('👨🏽‍💼', style: TextStyle(fontSize: 20))
                  : const Icon(Icons.person, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HALO,',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Budi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sync,
                      size: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'SINKRON 2 MNT LALU',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.battery_std_rounded, size: 14, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text(
                      '68%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight,
                ),
              ),
              child: Icon(
                Icons.notifications_none,
                size: 20,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaspadaCard(bool isDark) {
    double temp = telemetryData?['temperature']?.toDouble() ?? 0.0;
    String statusTitle = temp > 35.0 ? 'WASPADA' : (temp > 0 ? 'AMAN' : 'MENUNGGU DATA');
    String statusDesc = temp > 35.0 ? 'Terik dan udara mulai panas. Pakai masker, cari tempat teduh.' : 'Kondisi cukup bersahabat. Tetap pantau indikator sekitar.';
    
    Color titleColor = temp > 35.0 ? (isDark ? Colors.white : const Color(0xFF78350F)) : (isDark ? Colors.white : const Color(0xFF065F46));
    Color bgColor = temp > 35.0 ? (isDark ? AppTheme.darkCard : const Color(0xFFFDE68A)) : (isDark ? AppTheme.darkCard : const Color(0xFFD1FAE5));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -15,
            right: -15,
            child: Icon(
              Icons.wb_sunny_outlined,
              size: 110,
              color: isDark
                  ? const Color(0xFF1E2D40).withValues(alpha: 0.6)
                  : (temp > 35.0 ? Colors.orange.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STATUS SEKARANG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? AppTheme.darkTextSecondary : (temp > 35.0 ? const Color(0xFF92400E) : const Color(0xFF065F46)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusTitle,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                statusDesc,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? AppTheme.darkTextSecondary : (temp > 35.0 ? const Color(0xFF92400E) : const Color(0xFF065F46)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildTag(
                    Icons.wb_sunny_outlined,
                    'UV ${telemetryData?['uv_index'] ?? '-'}',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildTag(
                    Icons.thermostat_outlined,
                    'Suhu ${telemetryData?['temperature'] ?? '-'}°C',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildTag(
                    Icons.water_drop_outlined,
                    'RH ${telemetryData?['humidity'] ?? '-'}%',
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2D) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2E42) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: isDark ? AppTheme.primary : const Color(0xFF92400E)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF92400E),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUVCard(BuildContext context, bool isDark) {
    double uv = telemetryData?['uv_index']?.toDouble() ?? 0.0;
    String uvText = uv.toStringAsFixed(1);
    
    return _buildStatusCard(
      title: 'UV · LUX',
      titleColor: isDark ? AppTheme.darkTextSecondary : AppTheme.primary,
      value: uvText,
      subtitle: uv > 7 ? 'Sangat tinggi' : (uv > 3 ? 'Sedang' : 'Rendah'),
      progressValue: (uv / 11.0).clamp(0.0, 1.0),
      progressColor: uv > 7 ? const Color(0xFFF59E0B) : AppTheme.primary,
      bottomText: 'Data Live API',
      isDark: isDark,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UVDetailScreen()),
        );
      },
    );
  }

  Widget _buildGasCard(bool isDark) {
    int voc = telemetryData?['voc'] ?? 0;
    String status = voc > 200 ? 'Bahaya' : (voc > 100 ? 'Sedang' : 'Baik');

    return _buildStatusCard(
      title: 'GAS VOC',
      titleColor: isDark ? AppTheme.darkTextSecondary : AppTheme.primary,
      value: status,
      valueSize: 28,
      subtitle: 'Indeks $voc',
      progressValue: (voc / 500.0).clamp(0.0, 1.0),
      progressColor: voc > 200 ? const Color(0xFFEF4444) : AppTheme.primary,
      bottomText: 'Data Live API',
      isDark: isDark,
    );
  }

  Widget _buildStatusCard({
    required String title,
    required Color titleColor,
    required String value,
    double valueSize = 40,
    required String subtitle,
    required double progressValue,
    required Color progressColor,
    required String bottomText,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textDark,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: isDark ? const Color(0xFF101B2B) : AppTheme.greyLight,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bottomText,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: isDark ? AppTheme.primary : const Color(0xFFD97706),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF92400E),
                  fontSize: 13,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: 'Polusi gas naik— ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF92400E),
                    ),
                  ),
                  const TextSpan(text: 'Disarankan pakai masker atau pindah sebentar.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSunscreenCard(bool isDark) {
    return _buildActionCard(
      icon: Icons.wb_sunny_outlined,
      title: 'Sunscreen',
      value: '42:10',
      subtitle: 'lagi',
      buttonText: 'Sudah oles',
      isOutlined: false,
      isDark: isDark,
    );
  }

  Widget _buildMinumCard(bool isDark) {
    return _buildActionCard(
      icon: Icons.local_drink_outlined,
      title: 'Minum',
      value: '15 mnt',
      subtitle: 'lagi',
      buttonText: 'Sudah minum',
      isOutlined: true,
      isDark: isDark,
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required String buttonText,
    required bool isOutlined,
    required bool isDark,
  }) {
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
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: isOutlined
                ? OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      backgroundColor: isDark ? AppTheme.darkCard : Colors.transparent,
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
