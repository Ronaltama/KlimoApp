# 📦 KlimoApp - Android Release Package

Direktori ini berisi berkas instalasi biner aplikasi Android resmi (**Production APK**) yang siap diunduh dan dipasang langsung ke smartphone.

---

## 📱 Berkas APK
* **Nama Berkas**: [`KlimoApp-release.apk`](KlimoApp-release.apk)
* **Ukuran Berkas**: **~60.7 MB**
* **Tipe Build**: Production Release (AOT Compiled, Tree-shaking asset aktif)
* **Arsitektur**: Universal FAT APK (Mendukung `arm64-v8a`, `armeabi-v7a`, `x86_64`)
* **Minimum Android**: Android 6.0 Marshmallow (API level 23+)
* **Target Android**: Android 14+ (API level 34+)

---

## 📲 Cara Instalasi ke HP Android

### Metode 1: Download Langsung dari GitHub
1. Buka repositori GitHub KlimoApp di browser HP Anda.
2. Buka folder `release/` lalu klik berkas **`KlimoApp-release.apk`**.
3. Klik tombol **Download** (atau **View Raw**).
4. Setelah terunduh, buka berkas dari notifikasi / File Manager lalu pilih **Pasang / Install**.
   *(Jika muncul peringatan keamanan, izinkan "Instal dari sumber ini" / "Allow from this source")*.

### Metode 2: Menggunakan ADB (Kabel USB)
Jika Anda menghubungkan HP ke laptop dalam mode Developer / USB Debugging:
```bash
adb install -r release/KlimoApp-release.apk
```

---

## 🔑 Fitur dalam Rilis Ini
- ✅ **Offline-First SQLite Cache**: Data sensor tersimpan lokal sebelum dikirim ke cloud.
- ✅ **Peta Iklim Wilayah Privasi**: Pemetaan kondisi makro lingkungan berbasis grid ~150m (tanpa melacak titik pribadi).
- ✅ **Mode Demo & Simulasi Virtual**: 4 skenario cuaca dinamis tanpa alat fisik.
- ✅ **Personalisasi Tipe Kulit (Tipe I - VI)**: Saran sunscreen dan deteksi bahaya UV real-time.
- ✅ **Koneksi BLE ESP32-C3**: Terintegrasi mulus dengan modul sensor Klimo Wearth.
