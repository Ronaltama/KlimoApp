import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'uv_detail_screen.dart';
import '../services/local_data_service.dart';
import '../services/ble_simulator_service.dart';
import '../services/sync_manager.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TelemetryRecord? _telemetryRecord;
  String _userName = 'Budi';
  Timer? _uiRefreshTimer;
  Timer? _countdownTicker;
  StreamSubscription<TelemetryRecord>? _bleSubscription;
  StreamSubscription<BleConnectionStatus>? _statusSubscription;

  final _ble = BleSimulatorService();
  final _sync = SyncManager();

  BleConnectionStatus _bleStatus = BleConnectionStatus.disconnected;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _pendingSync = 0;

  // State Pelindung Matahari (Sunscreen) & Hidrasi (Minum)
  DateTime? _lastSunscreenTime;
  DateTime? _lastDrinkTime;
  int _waterGlassesCount = 0;
  static const int _targetGlasses = 8;

  @override
  void initState() {
    super.initState();
    _loadSunscreenAndDrinkState();
    _initOfflineFirst();

    // Ticker periodik tiap 5 detik agar countdown timer oles sunscreen & minum terbarui otomatis
    _countdownTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _refreshData() async {
    await _sync.syncNow();
    final cached = await LocalDataService.getLatest();
    if (cached != null && mounted) {
      setState(() => _telemetryRecord = cached);
    } else {
      final cloudLatest = await ApiService.getLatestTelemetry();
      if (cloudLatest != null && mounted) {
        setState(() => _telemetryRecord = TelemetryRecord.fromMap(cloudLatest));
      }
    }
  }

  Future<void> _initOfflineFirst() async {
    // 0. Ambil nama profil pengguna jika tersedia
    ApiService.getProfile().then((p) {
      if (p != null && p['name'] != null && mounted) {
        setState(() => _userName = p['name'].toString());
      }
    });

    // 1. Tampilkan data lokal yang sudah ada (langsung dari SQLite HP)
    final cached = await LocalDataService.getLatest();
    if (cached != null && mounted) {
      setState(() => _telemetryRecord = cached);
    } else {
      // Jika SQLite lokal kosong, coba tarik telemetri terkini langsung dari Backend
      ApiService.getLatestTelemetry().then((cloudLatest) {
        if (cloudLatest != null && mounted && _telemetryRecord == null) {
          setState(() => _telemetryRecord = TelemetryRecord.fromMap(cloudLatest));
        }
      });
    }

    // 2. Subscribe ke stream BLE simulator untuk update realtime
    _bleSubscription = _ble.recordStream.listen((record) {
      if (mounted) setState(() => _telemetryRecord = record);
    });
    _statusSubscription = _ble.statusStream.listen((status) {
      if (mounted) setState(() => _bleStatus = status);
    });

    // 3. Subscribe ke SyncManager untuk status cloud sync
    _sync.statusStream.listen((s) {
      if (mounted) setState(() => _syncStatus = s);
    });
    _sync.pendingCountStream.listen((c) {
      if (mounted) setState(() => _pendingSync = c);
    });

    // 4. Inisialisasi sync manager (auto-sync tiap 30 detik jika ada internet)
    _sync.initialize();

    // 5. Periksa apakah mode demo diaktifkan dari Pengaturan Profil
    final prefs = await SharedPreferences.getInstance();
    final isDemo = prefs.getBool('demo_system_mode') ?? true;
    if (isDemo) {
      _ble.startSimulation(mode: BleSimMode.auto);
    } else {
      _ble.stop();
    }
  }

  @override
  void dispose() {
    _bleSubscription?.cancel();
    _statusSubscription?.cancel();
    _uiRefreshTimer?.cancel();
    _countdownTicker?.cancel();
    super.dispose();
  }

  // Konversi TelemetryRecord ke Map agar widget lama tetap kompatibel
  Map<String, dynamic>? get telemetryData {
    if (_telemetryRecord == null) return null;
    return {
      'uv_index': _telemetryRecord!.uvIndex,
      'temperature': _telemetryRecord!.temperature,
      'humidity': _telemetryRecord!.humidity,
      'voc': _telemetryRecord!.voc,
      'latitude': _telemetryRecord!.latitude,
      'longitude': _telemetryRecord!.longitude,
      'created_at': _telemetryRecord!.timestamp.toIso8601String(),
    };
  }

  String _getConnectionLabel() {
    switch (_bleStatus) {
      case BleConnectionStatus.simulating:
        return 'Mode Demo (Simulasi)';
      case BleConnectionStatus.connected:
        return 'Gelang Terhubung';
      case BleConnectionStatus.scanning:
        return 'Mencari Gelang...';
      case BleConnectionStatus.disconnected:
        return 'Gelang Belum Terhubung';
    }
  }

  String _getSyncText() {
    if (_telemetryRecord == null) return 'MENUNGGU DATA';
    switch (_bleStatus) {
      case BleConnectionStatus.scanning:
        return 'MENCARI...';
      case BleConnectionStatus.connected:
        return 'SENSOR LANGSUNG';
      case BleConnectionStatus.simulating:
        final diff = DateTime.now().difference(_telemetryRecord!.timestamp);
        if (diff.inSeconds < 5) return 'BARU SAJA';
        if (diff.inSeconds < 60) return '${diff.inSeconds} DTK LALU';
        if (diff.inMinutes < 60) return '${diff.inMinutes} MNT LALU';
        return '${diff.inHours} JAM LALU';
      case BleConnectionStatus.disconnected:
        return 'TERSIMPAN DI HP';
    }
  }

  Color _getSyncColor() {
    switch (_bleStatus) {
      case BleConnectionStatus.simulating:
      case BleConnectionStatus.connected:
        return AppTheme.primary;
      case BleConnectionStatus.scanning:
        return Colors.orange;
      case BleConnectionStatus.disconnected:
        return Colors.grey;
    }
  }

  IconData _getSyncIcon() {
    switch (_bleStatus) {
      case BleConnectionStatus.simulating:
      case BleConnectionStatus.connected:
        return Icons.bluetooth_connected;
      case BleConnectionStatus.scanning:
        return Icons.bluetooth_searching;
      case BleConnectionStatus.disconnected:
        return Icons.storage_outlined;
    }
  }

  Widget _buildCloudStatusBadge(bool isDark) {
    final (icon, color, text) = _getCloudStatusInfo(isDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
          ),
        ),
      ],
    );
  }

  (IconData, Color, String) _getCloudStatusInfo(bool isDark) {
    final defaultColor = isDark ? AppTheme.darkTextSecondary : AppTheme.textLight;
    if (_pendingSync == 0) {
      return (Icons.cloud_done_outlined, AppTheme.primary, 'Tersinkronisasi');
    }
    switch (_syncStatus) {
      case SyncStatus.syncing:
        return (Icons.cloud_upload_outlined, AppTheme.primary, 'Mengunggah...');
      case SyncStatus.noInternet:
        return (Icons.cloud_off_outlined, defaultColor, '$_pendingSync tertahan');
      case SyncStatus.error:
        return (Icons.error_outline, const Color(0xFFEF4444), 'Gagal sync');
      default:
        return (Icons.schedule, defaultColor, '$_pendingSync menunggu');
    }
  }

  // --- Logika Tabir Surya (Sunscreen) ---
  int get _effectiveSunscreenMinutes {
    final uv = telemetryData?['uv_index']?.toDouble() ?? 0.0;
    if (uv >= 8.0) return 80; // Sinar UV ekstrem: dokter kulit menyarankan oles ulang tiap 80 menit
    return 120; // Default normal: 2 jam (120 menit)
  }

  Duration get _sunscreenRemainingTime {
    if (_lastSunscreenTime == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_lastSunscreenTime!);
    final total = Duration(minutes: _effectiveSunscreenMinutes);
    final remaining = total - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get _isSunscreenActive => _sunscreenRemainingTime.inSeconds > 0;

  Future<void> _recordSunscreenApplied() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sunscreen_time', now.toIso8601String());
    setState(() {
      _lastSunscreenTime = now;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tabir surya dicatat! Proteksi kulit aktif selama $_effectiveSunscreenMinutes menit ke depan.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // --- Logika Asupan Air (Hidrasi) ---
  int get _hydrationIntervalMinutes {
    final temp = telemetryData?['temperature']?.toDouble() ?? 0.0;
    if (temp >= 35.0) return 15; // Suhu terik ekstrem: minum tiap 15 menit
    if (temp >= 30.0) return 30; // Suhu panas/hangat: minum tiap 30 menit
    return 60; // Normal: minum tiap 60 menit
  }

  Duration get _drinkRemainingTime {
    if (_lastDrinkTime == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_lastDrinkTime!);
    final total = Duration(minutes: _hydrationIntervalMinutes);
    final remaining = total - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get _isDrinkDue => _lastDrinkTime == null || _drinkRemainingTime.inSeconds <= 0;

  Future<void> _recordDrinkApplied() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final newCount = _waterGlassesCount + 1;
    await prefs.setString('last_drink_time', now.toIso8601String());
    await prefs.setInt('daily_water_glasses', newCount);
    await prefs.setString('last_drink_date', todayStr);

    setState(() {
      _lastDrinkTime = now;
      _waterGlassesCount = newCount;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.local_drink_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bagus! Asupan gelas ke-$newCount tercatat ($newCount/$_targetGlasses gelas). Tubuh tetap segar & terhidrasi.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _loadSunscreenAndDrinkState() async {
    final prefs = await SharedPreferences.getInstance();
    final sunscreenStr = prefs.getString('last_sunscreen_time');
    if (sunscreenStr != null) {
      _lastSunscreenTime = DateTime.tryParse(sunscreenStr);
    }

    final drinkStr = prefs.getString('last_drink_time');
    if (drinkStr != null) {
      _lastDrinkTime = DateTime.tryParse(drinkStr);
    }

    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final savedDate = prefs.getString('last_drink_date');
    if (savedDate == todayStr) {
      _waterGlassesCount = prefs.getInt('daily_water_glasses') ?? 0;
    } else {
      _waterGlassesCount = 0;
      await prefs.setInt('daily_water_glasses', 0);
      await prefs.setString('last_drink_date', todayStr);
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isDark),
              const SizedBox(height: 12),
              _buildConnectionBanner(isDark),
              const SizedBox(height: 12),
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
    ),
  );
}

  /// Banner status koneksi BLE + Cloud Sync
  Widget _buildConnectionBanner(bool isDark) {
    final bleColor = _getSyncColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight,
        ),
      ),
      child: Row(
        children: [
          // Status BLE
          Icon(_getSyncIcon(), size: 16, color: bleColor),
          const SizedBox(width: 8),
          Text(
            _getConnectionLabel(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: bleColor,
            ),
          ),
          const SizedBox(width: 8),
          // Indikator berkedip (dot animasi)
          if (_bleStatus == BleConnectionStatus.simulating ||
              _bleStatus == BleConnectionStatus.connected)
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 6),
                ],
              ),
            ),
          const Spacer(),
          // Status Cloud Sync
          _buildCloudStatusBadge(isDark),
        ],
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
              child: const Icon(Icons.person, color: AppTheme.primary),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _userName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
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
                      _getSyncIcon(),
                      size: 13,
                      color: _getSyncColor(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getSyncText(),
                      style: TextStyle(
                        fontSize: 10,
                        color: _getSyncColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.battery_std_rounded, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${_ble.batteryPercentage}%',
                      style: const TextStyle(
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
    final temp = telemetryData?['temperature']?.toDouble() ?? 0.0;
    final uv = telemetryData?['uv_index']?.toDouble() ?? 0.0;
    final voc = (telemetryData?['voc'] as num?)?.toInt() ?? 0;
    final hasData = temp > 0 || uv > 0 || voc > 0;

    final isBahaya = voc >= 250 || uv >= 8.0 || temp >= 36.0;
    final isWaspada = !isBahaya && (voc >= 120 || uv >= 6.0 || temp >= 33.0);

    String statusTitle = 'MENUNGGU DATA';
    String statusDesc = 'Mencari sinyal sensor Klimo...';
    Color titleColor = isDark ? Colors.white : AppTheme.textLight;
    Color bgColor = isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9);
    IconData bgIcon = Icons.sensors;

    if (hasData) {
      if (isBahaya) {
        statusTitle = 'BAHAYA';
        if (voc >= 250) {
          statusDesc = 'Konsentrasi gas VOC tinggi ($voc). Hindari polusi, gunakan masker respirator.';
        } else if (uv >= 8.0) {
          statusDesc = 'Radiasi UV sangat ekstrem (${uv.toStringAsFixed(1)}). Wajib tabir surya SPF 50+ & cari tempat teduh.';
        } else {
          statusDesc = 'Suhu panas ekstrem (${temp.toStringAsFixed(1)}°C). Waspada dehidrasi akut dan sengatan panas.';
        }
        titleColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
        bgColor = isDark ? const Color(0xFF241416) : const Color(0xFFFEE2E2);
        bgIcon = Icons.warning_amber_rounded;
      } else if (isWaspada) {
        statusTitle = 'WASPADA';
        if (voc >= 120) {
          statusDesc = 'Polusi udara meningkat (VOC $voc). Batasi aktivitas fisik berat di luar.';
        } else if (uv >= 6.0) {
          statusDesc = 'Indeks radiasi UV tinggi (${uv.toStringAsFixed(1)}). Disarankan berteduh dan gunakan pelindung surya.';
        } else {
          statusDesc = 'Udara cukup terik (${temp.toStringAsFixed(1)}°C). Jaga asupan hidrasi secara berkala.';
        }
        titleColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
        bgColor = isDark ? const Color(0xFF221C11) : const Color(0xFFFEF3C7);
        bgIcon = Icons.wb_sunny_outlined;
      } else {
        statusTitle = 'AMAN';
        statusDesc = 'Kondisi cukup bersahabat. Semua parameter sensor dalam batas aman.';
        titleColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
        bgColor = isDark ? AppTheme.darkCard : const Color(0xFFD1FAE5);
        bgIcon = Icons.check_circle_outline;
      }
    }

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
              bgIcon,
              size: 110,
              color: isDark
                  ? const Color(0xFF1E2D40).withValues(alpha: 0.6)
                  : (isBahaya
                      ? Colors.red.withValues(alpha: 0.15)
                      : (isWaspada
                          ? Colors.orange.withValues(alpha: 0.15)
                          : Colors.green.withValues(alpha: 0.15))),
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
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : (isBahaya
                          ? const Color(0xFF991B1B)
                          : (isWaspada ? const Color(0xFF92400E) : const Color(0xFF065F46))),
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
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : (isBahaya
                          ? const Color(0xFF991B1B)
                          : (isWaspada ? const Color(0xFF92400E) : const Color(0xFF065F46))),
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
                    'Kelembapan ${telemetryData?['humidity'] ?? '-'}%',
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
    
    String uvSubtitle;
    Color uvColor;
    if (uv >= 8.0) {
      uvSubtitle = 'Ekstrem (Wajib Teduh)';
      uvColor = const Color(0xFFEF4444);
    } else if (uv >= 6.0) {
      uvSubtitle = 'Tinggi (Bahaya Kulit)';
      uvColor = const Color(0xFFF59E0B);
    } else if (uv >= 3.0) {
      uvSubtitle = 'Sedang (Pakai Topi)';
      uvColor = const Color(0xFFEAB308);
    } else {
      uvSubtitle = 'Rendah (Aman Nyaman)';
      uvColor = AppTheme.primary;
    }
    
    return _buildStatusCard(
      title: 'SINAR UV (MATAHARI)',
      titleColor: isDark ? AppTheme.darkTextSecondary : AppTheme.primary,
      value: uvText,
      subtitle: uvSubtitle,
      progressValue: (uv / 11.0).clamp(0.0, 1.0),
      progressColor: uvColor,
      bottomText: _bleStatus == BleConnectionStatus.connected
          ? 'Sensor Gelang Langsung'
          : 'Data Simulasi Demo',
      isDark: isDark,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UVDetailScreen(currentUv: uv)),
        );
      },
    );
  }

  Widget _buildGasCard(bool isDark) {
    int voc = telemetryData?['voc'] ?? 0;
    String status = voc >= 250 ? 'Bahaya' : (voc >= 120 ? 'Waspada' : 'Bersih');
    String vocSubtitle = voc >= 250 
        ? 'Polusi tinggi ($voc)' 
        : (voc >= 120 ? 'Polusi sedang ($voc)' : 'Udara segar ($voc)');
    Color gasColor = voc >= 250 
        ? const Color(0xFFEF4444) 
        : (voc >= 120 ? const Color(0xFFF59E0B) : AppTheme.primary);

    return _buildStatusCard(
      title: 'KUALITAS UDARA',
      titleColor: isDark ? AppTheme.darkTextSecondary : AppTheme.primary,
      value: status,
      valueSize: 28,
      subtitle: vocSubtitle,
      progressValue: (voc / 500.0).clamp(0.0, 1.0),
      progressColor: gasColor,
      bottomText: _bleStatus == BleConnectionStatus.connected
          ? 'Sensor Gelang Langsung'
          : 'Data Simulasi Demo',
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
    final voc = (telemetryData?['voc'] as num?)?.toInt() ?? 0;
    final uv = telemetryData?['uv_index']?.toDouble() ?? 0.0;
    final temp = telemetryData?['temperature']?.toDouble() ?? 0.0;

    IconData bannerIcon;
    Color iconColor;
    Color borderClr;
    Color bgClr;
    String boldText;
    String detailText;

    if (voc >= 200) {
      bannerIcon = Icons.air;
      iconColor = const Color(0xFFEF4444);
      borderClr = const Color(0xFFF87171);
      bgClr = isDark ? const Color(0xFF261214) : const Color(0xFFFEF2F2);
      boldText = 'Polusi gas naik (VOC $voc)— ';
      detailText = 'Disarankan pakai masker atau pindah ke area ventilasi baik.';
    } else if (uv >= 8.0) {
      bannerIcon = Icons.wb_sunny_rounded;
      iconColor = const Color(0xFFF59E0B);
      borderClr = const Color(0xFFFBBF24);
      bgClr = isDark ? const Color(0xFF261D12) : const Color(0xFFFFFBEB);
      boldText = 'Radiasi UV ekstrem (${uv.toStringAsFixed(1)})— ';
      detailText = 'Disarankan berteduh dan aplikasikan ulang tabir surya SPF 50+.';
    } else if (temp >= 35.0) {
      bannerIcon = Icons.thermostat;
      iconColor = const Color(0xFFF97316);
      borderClr = const Color(0xFFFB923C);
      bgClr = isDark ? const Color(0xFF261812) : const Color(0xFFFFF7ED);
      boldText = 'Suhu udara panas (${temp.toStringAsFixed(1)}°C)— ';
      detailText = 'Waspada dehidrasi, minum air putih dan istirahat di tempat sejuk.';
    } else {
      bannerIcon = Icons.verified_user_outlined;
      iconColor = AppTheme.primary;
      borderClr = AppTheme.primary.withValues(alpha: 0.3);
      bgClr = isDark ? AppTheme.darkCard : const Color(0xFFF0FDF4);
      boldText = 'Kualitas lingkungan baik— ';
      detailText = 'Indikator sensor menunjukkan kondisi aman untuk aktivitas luar.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgClr,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : borderClr,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            bannerIcon,
            color: iconColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF1E293B),
                  fontSize: 13,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: boldText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : iconColor,
                    ),
                  ),
                  TextSpan(text: detailText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSunscreenCard(bool isDark) {
    final uv = telemetryData?['uv_index']?.toDouble() ?? 0.0;
    final remaining = _sunscreenRemainingTime;
    final isActive = _isSunscreenActive;

    String val;
    String sub;
    String btnText;
    bool isOutlined;
    double progress;
    Color progressColor;

    if (isActive) {
      if (remaining.inMinutes >= 60) {
        val = '${remaining.inHours}j ${remaining.inMinutes % 60}m';
      } else {
        val = '${remaining.inMinutes} mnt';
      }
      sub = 'Proteksi aktif • Sisa waktu';
      btnText = 'Oles Ulang';
      isOutlined = true;
      progress = (remaining.inSeconds / (_effectiveSunscreenMinutes * 60)).clamp(0.0, 1.0);
      progressColor = remaining.inMinutes < 20 ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    } else {
      val = uv >= 8.0 ? 'SPF 50+' : (uv >= 3.0 ? 'SPF 30+' : 'Perlu Oles');
      sub = uv >= 8.0 
          ? 'UV ekstrem! Oleskan sekarang' 
          : (uv >= 3.0 ? 'Belum dioles • Butuh pelindung' : 'Kondisi UV aman saat ini');
      btnText = 'Sudah Oles';
      isOutlined = false;
      progress = 0.0;
      progressColor = const Color(0xFFEF4444);
    }

    return _buildActionCard(
      icon: Icons.wb_sunny_outlined,
      title: 'Tabir Surya',
      value: val,
      subtitle: sub,
      buttonText: btnText,
      isOutlined: isOutlined,
      isDark: isDark,
      progress: progress,
      progressColor: progressColor,
      onTap: _recordSunscreenApplied,
    );
  }

  Widget _buildMinumCard(bool isDark) {
    final temp = telemetryData?['temperature']?.toDouble() ?? 0.0;
    final remaining = _drinkRemainingTime;
    final isDue = _isDrinkDue;

    String val;
    String sub;
    String btnText;
    bool isOutlined;
    double progress;
    Color progressColor;

    if (isDue) {
      val = 'Waktunya!';
      sub = temp >= 35.0 ? 'Suhu terik, segera minum air' : 'Jaga cairan, minum sekarang';
      btnText = 'Sudah Minum';
      isOutlined = false;
      progress = 1.0;
      progressColor = const Color(0xFFEF4444);
    } else {
      val = '${remaining.inMinutes} mnt';
      sub = '$_waterGlassesCount/$_targetGlasses gelas hari ini';
      btnText = 'Minum Lagi';
      isOutlined = true;
      progress = (_waterGlassesCount / _targetGlasses).clamp(0.0, 1.0);
      progressColor = AppTheme.primary;
    }

    return _buildActionCard(
      icon: Icons.local_drink_outlined,
      title: 'Minum Air',
      value: val,
      subtitle: sub,
      buttonText: btnText,
      isOutlined: isOutlined,
      isDark: isDark,
      progress: progress,
      progressColor: progressColor,
      onTap: _recordDrinkApplied,
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
    VoidCallback? onTap,
    double? progress,
    Color? progressColor,
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
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? const Color(0xFF101B2B) : AppTheme.greyLight,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor ?? AppTheme.primary),
                minHeight: 4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: isOutlined
                ? OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      backgroundColor: isDark ? AppTheme.darkCard : Colors.transparent,
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                : ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
