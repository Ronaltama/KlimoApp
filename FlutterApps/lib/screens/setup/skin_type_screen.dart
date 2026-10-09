import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SkinTypeScreen extends StatelessWidget {
  const SkinTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Langkah 3 dari 3', style: TextStyle(fontSize: 16)),
        titleSpacing: 0,
        bottom: const PreferredSize(
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
            const Text(
              'Pilih tipe kulitmu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dipakai untuk menghitung batas UV dan pengingat oles ulang.',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textLight,
              ),
            ),
            const SizedBox(height: 24),
            _buildSkinTypeCard('Tipe I', 'Sangat terang · selalu terbakar', const Color(0xFFF1D4B3)),
            _buildSkinTypeCard('Tipe II', 'Terang · mudah terbakar', const Color(0xFFDFAB87)),
            _buildSkinTypeCard('Tipe III', 'Sedang · kadang terbakar', const Color(0xFFC78B60)),
            _buildSkinTypeCard('Tipe IV', 'Sawo matang · jarang terbakar', const Color(0xFFA56637), isSelected: true),
            _buildSkinTypeCard('Tipe V', 'Cokelat · sangat jarang terbakar', const Color(0xFF703D1A)),
            _buildSkinTypeCard('Tipe VI', 'Gelap · hampir tidak terbakar', const Color(0xFF3B1E0D)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Tidak yakin? ', style: TextStyle(color: AppTheme.textLight)),
                  GestureDetector(
                    onTap: () {},
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/main');
                  },
                  child: const Text('Lanjut'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkinTypeCard(String title, String subtitle, Color color, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textLight,
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
                'Bawaan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
