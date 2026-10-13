import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'setup/device_pairing_screen.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool _powerSaving = true;
  List<dynamic> _devices = [];
  Map<String, dynamic>? _latestTelemetry;
  String _savedDeviceName = 'Klimo Wearth C3-4A1B';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDeviceData();
  }

  Future<void> _fetchDeviceData() async {
    setState(() {
      _isLoading = true;
    });

    final devicesData = await ApiService.getDevices();
    final savedName = await ApiService.getConnectedDevice();
    final latestTel = await ApiService.getLatestTelemetry();

    if (!mounted) return;

    setState(() {
      _devices = devicesData;
      _savedDeviceName = savedName;
      _latestTelemetry = latestTel;
      _isLoading = false;
    });
  }

  String _getSyncTimeText() {
    if (_latestTelemetry == null || _latestTelemetry!['created_at'] == null) {
      return 'Terakhir sinkron: Baru saja';
    }
    try {
      final dt = DateTime.parse(_latestTelemetry!['created_at'].toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 10) return 'Terakhir sinkron: Baru saja';
      if (diff.inSeconds < 60) return 'Terakhir sinkron: ${diff.inSeconds} detik lalu';
      if (diff.inMinutes < 60) return 'Terakhir sinkron: ${diff.inMinutes} menit lalu';
      return 'Terakhir sinkron: ${diff.inHours} jam lalu';
    } catch (_) {
      return 'Terakhir sinkron: Aktif via BLE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchDeviceData,
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 20),
                _buildDeviceCard(isDark),
                const SizedBox(height: 16),
                _buildHardwareSpecsCard(isDark),
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
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alat Klimo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Text(
                  'Kelola alat Klimo kamu',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        InkWell(
          onTap: _isLoading ? null : _fetchDeviceData,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                _isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : const Icon(Icons.refresh, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Perbarui',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(bool isDark) {
    if (_isLoading) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.card,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    // Nama perangkat diprioritaskan dari device yang tersimpan atau API
    String deviceDisplayName = _savedDeviceName;
    if (_devices.isNotEmpty && _devices.first['name'] != null) {
      deviceDisplayName = _devices.first['name'];
    }

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceDisplayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Klimo Wearth Gen 1',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                      ),
                    ),
                  ],
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
                'Baterai 85%',
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· Sisa ~14 jam',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.85,
              backgroundColor: isDark ? const Color(0xFF101B2B) : AppTheme.greyLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getSyncTimeText(),
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  fontSize: 12,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final newDevice = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DevicePairingScreen(isEditMode: true),
                    ),
                  );
                  if (newDevice != null && mounted) {
                    _fetchDeviceData();
                  }
                },
                child: const Text(
                  'Sambungkan Baru',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareSpecsCard(bool isDark) {
    String macAddress = '00:1B:44:11:3A:B7';
    if (_devices.isNotEmpty && _devices.first['mac_address'] != null) {
      macAddress = _devices.first['mac_address'];
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
            children: [
              const Icon(Icons.memory, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Info Perangkat',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSpecRow('ID Perangkat', macAddress, isDark),
          _buildSpecRow('Versi Firmware', 'v1.2.0', isDark),
          _buildSpecRow('Koneksi', 'Bluetooth & WiFi', isDark),
          _buildSpecRow('Chip', 'ESP32-C3 RISC-V', isDark),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
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
            'Status Sensor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 14),
          _buildSensorRow(Icons.wb_sunny_outlined, 'Sinar UV', isDark),
          _buildSensorRow(Icons.lightbulb_outline, 'Cahaya', isDark),
          _buildSensorRow(Icons.thermostat_outlined, 'Suhu & Kelembapan', isDark),
          _buildSensorRow(Icons.air, 'Kualitas Udara', isDark),
          _buildSensorRow(Icons.timeline, 'Gerakan', isDark),
        ],
      ),
    );
  }

  Widget _buildSensorRow(IconData icon, String name, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
                  fontSize: 13,
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
                  fontSize: 12,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mode hemat daya',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _powerSaving ? 'Baterai lebih awet, data tiap 10 detik' : 'Performa penuh, data tiap 2 detik',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                ),
              ),
            ],
          ),
          Switch(
            value: _powerSaving,
            onChanged: (val) {
              setState(() {
                _powerSaving = val;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    val
                        ? 'Mode hemat daya aktif. Interval transmisi 10 detik.'
                        : 'Mode performa tinggi aktif. Interval transmisi 2 detik.',
                  ),
                  duration: const Duration(milliseconds: 1500),
                ),
              );
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
            'Arti pola getar',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Alat akan bergetar sesuai jenis peringatan',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              _buildPatternLegend(AppTheme.primary, 'UV tinggi → 2× getar pendek', isDark),
              _buildPatternLegend(
                isDark ? AppTheme.darkTextSecondary : const Color(0xFFF59E0B),
                'Terlalu panas → 1× getar panjang',
                isDark,
              ),
              _buildPatternLegend(
                isDark ? AppTheme.darkTextSecondary : const Color(0xFFEF4444),
                'Udara buruk → 3× getar pendek',
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
