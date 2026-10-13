import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'uv_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _VocPoint {
  final DateTime time;
  final double value;
  const _VocPoint(this.time, this.value);
}

class _HomeScreenState extends State<HomeScreen> {
  // ---------- Pengaturan ----------
  static const _userName = 'Budi'; // TODO: ambil dari profil user
  static const _reapplyEvery = Duration(hours: 2);
  static const _drinkEvery = Duration(hours: 1);
  static const _vocWindow = Duration(minutes: 10);
  static const _prefOles = 'last_oles_ms';
  static const _prefDrink = 'last_drink_ms';

  // Ukuran huruf. Hanya 6 ukuran dipakai di seluruh layar ini.
  static const _fsCaption = 11.0; // label kecil di atas angka
  static const _fsSmall = 12.0; // keterangan
  static const _fsBody = 13.0; // teks kalimat
  static const _fsTitle = 15.0; // judul kartu
  static const _fsBig = 28.0; // angka utama
  static const _fsStatus = 30.0; // WASPADA / AMAN

  // Batas harian dalam satuan "indeks UV x jam" (perkiraan, sesuaikan)
  static const _dailyLimit = {
    'Tipe I': 10.0,
    'Tipe II': 12.0,
    'Tipe III': 15.0,
    'Tipe IV': 18.0,
    'Tipe V': 22.0,
    'Tipe VI': 27.0,
  };

  // ---------- State ----------
  Map<String, dynamic>? _data;
  String _skin = 'Tipe IV';
  DateTime? _lastOles;
  DateTime? _lastDrink;
  DateTime? _lastSample;
  double _exposure = 0;
  final List<_VocPoint> _vocHistory = [];
  String? _lastKey;
  bool _loading = true;
  bool _online = false;

  Timer? _pollTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final olesMs = prefs.getInt(_prefOles);
    final drinkMs = prefs.getInt(_prefDrink);
    final skin = await ApiService.getSkinType();
    if (!mounted) return;

    setState(() {
      _lastOles = olesMs == null ? null : DateTime.fromMillisecondsSinceEpoch(olesMs);
      _lastDrink = drinkMs == null ? null : DateTime.fromMillisecondsSinceEpoch(drinkMs);
      _skin = skin;
    });

    await _fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetch({bool manual = false}) async {
    final data = await ApiService.getLatestTelemetry();
    if (!mounted) return;

    setState(() {
      _loading = false;
      _online = data != null;
      if (data != null) _ingest(data);
    });

    if (manual) {
      _notify(
        data == null
            ? 'Gagal memuat data. Pastikan alat menyala dan terhubung.'
            : 'Data berhasil diperbarui.',
        error: data == null,
      );
    }
  }

  /// Memproses satu pembacaan. Pembacaan yang sama tidak dihitung dua kali.
  void _ingest(Map<String, dynamic> d) {
    _data = d;
    final key = d['created_at']?.toString() ?? '';
    if (key.isEmpty || key == _lastKey) return;
    _lastKey = key;

    final t = _parse(key);
    final uv = _num(d['uv_index']);
    final voc = _num(d['voc']);

    // Ganti hari: total paparan mulai dari nol lagi
    if (_lastSample != null && !_sameDay(_lastSample!, t)) {
      _exposure = 0;
    }

    // Tambah paparan: UV x lamanya waktu sejak pembacaan sebelumnya
    if (_lastSample != null) {
      final hours = t.difference(_lastSample!).inSeconds / 3600;
      // Jeda lebih dari 1 jam dianggap alat mati, tidak dihitung
      if (hours > 0 && hours <= 1) _exposure += uv * hours;
    }
    _lastSample = t;

    // Simpan riwayat VOC untuk menghitung kenaikan
    _vocHistory.add(_VocPoint(t, voc));
    _vocHistory.removeWhere((e) => t.difference(e.time) > const Duration(minutes: 30));
  }

