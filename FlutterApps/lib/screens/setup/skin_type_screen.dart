import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class SkinTypeScreen extends StatefulWidget {
  final bool isEditMode;
  const SkinTypeScreen({super.key, this.isEditMode = false});

  @override
  State<SkinTypeScreen> createState() => _SkinTypeScreenState();
}

class _SkinTypeScreenState extends State<SkinTypeScreen> {
  String _selectedType = 'Tipe IV';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _skinTypes = [
    {
      'title': 'Tipe I',
      'subtitle': 'Sangat terang · selalu terbakar',
      'color': const Color(0xFFF1D4B3),
    },
    {
      'title': 'Tipe II',
      'subtitle': 'Terang · mudah terbakar',
      'color': const Color(0xFFDFAB87),
    },
    {
      'title': 'Tipe III',
      'subtitle': 'Sedang · kadang terbakar',
      'color': const Color(0xFFC78B60),
    },
    {
      'title': 'Tipe IV',
      'subtitle': 'Sawo matang · jarang terbakar',
      'color': const Color(0xFFA56637),
    },
    {
      'title': 'Tipe V',
      'subtitle': 'Cokelat · sangat jarang terbakar',
      'color': const Color(0xFF703D1A),
    },
    {
      'title': 'Tipe VI',
      'subtitle': 'Gelap · hampir tidak terbakar',
      'color': const Color(0xFF3B1E0D),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentSkinType();
  }

  Future<void> _loadCurrentSkinType() async {
    final saved = await ApiService.getSkinType();
    if (mounted) {
      setState(() {
        _selectedType = saved;
      });
    }
  }

  Future<void> _handleFinish() async {
    setState(() {
      _isLoading = true;
    });

    // Simpan tipe kulit yang dipilih dan tandai bahwa onboarding sudah selesai
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: 18,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditMode ? 'Ubah Tipe Kulit' : 'Langkah 3 dari 3',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        titleSpacing: 0,
        bottom: widget.isEditMode
            ? null
            : const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: AppTheme.greyLight,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih tipe kulitmu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dipakai untuk menghitung batas toleransi UV dan timer pengingat sunscreen.',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
              ),
            ),
            const SizedBox(height: 24),
            ..._skinTypes.map((item) {
              final isSelected = _selectedType == item['title'];
              return _buildSkinTypeCard(
                title: item['title'] as String,
                subtitle: item['subtitle'] as String,
                color: item['color'] as Color,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () {
                  setState(() {
                    _selectedType = item['title'] as String;
                  });
                },
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.isEditMode) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tidak yakin? ',
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Skala Fitzpatrick: Tipe IV umum untuk kulit Asia / Sawo Matang.'),
                          ),
                        );
                      },
                      child: const Text(
                        'Jawab 2 pertanyaan',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleFinish,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(widget.isEditMode ? 'Simpan Perubahan' : 'Lanjut'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkinTypeCard({
    required String title,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? AppTheme.darkCardBorder : Colors.transparent),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Dipilih',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
