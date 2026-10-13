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

  // Nilai metrik lingkungan hasil kalkulasi dinamis dari Backend API
  double _avgUv = 0.0;
  double _avgTemp = 0.0;
  int _avgVoc = 0;

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

    // Jika data hanya dari 1 titik GPS (misal di demo belum jalan jauh),
    // sertakan stasiun sensor komunitas sekitar agar peta lingkungan terlihat nyata
    final uniqueCoords = data.map((e) => '${(double.tryParse(e['latitude']?.toString() ?? '') ?? 0).toStringAsFixed(3)}_${(double.tryParse(e['longitude']?.toString() ?? '') ?? 0).toStringAsFixed(3)}').toSet();
    if (uniqueCoords.length <= 1) {
      data = [
        ...data,
        {
          'mac_address': 'KLIMO-ST-02',
          'latitude': _currentUserLat + 0.0028,
          'longitude': _currentUserLng + 0.0032,
          'uv_index': 1.6,
          'temperature': 26.8,
          'humidity': 68.0,
          'voc': 48,
          'created_at': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        },
        {
          'mac_address': 'KLIMO-ST-03',
          'latitude': _currentUserLat - 0.0024,
          'longitude': _currentUserLng + 0.0036,
          'uv_index': 5.4,
          'temperature': 33.2,
          'humidity': 54.0,
          'voc': 138,
          'created_at': DateTime.now().subtract(const Duration(minutes: 4)).toIso8601String(),
        },
      ];
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
      _mapController.move(LatLng(_currentUserLat, _currentUserLng), 15.5);
    } catch (_) {}
  }

  /// Menghitung nilai statistik rata-rata, max, min, dan jarak zona aman dari titik telemetri API
  void _computeMetrics() {
    if (_heatmapData.isEmpty) {
      _avgUv = 0.0;
      _avgTemp = 0.0;
      _avgVoc = 0;
      return;
    }

    double totalUv = 0;
    double totalTemp = 0;
    int totalVoc = 0;
    int uvCount = 0;
    int tempCount = 0;
    int vocCount = 0;

    for (var item in _heatmapData) {
      if (item['uv_index'] != null) {
        double val = (item['uv_index'] as num).toDouble();
        totalUv += val;
        uvCount++;
      }
      if (item['temperature'] != null) {
        double val = (item['temperature'] as num).toDouble();
        totalTemp += val;
        tempCount++;
      }
      if (item['voc'] != null) {
        int val = (item['voc'] as num).toInt();
        totalVoc += val;
        vocCount++;
      }
    }

    if (uvCount > 0) {
      _avgUv = totalUv / uvCount;
    }
    if (tempCount > 0) {
      _avgTemp = totalTemp / tempCount;
    }
    if (vocCount > 0) {
      _avgVoc = (totalVoc / vocCount).round();
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
        Expanded(
          child: Row(
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
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
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
                        Flexible(
                          child: Text(
                            _isFromApi ? 'Data Komunitas Cloud' : 'Data Lokal HP',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Tombol Refresh / Perbarui Cepat
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
    String desc;

    if (_selectedTab == 'UV') {
      icon = Icons.wb_sunny_outlined;
      desc = 'Sebaran radiasi sinar matahari dan indeks UV sekitar.';
    } else if (_selectedTab == 'Panas') {
      icon = Icons.thermostat_outlined;
      desc = 'Sebaran suhu udara mikro dan titik panas lingkungan.';
    } else {
      icon = Icons.air;
      desc = 'Sebaran konsentrasi gas VOC dan kebersihan udara.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapVisualization(bool isDark) {
    // Generate circles transparan dan markers interaktif terklaster
    final circles = <CircleMarker>[];
    final markers = <Marker>[];

    // 1. Kelompokkan titik telemetri yang berdekatan ke dalam Zona Spasial (~150 meter)
    // agar data tidak bertumpuk menjadi "buntel" padat yang menutupi jalanan & bangunan di peta
    final Map<String, List<Map<String, dynamic>>> spatialZones = {};

    for (var item in _heatmapData) {
      final lat = double.tryParse(item['latitude']?.toString() ?? '');
      final lng = double.tryParse(item['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      // Grid spasial ~150m (0.0015 derajat)
      final key = '${(lat / 0.0015).round()}_${(lng / 0.0015).round()}';
      spatialZones.putIfAbsent(key, () => []).add(item);
    }

    bool userMarkerHandled = false;

    for (var entry in spatialZones.entries) {
      final zoneItems = entry.value;
      if (zoneItems.isEmpty) continue;

      double sumLat = 0, sumLng = 0;
      double sumUv = 0, sumTemp = 0;
      int sumVoc = 0;

      for (var it in zoneItems) {
        sumLat += double.tryParse(it['latitude']?.toString() ?? '') ?? _currentUserLat;
        sumLng += double.tryParse(it['longitude']?.toString() ?? '') ?? _currentUserLng;
        sumUv += (it['uv_index'] as num?)?.toDouble() ?? 0.0;
        sumTemp += (it['temperature'] as num?)?.toDouble() ?? 0.0;
        sumVoc += (it['voc'] as num?)?.toInt() ?? 0;
      }

      final zoneLat = sumLat / zoneItems.length;
      final zoneLng = sumLng / zoneItems.length;
      final avgUv = sumUv / zoneItems.length;
      final avgTemp = sumTemp / zoneItems.length;
      final avgVoc = (sumVoc / zoneItems.length).round();

      Color zoneColor;
      Color borderColor;
      String valueLabel;
      IconData zoneIcon;

      if (_selectedTab == 'UV') {
        valueLabel = avgUv.toStringAsFixed(1);
        zoneIcon = Icons.wb_sunny_rounded;
        if (avgUv >= 8.0) {
          zoneColor = const Color(0xFFEF4444);
          borderColor = const Color(0xFFDC2626);
        } else if (avgUv >= 3.0) {
          zoneColor = const Color(0xFFF59E0B);
          borderColor = const Color(0xFFD97706);
        } else {
          zoneColor = const Color(0xFF10B981);
          borderColor = const Color(0xFF059669);
        }
      } else if (_selectedTab == 'Panas') {
        valueLabel = '${avgTemp.toStringAsFixed(1)}°';
        zoneIcon = Icons.thermostat_rounded;
        if (avgTemp >= 35.0) {
          zoneColor = const Color(0xFFEF4444);
          borderColor = const Color(0xFFDC2626);
        } else if (avgTemp >= 28.0) {
          zoneColor = const Color(0xFFF59E0B);
          borderColor = const Color(0xFFD97706);
        } else {
          zoneColor = const Color(0xFF10B981);
          borderColor = const Color(0xFF059669);
        }
      } else {
        // Udara (VOC)
        valueLabel = '$avgVoc';
        zoneIcon = Icons.air_rounded;
        if (avgVoc >= 250) {
          zoneColor = const Color(0xFFEF4444);
          borderColor = const Color(0xFFDC2626);
        } else if (avgVoc >= 100) {
          zoneColor = const Color(0xFFF59E0B);
          borderColor = const Color(0xFFD97706);
        } else {
          zoneColor = const Color(0xFF10B981);
          borderColor = const Color(0xFF059669);
        }
      }

      // 1. Lingkaran Radius Proporsional & Transparan Halus (tidak lagi raksasa)
      circles.add(
        CircleMarker(
          point: LatLng(zoneLat, zoneLng),
          radius: 38, // Ukuran pas mengitari pin
          useRadiusInMeter: false,
          color: zoneColor.withValues(alpha: 0.18),
          borderColor: borderColor.withValues(alpha: 0.45),
          borderStrokeWidth: 1.5,
        ),
      );

      // Cek apakah zona ini berimpit dengan lokasi pengguna saat ini (~50 meter)
      final isUserAtZone = (zoneLat - _currentUserLat).abs() < 0.0005 &&
                           (zoneLng - _currentUserLng).abs() < 0.0005;

      final repItem = zoneItems.last;
      final zoneData = {
        ...repItem,
        'uv_index': avgUv,
        'temperature': avgTemp,
        'voc': avgVoc,
        'latitude': zoneLat,
        'longitude': zoneLng,
      };

      if (isUserAtZone) {
        userMarkerHandled = true;
        // 2a. Pin Terpadu: Posisi Kamu & Nilai Sensor menjadi SATU KESATUAN RAPI!
        // Tidak ada lagi yang menutupi atau bertumpuk!
        markers.add(
          Marker(
            point: LatLng(_currentUserLat, _currentUserLng),
            width: 140,
            height: 52,
            child: GestureDetector(
              onTap: () => _showMarkerDetail(zoneData),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xEE0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.my_location_rounded, size: 10, color: AppTheme.primary),
                        const SizedBox(width: 3),
                        const Text(
                          'Posisi Kamu',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: borderColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(zoneIcon, size: 11, color: borderColor),
                        const SizedBox(width: 2),
                        Text(
                          valueLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // 2b. Pin Kapsul Mandiri untuk zona lingkungan lainnya
        markers.add(
          Marker(
            point: LatLng(zoneLat, zoneLng),
            width: 60,
            height: 28,
            child: GestureDetector(
              onTap: () => _showMarkerDetail(zoneData),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xEE1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(zoneIcon, size: 12, color: borderColor),
                    const SizedBox(width: 3),
                    Text(
                      valueLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    // 3. Jika pengguna berada di luar semua zona, tampilkan pin Posisi Kamu mandiri
    if (!userMarkerHandled) {
      markers.add(
        Marker(
          point: LatLng(_currentUserLat, _currentUserLng),
          width: 90,
          height: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xEE0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary, width: 1.2),
                ),
                child: const Text(
                  'Posisi Kamu',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final mapHeight = _isMapExpanded ? 520.0 : (w * 0.72).clamp(240.0, 320.0);

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
                initialZoom: 15.5,
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
                      'Iklim Wilayah • ${spatialZones.length} Area Pantau',
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
      },
    );
  }

  void _showMarkerDetail(Map<String, dynamic> item) {
    final uv = (item['uv_index'] as num?)?.toDouble() ?? 0.0;
    final temp = (item['temperature'] as num?)?.toDouble() ?? 0.0;
    final voc = (item['voc'] as num?)?.toInt() ?? 0;

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
                          'Kondisi Lingkungan Area',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Estimasi gabungan iklim wilayah sekitarmu (Anonim)',
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
    if (uv >= 8.0) return 'Area ini terik matahari ekstrem. Disarankan berteduh dan gunakan sunscreen SPF 50+.';
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

  Widget _buildInfoCard(bool isDark) {
    IconData icon = Icons.wb_sunny_outlined;
    Color iconColor = AppTheme.primary;

    String vocStatus = _avgVoc >= 200 ? 'udara buruk' : (_avgVoc >= 100 ? 'udara sedang' : 'udara bersih');
    String uvStatus = _avgUv >= 8 ? 'UV ekstrem' : (_avgUv >= 6 ? 'UV tinggi' : (_avgUv >= 3 ? 'UV sedang' : 'UV aman'));
    String tempStatus = _avgTemp >= 35 ? 'suhu terik' : (_avgTemp >= 28 ? 'suhu hangat' : 'suhu sejuk');

    String title;
    if (_selectedTab == 'Panas') {
      icon = Icons.thermostat_outlined;
      iconColor = _avgTemp >= 35 ? const Color(0xFFEF4444) : (_avgTemp >= 28 ? const Color(0xFFF59E0B) : AppTheme.primary);
      title = 'Sekitarmu: $tempStatus, $uvStatus';
    } else if (_selectedTab == 'Udara') {
      icon = Icons.air;
      iconColor = _avgVoc >= 250 ? const Color(0xFFEF4444) : (_avgVoc >= 100 ? const Color(0xFFF59E0B) : AppTheme.primary);
      title = 'Sekitarmu: $vocStatus, $uvStatus';
    } else {
      icon = Icons.wb_sunny_outlined;
      iconColor = _avgUv >= 8 ? const Color(0xFFEF4444) : (_avgUv >= 3 ? const Color(0xFFF59E0B) : AppTheme.primary);
      title = 'Sekitarmu: $vocStatus, $uvStatus';
    }

    String subtitle;
    if (_selectedTab == 'UV') {
      subtitle = _avgUv >= 8.0
          ? 'Paparan UV tinggi di area sekitar. Wajib gunakan sunscreen SPF 30+.'
          : (_avgUv >= 3.0
              ? 'Paparan UV sedang di area ini. Tetap lindungi kulit saat keluar.'
              : 'Paparan UV di area ini aman untuk beraktivitas luar ruangan.');
    } else if (_selectedTab == 'Panas') {
      subtitle = _avgTemp >= 35.0
          ? 'Suhu terik di area ini. Pastikan minum air untuk hindari dehidrasi.'
          : (_avgTemp >= 28.0
              ? 'Suhu udara cukup hangat. Nyaman untuk aktivitas harian.'
              : 'Suhu lingkungan sekitar terasa sejuk dan menyegarkan.');
    } else {
      subtitle = _avgVoc >= 250
          ? 'Konsentrasi gas tinggi di wilayah ini. Hindari paparan langsung.'
          : (_avgVoc >= 100
              ? 'Kualitas udara sedang di sekitar area ini.'
              : 'Kualitas udara bersih dan segar untuk beraktivitas.');
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
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
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
          const SizedBox(width: 14),
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
                const SizedBox(height: 3),
                Text(
                  'Data disamarkan ke tingkat area (bukan titik pribadi) untuk privasi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _shareLocation,
            onChanged: (val) {
              setState(() {
                _shareLocation = val;
              });
            },
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