  Future<void> _markOles() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefOles, now.millisecondsSinceEpoch);
    if (!mounted) return;

    setState(() => _lastOles = now);
    _notify('Oles tercatat pukul ${_hhmm(now)}. Oles lagi dalam 2 jam.');
  }

  Future<void> _markDrink() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefDrink, now.millisecondsSinceEpoch);
    if (!mounted) return;

    setState(() => _lastDrink = now);
    _notify('Minum tercatat pukul ${_hhmm(now)}. Minum lagi dalam 1 jam.');
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

  // ---------- Nilai turunan ----------

  double get _uv => _num(_data?['uv_index']);
  double get _temp => _num(_data?['temperature']);
  double get _humidity => _num(_data?['humidity']);
  double get _voc => _num(_data?['voc']);
  double get _lux => _num(_data?['lux']);

  double get _limit => _dailyLimit[_skin] ?? 18.0;
  double get _progress => (_exposure / _limit).clamp(0.0, 1.0);
  int get _percent => (_progress * 100).round();

  String get _skinText => _skin.replaceFirst('Tipe ', 'tipe ');

  bool get _isWarning => _uv >= 6 || _temp > 35 || _voc >= 200;

  String get _uvLabel {
    final u = _uv;
    if (u >= 11) return 'Ekstrem';
    if (u >= 8) return 'Sangat tinggi';
    if (u >= 6) return 'Tinggi';
    if (u >= 3) return 'Sedang';
    return 'Rendah';
  }

  String get _vocLabel {
    if (_voc >= 200) return 'Buruk';
    if (_voc >= 100) return 'Sedang';
    return 'Baik';
  }

  String get _vocTrend {
    if (_vocHistory.length < 2) return 'Data belum cukup';
    final latest = _vocHistory.last;
    final cutoff = latest.time.subtract(_vocWindow);
    final past = _vocHistory.firstWhere(
      (e) => !e.time.isBefore(cutoff),
      orElse: () => _vocHistory.first,
    );
    final diff = latest.value - past.value;
    if (diff.abs() < 1) return 'Tidak berubah';
    return diff > 0
        ? 'Naik ${diff.round()} dalam 10 menit terakhir'
        : 'Turun ${diff.abs().round()} dalam 10 menit terakhir';
  }

  String get _vocArrow {
    if (_vocHistory.length < 2) return '';
    final diff = _vocHistory.last.value - _vocHistory.first.value;
    if (diff > 1) return ' ↑';
    if (diff < -1) return ' ↓';
    return '';
  }

  Duration? get _untilReapply {
    if (_lastOles == null) return null;
    final r = _lastOles!.add(_reapplyEvery).difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  Duration? get _untilDrink {
    if (_lastDrink == null) return null;
    final r = _lastDrink!.add(_drinkEvery).difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetch(manual: true),
          color: p.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _header(p),
              const SizedBox(height: 20),
              _statusCard(p),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _uvCard(p)),
                    const SizedBox(width: 14),
                    Expanded(child: _airCard(p)),
                  ],
                ),
              ),
              if (_voc >= 100) ...[
                const SizedBox(height: 14),
                _pollutionBanner(p),
              ],
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _sunscreenCard(p)),
                    const SizedBox(width: 14),
                    Expanded(child: _drinkCard(p)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Bagian-bagian layar ----------

  Widget _header(AppPalette p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);
    final batteryText = _data?['battery'] == null
        ? '--%'
        : '${_num(_data?['battery']).round()}%';

    return Row(
      children: [
        if (canPop) ...[
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.chevron_left, size: 28, color: p.textPrimary),
          ),
          const SizedBox(width: 4),
        ],
        CircleAvatar(
          radius: 22,
          backgroundColor: isDark ? p.card : const Color(0xFFD1FAE5),
          child: Icon(Icons.person, color: p.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HALO,',
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: _fsCaption,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _userName,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _fetch(manual: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync, size: 12, color: p.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    _syncText,
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: _fsCaption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.battery_std_rounded, size: 14, color: p.primary),
                  const SizedBox(width: 4),
                  Text(
                    batteryText,
                    style: TextStyle(
                      color: p.primary,
                      fontSize: _fsSmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _notify('Belum ada notifikasi baru.'),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.card,
              shape: BoxShape.circle,
              border: Border.all(color: p.cardBorder),
            ),
            child: Icon(Icons.notifications_none, size: 20, color: p.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _statusCard(AppPalette p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warn = _isWarning;
    final noData = _data == null;

    final bg = isDark
        ? p.card
        : (warn ? const Color(0xFFFDE68A) : const Color(0xFFD1FAE5));
    final titleColor = isDark
        ? p.textPrimary
        : (warn ? const Color(0xFF422006) : const Color(0xFF064E3B));
    final bodyColor = isDark
        ? p.textSecondary
        : (warn ? const Color(0xFF78350F) : const Color(0xFF065F46));
    final tagBg = isDark ? p.bg : Colors.white.withValues(alpha: 0.7);
    final sunColor = warn
        ? Colors.amber.withValues(alpha: 0.25)
        : Colors.green.withValues(alpha: 0.15);

    final statusTitle = noData ? 'MENUNGGU DATA' : (warn ? 'WASPADA' : 'AMAN');
    final description = noData
        ? 'Alat belum mengirim data.'
        : warn
            ? 'Terik dan udara mulai kotor. Pakai masker, cari tempat teduh.'
            : 'Kondisi cukup bersahabat. Tetap pantau sekitar.';

    return GestureDetector(
      onTap: () => _notify(
        warn
            ? 'Kurangi jemur. Pakai masker dan cari tempat teduh.'
            : 'Kondisi aman. Tetap pantau sekitar.',
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? p.cardBorder : Colors.transparent),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -6,
                right: -6,
                child: Icon(Icons.wb_sunny_outlined, size: 96, color: sunColor),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS SEKARANG',
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: _fsCaption,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusTitle,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: _fsStatus,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: _fsBody,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _tag(
                        icon: Icons.wb_sunny_outlined,
                        label: _uv >= 6 ? 'Terik' : 'Tidak terik',
                        color: titleColor,
                        background: tagBg,
                      ),
                      _tag(
                        icon: Icons.thermostat_outlined,
                        label: 'Terasa ${_temp.round()}°',
                        color: titleColor,
                        background: tagBg,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _uvCard(AppPalette p) {
    final value = _data == null ? '-' : _uv.round().toString();
    final status = !_online && !_loading
        ? 'Alat belum terhubung'
        : _loading
            ? 'Memuat...'
            : _uvLabel;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UVDetailScreen()),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SINAR UV',
              style: TextStyle(
                color: p.primary,
                fontSize: _fsCaption,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: _fsBig,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(color: p.textSecondary, fontSize: _fsBody),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: p.divider,
                valueColor: AlwaysStoppedAnimation<Color>(p.orange),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_percent% batas kulit',
              style: TextStyle(color: p.textMuted, fontSize: _fsCaption),
            ),
          ],
        ),
      ),
    );
  }

  Widget _airCard(AppPalette p) {
    final value = _data == null ? '-' : _vocLabel;
    final arrow = _vocArrow;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _notify(
          'Indeks gas VOC ${_voc.round()}. Di bawah 100 itu baik.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KUALITAS UDARA',
              style: TextStyle(
                color: p.primary,
                fontSize: _fsCaption,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: _fsBig,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Indeks ${_voc.round()}$arrow',
              style: TextStyle(color: p.textSecondary, fontSize: _fsBody),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_voc / 500).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: p.divider,
                valueColor: AlwaysStoppedAnimation<Color>(p.danger),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _vocTrend,
              style: TextStyle(color: p.textMuted, fontSize: _fsCaption),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pollutionBanner(AppPalette p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _notify('Pakai masker saat di luar. Pindah ke ruang yang lebih bersih jika bisa.'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? p.card : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? p.cardBorder : const Color(0xFFFDE68A),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 22,
              color: isDark ? p.orange : const Color(0xFFD97706),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: isDark ? p.textSecondary : const Color(0xFF78350F),
                    fontSize: _fsBody,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: 'Polusi gas naik. ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? p.textPrimary : const Color(0xFF78350F),
                      ),
                    ),
                    const TextSpan(
                      text: 'Disarankan pakai masker atau pindah sebentar.',
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

  Widget _sunscreenCard(AppPalette p) {
    final remaining = _untilReapply;
    final isDue = remaining == Duration.zero;

    final value = remaining == null
        ? '--:--'
        : (isDue ? '00:00' : _mmss(remaining));
    final sub = remaining == null
        ? 'Belum dicatat'
        : isDue
            ? 'Waktunya oles lagi'
            : 'lagi';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, size: 16, color: p.primary),
              const SizedBox(width: 8),
              Text(
                'Sunscreen',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: _fsTitle,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: isDue ? p.orange : p.textPrimary,
              fontSize: _fsBig,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(color: p.textSecondary, fontSize: _fsSmall),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _markOles,
              style: ElevatedButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sudah oles',
                style: TextStyle(fontSize: _fsSmall, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drinkCard(AppPalette p) {
    final remaining = _untilDrink;
    final isDue = remaining == Duration.zero;

    final value = remaining == null
        ? '--'
        : isDue
            ? 'Sekarang'
            : '${(remaining.inSeconds / 60).ceil()} menit';
    final sub = remaining == null
        ? 'Belum dicatat'
        : isDue
            ? 'Waktunya minum'
            : 'lagi';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_drink_outlined, size: 16, color: p.primary),
              const SizedBox(width: 8),
              Text(
                'Minum',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: _fsTitle,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: isDue ? p.orange : p.textPrimary,
              fontSize: _fsBig,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(color: p.textSecondary, fontSize: _fsSmall),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: _markDrink,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.primary,
                side: BorderSide(color: p.primary, width: 1.5),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sudah minum',
                style: TextStyle(fontSize: _fsSmall, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag({
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: _fsSmall,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Helper ----------

  String get _syncText {
    if (_lastSample == null) return 'Belum tersambung';
    final diff = DateTime.now().difference(_lastSample!);
    if (diff.inSeconds < 10) return 'Sinkron baru saja';
    if (diff.inSeconds < 60) return 'Sinkron ${diff.inSeconds} detik lalu';
    if (diff.inMinutes < 60) return 'Sinkron ${diff.inMinutes} menit lalu';
    return 'Sinkron ${diff.inHours} jam lalu';
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  DateTime _parse(String s) {
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _mmss(Duration d) {
    final m = d.inMinutes.toString();
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}