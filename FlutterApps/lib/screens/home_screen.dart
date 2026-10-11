import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import 'uv_detail_screen.dart';
import '../services/local_data_service.dart';
import '../services/ble_simulator_service.dart';
import '../services/sync_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TelemetryRecord? _telemetryRecord;
  Timer? _uiRefreshTimer;
  StreamSubscription<TelemetryRecord>? _bleSubscription;
  StreamSubscription<BleConnectionStatus>? _statusSubscription;

  final _ble = BleSimulatorService();
  final _sync = SyncManager();

  BleConnectionStatus _bleStatus = BleConnectionStatus.disconnected;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _pendingSync = 0;

  @override
  void initState() {
    super.initState();
    _initOfflineFirst();
  }

  Future<void> _initOfflineFirst() async {
    // 1. Tampilkan data lokal yang sudah ada (langsung dari SQLite HP)
    final cached = await LocalDataService.getLatest();
    if (cached != null && mounted) {
      setState(() => _telemetryRecord = cached);
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

    // 5. Auto-mulai simulasi BLE virtual (mode demo)
    _ble.startSimulation(mode: BleSimMode.auto);
  }

  @override
  void dispose() {
    _bleSubscription?.cancel();
    _statusSubscription?.cancel();
    _uiRefreshTimer?.cancel();
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

  String _getSyncText() {
    if (_telemetryRecord == null) return 'MENUNGGU DATA';
    switch (_bleStatus) {
      case BleConnectionStatus.scanning:
        return 'SCANNING...';
      case BleConnectionStatus.connected:
        return 'BLE LIVE';
      case BleConnectionStatus.simulating:
        final diff = DateTime.now().difference(_telemetryRecord!.timestamp);
        if (diff.inSeconds < 5) return 'BARU SAJA';
        if (diff.inSeconds < 60) return '${diff.inSeconds} DTK LALU';
        if (diff.inMinutes < 60) return '${diff.inMinutes} MNT LALU';
        return '${diff.inHours} JAM LALU';
      case BleConnectionStatus.disconnected:
        return 'LOKAL HP';
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

  void _showSimModeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Mode Simulasi BLE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Pilih kondisi lingkungan yang disimulasikan',
                  style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                ),
                const SizedBox(height: 20),
                ..._buildModeOptions(isDark, ctx),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildModeOptions(bool isDark, BuildContext ctx) {
    final options = [
      (
        BleSimMode.auto,
        'Otomatis (Fluktuatif Realistis)',
        'UV 1.5–7.5 • Suhu 27–34°C • VOC 45–180',
        AppTheme.primary,
        Icons.autorenew,
      ),
      (
        BleSimMode.normal,
        'Normal / Sejuk',
        'UV 1.2–2.5 • Suhu 26–28°C • VOC 40–85',
        const Color(0xFF10B981),
        Icons.wb_sunny_outlined,
      ),
      (
        BleSimMode.uvExtreme,
        'Panas Ekstrem (UV Bahaya)',
        'UV 9.8–11.6 • Suhu 36–39°C • VOC 105–155',
        const Color(0xFFEF4444),
        Icons.warning_amber_rounded,
      ),
      (
        BleSimMode.pollution,
        'Polusi Udara (VOC Tinggi)',
        'UV 2.5–3.8 • Suhu 29–32°C • VOC 395–475',
        const Color(0xFFF59E0B),
        Icons.air,
      ),
    ];

    return options.map((opt) {
      final (mode, title, desc, color, icon) = opt;
      final isSelected = _ble.currentMode == mode;
      return Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          subtitle: Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check_circle, color: color, size: 20)
              : null,
          onTap: () {
            _ble.changeMode(mode);
            setState(() {});
            Navigator.pop(ctx);
          },
        ),
      );
    }).toList();
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
    );
  }

  /// Banner status koneksi BLE + Cloud Sync (baru)
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
          const SizedBox(width: 6),
          Text(
            _bleStatus == BleConnectionStatus.simulating
                ? 'Simulator BLE'
                : _bleStatus == BleConnectionStatus.connected
                    ? 'Klimo-A3F2'
                    : 'Tidak Tersambung',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: bleColor,
            ),
          ),
          const SizedBox(width: 12),
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
          const SizedBox(width: 8),
          // Tombol mode simulasi
          GestureDetector(
            onTap: _showSimModeDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F2237) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Mode',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
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
      bottomText: _bleStatus == BleConnectionStatus.connected
          ? 'Sensor Live ESP32'
          : 'Simulasi BLE (${_ble.modeName})',
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
    String status = voc > 200 ? 'Bahaya' : (voc > 100 ? 'Sedang' : 'Baik');

    return _buildStatusCard(
      title: 'GAS VOC',
      titleColor: isDark ? AppTheme.darkTextSecondary : AppTheme.primary,
      value: status,
      valueSize: 28,
      subtitle: 'Indeks $voc',
      progressValue: (voc / 500.0).clamp(0.0, 1.0),
      progressColor: voc > 200 ? const Color(0xFFEF4444) : AppTheme.primary,
      bottomText: _bleStatus == BleConnectionStatus.connected
          ? 'Sensor Live ESP32'
          : 'Simulasi BLE (${_ble.modeName})',
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
    String val = uv >= 8.0 ? 'SPF 50+' : (uv >= 3.0 ? 'SPF 30+' : 'Aman');
    String sub = uv >= 8.0 ? 'Wajib proteksi maksimal' : (uv >= 3.0 ? 'Oles sebelum keluar' : 'UV rendah');

    return _buildActionCard(
      icon: Icons.wb_sunny_outlined,
      title: 'Sunscreen',
      value: val,
      subtitle: sub,
      buttonText: 'Sudah oles',
      isOutlined: false,
      isDark: isDark,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proteksi tabir surya dicatat. Perlindungan aktif!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Widget _buildMinumCard(bool isDark) {
    final temp = telemetryData?['temperature']?.toDouble() ?? 0.0;
    String val = temp >= 35.0 ? '15 mnt' : (temp >= 30.0 ? '30 mnt' : '60 mnt');
    String sub = temp >= 35.0 ? 'Lagi (suhu terik)' : (temp >= 30.0 ? 'Lagi (suhu hangat)' : 'Lagi (suhu normal)');

    return _buildActionCard(
      icon: Icons.local_drink_outlined,
      title: 'Minum',
      value: val,
      subtitle: sub,
      buttonText: 'Sudah minum',
      isOutlined: true,
      isDark: isDark,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asupan air tercatat. Kebutuhan hidrasi terjaga!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
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
                    onPressed: onTap,
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
                    onPressed: onTap,
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
