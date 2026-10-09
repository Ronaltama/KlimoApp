import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool _powerSaving = true;
  List<dynamic> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    final data = await ApiService.getDevices();
    if (mounted) {
      setState(() {
        _devices = data;
        _isLoading = false;
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
              _buildHeader(isDark),
              const SizedBox(height: 20),
              _buildDeviceCard(isDark),
              const SizedBox(height: 16),
              _buildSensorStatusCard(isDark),
              const SizedBox(height: 16),
              _buildPowerSavingCard(isDark),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      Icons.thermostat_outlined,
                      'Kalibrasi suhu',
                      isDark,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kalibrasi offset sensor SHT40 berhasil disimpan (-0.2°C).'),
                            backgroundColor: AppTheme.primary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildActionButton(
                      Icons.vibration,
                      'Tes getar',
                      isDark,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sinyal haptic getar dikirim ke Klimo Wearth via Bluetooth!'),
                            backgroundColor: AppTheme.primary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildVibrationPatternCard(isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.watch, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Text(
          'Alat Klimo Wearth',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    String deviceName = _devices.isNotEmpty ? _devices.first['name'] ?? 'Klimo-A3F2' : 'Belum Ada Alat';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(24),
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
              Text(
                deviceName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, color: AppTheme.primary, size: 7),
                    SizedBox(width: 6),
                    Text(
                      'Terhubung',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.battery_std_rounded, color: AppTheme.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Baterai 68%',
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.68,
              backgroundColor: isDark ? const Color(0xFF101B2B) : AppTheme.greyLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Terakhir sinkron: 2 menit lalu',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorStatusCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status sensor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 16),
          _buildSensorRow(Icons.wb_sunny_outlined, 'UV', isDark),
          _buildSensorRow(Icons.lightbulb_outline, 'Cahaya', isDark),
          _buildSensorRow(Icons.thermostat_outlined, 'Suhu & kelembapan', isDark),
          _buildSensorRow(Icons.air, 'Gas VOC', isDark),
          _buildSensorRow(Icons.timeline, 'Accelerometer', isDark),
        ],
      ),
    );
  }

  Widget _buildSensorRow(IconData icon, String name, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                size: 20,
              ),
              const SizedBox(width: 14),
              Text(
                name,
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            children: const [
              Icon(Icons.circle, color: AppTheme.primary, size: 7),
              SizedBox(width: 6),
              Text(
                'Aktif',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPowerSavingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mode hemat daya',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          Switch(
            value: _powerSaving,
            onChanged: (val) {
              setState(() {
                _powerSaving = val;
              });
            },
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, bool isDark, {VoidCallback? onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        foregroundColor: AppTheme.primary,
        backgroundColor: isDark ? AppTheme.darkCard : Colors.transparent,
        side: const BorderSide(color: AppTheme.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: Icon(icon, size: 18, color: AppTheme.primary),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildVibrationPatternCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFDCFCE7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pola getar',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              _buildPatternLegend(AppTheme.primary, 'UV: 2 pendek', isDark),
              _buildPatternLegend(
                isDark ? AppTheme.darkTextSecondary : const Color(0xFFF59E0B),
                'Panas: 1 panjang',
                isDark,
              ),
              _buildPatternLegend(
                isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                'Udara: 3 pendek',
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatternLegend(Color dotColor, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: dotColor, size: 7),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
