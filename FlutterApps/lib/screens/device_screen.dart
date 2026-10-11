import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/ble_simulator_service.dart';
import '../services/local_data_service.dart';
import '../services/sync_manager.dart';
import 'setup/device_pairing_screen.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool _powerSaving = false;
  List<dynamic> _devices = [];
  String _savedDeviceName = 'Klimo Wearth C3-4A1B';
  bool _isLoading = true;
  double _tempOffset = 0.0;

  final _ble = BleSimulatorService();
  final _sync = SyncManager();
  BleConnectionStatus _bleStatus = BleConnectionStatus.disconnected;
  int _pendingSync = 0;
  int _localRecordCount = 0;

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
    _sync.pendingCountStream.listen((c) {
      if (mounted) setState(() => _pendingSync = c);
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
    setState(() => _isLoading = true);

    final devicesData = await ApiService.getDevices();
    final savedName = await ApiService.getConnectedDevice();
    final history = await LocalDataService.getHistory(limit: 1000);
    final pendingCount = await LocalDataService.countPendingSync();

    if (!mounted) return;

    setState(() {
      _devices = devicesData;
      _savedDeviceName = savedName;
      _localRecordCount = history.length;
      _pendingSync = pendingCount;
      _isLoading = false;
    });
  }

  String _getSyncTimeText() {
    // Tampilkan status BLE + sinkronisasi lokal
    switch (_bleStatus) {
      case BleConnectionStatus.simulating:
        return 'Simulator BLE Aktif • $_pendingSync data pending sync';
      case BleConnectionStatus.connected:
        return 'BLE Tersambung • $_pendingSync data pending sync';
      case BleConnectionStatus.scanning:
        return 'Sedang mencari perangkat BLE...';
      case BleConnectionStatus.disconnected:
        if (_localRecordCount > 0) {
          return '$_localRecordCount data tersimpan lokal • $_pendingSync belum tersinkron';
        }
        return 'Perangkat tidak tersambung';
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
                        onTap: () => _showCalibrationDialog(context, isDark),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildActionButton(
                        Icons.vibration,
                        'Tes getar',
                        isDark,
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          if (_ble.isActive) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sinyal getar haptic terkirim ke $_savedDeviceName via BLE!'),
                                backgroundColor: AppTheme.primary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Alat tidak terhubung. Menguji getaran haptic motor ponsel.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
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
                  'Manajemen perangkat wearable',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        InkWell(
          onTap: _isLoading
              ? null
              : () async {
                  await SyncManager().syncNow();
                  await _fetchDeviceData();
                },
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
                  'Sinkron',
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

    Color statusBg;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_bleStatus) {
      case BleConnectionStatus.connected:
        statusBg = isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5);
        statusColor = AppTheme.primary;
        statusText = 'BLE Terhubung';
        statusIcon = Icons.bluetooth_connected;
        break;
      case BleConnectionStatus.simulating:
        statusBg = isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5);
        statusColor = AppTheme.primary;
        statusText = 'Simulator Aktif';
        statusIcon = Icons.check_circle;
        break;
      case BleConnectionStatus.scanning:
        statusBg = isDark ? const Color(0xFF332313) : const Color(0xFFFEF3C7);
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Memindai...';
        statusIcon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.disconnected:
        statusBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        statusColor = isDark ? AppTheme.darkTextSecondary : AppTheme.textLight;
        statusText = 'Terputus';
        statusIcon = Icons.bluetooth_disabled;
        break;
    }

    final int batteryLevel = _ble.isActive ? _ble.batteryPercentage : 0;
    final int hoursRemaining = (batteryLevel * 0.16).round();

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
                      'ESP32-C3 RISC-V Wearable',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  if (_ble.isActive) {
                    _ble.stop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Koneksi perangkat BLE diputuskan.')),
                    );
                  } else {
                    _ble.startSimulation();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Menghubungkan ke Klimo Wearable...')),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(
                batteryLevel > 20 ? Icons.battery_std_rounded : Icons.battery_alert_rounded,
                color: batteryLevel > 20 ? AppTheme.primary : const Color(0xFFEF4444),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _ble.isActive ? 'Baterai $batteryLevel%' : 'Baterai: Tidak Terdeteksi',
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _ble.isActive ? '· Sisa ~$hoursRemaining jam' : '· Sambungkan alat',
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
              value: _ble.isActive ? (batteryLevel / 100.0) : 0.0,
              backgroundColor: isDark ? const Color(0xFF101B2B) : AppTheme.greyLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                batteryLevel > 20 ? AppTheme.primary : const Color(0xFFEF4444),
              ),
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
    String macAddress = _devices.isNotEmpty && _devices.first['mac_address'] != null
        ? _devices.first['mac_address']
        : (_ble.isActive ? '00:1B:44:11:3A:B7' : '-');

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
                'Spesifikasi Hardware',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSpecRow('MAC Address', macAddress, isDark),
          _buildSpecRow('Versi Firmware', 'v1.2.0 (PlatformIO / ESP-IDF)', isDark),
          _buildSpecRow('Konektivitas', 'BLE 5.0 GATT & WiFi 2.4GHz', isDark),
          _buildSpecRow('Mikrokontroler', 'Espressif ESP32-C3 RISC-V 160MHz', isDark),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorStatusCard(bool isDark) {
    final record = _ble.lastRecord;
    final isOnline = _ble.isActive && record != null;

    final uvText = isOnline ? 'Aktif (${record.uvIndex.toStringAsFixed(1)} UVI)' : 'Offline';
    final tempText = isOnline
        ? 'Aktif (${(record.temperature + _tempOffset).toStringAsFixed(1)}°C / ${record.humidity.toStringAsFixed(0)}%)'
        : 'Offline';
    final vocText = isOnline ? 'Aktif (${record.voc} ppm)' : 'Offline';
    final lightText = isOnline ? 'Terkalibrasi (Ambient Lux)' : 'Offline';
    final imuText = isOnline ? 'Siaga (6-Axis IMU)' : 'Offline';

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
                'Status Sensor Fisik',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.12)
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOnline ? 'Real-Time Live' : 'Sensor Mati',
                  style: TextStyle(
                    color: isOnline ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSensorRow(Icons.wb_sunny_outlined, 'Sensor UV (LTR-390 / Analog)', uvText, isOnline, isDark),
          _buildSensorRow(Icons.thermostat_outlined, 'Suhu & Kelembapan (SHT40)', tempText, isOnline, isDark),
          _buildSensorRow(Icons.air, 'Gas VOC & Udara (SGP41)', vocText, isOnline, isDark),
          _buildSensorRow(Icons.lightbulb_outline, 'Sensor Cahaya (Lux)', lightText, isOnline, isDark),
          _buildSensorRow(Icons.timeline, 'Accelerometer (Gerak Pengguna)', imuText, isOnline, isDark),
        ],
      ),
    );
  }

  Widget _buildSensorRow(IconData icon, String name, String statusText, bool isOnline, bool isDark) {
    final statusColor = isOnline ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isOnline ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                size: 18,
              ),
              const SizedBox(width: 12),
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
            children: [
              Icon(Icons.circle, color: statusColor, size: 7),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
                  fontSize: 15,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Interval pengiriman: ${_powerSaving ? "10 detik" : "3 detik"}',
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
              _ble.setInterval(val ? 10 : 3);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    val
                        ? 'Mode hemat daya aktif. Interval transmisi sensor diubah ke 10 detik.'
                        : 'Mode responsif aktif. Interval transmisi sensor diubah ke 3 detik.',
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
            'Pola Peringatan Getar (Haptic)',
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
              _buildPatternLegend(AppTheme.primary, 'UV: 2 getar pendek', isDark),
              _buildPatternLegend(
                isDark ? AppTheme.darkTextSecondary : const Color(0xFFF59E0B),
                'Panas: 1 getar panjang',
                isDark,
              ),
              _buildPatternLegend(
                isDark ? AppTheme.darkTextSecondary : const Color(0xFFEF4444),
                'Udara: 3 getar pendek',
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
                      'Kalibrasi Suhu SHT40',
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
                  'Sesuaikan offset kalibrasi untuk mengkompensasi suhu tubuh saat perangkat dipakai di pergelangan tangan.',
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
                  'Pilih Nilai Offset Kalibrasi:',
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
                            'Offset kalibrasi suhu berhasil disimpan (${selectedOffset >= 0 ? "+" : ""}${selectedOffset.toStringAsFixed(1)}°C).',
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
