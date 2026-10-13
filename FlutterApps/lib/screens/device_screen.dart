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
  bool _showTechSpecs = false; // Informasi teknis hardware dapat dilipat

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
                _buildSensorStatusCard(isDark),
                const SizedBox(height: 16),
                _buildPowerSavingCard(isDark),
                const SizedBox(height: 16),
                _buildVibrationPatternCard(isDark),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        Icons.thermostat_outlined,
                        'Kalibrasi Suhu Tubuh',
                        isDark,
                        onTap: () => _showCalibrationDialog(context, isDark),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildActionButton(
                        Icons.vibration,
                        'Tes Getar Gelang',
                        isDark,
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          if (_ble.isActive) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sinyal getar alarm terkirim ke $_savedDeviceName!'),
                                backgroundColor: AppTheme.primary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Alat tidak terhubung. Menguji getaran motor ponsel.'),
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
                _buildHardwareSpecsCard(isDark),
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

    Color statusBg;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_bleStatus) {
      case BleConnectionStatus.connected:
        statusBg = isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5);
        statusColor = AppTheme.primary;
        statusText = 'Gelang Terhubung';
        statusIcon = Icons.bluetooth_connected;
        break;
      case BleConnectionStatus.simulating:
        statusBg = isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5);
        statusColor = AppTheme.primary;
        statusText = 'Simulasi Virtual Aktif';
        statusIcon = Icons.computer;
        break;
      case BleConnectionStatus.scanning:
        statusBg = isDark ? const Color(0xFF332313) : const Color(0xFFFEF3C7);
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Memindai Perangkat...';
        statusIcon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.disconnected:
        statusBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        statusColor = isDark ? AppTheme.darkTextSecondary : AppTheme.textLight;
        statusText = 'Belum Terhubung';
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
          if (_bleStatus == BleConnectionStatus.simulating) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aplikasi sedang menampilkan data simulasi virtual. Anda dapat mematikan Mode Demo di menu Profil jika ingin menyambungkan gelang fisik via Bluetooth.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textDark,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHardwareSpecsCard(bool isDark) {
    String macAddress = _devices.isNotEmpty && _devices.first['mac_address'] != null
        ? _devices.first['mac_address']
        : (_ble.isActive ? '00:1B:44:11:3A:B7' : '-');

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
                    const Icon(Icons.tune, color: AppTheme.primary, size: 18),
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
            const SizedBox(height: 14),
            Divider(height: 1, color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight),
            const SizedBox(height: 10),
            _buildSpecRow('ID Perangkat', macAddress, isDark),
            _buildSpecRow('Versi Firmware', 'v1.2.0 (PlatformIO / ESP-IDF)', isDark),
            _buildSpecRow('Koneksi', 'BLE 5.0 GATT & WiFi 2.4GHz', isDark),
            _buildSpecRow('Chip', 'Espressif ESP32-C3 RISC-V 160MHz', isDark),
          ],
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

  Widget _buildSensorStatusCard(bool isDark) {
    final record = _ble.lastRecord;
    final isOnline = _ble.isActive && record != null;

    final uvStatus = isOnline ? '${record.uvIndex.toStringAsFixed(1)} UVI' : 'Offline';
    final tempStatus = isOnline
        ? '${(record.temperature + _tempOffset).toStringAsFixed(1)}°C / ${record.humidity.toStringAsFixed(0)}%'
        : 'Offline';
    final vocStatus = isOnline ? '${record.voc} VOC' : 'Offline';

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
              Row(
                children: [
                  const Icon(Icons.sensors, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Status Sensor',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ],
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
                  isOnline ? 'Terhubung & Aktif' : 'Sensor Mati',
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
          _buildSensorRow(
            icon: Icons.wb_sunny_outlined,
            name: 'Sinar UV',
            desc: 'Mengukur sengatan sinar matahari langsung',
            statusText: uvStatus,
            isOnline: isOnline,
            isDark: isDark,
          ),
          _buildSensorRow(
            icon: Icons.thermostat_outlined,
            name: 'Suhu & Kelembapan',
            desc: 'Mengukur panas sekitar & kelembapan udara',
            statusText: tempStatus,
            isOnline: isOnline,
            isDark: isDark,
          ),
          _buildSensorRow(
            icon: Icons.air,
            name: 'Kualitas Udara',
            desc: 'Mendeteksi polusi & senyawa gas berbahaya',
            statusText: vocStatus,
            isOnline: isOnline,
            isDark: isDark,
          ),
          _buildSensorRow(
            icon: Icons.vibration,
            name: 'Alarm Getar',
            desc: 'Alarm fisik saat bahaya cuaca terdeteksi',
            statusText: isOnline ? 'Siaga Bergetar' : 'Offline',
            isOnline: isOnline,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF101B2B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sensor bekerja terus-menerus dan otomatis memberi getaran jika parameter lingkungan melewati batas aman.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
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

  Widget _buildSensorRow({
    required IconData icon,
    required String name,
    required String desc,
    required String statusText,
    required bool isOnline,
    required bool isDark,
  }) {
    final statusColor = isOnline ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isOnline ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        desc,
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerSavingCard(bool isDark) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _powerSaving
                            ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _powerSaving ? Icons.battery_saver : Icons.battery_charging_full,
                        color: _powerSaving ? const Color(0xFF10B981) : AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Hemat Baterai Gelang',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _powerSaving
                                ? 'Aktif: Baterai awet hingga 24+ jam'
                                : 'Nonaktif: Pembaruan data cepat & responsif',
                            style: TextStyle(
                              fontSize: 11,
                              color: _powerSaving ? const Color(0xFF10B981) : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                              fontWeight: _powerSaving ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _powerSaving,
                onChanged: (val) {
                  setState(() {
                    _powerSaving = val;
                  });
                  _ble.setInterval(val ? 15 : 3);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? 'Mode hemat daya aktif. Sensor membaca tiap 15 detik untuk menghemat baterai gelang.'
                            : 'Mode responsif aktif. Sensor membaca tiap 3 detik untuk data real-time.',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                activeThumbColor: Colors.white,
                activeTrackColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF101B2B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _powerSaving
                        ? 'Pengiriman data diatur tiap 15 detik. Cocok saat Anda beraktivitas seharian di luar tanpa charger.'
                        : 'Pengiriman data diatur tiap 3 detik. Cocok saat pemantauan intensif di kondisi cuaca ekstrem.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                      height: 1.35,
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
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vibration, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Arti Pola Getar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Alat akan bergetar sesuai jenis peringatan:',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 16),
          _buildVibrationItem(
            icon: Icons.wb_sunny_outlined,
            iconColor: const Color(0xFFF59E0B),
            condition: 'Sinar UV Ekstrem',
            pattern: '2x Getaran Pendek',
            advice: 'Gunakan tabir surya & topi',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildVibrationItem(
            icon: Icons.thermostat_outlined,
            iconColor: const Color(0xFFEF4444),
            condition: 'Suhu Panas Berlebih',
            pattern: '1x Getaran Panjang',
            advice: 'Segera berteduh & minum air',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildVibrationItem(
            icon: Icons.air,
            iconColor: const Color(0xFF3B82F6),
            condition: 'Polusi Gas Berbahaya',
            pattern: '3x Getaran Pendek',
            advice: 'Gunakan masker pelindung',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildVibrationItem({
    required IconData icon,
    required Color iconColor,
    required String condition,
    required String pattern,
    required String advice,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  condition,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Text(
                  'Tindakan: $advice',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pattern,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
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
