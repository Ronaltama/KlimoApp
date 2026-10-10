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
  String _selectedTab = 'UV'; // Default ke UV untuk tema utama Klimo
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
                  'Peta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Text(
                  'Peta sebaran mikroiklim',
                  style: TextStyle(
                    fontSize: 14,
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
          Expanded(child: _buildTabItem('UV', isDark)),
          Expanded(child: _buildTabItem('Panas', isDark)),
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
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapVisualization(bool isDark) {
    // Tentukan label dan teks badge secara dinamis berdasarkan tab yang dipilih
    String highLabel;
    String midLabel;
    String lowLabel;

    if (_selectedTab == 'UV') {
      highLabel = 'UV ${_maxUv.toStringAsFixed(1)} · Ekstrem';
      midLabel = 'UV ${_avgUv.toStringAsFixed(1)} · Sedang';
      lowLabel = 'UV ${_minUv.toStringAsFixed(1)} · Teduh';
    } else if (_selectedTab == 'Panas') {
      highLabel = '${_maxTemp.toStringAsFixed(1)}°C · Terik';
      midLabel = '${_avgTemp.toStringAsFixed(1)}°C · Hangat';
      lowLabel = '${_minTemp.toStringAsFixed(1)}°C · Sejuk';
    } else {
      // Udara (VOC)
      highLabel = 'VOC $_maxVoc · Buruk';
      midLabel = 'VOC $_avgVoc · Sedang';
      lowLabel = 'VOC $_minVoc · Segar';
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

            // Badge Dinamis - Zona Tinggi (Atas Kiri)
            Positioned(
              top: 30,
              left: 36,
              child: _buildMapLabel(
                highLabel,
                isDark ? const Color(0xFF2E1720) : const Color(0xFFFEE2E2),
                const Color(0xFFF87171),
                isDark,
              ),
            ),

            // Badge Dinamis - Zona Sedang (Kanan)
            Positioned(
              right: 25,
              top: 90,
              child: _buildMapLabel(
                midLabel,
                isDark ? const Color(0xFF2D2517) : const Color(0xFFFEF3C7),
                const Color(0xFFFBBF24),
                isDark,
              ),
            ),

            // Badge Dinamis - Zona Aman (Bawah Kiri)
            Positioned(
              bottom: 35,
              left: 60,
              child: _buildMapLabel(
                lowLabel,
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

  Widget _buildMapLabel(String text, Color bgColor, Color textColor, bool isDark) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: textColor.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
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
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF10B981), // Hijau
                Color(0xFFF59E0B), // Kuning
                Color(0xFFEF4444), // Merah
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftLegend,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              midLegend,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              rightLegend,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStats(bool isDark) {
    return Row(
      children: [
        _buildStatChip('Perangkatmu: Aktif', Icons.sensors, isDark),
        const SizedBox(width: 10),
        _buildStatChip(
          'Komunitas: ${_heatmapData.isNotEmpty ? _heatmapData.length : 1} Titik Data',
          Icons.people_outline,
          isDark,
        ),
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
    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    if (_selectedTab == 'UV') {
      icon = Icons.wb_sunny_outlined;
      iconColor = _avgUv >= 8 ? const Color(0xFFEF4444) : (_avgUv >= 3 ? const Color(0xFFF59E0B) : AppTheme.primary);
      title = 'Sekitarmu: Rata-rata UV ${_avgUv.toStringAsFixed(1)} (${_avgUv >= 8 ? 'Tinggi/Ekstrem' : (_avgUv >= 3 ? 'Sedang' : 'Aman')})';
      subtitle = _avgUv >= 7
          ? 'Radiasi matahari terik. Disarankan memakai sunscreen & topi.'
          : 'Area aman untuk berjalan kaki. Area teduh terdekat 120 m.';
    } else if (_selectedTab == 'Panas') {
      icon = Icons.thermostat_outlined;
      iconColor = _avgTemp >= 35 ? const Color(0xFFEF4444) : (_avgTemp >= 28 ? const Color(0xFFF59E0B) : AppTheme.primary);
      title = 'Sekitarmu: Suhu rata-rata ${_avgTemp.toStringAsFixed(1)}°C';
      subtitle = _avgTemp >= 35
          ? 'Potensi stres panas (heat stress). Perbanyak minum air mineral.'
          : 'Suhu lingkungan cukup bersahabat untuk aktivitas luar ruangan.';
    } else {
      icon = Icons.air;
      iconColor = _avgVoc >= 250 ? const Color(0xFFEF4444) : (_avgVoc >= 100 ? const Color(0xFFF59E0B) : AppTheme.primary);
      title = 'Sekitarmu: Kualitas gas VOC $_avgVoc (${_avgVoc >= 250 ? 'Buruk' : (_avgVoc >= 100 ? 'Sedang' : 'Baik')})';
      subtitle = _avgVoc >= 250
          ? 'Kadar senyawa organik volatil tinggi. Disarankan memakai masker.'
          : 'Sirkulasi udara segar, ventilasi alami di sekitar baik.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    height: 1.3,
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bagikan lokasi anonim',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Data digabung per area radius, bukan titik presisi pribadi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
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
                        ? 'Berbagi lokasi sensor anonim diaktifkan.'
                        : 'Berbagi lokasi dinonaktifkan (mode privat).',
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
