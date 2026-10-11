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
  bool _isMapExpanded = false; // Mode perbesar peta
  bool _isFromApi = false; // Status apakah data dari Server Cloud atau SQLite HP

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
    bool fromCloud = data.isNotEmpty;

    // 3. Fallback cerdas: jika backend offline/kosong, gunakan data historis lokal SQLite
    if (data.isEmpty) {
      final localRecords = await LocalDataService.getHistory(limit: 100);
      data = localRecords.map((r) => r.toMap()).toList();
      fromCloud = false;
    }

    if (!mounted) return;

    setState(() {
      _heatmapData = data;
      _isFromApi = fromCloud;
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
                  'Peta Lingkungan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      _isFromApi ? Icons.cloud_done_outlined : Icons.storage_outlined,
                      size: 13,
                      color: _isFromApi ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isFromApi ? 'Data Komunitas Cloud' : 'Data Lokal HP',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                      ),
                    ),
                  ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
              Expanded(child: _buildTabItem('UV', 'Sinar UV', Icons.wb_sunny_rounded, isDark)),
              Expanded(child: _buildTabItem('Panas', 'Suhu Panas', Icons.thermostat_rounded, isDark)),
              Expanded(child: _buildTabItem('Udara', 'Kualitas Udara', Icons.air_rounded, isDark)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildFilterExplanationBanner(isDark),
      ],
    );
  }

  Widget _buildTabItem(String tabKey, String label, IconData icon, bool isDark) {
    final isActive = _selectedTab == tabKey;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tabKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive
                  ? Colors.white
                  : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterExplanationBanner(bool isDark) {
    IconData icon;
    String title;
    String desc;

    if (_selectedTab == 'UV') {
      icon = Icons.wb_sunny_outlined;
      title = 'Filter Sinar UV (Matahari)';
      desc = 'Menampilkan tingkat radiasi matahari. Berguna untuk memeriksa kebutuhan tabir surya & pelindung sebelum beraktivitas di luar.';
    } else if (_selectedTab == 'Panas') {
      icon = Icons.thermostat_outlined;
      title = 'Filter Suhu Panas Lingkungan';
      desc = 'Menampilkan suhu udara mikro sekitar. Berguna untuk menghindari area panas ekstrem (> 35°C) pemicu dehidrasi.';
    } else {
      icon = Icons.air;
      title = 'Filter Kualitas Udara (Gas VOC)';
      desc = 'Menampilkan kebersihan udara & polusi gas. Berguna untuk mengetahui area mana yang udaranya kotor dan butuh masker.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapVisualization(bool isDark) {
    // Generate circles dan markers interaktif dari data telemetri
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

      // Radius sebaran warna indikator
      circles.add(
        CircleMarker(
          point: LatLng(lat, lng),
          radius: 26,
          useRadiusInMeter: false,
          color: circleColor,
          borderColor: borderColor.withValues(alpha: 0.7),
          borderStrokeWidth: 1.5,
        ),
      );

      // Pin marker interaktif yang dapat di-klik untuk melihat detail
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () => _showMarkerDetail(item),
            child: Container(
              decoration: BoxDecoration(
                color: borderColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.55),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _selectedTab == 'UV'
                    ? Icons.wb_sunny_rounded
                    : (_selectedTab == 'Panas' ? Icons.thermostat_rounded : Icons.air_rounded),
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
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
              width: 15,
              height: 15,
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
                'Posisi Kamu',
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

    final mapHeight = _isMapExpanded ? 520.0 : 290.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: mapHeight,
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

            // Tombol Kontrol Peta: Fullscreen, Zoom, dan Lokasi Saya
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapControlButton(
                    icon: _isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                    onTap: () {
                      setState(() {
                        _isMapExpanded = !_isMapExpanded;
                      });
                    },
                    tooltip: _isMapExpanded ? 'Perkecil Peta' : 'Perbesar Peta',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildMapControlButton(
                    icon: Icons.add,
                    onTap: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
                    },
                    tooltip: 'Perbesar Zoom',
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
                    tooltip: 'Perkecil Zoom',
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
                    tooltip: 'Pusatkan ke Lokasi Saya',
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Badge Info Peta & Jumlah Titik Sensor
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    const Icon(Icons.public, size: 13, color: AppTheme.primary),
                    const SizedBox(width: 5),
                    Text(
                      'Peta Spasial • ${_heatmapData.length} Titik Sensor',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tombol Toggle Perbesar / Perkecil Cepat di Pojok Kanan Atas
            Positioned(
              right: 12,
              top: 12,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isMapExpanded = !_isMapExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xDD0F172A) : const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isMapExpanded ? Icons.fullscreen_exit : Icons.open_in_full,
                        size: 13,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isMapExpanded ? 'Perkecil' : 'Perbesar',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarkerDetail(Map<String, dynamic> item) {
    final uv = (item['uv_index'] as num?)?.toDouble() ?? 0.0;
    final temp = (item['temperature'] as num?)?.toDouble() ?? 0.0;
    final voc = (item['voc'] as num?)?.toInt() ?? 0;
    final lat = double.tryParse(item['latitude']?.toString() ?? '') ?? 0.0;
    final lng = double.tryParse(item['longitude']?.toString() ?? '') ?? 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.place_outlined, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Titik Sensor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Koordinat: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: isDark ? Colors.white : AppTheme.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailMetricTile(
                      icon: Icons.wb_sunny_outlined,
                      label: 'Sinar UV',
                      value: uv.toStringAsFixed(1),
                      status: uv >= 8.0 ? 'Bahaya' : (uv >= 3.0 ? 'Waspada' : 'Aman'),
                      statusColor: uv >= 8.0
                          ? const Color(0xFFEF4444)
                          : (uv >= 3.0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDetailMetricTile(
                      icon: Icons.thermostat_outlined,
                      label: 'Suhu',
                      value: '${temp.toStringAsFixed(1)}°C',
                      status: temp >= 35.0 ? 'Terik' : (temp >= 28.0 ? 'Hangat' : 'Sejuk'),
                      statusColor: temp >= 35.0
                          ? const Color(0xFFEF4444)
                          : (temp >= 28.0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDetailMetricTile(
                      icon: Icons.air,
                      label: 'Kualitas Udara',
                      value: '$voc',
                      status: voc >= 250 ? 'Bahaya' : (voc >= 100 ? 'Sedang' : 'Bersih'),
                      statusColor: voc >= 250
                          ? const Color(0xFFEF4444)
                          : (voc >= 100 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF101B2B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getRecommendationForPoint(uv, temp, voc),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getRecommendationForPoint(double uv, double temp, int voc) {
    if (uv >= 8.0) return 'Area ini terik matahari ekstrem. Disarankan berteduh dan wajib tabir surya.';
    if (temp >= 35.0) return 'Area ini bersuhu sangat panas. Waspadai dehidrasi dan perbanyak minum air.';
    if (voc >= 250) return 'Kadar polusi gas tinggi di area ini. Disarankan memakai masker.';
    return 'Kondisi lingkungan di area ini relatif aman untuk beraktivitas.';
  }

  Widget _buildDetailMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required String status,
    required Color statusColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101B2B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
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
            size: 19,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    String safeLabel;
    String safeRange;
    String warnLabel;
    String warnRange;
    String dangerLabel;
    String dangerRange;

    if (_selectedTab == 'UV') {
      safeLabel = 'Aman';
      safeRange = 'Indeks < 3';
      warnLabel = 'Waspada';
      warnRange = 'Indeks 3 - 7';
      dangerLabel = 'Bahaya';
      dangerRange = 'Indeks 8+';
    } else if (_selectedTab == 'Panas') {
      safeLabel = 'Sejuk';
      safeRange = 'Suhu < 28°C';
      warnLabel = 'Hangat';
      warnRange = 'Suhu 28 - 34°C';
      dangerLabel = 'Terik Panas';
      dangerRange = 'Suhu ≥ 35°C';
    } else {
      safeLabel = 'Bersih';
      safeRange = 'Gas < 100';
      warnLabel = 'Sedang';
      warnRange = 'Gas 100 - 249';
      dangerLabel = 'Tercemar';
      dangerRange = 'Gas ≥ 250';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.greyLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Makna Warna Titik Sensor:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const Spacer(),
              Text(
                'Klik titik di peta untuk detail',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFF10B981),
                  icon: Icons.check_circle_outline,
                  status: safeLabel,
                  desc: safeRange,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFFF59E0B),
                  icon: Icons.warning_amber_rounded,
                  status: warnLabel,
                  desc: warnRange,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFFEF4444),
                  icon: Icons.error_outline,
                  status: dangerLabel,
                  desc: dangerRange,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required IconData icon,
    required String status,
    required String desc,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textDark,
            ),
          ),
        ],
      ),
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
          _buildStatChip('Posisi Kamu: Pin Biru', Icons.my_location, isDark),
          const SizedBox(width: 10),
          _buildStatChip(
            'Sumber: ${_isFromApi ? "Server Cloud" : "Lokal HP"}',
            _isFromApi ? Icons.cloud_outlined : Icons.storage_outlined,
            isDark,
          ),
          const SizedBox(width: 10),
          _buildStatChip(
            'Data: ${_heatmapData.isNotEmpty ? _heatmapData.length : 1} Titik Sensor',
            Icons.pin_drop_outlined,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132D27) : const Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_location_outlined, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Bagikan Lokasi Anonim',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _shareLocation
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _shareLocation ? 'Aktif' : 'Privat',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _shareLocation ? const Color(0xFF10B981) : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Data sensor perangkatmu dikirim tanpa identitas pribadi untuk membantu pengguna lain melihat kondisi lingkungan area ini. Jika dimatikan, kamu hanya melihat data tanpa berkontribusi.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
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
                        ? 'Berbagi lokasi sensor anonim diaktifkan. Kontribusi data aktif.'
                        : 'Berbagi lokasi dinonaktifkan (mode privat).',
                  ),
                  duration: const Duration(seconds: 2),
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
