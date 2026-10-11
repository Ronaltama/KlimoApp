import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/local_data_service.dart';
import '../services/api_service.dart';
import '../services/ble_simulator_service.dart';
import '../services/sync_manager.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isWeekly = true;
  List<dynamic> _historyData = [];
  bool _isLoading = true;
  bool _isFromLocal = false; // indikator sumber data

  double _peakUv = 0.0;
  double _avgTemp = 0.0;
  double _avgHum = 0.0;
  int _avgVoc = 0;
  int _safeUvPercent = 0;
  int _comfortTempPercent = 0;

  List<(String label, double val, bool isActive)> _weeklyBars = [];
  List<(String label, double val, bool isActive)> _dailyBars = [];

  @override
  void initState() {
    super.initState();
    _calculateMetrics();
    _fetchHistoryData();
    // Subscribe ke stream BLE untuk auto-refresh riwayat saat data baru masuk
    BleSimulatorService().recordStream.listen((_) {
      if (mounted && _isFromLocal) _fetchHistoryData();
    });
  }

  Future<void> _fetchHistoryData() async {
    setState(() => _isLoading = true);

    // Coba ambil dari lokal HP terlebih dahulu (Offline-First)
    final localData = await LocalDataService.getHistory(limit: 100);

    if (localData.isNotEmpty) {
      // Ada data lokal — tampilkan langsung tanpa internet
      final mapped = localData.map((r) => {
        'uv_index': r.uvIndex,
        'temperature': r.temperature,
        'humidity': r.humidity,
        'voc': r.voc,
        'created_at': r.timestamp.toIso8601String(),
      }).toList();

      if (!mounted) return;
      setState(() {
        _historyData = mapped;
        _isLoading = false;
        _isFromLocal = true;
        _calculateMetrics();
      });
    } else {
      // Lokal kosong (belum ada data BLE) — fallback ke API backend
      final data = await ApiService.getHistoryData();
      if (!mounted) return;
      setState(() {
        _historyData = data;
        _isLoading = false;
        _isFromLocal = false;
        _calculateMetrics();
      });
    }
  }

  void _calculateMetrics() {
    const dayLabels = {1: 'Sen', 2: 'Sel', 3: 'Rab', 4: 'Kam', 5: 'Jum', 6: 'Sab', 7: 'Min'};
    final dailySlots = [8, 10, 12, 14, 16, 18];
    final currentWeekday = DateTime.now().weekday;

    if (_historyData.isEmpty) {
      _peakUv = 0.0;
      _avgTemp = 0.0;
      _avgHum = 0.0;
      _avgVoc = 0;
      _safeUvPercent = 0;
      _comfortTempPercent = 0;
      _weeklyBars = List.generate(7, (i) {
        final dayIndex = i + 1;
        return (dayLabels[dayIndex]!, 0.0, dayIndex == currentWeekday);
      });
      _dailyBars = dailySlots.map((slot) => ('${slot.toString().padLeft(2, '0')}:00', 0.0, false)).toList();
      return;
    }

    double maxUv = 0.0;
    double sumTemp = 0.0;
    double sumHum = 0.0;
    int sumVoc = 0;
    int count = 0;
    int safeUvCount = 0;
    int comfortTempCount = 0;

    final weeklyMaxUv = <int, double>{1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0};
    final dailyMaxUv = <int, double>{8: 0.0, 10: 0.0, 12: 0.0, 14: 0.0, 16: 0.0, 18: 0.0};

    for (var item in _historyData) {
      final uv = (item['uv_index'] as num?)?.toDouble() ?? 0.0;
      final temp = (item['temperature'] as num?)?.toDouble() ?? 0.0;
      final hum = (item['humidity'] as num?)?.toDouble() ?? 0.0;
      final voc = (item['voc'] as num?)?.toInt() ?? 0;

      if (uv > maxUv) maxUv = uv;
      if (uv < 3.0) safeUvCount++;
      if (temp < 32.0) comfortTempCount++;

      sumTemp += temp;
      sumHum += hum;
      sumVoc += voc;
      count++;

      DateTime? dt;
      if (item['created_at'] != null) {
        dt = DateTime.tryParse(item['created_at'].toString())?.toLocal();
      }

      if (dt != null) {
        final w = dt.weekday; // 1 = Senin ... 7 = Minggu
        if (weeklyMaxUv.containsKey(w)) {
          if (uv > weeklyMaxUv[w]!) weeklyMaxUv[w] = uv;
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

    if (count > 0) {
      _peakUv = maxUv;
      _avgTemp = sumTemp / count;
      _avgHum = sumHum / count;
      _avgVoc = (sumVoc / count).round();
      _safeUvPercent = ((safeUvCount / count) * 100).round();
      _comfortTempPercent = ((comfortTempCount / count) * 100).round();
    }

    _weeklyBars = [];
    for (int i = 1; i <= 7; i++) {
      final val = weeklyMaxUv[i] ?? 0.0;
      final isPeak = maxUv > 0 && val == maxUv;
      final isToday = i == currentWeekday;
      _weeklyBars.add((dayLabels[i]!, val, isPeak || (val > 0 && isToday)));
    }

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
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 20),
                _buildToggle(isDark),
                const SizedBox(height: 20),
                _buildChartCard(isDark),
                const SizedBox(height: 16),
                _buildMetricCards(isDark),
                const SizedBox(height: 20),
                _buildRecentLogsSection(isDark),
                const SizedBox(height: 20),
                _buildComplianceCard(isDark),
                const SizedBox(height: 16),
                _buildTipsCard(isDark),
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
              child: const Icon(Icons.calendar_today, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isFromLocal ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isFromLocal ? 'SQLite Lokal HP (Offline)' : 'Database API Server',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isFromLocal ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
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
                  await _fetchHistoryData();
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

  Widget _buildToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isWeekly = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: !_isWeekly ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Harian',
                style: TextStyle(
                  color: !_isWeekly
                      ? Colors.white
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                  fontWeight: !_isWeekly ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isWeekly = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: _isWeekly ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Mingguan',
                style: TextStyle(
                  color: _isWeekly
                      ? Colors.white
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
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

  Widget _buildChartCard(bool isDark) {
    String chartTitle = _isWeekly ? 'Paparan UV Mingguan (Maksimum per Hari)' : 'Paparan UV Harian (Kurva Jam)';
    String subtitle = _isWeekly ? 'Data paparan 7 hari terakhir' : 'Fluktuasi intensitas UV sepanjang hari';

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chartTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textDark,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Puncak: ${_historyData.isEmpty ? "-" : _peakUv.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isWeekly
                ? Row(
                    key: const ValueKey('weekly_chart'),
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _weeklyBars.map((bar) {
                      final heightFactor = bar.$2 > 0 ? (bar.$2 / 12.0).clamp(0.12, 1.0) : 0.08;
                      final valText = bar.$2 > 0 ? bar.$2.toStringAsFixed(1) : '-';
                      return _buildBar(bar.$1, heightFactor, bar.$3, isDark, valText);
                    }).toList(),
                  )
                : Row(
                    key: const ValueKey('daily_chart'),
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _dailyBars.map((bar) {
                      final heightFactor = bar.$2 > 0 ? (bar.$2 / 12.0).clamp(0.12, 1.0) : 0.08;
                      final valText = bar.$2 > 0 ? bar.$2.toStringAsFixed(1) : '-';
                      return _buildBar(bar.$1, heightFactor, bar.$3, isDark, valText);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double heightFactor, bool isActive, bool isDark, String valueLabel) {
    return Column(
      children: [
        Text(
          valueLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 24,
          height: 120 * heightFactor,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isActive
                  ? [
                      const Color(0xFF34D399),
                      const Color(0xFF00B074),
                    ]
                  : [
                      isDark ? const Color(0xFF264C46) : const Color(0xFFA7F3D0),
                      isDark ? const Color(0xFF13755C) : const Color(0xFF059669),
                    ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
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
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCards(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallCard(
            'Puncak UV',
            _historyData.isEmpty ? '-' : _peakUv.toStringAsFixed(1),
            _peakUv >= 8 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            isDark,
            subtitle: _historyData.isEmpty
                ? 'Belum Ada'
                : (_peakUv >= 8 ? 'Ekstrem' : (_peakUv >= 6 ? 'Tinggi' : (_peakUv >= 3 ? 'Sedang' : 'Rendah'))),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildSmallCard(
            'Rata-rata Suhu',
            _historyData.isEmpty ? '-' : '${_avgTemp.toStringAsFixed(1)}°C',
            AppTheme.primary,
            isDark,
            subtitle: _historyData.isEmpty ? 'RH -' : 'RH ~${_avgHum.toStringAsFixed(0)}%',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildSmallCard(
            'Rata Gas VOC',
            _historyData.isEmpty ? '-' : '$_avgVoc',
            _avgVoc >= 200 ? const Color(0xFFEF4444) : AppTheme.primary,
            isDark,
            subtitle: _historyData.isEmpty ? 'Belum Ada' : (_avgVoc >= 200 ? 'Waspada' : 'Baik'),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallCard(String title, String value, Color valueColor, bool isDark, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentLogsSection(bool isDark) {
    final recentItems = _historyData.take(5).toList();

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
              Text(
                'Log Rekaman Terbaru',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              Text(
                'Total: ${_historyData.length} data',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
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
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
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
          timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
              Icon(Icons.access_time, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
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
              _buildBadge('UV ${uv.toStringAsFixed(1)}', uv >= 8 ? const Color(0xFFEF4444) : AppTheme.primary, isDark),
              const SizedBox(width: 6),
              _buildBadge('${temp.toStringAsFixed(1)}°C', const Color(0xFFF59E0B), isDark),
              const SizedBox(width: 6),
              _buildBadge('VOC $voc', voc >= 250 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildComplianceCard(bool isDark) {
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
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Kepatuhan Ambang Aman',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressRow(
            'Paparan UV aman (< 3.0 UVI)',
            '$_safeUvPercent%',
            _safeUvPercent / 100.0,
            isDark,
          ),
          const SizedBox(height: 18),
          _buildProgressRow(
            'Suhu lingkungan nyaman (< 32°C)',
            '$_comfortTempPercent%',
            _comfortTempPercent / 100.0,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String title, String percentText, double percent, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              percentText,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: isDark ? const Color(0xFF101B2B) : AppTheme.greyLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight: 7,
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard(bool isDark) {
    String tipsText;
    if (_historyData.isEmpty) {
      tipsText = 'Belum ada data rekaman sensor. Hubungkan perangkat IoT atau jalankan simulator untuk memulai monitoring mikroiklim secara real-time.';
    } else if (_peakUv >= 8) {
      tipsText = 'Terdeteksi paparan UV puncak ${_peakUv.toStringAsFixed(1)} (Ekstrem). Disarankan menggunakan sunscreen SPF 50+, pakaian protektif berlengan panjang, dan hindari paparan matahari langsung pada jam terik.';
    } else if (_peakUv >= 6) {
      tipsText = 'Paparan UV puncak ${_peakUv.toStringAsFixed(1)} (Tinggi). Gunakan pelindung topi, kacamata hitam, dan aplikasikan ulang tabir surya setiap 2 jam.';
    } else if (_avgTemp >= 34) {
      tipsText = 'Rata-rata suhu lingkungan tergolong panas (${_avgTemp.toStringAsFixed(1)}°C). Pastikan hidrasi cukup dan istirahat berkala di tempat teduh.';
    } else {
      tipsText = 'Kondisi mikrolingkungan stabil dan dalam batas ambang aman. Lanjutkan pemantauan rutin untuk perlindungan optimal.';
    }

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
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Evaluasi & Saran',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tipsText,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.primary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
