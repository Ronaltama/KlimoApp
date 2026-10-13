import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../services/local_data_service.dart';
import '../services/api_service.dart';
import '../services/ble_simulator_service.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isWeekly = true;
  List<dynamic> _historyData = [];
  bool _isLoading = true;
  StreamSubscription? _bleSub;

  double _peakUv = 0.0;
  double _maxTemp = 0.0;
  int _avgVoc = 0;
  int _peakHour = 12;
  String _peakHourRange = '11–14';
  int _badAirCount = 0; // hari jika mingguan, jam jika harian
  int _sunscreenAdherence = 75; // %
  int _waterAdherence = 60; // %

  List<(String label, double val, bool isActive)> _weeklyBars = [];
  List<(String label, double val, bool isActive)> _dailyBars = [];

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
    // Subscribe ke stream BLE untuk sinkronisasi otomatis
    _bleSub = BleSimulatorService().recordStream.listen((_) {
      if (mounted) {
        _fetchHistoryData(isBackgroundUpdate: true);
      }
    });
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchHistoryData({bool isBackgroundUpdate = false}) async {
    if (!isBackgroundUpdate) {
      setState(() => _isLoading = true);
    }

    try {
      // Baca data preferensi pengguna untuk target minum & sunscreen
      final prefs = await SharedPreferences.getInstance();
      final waterGlasses = prefs.getInt('daily_water_glasses') ?? 0;
      // Target minum 8 gelas sehari
      final calculatedWater = waterGlasses > 0
          ? ((waterGlasses / 8.0) * 100).round().clamp(10, 100)
          : 60;

      // Cek riwayat sunscreen terakhir
      final lastSunscreen = prefs.getString('last_sunscreen_time');
      int calculatedSunscreen = 75;
      if (lastSunscreen != null) {
        final lastTime = DateTime.tryParse(lastSunscreen);
        if (lastTime != null) {
          final diffHours = DateTime.now().difference(lastTime).inHours;
          if (diffHours <= 2) {
            calculatedSunscreen = 90;
          } else if (diffHours <= 4) {
            calculatedSunscreen = 75;
          } else {
            calculatedSunscreen = 50;
          }
        }
      }

      // Ambil data dari SQLite Lokal HP terlebih dahulu (Offline-First)
      final localData = await LocalDataService.getHistory(limit: 100);

      if (localData.isNotEmpty) {
        final mapped = localData
            .map(
              (r) => {
                'uv_index': r.uvIndex,
                'temperature': r.temperature,
                'humidity': r.humidity,
                'voc': r.voc,
                'created_at': r.timestamp.toIso8601String(),
              },
            )
            .toList();

        if (!mounted) return;
        setState(() {
          _historyData = mapped;
          _isLoading = false;
          _waterAdherence = calculatedWater;
          _sunscreenAdherence = calculatedSunscreen;
          _calculateMetrics();
        });
      } else {
        // Fallback ke Backend API
        final data = await ApiService.getHistoryData();
        if (!mounted) return;
        setState(() {
          _historyData = data;
          _isLoading = false;
          _waterAdherence = calculatedWater;
          _sunscreenAdherence = calculatedSunscreen;
          _calculateMetrics();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateMetrics() {
    const dayLabels = {
      1: 'Sen',
      2: 'Sel',
      3: 'Rab',
      4: 'Kam',
      5: 'Jum',
      6: 'Sab',
      7: 'Min',
    };
    final dailySlots = [8, 10, 12, 14, 16, 18];
    final currentWeekday = DateTime.now().weekday;

    if (_historyData.isEmpty) {
      _peakUv = 0.0;
      _maxTemp = 0.0;
      _avgVoc = 0;
      _peakHour = 12;
      _peakHourRange = '11–14';
      _badAirCount = 0;
      _weeklyBars = List.generate(7, (i) {
        final dayIndex = i + 1;
        // Default representasi bar yang estetik jika belum ada data sensor
        final mockHeights = [4.5, 6.2, 8.0, 9.8, 6.5, 3.8, 7.2];
        return (
          dayLabels[dayIndex]!,
          mockHeights[i],
          dayIndex == currentWeekday,
        );
      });
      _dailyBars = dailySlots
          .map((slot) => ('${slot.toString().padLeft(2, '0')}:00', 0.0, false))
          .toList();
      return;
    }

    double maxUv = 0.0;
    double maxTemp = 0.0;
    int sumVoc = 0;
    int count = 0;
    int maxUvHour = 12;
    final weeklyMaxUv = <int, double>{
      1: 0.0,
      2: 0.0,
      3: 0.0,
      4: 0.0,
      5: 0.0,
      6: 0.0,
      7: 0.0,
    };
    final dailyMaxUv = <int, double>{
      8: 0.0,
      10: 0.0,
      12: 0.0,
      14: 0.0,
      16: 0.0,
      18: 0.0,
    };
    final badAirDaysSet = <int>{};
    int badAirHoursCount = 0;

    for (var item in _historyData) {
      final uv = (item['uv_index'] as num?)?.toDouble() ?? 0.0;
      final temp = (item['temperature'] as num?)?.toDouble() ?? 0.0;
      final voc = (item['voc'] as num?)?.toInt() ?? 0;

      if (uv > maxUv) {
        maxUv = uv;
      }
      if (temp > maxTemp) {
        maxTemp = temp;
      }
      sumVoc += voc;
      count++;

      DateTime? dt;
      if (item['created_at'] != null) {
        dt = DateTime.tryParse(item['created_at'].toString())?.toLocal();
      }

      if (dt != null) {
        if (uv == maxUv && uv > 0) {
          maxUvHour = dt.hour;
        }

        final w = dt.weekday; // 1 = Sen ... 7 = Min
        if (weeklyMaxUv.containsKey(w)) {
          if (uv > weeklyMaxUv[w]!) weeklyMaxUv[w] = uv;
        }

        // Catat hari dengan kualitas udara buruk (VOC >= 150)
        if (voc >= 150) {
          badAirDaysSet.add(w);
          badAirHoursCount++;
        }

        final hour = dt.hour;
        int matchedSlot = 8;
        int minDiff = 999;
        for (var s in dailySlots) {
          final diff = (hour - s).abs();
          if (diff < minDiff) {
            minDiff = diff;
            matchedSlot = s;
          }
        }
        if (uv > dailyMaxUv[matchedSlot]!) {
          dailyMaxUv[matchedSlot] = uv;
        }
      }
    }

    _peakUv = maxUv;
    _peakHour = maxUvHour;
    _maxTemp = maxTemp;
    _avgVoc = count > 0 ? (sumVoc / count).round() : 0;

    // Jam puncak: jika dalam rentang siang, tampilkan 11–14
    if (maxUvHour >= 11 && maxUvHour <= 14) {
      _peakHourRange = '11–14';
    } else if (maxUv > 0) {
      final start = (maxUvHour - 1).clamp(8, 16);
      final end = (maxUvHour + 2).clamp(10, 18);
      _peakHourRange = '$start–$end';
    } else {
      _peakHourRange = '11–14';
    }

    _badAirCount = _isWeekly
        ? (badAirDaysSet.isNotEmpty ? badAirDaysSet.length : 0)
        : (badAirHoursCount > 0 ? (badAirHoursCount / 2).ceil() : 0);

    // Siapkan data batang mingguan
    _weeklyBars = [];
    for (int i = 1; i <= 7; i++) {
      final val = weeklyMaxUv[i] ?? 0.0;
      final isPeak = maxUv > 0 && val == maxUv;
      final isToday = i == currentWeekday;
      _weeklyBars.add((dayLabels[i]!, val, isPeak || (val > 0 && isToday)));
    }

    // Siapkan data batang harian
    _dailyBars = [];
    for (var slot in dailySlots) {
      final val = dailyMaxUv[slot] ?? 0.0;
      final isPeak = maxUv > 0 && val == maxUv;
      _dailyBars.add(('${slot.toString().padLeft(2, '0')}:00', val, isPeak));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchHistoryData,
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 18),
                _buildToggle(isDark),
                const SizedBox(height: 18),
                _buildChartCard(isDark),
                const SizedBox(height: 16),
                _buildMetricCards(isDark),
                const SizedBox(height: 16),
                _buildProtectionRoutineCard(isDark),
                const SizedBox(height: 16),
                _buildTipsCard(isDark),
                const SizedBox(height: 18),
                _buildRecentLogsSection(isDark),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header bersih sesuai mockup: Icon kalender + Text 'Riwayat'
  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132D27) : const Color(0xFFE8F8F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.calendar_today_outlined,
            color: AppTheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Riwayat',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  /// Tombol Toggle Harian / Mingguan (Pill Style)
  Widget _buildToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isWeekly = false;
                _calculateMetrics();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
              decoration: BoxDecoration(
                color: !_isWeekly ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Harian',
                style: TextStyle(
                  color: !_isWeekly
                      ? Colors.white
                      : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textLight),
                  fontWeight: !_isWeekly ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isWeekly = true;
                _calculateMetrics();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
              decoration: BoxDecoration(
                color: _isWeekly ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Mingguan',
                style: TextStyle(
                  color: _isWeekly
                      ? Colors.white
                      : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textLight),
                  fontWeight: _isWeekly ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Grafik Paparan UV (perkiraan) dengan batang gradien
  Widget _buildChartCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
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
            'Paparan UV (perkiraan)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              final barMaxHeight = (chartWidth * 0.38).clamp(95.0, 140.0);
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isWeekly
                    ? Row(
                        key: const ValueKey('weekly_chart'),
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: _weeklyBars.map((bar) {
                          final heightFactor = bar.$2 > 0
                              ? (bar.$2 / 12.0).clamp(0.2, 1.0)
                              : 0.12;
                          return _buildBar(
                            bar.$1,
                            heightFactor,
                            bar.$3,
                            isDark,
                            barMaxHeight,
                          );
                        }).toList(),
                      )
                    : Row(
                        key: const ValueKey('daily_chart'),
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: _dailyBars.map((bar) {
                          final heightFactor = bar.$2 > 0
                              ? (bar.$2 / 12.0).clamp(0.2, 1.0)
                              : 0.12;
                          return _buildBar(
                            bar.$1,
                            heightFactor,
                            bar.$3,
                            isDark,
                            barMaxHeight,
                          );
                        }).toList(),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBar(
    String label,
    double heightFactor,
    bool isActive,
    bool isDark,
    double barMaxHeight,
  ) {
    return Column(
      children: [
        Container(
          width: 26,
          height: barMaxHeight * heightFactor,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF6EE7B7), const Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? AppTheme.primary
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Card Mini: Jam puncak, Udara buruk, Suhu tertinggi, Kualitas udara
  Widget _buildMetricCards(bool isDark) {
    final badAirText = _isWeekly
        ? (_badAirCount > 0 ? '$_badAirCount hari' : '0 hari')
        : (_badAirCount > 0 ? '$_badAirCount jam' : '0 jam');

    final tempVal = _historyData.isEmpty
        ? '-'
        : '${_maxTemp.toStringAsFixed(1)}°C';

    final vocVal = _historyData.isEmpty
        ? '-'
        : (_avgVoc >= 200 ? 'Waspada' : (_avgVoc >= 100 ? 'Sedang' : 'Bersih'));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniCard(
                title: 'Jam puncak',
                value: _peakHourRange,
                valueColor: isDark ? Colors.white : AppTheme.textDark,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMiniCard(
                title: 'Udara buruk',
                value: badAirText,
                valueColor: const Color(0xFFD97706),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMiniCard(
                title: 'Suhu tertinggi',
                value: tempVal,
                valueColor: _maxTemp >= 35.0
                    ? const Color(0xFFEF4444)
                    : (_maxTemp >= 30.0 ? const Color(0xFFF59E0B) : AppTheme.primary),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMiniCard(
                title: 'Kualitas udara',
                value: vocVal,
                valueColor: _avgVoc >= 200
                    ? const Color(0xFFEF4444)
                    : (_avgVoc >= 100 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCard({
    required String title,
    required String value,
    required Color valueColor,
    required bool isDark,
  }) {
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
            title,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  /// Card Rutinitas Proteksi (Pengganti 'Kepatuhan')
  Widget _buildProtectionRoutineCard(bool isDark) {
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
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Rutinitas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRoutineRow(
            label: 'Oles ulang tepat waktu',
            percent: _sunscreenAdherence,
            isDark: isDark,
          ),
          const SizedBox(height: 18),
          _buildRoutineRow(
            label: 'Target minum tercapai',
            percent: _waterAdherence,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineRow({
    required String label,
    required int percent,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (percent / 100.0).clamp(0.0, 1.0),
            backgroundColor: isDark
                ? const Color(0xFF101B2B)
                : const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight: 6.5,
          ),
        ),
      ],
    );
  }

  /// Card Tips minggu ini / Tips hari ini (Banner Hijau Muda Rapi)
  Widget _buildTipsCard(bool isDark) {
    final title = _isWeekly ? 'Tips minggu ini' : 'Tips hari ini';

    String tipDescription;
    if (_historyData.isEmpty) {
      tipDescription =
          'Paparan tertinggi jam 12. Coba istirahat di tempat teduh.';
    } else if (_peakUv >= 8.0) {
      tipDescription =
          'Paparan tertinggi jam $_peakHour. Lindungi kulit dan istirahat di tempat teduh.';
    } else if (_peakUv >= 4.0) {
      tipDescription =
          'Paparan tertinggi jam $_peakHour. Coba istirahat di tempat teduh.';
    } else {
      tipDescription = 'Kondisi sinar stabil. Tetap jaga hidrasi dan oleskan sunscreen saat keluar.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: Color(0xFF059669),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tipDescription,
            style: TextStyle(
              color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Section Log Rekaman Terbaru + Tombol Detail
  Widget _buildRecentLogsSection(bool isDark) {
    final recentItems = _historyData.take(5).toList();

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log Rekaman Terbaru',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '5 data pembacaan sensor terakhir yang tersimpan',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textLight,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          HistoryDetailScreen(initialData: _historyData),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Lihat Detail',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (recentItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Belum ada rekaman sensor yang tersimpan.',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textLight,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...recentItems.map((item) => _buildLogRow(item, isDark)),
        ],
      ),
    );
  }

  Widget _buildLogRow(dynamic item, bool isDark) {
    String timeStr = 'Baru saja';
    if (item['created_at'] != null) {
      try {
        final dt = DateTime.parse(item['created_at'].toString()).toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) {
          timeStr = '${diff.inSeconds} dtk lalu';
        } else if (diff.inHours < 1) {
          timeStr = '${diff.inMinutes} mnt lalu';
        } else {
          timeStr =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }
      } catch (_) {}
    }

    final double uv = (item['uv_index'] as num?)?.toDouble() ?? 0.0;
    final double temp = (item['temperature'] as num?)?.toDouble() ?? 0.0;
    final int voc = (item['voc'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              ),
              const SizedBox(width: 6),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTheme.textDark,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildBadgeWithIcon(
                Icons.wb_sunny_outlined,
                'UV ${uv.toStringAsFixed(1)}',
                uv >= 8
                    ? const Color(0xFFEF4444)
                    : (uv >= 3
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981)),
                isDark,
              ),
              const SizedBox(width: 6),
              _buildBadgeWithIcon(
                Icons.thermostat_outlined,
                '${temp.toStringAsFixed(1)}°C',
                temp >= 35
                    ? const Color(0xFFEF4444)
                    : (temp >= 28
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981)),
                isDark,
              ),
              const SizedBox(width: 6),
              _buildBadgeWithIcon(
                Icons.air,
                'VOC $voc',
                voc >= 250
                    ? const Color(0xFFEF4444)
                    : (voc >= 100
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981)),
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeWithIcon(
    IconData icon,
    String text,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
