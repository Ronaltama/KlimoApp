# 📦 KlimoApp - Production Release Packages

Direktori ini berisi berkas instalasi biner aplikasi resmi (**Production Packages**) untuk Android dan dokumentasi CI/CD untuk iOS.

---

## 🤖 1. Android Release (APK Siap Pasang)

* **Nama Berkas**: [`KlimoApp-release.apk`](KlimoApp-release.apk)
* **Ukuran Berkas**: **~60.7 MB**
* **Tipe Build**: Production Release (AOT Compiled, Tree-shaking asset aktif)
* **Arsitektur**: Universal FAT APK (Mendukung `arm64-v8a`, `armeabi-v7a`, `x86_64`)
* **Minimum Android**: Android 6.0 Marshmallow (API level 23+)
* **Target Android**: Android 14+ (API level 34+)

### Cara Instalasi ke Smartphone Android:
1. **Download Langsung**: Unduh berkas [`KlimoApp-release.apk`](KlimoApp-release.apk) dari repositori ini, buka di HP, lalu pilih **Pasang / Install**.
2. **Via USB Debugging (ADB)**:
   ```bash
   adb install -r release/KlimoApp-release.apk
   ```

---

## 🍏 2. iOS Release (CI/CD via GitHub Actions)

Kompilasi aplikasi iOS memerlukan lingkungan sistem operasi macOS dengan Xcode. Proyek ini telah dilengkapi dengan pipeline otomatis **GitHub Actions CI/CD** di berkas [`.github/workflows/build-ios.yml`](../.github/workflows/build-ios.yml).

### Spesifikasi Build iOS:
* **Target OS**: iOS 14.0+
* **Format Output**: `KlimoApp-ios-release.ipa` (Unsigned / Enterprise Distribution)
* **Runner Environment**: `macos-14` (Apple Silicon M1 Runner) dengan Xcode & CocoaPods

### Cara Menjalankan CI/CD Build iOS di GitHub:
1. Buka tab **Actions** di repositori GitHub KlimoApp.
2. Di sidebar kiri, pilih workflow **"Build iOS Release (CI/CD)"**.
3. Klik tombol **Run workflow** di sebelah kanan.
4. Pastikan opsi `Commit file IPA hasil build ke folder release/ di repo?` dicentang (`true`), lalu klik tombol hijau **Run workflow**.
5. GitHub Actions akan otomatis mengompilasi aplikasi dan:
   * Mengunggah berkas `KlimoApp-ios-release.ipa` ke daftar **Artifacts** (dapat diunduh langsung).
   * Melakukan *auto-commit* berkas `KlimoApp-ios-release.ipa` ke dalam folder `release/` repositori ini.

### Cara Memasang Berkas IPA ke iPhone/iPad:
* Gunakan tools sideloading populer seperti **AltStore**, **Sideloadly**, atau akun **Apple Developer (TestFlight)**.

---

## 🔑 Fitur Utama dalam Rilis Ini
- ✅ **Offline-First SQLite Cache**: Data sensor tersimpan lokal sebelum dikirim ke cloud.
- ✅ **Peta Iklim Wilayah Privasi**: Pemetaan kondisi makro lingkungan berbasis grid ~150m (tanpa melacak titik pribadi).
- ✅ **Mode Demo & Simulasi Virtual**: 4 skenario cuaca dinamis tanpa alat fisik.
- ✅ **Personalisasi Tipe Kulit (Tipe I - VI)**: Saran sunscreen dan deteksi bahaya UV real-time.
- ✅ **Koneksi BLE ESP32-C3**: Terintegrasi mulus dengan modul sensor Klimo Wearth.
