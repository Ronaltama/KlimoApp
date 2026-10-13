import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class SkinTypeScreen extends StatefulWidget {
  final bool isEditMode;
  const SkinTypeScreen({super.key, this.isEditMode = false});

  @override
  State<SkinTypeScreen> createState() => _SkinTypeScreenState();
}

class _SkinType {
  final String title;
  final String subtitle;
  final Color color;
  const _SkinType(this.title, this.subtitle, this.color);
}

class _SkinTypeScreenState extends State<SkinTypeScreen> {
  static const _defaultType = 'Tipe IV';

  static const _types = [
    _SkinType('Tipe I', 'Sangat terang · selalu terbakar', Color(0xFFF5D9BE)),
    _SkinType('Tipe II', 'Terang · mudah terbakar', Color(0xFFE8B896)),
    _SkinType('Tipe III', 'Sedang · kadang terbakar', Color(0xFFD4956A)),
    _SkinType('Tipe IV', 'Sawo matang · jarang terbakar', Color(0xFFB87340)),
    _SkinType('Tipe V', 'Cokelat · sangat jarang terbakar', Color(0xFF8B5530)),
    _SkinType('Tipe VI', 'Gelap · hampir tidak terbakar', Color(0xFF4A2716)),
  ];

  String _selectedType = _defaultType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSkinType();
  }

  Future<void> _loadCurrentSkinType() async {
    final saved = await ApiService.getSkinType();
    if (!mounted) return;
    setState(() => _selectedType = saved);
  }

  Future<void> _handleFinish() async {
    setState(() => _isLoading = true);

    await ApiService.saveSkinType(_selectedType);
    await ApiService.setOnboardingCompleted(true);

    if (!mounted) return;

    if (widget.isEditMode && Navigator.canPop(context)) {
      Navigator.pop(context, _selectedType);
    } else {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 26, color: p.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditMode ? 'Ubah Tipe Kulit' : 'Langkah 3 dari 3',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        bottom: widget.isEditMode
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: 1.0,
                  minHeight: 4,
                  backgroundColor: p.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                ),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih tipe kulitmu',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dipakai untuk menghitung batas UV dan pengingat oles ulang.',
              style: TextStyle(fontSize: 14, height: 1.4, color: p.textSecondary),
            ),
            const SizedBox(height: 20),
            ..._types.map((t) => _buildCard(p, t)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.isEditMode) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tidak yakin? ',
                      style: TextStyle(fontSize: 13, color: p.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Skala Fitzpatrick: Tipe IV umum untuk kulit Asia / sawo matang.',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      ),
                      child: Text(
                        'Jawab 2 pertanyaan',
                        style: TextStyle(
                          color: p.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isEditMode ? 'Simpan Perubahan' : 'Lanjut',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(AppPalette p, _SkinType t) {
    final isSelected = _selectedType == t.title;
    final isDefault = t.title == _defaultType;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = t.title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? p.primary : p.cardBorder,
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: Theme.of(context).brightness == Brightness.light
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.cardBorder),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.subtitle,
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Bawaan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}