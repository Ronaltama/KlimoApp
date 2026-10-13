import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _shareLocation = true;
  String _selectedTab = 'Sinar UV';
  List<dynamic> _heatmapData = [];
  bool _isLoading = false;

  // Nilai metrik lingkungan hasil kalkulasi dari Backend API
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
    setState(() {
      _isLoading = true;
    });

    final data = await ApiService.getHeatmapData();

    if (!mounted) return;

    setState(() {
      _heatmapData = data;
      _isLoading = false;
      _computeMetrics();
    });
  }

  /// Menghitung nilai statistik rata-rata, max, dan min dari titik telemetri API
  void _computeMetrics() {
    if (_heatmapData.isEmpty) return;

    double totalUv = 0;
    double totalTemp = 0;
    int totalVoc = 0;
    int uvCount = 0;
    int tempCount = 0;
    int vocCount = 0;

    double maxUv = -1;
    double minUv = 999;
    double maxTemp = -1;
    double minTemp = 999;
    int maxVoc = -1;
    int minVoc = 9999;

    for (var item in _heatmapData) {
      if (item['uv_index'] != null) {
        double val = (item['uv_index'] as num).toDouble();
        totalUv += val;
        uvCount++;
        if (val > maxUv) maxUv = val;
        if (val < minUv) minUv = val;
      }
      if (item['temperature'] != null) {
        double val = (item['temperature'] as num).toDouble();
        totalTemp += val;
        tempCount++;
        if (val > maxTemp) maxTemp = val;
        if (val < minTemp) minTemp = val;
      }
      if (item['voc'] != null) {
        int val = (item['voc'] as num).toInt();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchMapData,
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 20),
                _buildTabs(isDark),
                const SizedBox(height: 20),
                _buildMapVisualization(isDark),
                const SizedBox(height: 16),
                _buildLegend(isDark),
                const SizedBox(height: 16),
                _buildStats(isDark),
                const SizedBox(height: 20),
                _buildInfoCard(isDark),
                const SizedBox(height: 16),
                _buildToggleCard(isDark),
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
                color: isDark ? const Color(0xFF132D27) : const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peta Lingkungan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Kondisi cuaca di sekitar kamu',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        // Tombol Refresh / Sinkronisasi Cepat
        InkWell(
          onTap: _isLoading ? null : _fetchMapData,
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

  Widget _buildTabs(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabItem('Sinar UV', isDark)),
          Expanded(child: _buildTabItem('Suhu', isDark)),
          Expanded(child: _buildTabItem('Udara', isDark)),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, bool isDark) {
    final isActive = _selectedTab == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isActive
                  ? Colors.white
                  : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapVisualization(bool isDark) {
    // Label badge zona: nama kondisi + nilai di baris kedua
    String highZoneLabel, highZoneValue;
    String midZoneLabel, midZoneValue;
    String lowZoneLabel, lowZoneValue;

    if (_selectedTab == 'Sinar UV') {
      highZoneLabel = 'Sangat Terik';
      highZoneValue = 'UV ${_maxUv.toStringAsFixed(1)}';
      midZoneLabel = 'Sedang';
      midZoneValue = 'UV ${_avgUv.toStringAsFixed(1)}';
      lowZoneLabel = 'Teduh';
      lowZoneValue = 'UV ${_minUv.toStringAsFixed(1)}';
    } else if (_selectedTab == 'Suhu') {
      highZoneLabel = 'Panas Sekali';
      highZoneValue = '${_maxTemp.toStringAsFixed(1)}°C';
      midZoneLabel = 'Hangat';
      midZoneValue = '${_avgTemp.toStringAsFixed(1)}°C';
      lowZoneLabel = 'Sejuk';
      lowZoneValue = '${_minTemp.toStringAsFixed(1)}°C';
    } else {
      highZoneLabel = 'Udara Buruk';
      highZoneValue = 'VOC $_maxVoc';
      midZoneLabel = 'Cukup Baik';
      midZoneValue = 'VOC $_avgVoc';
      lowZoneLabel = 'Udara Segar';
      lowZoneValue = 'VOC $_minVoc';
    }

    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Grid latar belakang peta subtle
            Positioned.fill(
              child: Opacity(
                opacity: isDark ? 0.08 : 0.04,
                child: CustomPaint(
                  painter: _MapGridPainter(isDark: isDark),
                ),
              ),
            ),

            // Blob 1: Zona Bahaya / Tinggi (Merah)
            Positioned(
              left: 20,
              top: 20,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFEF4444).withValues(alpha: isDark ? 0.35 : 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Blob 2: Zona Sedang (Kuning/Oranye)
            Positioned(
              right: 10,
              top: 50,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Blob 3: Zona Aman / Baik (Hijau)
            Positioned(
              left: 50,
              bottom: 10,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Badge Zona Tinggi (Atas Kiri)
            Positioned(
              top: 28,
              left: 28,
              child: _buildMapLabel(
                highZoneLabel,
                highZoneValue,
                isDark ? const Color(0xFF2E1720) : const Color(0xFFFEE2E2),
                const Color(0xFFF87171),
                isDark,
              ),
            ),

            // Badge Zona Sedang (Kanan)
            Positioned(
              right: 22,
              top: 90,
              child: _buildMapLabel(
                midZoneLabel,
                midZoneValue,
                isDark ? const Color(0xFF2D2517) : const Color(0xFFFEF3C7),
                const Color(0xFFFBBF24),
                isDark,
              ),
            ),

            // Badge Zona Aman (Bawah Kiri)
            Positioned(
              bottom: 30,
              left: 55,
              child: _buildMapLabel(
                lowZoneLabel,
                lowZoneValue,
                isDark ? const Color(0xFF132D27) : const Color(0xFFD1FAE5),
                const Color(0xFF34D399),
                isDark,
              ),
            ),

            // Pin Lokasi Pengguna (Tengah)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black87 : Colors.white70,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Kamu di sini',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
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
  }

  Widget _buildMapLabel(
    String label,
    String value,
    Color bgColor,
    Color accentColor,
    bool isDark,
  ) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey('$label-$value'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: accentColor.withValues(alpha: 0.75),
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    String leftLegend;
    String midLegend;
    String rightLegend;

    if (_selectedTab == 'UV') {
      leftLegend = 'Rendah (< 3)';
      midLegend = 'Sedang (3 - 7)';
      rightLegend = 'Ekstrem (8+)';
    } else if (_selectedTab == 'Panas') {
      leftLegend = 'Sejuk (< 28°C)';
      midLegend = 'Hangat (28-34°C)';
      rightLegend = 'Terik (> 35°C)';
    } else {
      leftLegend = 'Baik (< 100)';
      midLegend = 'Sedang (100-250)';
      rightLegend = 'Buruk (> 250)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label atas
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Skala warna',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF10B981), // Hijau - aman
                Color(0xFFF59E0B), // Kuning - sedang
                Color(0xFFEF4444), // Merah - bahaya
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _legendLabel(leftLegend, const Color(0xFF10B981), isDark),
            _legendLabel(midLegend, const Color(0xFFF59E0B), isDark),
            _legendLabel(rightLegend, const Color(0xFFEF4444), isDark),
          ],
        ),
      ],
    );
  }

  Widget _legendLabel(String text, Color dotColor, bool isDark) {
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
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStats(bool isDark) {
    final communityCount = _heatmapData.isNotEmpty ? _heatmapData.length : 1;
    return Row(
      children: [
        _buildStatChip('Perangkatmu: Aktif', Icons.sensors, isDark),
        const SizedBox(width: 10),
        _buildStatChip('$communityCount pengguna di sekitar', Icons.people_outline, isDark),
      ],
    );
  }

  Widget _buildStatChip(String text, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    // ── Konten tergantung tab ──
    String headline;      // Satu kalimat singkat, mudah dipahami
    String explanation;   // Penjelasan & saran praktis
    String badgeLabel;    // Status singkat di badge
    Color badgeColor;
    Color iconColor;
    IconData icon;

    if (_selectedTab == 'Sinar UV') {
      icon = Icons.wb_sunny_outlined;
      if (_avgUv >= 8) {
        badgeLabel = 'Berbahaya';
        badgeColor = const Color(0xFFEF4444);
        iconColor = const Color(0xFFEF4444);
        headline = 'Sinar matahari sangat kuat saat ini!';
        explanation = 'Paparan sinar UV sangat tinggi. Sebaiknya pakai sunscreen, topi, atau hindari keluar antara pukul 10–14.';
      } else if (_avgUv >= 3) {
        badgeLabel = 'Sedang';
        badgeColor = const Color(0xFFF59E0B);
        iconColor = const Color(0xFFF59E0B);
        headline = 'Sinar UV sedang — tetap waspada';
        explanation = 'Masih aman beraktivitas di luar, tapi disarankan pakai sunscreen. Area teduh terdekat sekitar 120 m.';
      } else {
        badgeLabel = 'Aman';
        badgeColor = AppTheme.primary;
        iconColor = AppTheme.primary;
        headline = 'Sinar UV rendah — aman untuk keluar';
        explanation = 'Kondisi aman untuk aktivitas di luar ruangan. Tidak perlu khawatir dengan paparan matahari.';
      }
    } else if (_selectedTab == 'Suhu') {
      icon = Icons.thermostat_outlined;
      if (_avgTemp >= 35) {
        badgeLabel = 'Sangat Panas';
        badgeColor = const Color(0xFFEF4444);
        iconColor = const Color(0xFFEF4444);
        headline = 'Cuaca sangat panas sekarang!';
        explanation = 'Suhu terasa menyengat. Perbanyak minum air, hindari aktivitas berat di luar, dan cari tempat teduh.';
      } else if (_avgTemp >= 28) {
        badgeLabel = 'Hangat';
        badgeColor = const Color(0xFFF59E0B);
        iconColor = const Color(0xFFF59E0B);
        headline = 'Suhu hangat — cukup nyaman';
        explanation = 'Cuaca cukup bersahabat. Tetap terhidrasi jika beraktivitas di luar dalam waktu lama.';
      } else {
        badgeLabel = 'Sejuk';
        badgeColor = AppTheme.primary;
        iconColor = AppTheme.primary;
        headline = 'Suhu sejuk — cuaca sangat nyaman';
        explanation = 'Kondisi ideal untuk berjalan-jalan atau olahraga di luar ruangan.';
      }
    } else {
      // Udara (VOC)
      icon = Icons.air;
      if (_avgVoc >= 250) {
        badgeLabel = 'Udara Buruk';
        badgeColor = const Color(0xFFEF4444);
        iconColor = const Color(0xFFEF4444);
        headline = 'Kualitas udara kurang baik!';
        explanation = 'Udara mengandung banyak zat kimia (asap, polusi). Sebaiknya pakai masker saat keluar rumah.';
      } else if (_avgVoc >= 100) {
        badgeLabel = 'Cukup Baik';
        badgeColor = const Color(0xFFF59E0B);
        iconColor = const Color(0xFFF59E0B);
        headline = 'Kualitas udara cukup baik';
        explanation = 'Udara masih aman untuk aktivitas normal, tapi pastikan sirkulasi ruangan tetap terbuka.';
      } else {
        badgeLabel = 'Udara Segar';
        badgeColor = AppTheme.primary;
        iconColor = AppTheme.primary;
        headline = 'Udara segar — kondisi terbaik';
        explanation = 'Kualitas udara sangat baik. Bagus untuk olahraga, jalan santai, atau membuka jendela rumah.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Judul utama — besar & tegas
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                // Penjelasan — ringan & ramah
                Text(
                  explanation,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
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

  Widget _buildToggleCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_outlined, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ikut berkontribusi ke peta',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Lokasimu tidak disimpan secara pribadi — hanya dipakai untuk peta komunitas.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _shareLocation,
            onChanged: (val) {
              setState(() {
                _shareLocation = val;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    val
                        ? 'Kamu sekarang ikut berkontribusi ke peta komunitas!'
                        : 'Kontribusi peta dimatikan.',
                  ),
                  duration: const Duration(milliseconds: 1800),
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
}

/// Custom painter sederhana untuk menggambar aksen grid peta
class _MapGridPainter extends CustomPainter {
  final bool isDark;
  _MapGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white : Colors.black
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
