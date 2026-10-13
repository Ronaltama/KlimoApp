import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Ukuran huruf. Sama dengan layar lain.
  static const _fsCaption = 11.0;
  static const _fsSmall = 12.0;
  static const _fsBody = 13.0;
  static const _fsTitle = 15.0;
  static const _fsHeader = 20.0;

  static const _uvColor = Color(0xFFEF4444);
  static const _midColor = Color(0xFFF59E0B);
  static const _goodColor = Color(0xFF10B981);

  bool _shareLocation = true;
  String _selectedTab = 'Sinar UV';
  List<dynamic> _heatmapData = [];
  bool _isLoading = false;

  // Nilai metrik lingkungan hasil kalkulasi dari API
  double _avgUv = 4.8;
  double _maxUv = 9.5;
  double _minUv = 1.2;

  double _avgTemp = 31.0;
  double _maxTemp = 36.8;
  double _minTemp = 26.5;

  int _avgVoc = 135;
  int _maxVoc = 390;
  int _minVoc = 55;

  @override
  void initState() {
    super.initState();
    _fetchMapData();
  }

  Future<void> _fetchMapData() async {
    setState(() => _isLoading = true);

    final data = await ApiService.getHeatmapData();
    if (!mounted) return;

    setState(() {
      _heatmapData = data;
      _isLoading = false;
      _computeMetrics();
    });
  }

  /// Menghitung rata-rata, tertinggi, dan terendah dari data API.
  void _computeMetrics() {
    if (_heatmapData.isEmpty) return;

    double totalUv = 0, totalTemp = 0;
    int totalVoc = 0, uvCount = 0, tempCount = 0, vocCount = 0;

    double maxUv = -1, minUv = 999;
    double maxTemp = -1, minTemp = 999;
    int maxVoc = -1, minVoc = 9999;

    for (final item in _heatmapData) {
      if (item['uv_index'] != null) {
        final val = (item['uv_index'] as num).toDouble();
        totalUv += val;
        uvCount++;
        if (val > maxUv) maxUv = val;
        if (val < minUv) minUv = val;
      }
      if (item['temperature'] != null) {
        final val = (item['temperature'] as num).toDouble();
        totalTemp += val;
        tempCount++;
        if (val > maxTemp) maxTemp = val;
        if (val < minTemp) minTemp = val;
      }
      if (item['voc'] != null) {
        final val = (item['voc'] as num).toInt();
        totalVoc += val;
        vocCount++;
        if (val > maxVoc) maxVoc = val;
        if (val < minVoc) minVoc = val;
      }
    }

    if (uvCount > 0) {
      _avgUv = totalUv / uvCount;
      _maxUv = maxUv;
      _minUv = minUv;
    }
    if (tempCount > 0) {
      _avgTemp = totalTemp / tempCount;
      _maxTemp = maxTemp;
      _minTemp = minTemp;
    }
    if (vocCount > 0) {
      _avgVoc = (totalVoc / vocCount).round();
      _maxVoc = maxVoc;
      _minVoc = minVoc;
    }
  }

  void _notify(String message, {bool error = false}) {
    if (!mounted) return;
    final p = AppPalette.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? p.danger : p.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchMapData,
          color: p.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _header(p),
              const SizedBox(height: 20),
              _tabs(p),
              const SizedBox(height: 20),
              _mapCard(p),
              const SizedBox(height: 14),
              _legend(p),
              const SizedBox(height: 14),
              _statChips(p),
              const SizedBox(height: 18),
              _infoCard(p),
              const SizedBox(height: 14),
              _shareCard(p),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Header ----------

  Widget _header(AppPalette p) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.map, color: p.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Peta Lingkungan',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: _fsHeader,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Kondisi di sekitar kamu',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.textSecondary, fontSize: _fsSmall),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _isLoading ? null : _fetchMapData,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
                      )
                    : Icon(Icons.refresh, size: 16, color: p.primary),
                const SizedBox(width: 6),
                Text(
                  'Perbarui',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: _fsSmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Tab ----------

  Widget _tabs(AppPalette p) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(child: _tabItem(p, 'Sinar UV')),
          Expanded(child: _tabItem(p, 'Suhu')),
          Expanded(child: _tabItem(p, 'Udara')),
        ],
      ),
    );
  }

  Widget _tabItem(AppPalette p, String title) {
    final isActive = _selectedTab == title;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? p.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : p.textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              fontSize: _fsBody,
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Peta ----------

  Widget _mapCard(AppPalette p) {
    final labels = _zoneLabels();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = (w * 0.65).clamp(200.0, 280.0);
        final blob = w * 0.42;

        return Container(
          height: h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.cardBorder, width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: p.bg == AppPalette.dark.bg ? 0.08 : 0.04,
                    child: CustomPaint(
                      painter: _MapGridPainter(
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ),
                _blob(_uvColor, p, blob, left: -blob * 0.1, top: -blob * 0.1),
                _blob(_midColor, p, blob * 1.1, right: -blob * 0.1, top: h * 0.2),
                _blob(_goodColor, p, blob * 0.9, left: w * 0.15, bottom: -blob * 0.1),

                Positioned(
                  top: 12,
                  left: 12,
                  right: w * 0.45,
                  child: _zoneBadge(p, labels[0], _uvColor),
                ),
                Positioned(
                  right: 12,
                  top: h * 0.4,
                  child: _zoneBadge(p, labels[1], _midColor),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: w * 0.4,
                  child: _zoneBadge(p, labels[2], _goodColor),
                ),

                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: p.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Kamu di sini',
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: _fsCaption,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Label zona (judul, nilai) sesuai tab yang dipilih.
  List<(String, String)> _zoneLabels() {
    if (_selectedTab == 'Sinar UV') {
      return [
        ('Sangat terik', 'UV ${_maxUv.toStringAsFixed(1)}'),
        ('Sedang', 'UV ${_avgUv.toStringAsFixed(1)}'),
        ('Teduh', 'UV ${_minUv.toStringAsFixed(1)}'),
      ];
    } else if (_selectedTab == 'Suhu') {
      return [
        ('Panas sekali', '${_maxTemp.toStringAsFixed(1)}°C'),
        ('Hangat', '${_avgTemp.toStringAsFixed(1)}°C'),
        ('Sejuk', '${_minTemp.toStringAsFixed(1)}°C'),
      ];
    }
    return [
      ('Udara buruk', 'Indeks $_maxVoc'),
      ('Cukup baik', 'Indeks $_avgVoc'),
      ('Udara segar', 'Indeks $_minVoc'),
    ];
  }

  Widget _blob(
    Color color,
    AppPalette p,
    double size, {
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.25),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoneBadge(AppPalette p, (String, String) text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text.$1,
              style: TextStyle(color: accent, fontSize: _fsSmall, fontWeight: FontWeight.bold),
            ),
            Text(
              text.$2,
              style: TextStyle(color: p.textSecondary, fontSize: _fsCaption),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Skala warna ----------

  Widget _legend(AppPalette p) {
    final List<String> items;
    if (_selectedTab == 'Sinar UV') {
      items = ['Rendah (< 3)', 'Sedang (3–7)', 'Tinggi (8+)'];
    } else if (_selectedTab == 'Suhu') {
      items = ['Sejuk (< 28°C)', 'Hangat (28–34°C)', 'Panas (> 35°C)'];
    } else {
      items = ['Baik (< 100)', 'Sedang (100–250)', 'Buruk (> 250)'];
    }

    const colors = [_goodColor, _midColor, _uvColor];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skala warna',
          style: TextStyle(color: p.textMuted, fontSize: _fsCaption, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(colors: colors),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: List.generate(
            3,
            (i) => _legendItem(p, items[i], colors[i]),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(AppPalette p, String text, Color dotColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: p.textSecondary, fontSize: _fsCaption, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ---------- Statistik ----------

  Widget _statChips(AppPalette p) {
    final communityCount = _heatmapData.isNotEmpty ? _heatmapData.length : 1;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _chip(p, 'Perangkatmu: Aktif', Icons.sensors),
        _chip(p, '$communityCount orang di sekitar', Icons.people_outline),
      ],
    );
  }

  Widget _chip(AppPalette p, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: p.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: _fsSmall,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Info ----------

  Widget _infoCard(AppPalette p) {
    String headline;
    String explanation;
    String badgeLabel;
    Color color;
    IconData icon;

    if (_selectedTab == 'Sinar UV') {
      icon = Icons.wb_sunny_outlined;
      if (_avgUv >= 8) {
        badgeLabel = 'Berbahaya';
        color = _uvColor;
        headline = 'Sinar matahari sangat kuat sekarang';
        explanation = 'Pakai sunscreen dan topi. Hindari keluar antara pukul 10 sampai 14.';
      } else if (_avgUv >= 3) {
        badgeLabel = 'Sedang';
        color = _midColor;
        headline = 'Sinar UV sedang, tetap waspada';
        explanation = 'Masih aman di luar, tapi disarankan pakai sunscreen.';
      } else {
        badgeLabel = 'Aman';
        color = p.primary;
        headline = 'Sinar UV rendah, aman untuk keluar';
        explanation = 'Tidak perlu khawatir dengan paparan matahari sekarang.';
      }
    } else if (_selectedTab == 'Suhu') {
      icon = Icons.thermostat_outlined;
      if (_avgTemp >= 35) {
        badgeLabel = 'Sangat panas';
        color = _uvColor;
        headline = 'Cuaca sangat panas sekarang';
        explanation = 'Perbanyak minum air dan cari tempat teduh.';
      } else if (_avgTemp >= 28) {
        badgeLabel = 'Hangat';
        color = _midColor;
        headline = 'Suhu hangat, cukup nyaman';
        explanation = 'Tetap minum air jika beraktivitas di luar lama.';
      } else {
        badgeLabel = 'Sejuk';
        color = p.primary;
        headline = 'Suhu sejuk, cuaca nyaman';
        explanation = 'Cocok untuk jalan-jalan atau olahraga di luar.';
      }
    } else {
      icon = Icons.air;
      if (_avgVoc >= 250) {
        badgeLabel = 'Udara buruk';
        color = _uvColor;
        headline = 'Kualitas udara kurang baik';
        explanation = 'Pakai masker saat keluar rumah.';
      } else if (_avgVoc >= 100) {
        badgeLabel = 'Cukup baik';
        color = _midColor;
        headline = 'Kualitas udara cukup baik';
        explanation = 'Pastikan sirkulasi udara di ruangan tetap lancar.';
      } else {
        badgeLabel = 'Udara segar';
        color = p.primary;
        headline = 'Udara segar, kondisi terbaik';
        explanation = 'Bagus untuk olahraga atau membuka jendela rumah.';
      }
    }

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: _fsCaption,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  headline,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: _fsTitle,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  explanation,
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: _fsBody,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Kontribusi ----------

  Widget _shareCard(AppPalette p) {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on_outlined, color: p.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ikut berkontribusi ke peta',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: _fsTitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Lokasimu tidak disimpan secara pribadi.',
                  style: TextStyle(color: p.textSecondary, fontSize: _fsSmall, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _shareLocation,
            activeThumbColor: Colors.white,
            activeTrackColor: p.primary,
            onChanged: (val) {
              setState(() => _shareLocation = val);
              _notify(
                val
                    ? 'Kamu ikut berkontribusi ke peta komunitas.'
                    : 'Kontribusi peta dimatikan.',
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Garis grid tipis sebagai latar peta.
class _MapGridPainter extends CustomPainter {
  final Color color;
  _MapGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter old) => old.color != color;
}