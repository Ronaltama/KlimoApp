import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/local_data_service.dart';
import '../services/api_service.dart';

class HistoryDetailScreen extends StatefulWidget {
  final List<dynamic>? initialData;

  const HistoryDetailScreen({super.key, this.initialData});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  List<dynamic> _allLogs = [];
  bool _isLoading = true;
  DateTime? _selectedDate; // null berarti tampilkan semua data

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _allLogs = List.from(widget.initialData!);
      _isLoading = false;
    } else {
      _fetchLogs();
    }
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final localData = await LocalDataService.getHistory(limit: 300);
      if (localData.isNotEmpty) {
        final mapped = localData.map((r) => {
          'uv_index': r.uvIndex,
          'temperature': r.temperature,
          'humidity': r.humidity,
          'voc': r.voc,
          'created_at': r.timestamp.toIso8601String(),
          'source': 'SQLite Lokal',
        }).toList();
        if (mounted) {
          setState(() {
            _allLogs = mapped;
            _isLoading = false;
          });
        }
        return;
      }

      final apiData = await ApiService.getHistoryData();
      if (mounted) {
        setState(() {
          _allLogs = apiData;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredLogs {
    if (_selectedDate == null) return _allLogs;
    return _allLogs.where((item) {
      final raw = item['created_at'] ?? item['timestamp'];
      if (raw == null) return false;
      final dt = DateTime.tryParse(raw.toString())?.toLocal();
      if (dt == null) return false;
      return dt.year == _selectedDate!.year &&
          dt.month == _selectedDate!.month &&
          dt.day == _selectedDate!.day;
    }).toList();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
      helpText: 'Pilih Tanggal Rekaman',
      confirmText: 'Pilih',
      cancelText: 'Batal',
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: isDark ? AppTheme.darkCard : Colors.white,
              onSurface: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatDateShort(DateTime dt) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredLogs;

    // Hitung rata-rata data yang difilter
    double maxUv = 0;
    double sumTemp = 0;
    int sumVoc = 0;
    for (var item in filtered) {
      final uv = (item['uv_index'] as num?)?.toDouble() ?? 0.0;
      final temp = (item['temperature'] as num?)?.toDouble() ?? 0.0;
      final voc = (item['voc'] as num?)?.toInt() ?? 0;
      if (uv > maxUv) maxUv = uv;
      sumTemp += temp;
      sumVoc += voc;
    }
    final avgTemp = filtered.isNotEmpty ? (sumTemp / filtered.length).toStringAsFixed(1) : '-';
    final avgVoc = filtered.isNotEmpty ? (sumVoc / filtered.length).round().toString() : '-';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : AppTheme.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Detail Rekaman Sensor',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : AppTheme.textDark),
            tooltip: 'Muat ulang',
            onPressed: _fetchLogs,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Baris Filter Tanggal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: isDark ? AppTheme.darkCard : Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _selectedDate != null
                                    ? AppTheme.primary
                                    : (isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedDate == null
                                        ? 'Semua Tanggal (Filter)'
                                        : _formatDateShort(_selectedDate!),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _selectedDate != null ? FontWeight.bold : FontWeight.w500,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : AppTheme.textLight),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_selectedDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => setState(() => _selectedDate = null),
                          tooltip: 'Reset Filter',
                          icon: const Icon(Icons.clear, color: Color(0xFFEF4444), size: 20),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Quick Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickChip(
                          label: 'Semua',
                          isSelected: _selectedDate == null,
                          onTap: () => setState(() => _selectedDate = null),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                          label: 'Hari Ini',
                          isSelected: _selectedDate != null &&
                              _selectedDate!.year == DateTime.now().year &&
                              _selectedDate!.month == DateTime.now().month &&
                              _selectedDate!.day == DateTime.now().day,
                          onTap: () => setState(() => _selectedDate = DateTime.now()),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                          label: 'Kemarin',
                          isSelected: _selectedDate != null &&
                              _selectedDate!.year == DateTime.now().subtract(const Duration(days: 1)).year &&
                              _selectedDate!.month == DateTime.now().subtract(const Duration(days: 1)).month &&
                              _selectedDate!.day == DateTime.now().subtract(const Duration(days: 1)).day,
                          onTap: () => setState(() => _selectedDate = DateTime.now().subtract(const Duration(days: 1))),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                          label: 'Pilih Tanggal...',
                          isSelected: false,
                          onTap: _pickDate,
                          isDark: isDark,
                          icon: Icons.calendar_month,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Ringkasan Mini Stats
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('Total Record', '${filtered.length}', AppTheme.primary, isDark),
                  _buildMiniStat('Puncak UV', filtered.isNotEmpty ? maxUv.toStringAsFixed(1) : '-', const Color(0xFFF59E0B), isDark),
                  _buildMiniStat('Rata-rata Suhu', avgTemp != '-' ? '$avgTemp°C' : '-', AppTheme.primary, isDark),
                  _buildMiniStat('Rata-rata VOC', avgVoc, const Color(0xFF10B981), isDark),
                ],
              ),
            ),

            // Daftar List Item
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 48,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada rekaman data sensor',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedDate != null
                                    ? 'Coba pilih tanggal lain atau reset filter.'
                                    : 'Belum ada data rekaman sensor tersimpan.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return _buildRecordCard(filtered[index], isDark);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isSelected ? Colors.white : AppTheme.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
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
      ],
    );
  }

  Widget _buildRecordCard(dynamic item, bool isDark) {
    DateTime? dt;
    final raw = item['created_at'] ?? item['timestamp'];
    if (raw != null) {
      dt = DateTime.tryParse(raw.toString())?.toLocal();
    }

    final double uv = (item['uv_index'] as num?)?.toDouble() ?? 0.0;
    final double temp = (item['temperature'] as num?)?.toDouble() ?? 0.0;
    final double hum = (item['humidity'] as num?)?.toDouble() ?? 0.0;
    final int voc = (item['voc'] as num?)?.toInt() ?? 0;

    String dateStr = dt != null ? _formatDateShort(dt) : 'Tanggal tidak tersedia';
    String timeStr = dt != null
        ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}'
        : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
                  const SizedBox(width: 6),
                  Text(
                    '$dateStr • $timeStr',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              if (item['source'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item['source'],
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildBadge(
                  Icons.wb_sunny_outlined,
                  'UV ${uv.toStringAsFixed(1)}',
                  uv >= 8 ? const Color(0xFFEF4444) : (uv >= 3 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                  isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBadge(
                  Icons.thermostat_outlined,
                  '${temp.toStringAsFixed(1)}°C',
                  temp >= 35 ? const Color(0xFFEF4444) : (temp >= 28 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                  isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBadge(
                  Icons.water_drop_outlined,
                  '${hum.toStringAsFixed(0)}%',
                  AppTheme.primary,
                  isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBadge(
                  Icons.air,
                  'VOC $voc',
                  voc >= 200 ? const Color(0xFFEF4444) : (voc >= 100 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
