import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/ble_simulator_service.dart';
import 'setup/device_pairing_screen.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool _powerSaving = false;
  List<dynamic> _devices = [];
  String _savedDeviceName = 'Klimo-A3F2';
  double _tempOffset = 0.0;
  bool _showTechSpecs = false;

  final _ble = BleSimulatorService();
  BleConnectionStatus _bleStatus = BleConnectionStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _bleStatus = _ble.status;
    _powerSaving = _ble.intervalSeconds >= 10;
    _loadTempOffset();
    _fetchDeviceData();

    // Subscribe ke status BLE
    _ble.statusStream.listen((s) {
      if (mounted) setState(() => _bleStatus = s);
    });
    // Subscribe ke data record agar nilai sensor live di halaman alat reaktif
    _ble.recordStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadTempOffset() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _tempOffset = prefs.getDouble('temp_offset') ?? 0.0;
      });
    }
  }

  Future<void> _saveTempOffset(double offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('temp_offset', offset);
    if (mounted) {
      setState(() {
        _tempOffset = offset;
      });
    }
  }

  Future<void> _fetchDeviceData() async {
    try {
      final devicesData = await ApiService.getDevices();
      final savedName = await ApiService.getConnectedDevice();

      if (!mounted) return;

      setState(() {
        _devices = devicesData;
        if (savedName.isNotEmpty) {
          _savedDeviceName = savedName;
        }
      });
    } catch (_) {}
  }

  void _testVibration() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.vibration, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Tes getaran terkirim ke gelang'),
          ],
        ),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          onRefresh: _fetchDeviceData,
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 18),
                _buildDeviceCard(isDark),
                const SizedBox(height: 16),
                _buildSensorStatusCard(isDark),
                const SizedBox(height: 16),
                _buildPowerSavingCard(isDark),
                const SizedBox(height: 16),
                _buildActionButtons(isDark),
                const SizedBox(height: 16),
                _buildVibrationPatternCard(isDark),
                const SizedBox(height: 16),
                _buildHardwareSpecsCard(isDark),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header bersih: Ikon Jam Hijau + 'Alat Klimo Wearth'
  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132D27) : const Color(0xFFE8F8F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.watch_outlined, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Text(
          'Alat Klimo Wearth',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  /// Card Perangkat (Klimo-A3F2, Baterai %, Progress Bar, Terakhir sinkron)
  Widget _buildDeviceCard(bool isDark) {
    final isConnected = _bleStatus == BleConnectionStatus.connected ||
        _bleStatus == BleConnectionStatus.simulating;

    // Nama perangkat: jika BLE fisik asli terhubung, pakai nama asli. Jika simulasi, pakai Klimo-A3F2
    String deviceDisplayName;
    if (_bleStatus == BleConnectionStatus.connected) {
      deviceDisplayName = _savedDeviceName;
      if (_devices.isNotEmpty && _devices.first['name'] != null) {
        deviceDisplayName = _devices.first['name'];
      }
    } else {
      deviceDisplayName = 'Klimo-A3F2';
    }

    final int batteryLevel = _ble.isActive ? _ble.batteryPercentage : 0;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                deviceDisplayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppTheme.textDark,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isConnected ? const Color(0xFF00B074) : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Terhubung' : 'Terputus',
                      style: TextStyle(
                        color: isConnected
                            ? const Color(0xFF00B074)
                            : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.battery_std_rounded,
                color: AppTheme.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Baterai $batteryLevel%',
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (batteryLevel / 100.0).clamp(0.0, 1.0),
              backgroundColor: isDark ? const Color(0xFF101B2B) : const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isConnected ? 'Terakhir sinkron: Baru saja' : 'Perangkat belum tersambung',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            ),
          ),
          if (!isConnected) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/pairing');
                },
                icon: const Icon(Icons.bluetooth_searching, size: 16),
                label: const Text('Sambungkan Alat Fisik'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Card Status Sensor (UV, Cahaya, Suhu & kelembapan, Gas VOC, Accelerometer -> • Aktif)
  Widget _buildSensorStatusCard(bool isDark) {
    final isOnline = _ble.isActive;

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
          Text(
            'Status sensor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 14),
          _buildSensorLine(Icons.wb_sunny_outlined, 'UV', isOnline, isDark),
          _buildSensorLine(Icons.lightbulb_outline, 'Cahaya', isOnline, isDark),
          _buildSensorLine(Icons.thermostat_outlined, 'Suhu & kelembapan', isOnline, isDark),
          _buildSensorLine(Icons.air, 'Gas VOC', isOnline, isDark),
          _buildSensorLine(Icons.show_chart, 'Accelerometer', isOnline, isDark),
        ],
      ),
    );
  }

  Widget _buildSensorLine(IconData icon, String name, bool isOnline, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              ),
              const SizedBox(width: 12),
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF00B074) : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Aktif' : 'Nonaktif',
                style: TextStyle(
                  color: isOnline
                      ? const Color(0xFF00B074)
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card Mode Hemat Daya (Clean Row + Switch)
  Widget _buildPowerSavingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(20),
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
              fontSize: 14,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          Switch.adaptive(
            value: _powerSaving,
            onChanged: (val) {
              setState(() {
                _powerSaving = val;
              });
              _ble.setInterval(val ? 15 : 3);
            },
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  /// 2 Tombol Aksi: Kalibrasi suhu & Tes getar
  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showCalibrationDialog(context, isDark),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              backgroundColor: isDark ? AppTheme.darkCard : Colors.transparent,
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.tune, size: 16, color: AppTheme.primary),
            label: const Text(
              'Kalibrasi suhu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _testVibration,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              backgroundColor: isDark ? AppTheme.darkCard : Colors.transparent,
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.vibration, size: 16, color: AppTheme.primary),
            label: const Text(
              'Tes getar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  /// Card Pola Getar (Mint Green Banner)
  Widget _buildVibrationPatternCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132D27) : const Color(0xFFE8F8F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1A453B) : const Color(0xFFC7EBD9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pola getar',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildBulletItem(const Color(0xFF00B074), 'UV: 2 pendek', isDark),
              const SizedBox(width: 8),
              Text(
                '·',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              _buildBulletItem(const Color(0xFFF59E0B), 'Panas: 1 panjang', isDark),
            ],
          ),
          const SizedBox(height: 6),
          _buildBulletItem(const Color(0xFF00B074), 'Udara: 3 pendek', isDark),
        ],
      ),
    );
  }

  Widget _buildBulletItem(Color bulletColor, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: bulletColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  /// Card Info Perangkat (Dapat dilipat/expand)
  Widget _buildHardwareSpecsCard(bool isDark) {
    String macAddress = _devices.isNotEmpty && _devices.first['mac_address'] != null
        ? _devices.first['mac_address']
        : (_ble.isActive ? '00:1B:44:11:3A:B7' : '-');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showTechSpecs = !_showTechSpecs;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Info Perangkat',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showTechSpecs ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  size: 20,
                ),
              ],
            ),
          ),
          if (_showTechSpecs) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight),
            const SizedBox(height: 10),
            _buildSpecRow('ID Perangkat', macAddress, isDark),
            _buildSpecRow('Versi Firmware', 'v1.2.0 (PlatformIO / ESP-IDF)', isDark),
            _buildSpecRow('Koneksi', 'BLE 5.0 GATT', isDark),
            _buildSpecRow('Chip', 'ESP32-C3 RISC-V', isDark),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () async {
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
                  'Sambungkan Perangkat Baru',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  void _showCalibrationDialog(BuildContext context, bool isDark) {
    double selectedOffset = _tempOffset;
    final currentRaw = _ble.lastRecord?.temperature ?? 27.5;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final adjusted = currentRaw + selectedOffset;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kalibrasi Suhu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sesuaikan kompensasi suhu tubuh pergelangan tangan.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Suhu Sensor',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${currentRaw.toStringAsFixed(1)}°C',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward, color: AppTheme.primary, size: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Setelah Kalibrasi',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${adjusted.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Offset Kalibrasi:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [-1.0, -0.5, -0.2, 0.0, 0.2, 0.5].map((offset) {
                    final isSelected = (selectedOffset - offset).abs() < 0.01;
                    return ChoiceChip(
                      label: Text(
                        offset == 0.0 ? '0.0°C (Default)' : '${offset > 0 ? "+" : ""}${offset.toStringAsFixed(1)}°C',
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.primary : (isDark ? Colors.white70 : AppTheme.textDark),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setSheetState(() => selectedOffset = offset);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _saveTempOffset(selectedOffset);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Offset kalibrasi suhu disimpan (${selectedOffset >= 0 ? "+" : ""}${selectedOffset.toStringAsFixed(1)}°C).',
                          ),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Terapkan Kalibrasi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
