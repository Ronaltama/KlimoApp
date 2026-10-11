# Panduan Menjalankan Ekosistem KlimoApp (Klimo Wearth)

Dokumentasi resmi untuk menjalankan seluruh komponen proyek **KlimoApp**:
1. **IoT Firmware & Simulator** (ESP32-C3 Firmware, Arduino IDE, PlatformIO, Wokwi, dan Python)
2. **Flutter Mobile & Desktop App** (Arsitektur Offline-First / Huawei Health Style)
3. **Backend Cloud Server** (Laravel 13 REST API & MySQL)

---

## 1. Prasyarat Sistem (Prerequisites)

Pastikan peralatan berikut tersedia di komputer Anda:
* **Flutter SDK** (Versi 3.13+)
* **PHP 8.2+** & **Composer**
* **MySQL / MariaDB** (Database: `klimo_db`)
* **Python 3** & library `requests` (untuk testing backend injector)
* *(Untuk Flash Board Fisik)* **PlatformIO Core CLI** (`pio`) atau **Arduino IDE**

---

## 2. Cara Cepat: Skrip Demo Terpadu (`run_demo.sh`)

Gunakan skrip terpadu di root direktori untuk menjalankan berbagai skenario:

```bash
cd /home/ronaltama/PROJECT/KlimoApp
./run_demo.sh
```

Menu interaktif yang tersedia:
```text
  [1] Jalankan Aplikasi Flutter Saja (Offline-First / Demo Langsung)
  [2] Flash Firmware ke Board ESP32 (PlatformIO Upload via USB)
  [3] Buka Serial Monitor ESP32 (115200 baud)
  [4] Kompilasi / Validasi Firmware ESP32 (pio run)
  [5] Jalankan Backend Laravel Saja (host: 0.0.0.0:8000)
  [6] Full Stack Demo (Backend Laravel + Flutter App)
  [7] Jalankan Python Simulator (Backend Data Injector)
  [8] Info Panduan Demo Lomba & Web Controller ESP32
```

---

## 3. Panduan Demo Lomba (3 Tingkat)

Strategi demonstrasi terstruktur untuk presentasi di depan dewan juri lomba:

### Tingkat 1: Demo Utama (Hardware ESP32 Mandiri)
1. Colokkan board ESP32 ke laptop atau power bank portabel melalui kabel USB (tidak memerlukan modul sensor fisik eksternal).
2. ESP32 secara otomatis memancarkan:
   * **Bluetooth BLE:** Nama perangkat `Klimo-A3F2`.
   * **Hotspot WiFi:** SSID `Klimo-Simulator`, Password `klimo123`.
3. Hubungkan laptop atau ponsel kedua ke WiFi `Klimo-Simulator`.
4. Buka browser dan akses alamat:
   ```text
   http://192.168.4.1
   ```
5. Layar **Web Controller** interaktif akan muncul. Geser slider (UV, Suhu, Kelembaban, VOC) atau klik tombol preset (**Normal**, **UV Ekstrem**, **Polusi Gas**).
6. Buka aplikasi Klimo Wearth di ponsel utama. Aplikasi langsung mendeteksi pergerakan nilai secara live tanpa jeda.

### Tingkat 2: Visualisasi Proposal & Slide Presentasi (Wokwi)
1. Buka berkas [IoT_Simulator/diagram.json](IoT_Simulator/diagram.json) menggunakan ekstensi **Wokwi Simulator** di VS Code atau di situs [wokwi.com](https://wokwi.com).
2. Diagram menampilkan papan ESP32-C3 DevKit lengkap dengan 2 potentiometer simulator (UV di GPIO 2, Suhu di GPIO 3).
3. Tangkap layar (*screenshot*) skema diagram ini untuk kebutuhan dokumen proposal, poster ilmiah, atau slide PPT presentasi.

### Tingkat 3: Cadangan Darurat (In-App Simulation)
Jika board fisik tertinggal atau mengalami kendala baterai saat giliran presentasi:
1. Buka aplikasi Flutter di ponsel.
2. Di bagian banner atas Beranda, klik tombol **"Mode"**.
3. Pilih skenario simulasi: **Otomatis**, **Normal / Sejuk**, **Panas Ekstrem**, atau **Polusi Udara**.
4. Aplikasi akan tetap berjalan 100% normal secara offline tanpa bergantung pada hardware eksternal.

---

## 4. Panduan Flash Program ke Board ESP32 Fisik

### Opsi A: Menggunakan PlatformIO (CLI)
Pastikan modul ESP32 terhubung via USB, lalu jalankan:
```bash
cd /home/ronaltama/PROJECT/KlimoApp/IoT_Simulator

# 1. Kompilasi firmware
pio run

# 2. Upload firmware ke board
pio run -t upload

# 3. Pantau log serial
pio device monitor -b 115200
```

### Opsi B: Menggunakan Arduino IDE
1. Buka Arduino IDE.
2. Buka berkas:
   ```text
   /home/ronaltama/PROJECT/KlimoApp/IoT_Simulator/Klimo_ESP32_Firmware/Klimo_ESP32_Firmware.ino
   ```
3. Pilih board **ESP32C3 Dev Module** (atau **ESP32 Dev Module**) pada menu **Tools > Board**.
4. Pilih port USB yang sesuai pada **Tools > Port**.
5. Pastikan library `ArduinoJson` sudah terinstal di Library Manager.
6. Klik tombol **Upload**.

---

## 5. Menjalankan Komponen Secara Manual (Tab Terminal Terpisah)

### Tab 1: Aplikasi Flutter
```bash
cd /home/ronaltama/PROJECT/KlimoApp/FlutterApps

# Unduh paket dependensi
flutter pub get

# Jalankan aplikasi (Desktop Linux)
flutter run -d linux

# Atau jalankan ke perangkat ponsel Android yang terhubung
flutter run -d android
```

### Tab 2: Backend Laravel (Opsional untuk Full-Stack Sync)
```bash
cd /home/ronaltama/PROJECT/KlimoApp/Backend

# Jalankan server API di host 0.0.0.0
php artisan serve --host=0.0.0.0 --port=8000
```
* **URL API Lokal:** `http://127.0.0.1:8000/api`
* **Akun Demo Bawaan:** `test@example.com` / `password`

### Tab 3: Python Simulator (Opsional untuk Uji Coba Injeksi Backend)
```bash
cd /home/ronaltama/PROJECT/KlimoApp/IoT_Simulator
python3 simulator.py
```

---

## 6. Arsitektur Alur Data (Offline-First)

```text
[Alat Wearable ESP32]
        │
        ▼ (Bluetooth BLE Notification / Live AP Bridge)
[Ponsel Pintar - Aplikasi Flutter]
        │
        ├─► [Penyimpanan Lokal SQLite HP (Maks 500 Rekaman)]
        │      (Menyaring data via Delta Threshold & Heartbeat 60 detik)
        │
        └─► [SyncManager Background Worker]
               │
               ▼ (Hanya saat koneksi internet aktif - Tiap 30 detik)
        [Backend Laravel Cloud (POST /api/telemetry/batch)]
               │
               ▼
        [Database MySQL Komunitas & Peta Sebaran]
```
