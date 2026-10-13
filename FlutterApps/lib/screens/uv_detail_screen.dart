import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UVDetailScreen extends StatelessWidget {
  const UVDetailScreen({super.key});

  // Ukuran huruf. Sama dengan layar Beranda dan Profil.
  static const _fsCaption = 11.0;
  static const _fsSmall = 12.0;
  static const _fsBody = 13.0;
  static const _fsTitle = 15.0;
  static const _fsBig = 28.0;
  static const _fsHeader = 17.0;

  // Data contoh. Ganti dengan data dari ApiService saat sudah tersedia.
  static const _uv = 8;
  static const _uvMax = 11;
  static const _sensorName = 'Sensor UV';          
  static const _lightLabel = 'Panas terik';        
  static const _skinType = 'kulitmu';              
  static const _spf = '30+';
  static const _uvStatus = 'Sangat tinggi';
  static const _exposurePercent = 68;
  static const _lastOles = '10:15';
  static const _hourlyUv = [0.12, 0.22, 0.50, 0.72, 0.88, 1.00, 1.00, 0.82, 0.58, 0.38];
  static const _hourLabels = ['07', '08', '09', '10', '11', '12', '13', '14', '15', '16'];
  static const _labelShown = {'07', '10', '12', '14', '16'};

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: p.card,
                shape: BoxShape.circle,
                border: Border.all(color: p.cardBorder),
              ),
              child: Icon(Icons.chevron_left, size: 22, color: p.textPrimary),
            ),
          ),
        ),
        leadingWidth: 56,
        title: Text(
          'UV & Sunscreen',
          style: TextStyle(
            color: p.textPrimary,
            fontSize: _fsHeader,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: () => _notify(context, 'Menampilkan data hari ini.'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: p.cardBorder),
                  ),
                  child: Text(
                    'Hari ini',
                    style: TextStyle(color: p.textSecondary, fontSize: _fsSmall),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Lebar konten dibatasi agar rapi di tablet dan layar lebar
            final maxW = constraints.maxWidth > 480 ? 480.0 : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: maxW,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _uvCard(context, p),
                    const SizedBox(height: 14),
                    _hourlyCard(context, p),
                    const SizedBox(height: 14),
                    _exposureCard(context, p),
                    const SizedBox(height: 14),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _spfCard(p)),
                          const SizedBox(width: 14),
                          Expanded(child: _lastOlesCard(p)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _notify(BuildContext context, String message) {
    final p = AppPalette.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: p.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ---------- Kartu UV utama ----------

  Widget _uvCard(BuildContext context, AppPalette p) {
    return GestureDetector(
      onTap: () => _notify(context, 'UV $_uv dari $_uvMax. Tingkat $_uvStatus.'),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sensorName,
                    style: TextStyle(
                      color: p.primary,
                      fontSize: _fsSmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'UV $_uv · $_uvStatus',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _chip(p),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 76,
              height: 76,
              child: CustomPaint(
                painter: _UVGaugePainter(
                  progress: _uv / _uvMax,
                  strokeWidth: 8,
                  trackColor: p.divider,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_uv',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '/ $_uvMax',
                        style: TextStyle(color: p.textMuted, fontSize: _fsCaption),
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

  Widget _chip(AppPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_outlined, size: 14, color: p.orange),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _lightLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.orange,
                fontSize: _fsSmall,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Grafik per jam ----------

  Widget _hourlyCard(BuildContext context, AppPalette p) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sinar UV tiap jam',
            style: TextStyle(
              color: p.textPrimary,
              fontSize: _fsTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 150,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_hourLabels.length, (i) {
                final label = _hourLabels[i];
                final v = _hourlyUv[i];
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: v,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Color(0xFFEA580C), Color(0xFFFBBF24)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 14,
                        child: _labelShown.contains(label)
                            ? FittedBox(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: p.textMuted,
                                    fontSize: _fsCaption,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Akumulasi paparan ----------

  Widget _exposureCard(BuildContext context, AppPalette p) {
    return GestureDetector(
      onTap: () => _notify(
        context,
        'Kamu sudah memakai $_exposurePercent% dari batas aman $_skinType hari ini.',
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Akumulasi paparan (perkiraan)',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: _fsTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _exposurePercent / 100,
                minHeight: 8,
                backgroundColor: p.divider,
                valueColor: AlwaysStoppedAnimation<Color>(p.orange),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$_exposurePercent% dari batas aman kulit $_skinType',
              style: TextStyle(color: p.textSecondary, fontSize: _fsBody),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Kartu bawah ----------

  Widget _spfCard(AppPalette p) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPF disarankan',
            style: TextStyle(color: p.textMuted, fontSize: _fsSmall),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _spf,
              style: TextStyle(
                color: p.primary,
                fontSize: _fsBig,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lastOlesCard(AppPalette p) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terakhir dioles',
            style: TextStyle(color: p.textMuted, fontSize: _fsSmall),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _lastOles,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: _fsBig,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Painter ----------
}

class _UVGaugePainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;

  _UVGaugePainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [Color(0xFFE11D48), Color(0xFFF59E0B), Color(0xFFEA580C), Color(0xFFE11D48)],
          stops: [0.0, 0.4, 0.8, 1.0],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _UVGaugePainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor;
}