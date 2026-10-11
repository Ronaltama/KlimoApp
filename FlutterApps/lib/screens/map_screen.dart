import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/local_data_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _shareLocation = true;
  String _selectedTab = 'UV'; // Default ke UV untuk tema utama Klimo
  List<dynamic> _heatmapData = [];
  bool _isLoading = false;

  // Koordinat lokasi pengguna saat ini (default area Jakarta Pusat)
  double _currentUserLat = -6.200000;
  double _currentUserLng = 106.816666;
  double? _nearestSafeDistanceMeters;

  // Nilai metrik lingkungan hasil kalkulasi dinamis dari Backend API
  double _avgUv = 0.0;
  double _maxUv = 0.0;
  double _minUv = 0.0;

  double _avgTemp = 0.0;
  double _maxTemp = 0.0;
  double _minTemp = 0.0;

  int _avgVoc = 0;
  int _maxVoc = 0;
  int _minVoc = 0;

  @override
  void initState() {
    super.initState();
    _fetchMapData();
  }

  Future<void> _fetchMapData() async {
    setState(() {
      _isLoading = true;
    });

    // 1. Ambil data telemetri terkini pengguna dari SQLite lokal untuk pinpoint lokasi
    final cachedLatest = await LocalDataService.getLatest();
    if (cachedLatest != null && cachedLatest.latitude != null && cachedLatest.longitude != null) {
      _currentUserLat = cachedLatest.latitude!;
      _currentUserLng = cachedLatest.longitude!;
    }

    // 2. Ambil data sebaran spasial mikroiklim dari Backend API Laravel
    var data = await ApiService.getHeatmapData();

    // 3. Fallback cerdas: jika backend offline/kosong, gunakan data historis lokal SQLite
    if (data.isEmpty) {
      final localRecords = await LocalDataService.getHistory(limit: 100);
      data = localRecords.map((r) => r.toMap()).toList();
    }

    if (!mounted) return;

    setState(() {
      _heatmapData = data;
      _isLoading = false;
      _computeMetrics();
    });

    // Posisikan kamera peta ke titik koordinat pengguna
    try {
      _mapController.move(LatLng(_currentUserLat, _currentUserLng), 15.0);
    } catch (_) {}
  }

  /// Menghitung nilai statistik rata-rata, max, min, dan jarak zona aman dari titik telemetri API
  void _computeMetrics() {
    if (_heatmapData.isEmpty) {
      _avgUv = 0.0;
      _avgTemp = 0.0;
      _avgVoc = 0;
      _nearestSafeDistanceMeters = null;
      return;
    }

    double totalUv = 0;
    double totalTemp = 0;
    int totalVoc = 0;
    int uvCount = 0;
    int tempCount = 0;
    int vocCount = 0;

    double maxUv = 0;
    double minUv = 999;
    double maxTemp = 0;
    double minTemp = 999;
    int maxVoc = 0;
    int minVoc = 9999;

    final userPos = LatLng(_currentUserLat, _currentUserLng);
    const distCalc = Distance();
    double? minSafeDist;

    for (var item in _heatmapData) {
      final lat = double.tryParse(item['latitude']?.toString() ?? '');
      final lng = double.tryParse(item['longitude']?.toString() ?? '');

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

      // Hitung jarak riil (geometri bola bumi) ke titik aman terdekat
      if (lat != null && lng != null) {
        bool isSafe = false;
        if (_selectedTab == 'UV') {
          final uv = (item['uv_index'] as num?)?.toDouble() ?? 0.0;
          if (uv < 3.0) isSafe = true;
        } else if (_selectedTab == 'Panas') {
          final temp = (item['temperature'] as num?)?.toDouble() ?? 0.0;
          if (temp < 28.0) isSafe = true;
        } else {
          final voc = (item['voc'] as num?)?.toInt() ?? 0;
          if (voc < 100) isSafe = true;
        }

        if (isSafe) {
          final d = distCalc.as(LengthUnit.Meter, userPos, LatLng(lat, lng));
          if (minSafeDist == null || d < minSafeDist) {
            minSafeDist = d;
          }
        }
      }
    }

    if (uvCount > 0) {
      _avgUv = totalUv / uvCount;
      _maxUv = maxUv;
      _minUv = minUv == 999 ? 0 : minUv;
    }
    if (tempCount > 0) {
      _avgTemp = totalTemp / tempCount;
      _maxTemp = maxTemp;
      _minTemp = minTemp == 999 ? 0 : minTemp;
    }
    if (vocCount > 0) {
      _avgVoc = (totalVoc / vocCount).round();
      _maxVoc = maxVoc;
      _minVoc = minVoc == 9999 ? 0 : minVoc;
    }
    _nearestSafeDistanceMeters = minSafeDist;
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
    // Generate circles dan markers dinamis dari data telemetri backend
    final circles = <CircleMarker>[];
    final markers = <Marker>[];

    for (var item in _heatmapData) {
      final lat = double.tryParse(item['latitude']?.toString() ?? '');
      final lng = double.tryParse(item['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      Color circleColor;
      Color borderColor;

      if (_selectedTab == 'UV') {
        final uv = (item['uv_index'] as num?)?.toDouble() ?? 0.0;
        if (uv >= 8.0) {
          circleColor = const Color(0xFFEF4444).withValues(alpha: 0.35);
          borderColor = const Color(0xFFEF4444);
        } else if (uv >= 3.0) {
          circleColor = const Color(0xFFF59E0B).withValues(alpha: 0.35);
          borderColor = const Color(0xFFF59E0B);
        } else {
          circleColor = const Color(0xFF10B981).withValues(alpha: 0.35);
          borderColor = const Color(0xFF10B981);
        }
      } else if (_selectedTab == 'Panas') {
        final temp = (item['temperature'] as num?)?.toDouble() ?? 0.0;
        if (temp >= 35.0) {
          circleColor = const Color(0xFFEF4444).withValues(alpha: 0.35);
          borderColor = const Color(0xFFEF4444);
        } else if (temp >= 28.0) {
          circleColor = const Color(0xFFF59E0B).withValues(alpha: 0.35);
          borderColor = const Color(0xFFF59E0B);
        } else {
          circleColor = const Color(0xFF10B981).withValues(alpha: 0.35);
          borderColor = const Color(0xFF10B981);
        }
      } else {
        // Udara (VOC)
        final voc = (item['voc'] as num?)?.toInt() ?? 0;
        if (voc >= 250) {
          circleColor = const Color(0xFFEF4444).withValues(alpha: 0.35);
          borderColor = const Color(0xFFEF4444);
        } else if (voc >= 100) {
          circleColor = const Color(0xFFF59E0B).withValues(alpha: 0.35);
          borderColor = const Color(0xFFF59E0B);
        } else {
          circleColor = const Color(0xFF10B981).withValues(alpha: 0.35);
          borderColor = const Color(0xFF10B981);
        }
      }

      circles.add(
        CircleMarker(
          point: LatLng(lat, lng),
          radius: 24,
          useRadiusInMeter: false,
          color: circleColor,
          borderColor: borderColor.withValues(alpha: 0.7),
          borderStrokeWidth: 1.5,
        ),
      );
    }

    // Tambahkan pin penanda lokasi pengguna saat ini
    markers.add(
      Marker(
        point: LatLng(_currentUserLat, _currentUserLng),
        width: 100,
        height: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xDD0F172A) : const Color(0xEEFFFFFF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.5),
                  width: 0.8,
                ),
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
    );

    return Container(
      height: 290,
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
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_currentUserLat, _currentUserLng),
                initialZoom: 15.0,
                minZoom: 11.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.klimo.wearth',
                  tileBuilder: isDark
                      ? (context, tileWidget, tile) {
                          return ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              -0.85, 0, 0, 0, 255,
                              0, -0.85, 0, 0, 255,
                              0, 0, -0.85, 0, 255,
                              0, 0, 0, 1, 0,
                            ]),
                            child: tileWidget,
                          );
                        }
                      : null,
                ),
                CircleLayer(circles: circles),
                MarkerLayer(markers: markers),
              ],
            ),

            // Kontrol Peta: Zoom & Pusat Lokasi Pengguna
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapControlButton(
                    icon: Icons.add,
                    onTap: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildMapControlButton(
                    icon: Icons.remove,
                    onTap: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      );
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildMapControlButton(
                    icon: Icons.my_location,
                    onTap: () {
                      _mapController.move(
                        LatLng(_currentUserLat, _currentUserLng),
                        15.0,
                      );
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Badge Info Peta Spasial
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xDD0F172A) : const Color(0xEEFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.public, size: 12, color: AppTheme.primary),
                    const SizedBox(width: 5),
                    Text(
                      'Peta Spasial Indonesia (OSM)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white : AppTheme.textDark,
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

  String _getRangeString() {
    if (_selectedTab == 'UV') {
      return '${_minUv.toStringAsFixed(1)} - ${_maxUv.toStringAsFixed(1)}';
    } else if (_selectedTab == 'Panas') {
      return '${_minTemp.toStringAsFixed(1)}°C - ${_maxTemp.toStringAsFixed(1)}°C';
    } else {
      return '$_minVoc - $_maxVoc VOC';
    }
  }

  Widget _buildStats(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatChip('Perangkatmu: Aktif', Icons.sensors, isDark),
          const SizedBox(width: 10),
          _buildStatChip(
            'Komunitas: ${_heatmapData.isNotEmpty ? _heatmapData.length : 1} Titik Data',
            Icons.people_outline,
            isDark,
          ),
          if (_heatmapData.isNotEmpty) ...[
            const SizedBox(width: 10),
            _buildStatChip(
              'Rentang: ${_getRangeString()}',
              Icons.analytics_outlined,
              isDark,
            ),
          ],
        ],
      ),
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

    String safeDistanceText;
    if (_nearestSafeDistanceMeters != null) {
      if (_nearestSafeDistanceMeters! < 1000) {
        safeDistanceText = 'Area aman / teduh terdekat ${_nearestSafeDistanceMeters!.round()} m.';
      } else {
        safeDistanceText = 'Area aman / teduh terdekat ${(_nearestSafeDistanceMeters! / 1000).toStringAsFixed(1)} km.';
      }
    } else {
      safeDistanceText = 'Pantau indikator sekitar atau gunakan pelindung diri.';
    }

    if (_selectedTab == 'UV') {
      icon = Icons.wb_sunny_outlined;
      iconColor = _avgUv >= 8 ? const Color(0xFFEF4444) : (_avgUv >= 3 ? const Color(0xFFF59E0B) : AppTheme.primary);
      title = 'Sekitarmu: Rata-rata UV ${_avgUv.toStringAsFixed(1)} (${_avgUv >= 8 ? 'Tinggi/Ekstrem' : (_avgUv >= 3 ? 'Sedang' : 'Aman')})';
      subtitle = _avgUv >= 7
          ? 'Radiasi matahari terik. Disarankan memakai sunscreen & topi. $safeDistanceText'
          : 'Area aman untuk berjalan kaki. $safeDistanceText';
    } else if (_selectedTab == 'Panas') {
      icon = Icons.thermostat_outlined;
      iconColor = _avgTemp >= 35 ? const Color(0xFFEF4444) : (_avgTemp >= 28 ? const Color(0xFFF59E0B) : AppTheme.primary);
      title = 'Sekitarmu: Suhu rata-rata ${_avgTemp.toStringAsFixed(1)}°C';
      subtitle = _avgTemp >= 35
          ? 'Potensi stres panas (heat stress). Perbanyak minum air mineral. $safeDistanceText'
          : 'Suhu lingkungan cukup bersahabat untuk aktivitas luar. $safeDistanceText';
    } else {
      icon = Icons.air;
      iconColor = _avgVoc >= 250 ? const Color(0xFFEF4444) : (_avgVoc >= 100 ? const Color(0xFFF59E0B) : AppTheme.primary);
      title = 'Sekitarmu: Kualitas gas VOC $_avgVoc (${_avgVoc >= 250 ? 'Buruk' : (_avgVoc >= 100 ? 'Sedang' : 'Baik')})';
      subtitle = _avgVoc >= 250
          ? 'Kadar senyawa gas organik tinggi. Disarankan memakai masker. $safeDistanceText'
          : 'Sirkulasi udara segar, ventilasi alami di sekitar baik. $safeDistanceText';
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
