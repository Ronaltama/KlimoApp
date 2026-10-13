import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isWeekly = true;
  List<dynamic> _historyData = [];
  bool _isLoading = true;

  double _peakUv = 8.5;
  double _avgTemp = 31.2;
  int _avgVoc = 120;

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  Future<void> _fetchHistoryData() async {
    setState(() {
      _isLoading = true;
    });

    final data = await ApiService.getHistoryData();

    if (!mounted) return;

    setState(() {
      _historyData = data;
      _isLoading = false;
      _calculateMetrics();
    });
  }

  void _calculateMetrics() {
    if (_historyData.isEmpty) return;

    double maxUv = 0.0;
    double sumTemp = 0.0;
    int sumVoc = 0;
    int count = 0;

    for (var item in _historyData) {
      if (item['uv_index'] != null) {
        double uv = (item['uv_index'] as num).toDouble();
        if (uv > maxUv) maxUv = uv;
      }
      if (item['temperature'] != null) {
        sumTemp += (item['temperature'] as num).toDouble();
      }
      if (item['voc'] != null) {
        sumVoc += (item['voc'] as num).toInt();
      }
      count++;
    }

    if (count > 0) {
      _peakUv = maxUv > 0 ? maxUv : 6.5;
      _avgTemp = sumTemp / count;
      _avgVoc = (sumVoc / count).round();
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
                Text(
                  'Rekaman cuaca & paparan kamu',
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
          onTap: _isLoading ? null : _fetchHistoryData,
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
    final String chartTitle = _isWeekly ? 'Sinar UV Minggu Ini' : 'Sinar UV Hari Ini';
    final String subtitle = _isWeekly ? 'Nilai tertinggi tiap hari (7 hari terakhir)' : 'Seberapa kuat matahari tiap jam';

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
                  'Tertinggi: ${_peakUv.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              final barMaxHeight = chartWidth * 0.42; // proporsional dengan lebar kartu
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isWeekly
                    ? Row(
                        key: const ValueKey('weekly_chart'),
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBar('Sen', 0.40, false, isDark, '4.2', barMaxHeight),
                          _buildBar('Sel', 0.55, false, isDark, '5.8', barMaxHeight),
                          _buildBar('Rab', 0.70, false, isDark, '7.2', barMaxHeight),
                          _buildBar('Kam', (_peakUv / 11.0).clamp(0.2, 0.98), true, isDark, _peakUv.toStringAsFixed(1), barMaxHeight),
                          _buildBar('Jum', 0.60, false, isDark, '6.1', barMaxHeight),
                          _buildBar('Sab', 0.35, false, isDark, '3.8', barMaxHeight),
                          _buildBar('Min', 0.50, false, isDark, '5.0', barMaxHeight),
                        ],
                      )
                    : Row(
                        key: const ValueKey('daily_chart'),
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBar('08.00', 0.20, false, isDark, '2.1', barMaxHeight),
                          _buildBar('10.00', 0.55, false, isDark, '5.5', barMaxHeight),
                          _buildBar('12.00', (_peakUv / 11.0).clamp(0.2, 0.98), true, isDark, _peakUv.toStringAsFixed(1), barMaxHeight),
                          _buildBar('14.00', 0.75, false, isDark, '7.8', barMaxHeight),
                          _buildBar('16.00', 0.40, false, isDark, '4.0', barMaxHeight),
                          _buildBar('18.00', 0.10, false, isDark, '0.5', barMaxHeight),
                        ],
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
    String valueLabel,
    double maxHeight,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valueLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
            color: isActive
                ? AppTheme.primary
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 22,
          height: (maxHeight * heightFactor).clamp(8.0, maxHeight),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isActive
                  ? [const Color(0xFF34D399), const Color(0xFF00B074)]
                  : [
                      isDark ? const Color(0xFF264C46) : const Color(0xFFA7F3D0),
                      isDark ? const Color(0xFF13755C) : const Color(0xFF059669),
                    ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? AppTheme.primary
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 10,
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
            'UV Tertinggi',
            _peakUv.toStringAsFixed(1),
            _peakUv >= 8 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            isDark,
            subtitle: _peakUv >= 8 ? '⚠ Tinggi' : 'Sedang',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallCard(
            'Suhu Rata-rata',
            '${_avgTemp.toStringAsFixed(1)}°C',
            AppTheme.primary,
            isDark,
            subtitle: 'Lembap 62%',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallCard(
            'Kualitas Udara',
            _avgVoc >= 200 ? 'Buruk' : 'Baik',
            _avgVoc >= 200 ? const Color(0xFFEF4444) : AppTheme.primary,
            isDark,
            subtitle: 'VOC $_avgVoc',
          ),
        ),
      ],
    );
  }

  Widget _buildSmallCard(String title, String value, Color valueColor, bool isDark, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
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
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                fontSize: 10,
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
                'Rekaman Terbaru',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              Text(
                '${_historyData.length} catatan',
                style: const TextStyle(
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
              _buildBadge(
                'UV ${uv.toStringAsFixed(1)}',
                uv >= 8 ? const Color(0xFFEF4444) : AppTheme.primary,
                isDark,
                tooltip: uv >= 8 ? 'Tinggi' : 'Aman',
              ),
              const SizedBox(width: 6),
              _buildBadge('${temp.toStringAsFixed(1)}°C', const Color(0xFFF59E0B), isDark),
              const SizedBox(width: 6),
              _buildBadge(
                voc >= 250 ? 'Udara Buruk' : 'Udara OK',
                voc >= 250 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, bool isDark, {String? tooltip}) {
    final widget = Container(
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
    if (tooltip != null) return Tooltip(message: tooltip, child: widget);
    return widget;
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
                'Kepatuhan Proteksi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildProgressRow('Sunscreen dioles ulang tepat waktu', '85%', 0.85, isDark),
          const SizedBox(height: 16),
          _buildProgressRow('Target minum air harian tercapai', '70%', 0.70, isDark),
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
                'Saran untuk kamu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.primary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _peakUv >= 8
                ? 'Sinar UV hari ini sangat kuat (${_peakUv.toStringAsFixed(1)}). Pakai sunscreen SPF 50+ dan hindari keluar antara pukul 11.00–14.00.'
                : 'Paparan sinar UV masih dalam batas aman. Teruslah pakai perlindungan ringan saat beraktivitas di luar.',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.primary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
