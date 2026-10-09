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

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  Future<void> _fetchHistoryData() async {
    final data = await ApiService.getHistoryData();
    if (mounted) {
      setState(() {
        _historyData = data;
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
              _buildToggle(isDark),
              const SizedBox(height: 20),
              _buildChartCard(isDark),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallCard(
                        'Total Data Masuk',
                        '${_historyData.length}',
                        isDark ? Colors.white : AppTheme.textDark,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSmallCard(
                        'Dari API',
                        _historyData.isNotEmpty ? 'Real-time' : '-',
                        AppTheme.primary,
                        isDark,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              _buildComplianceCard(isDark),
              const SizedBox(height: 16),
              _buildTipsCard(isDark),
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
          child: const Icon(Icons.calendar_today, color: AppTheme.primary, size: 22),
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
                      ? (isDark ? const Color(0xFF0F172A) : Colors.white)
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
            'Paparan UV (perkiraan)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar('Sen', 0.50, false, isDark),
              _buildBar('Sel', 0.65, false, isDark),
              _buildBar('Rab', 0.80, false, isDark),
              _buildBar('Kam', 0.95, true, isDark),
              _buildBar('Jum', 0.60, false, isDark),
              _buildBar('Sab', 0.45, false, isDark),
              _buildBar('Min', 0.70, false, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String day, double heightFactor, bool isActive, bool isDark) {
    return Column(
      children: [
        Container(
          width: 26,
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
                      isDark
                          ? const Color(0xFF264C46)
                          : const Color(0xFFA7F3D0),
                      isDark
                          ? const Color(0xFF13755C)
                          : const Color(0xFF059669),
                    ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          day,
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

  Widget _buildSmallCard(String title, String value, Color valueColor, bool isDark) {
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
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
        ],
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
                'Kepatuhan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressRow('Oles ulang tepat waktu', '75%', 0.75, isDark),
          const SizedBox(height: 18),
          _buildProgressRow('Target minum tercapai', '60%', 0.60, isDark),
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
                'Tips minggu ini',
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
            'Paparan tertinggi jam 12. Coba istirahat di tempat teduh.',
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
