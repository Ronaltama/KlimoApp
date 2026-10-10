# 🌿 Panduan Menjalankan Ekosistem KlimoApp

Dokumentasi lengkap untuk menjalankan 3 komponen utama proyek **KlimoApp (Klimo Wearth)**:
1. 🗄️ **Backend** (Laravel 13 REST API)
2. 🛰️ **IoT_Simulator** (Python Simulator & Firmware ESP32-C3)
3. 📱 **FlutterApps** (Aplikasi Mobile & Desktop Flutter)

---

## 📋 Prasyarat Sistem (Prerequisites)

Pastikan peralatan berikut sudah terpasang di komputer Anda:
- **PHP 8.2+** & **Composer**
- **MySQL / MariaDB** (Sudah berjalan, database: `klimo_db`)
- **Python 3** & library `requests` (`pip install requests`)
- **Flutter SDK** (Channel stable)
- *(Opsional untuk hardware fisik)* **PlatformIO CLI** (`pio`)

---

## ⚡ Opsi 1: Cara Instan (All-in-One Runner Script)

Di direktori utama proyek, sudah disediakan skrip otomatis `run_demo.sh`:

```bash
cd /home/ronaltama/PROJECT/KlimoApp
./run_demo.sh
```

Menu interaktif akan muncul:
```text
  [1] Nyalakan Backend Laravel Saja (host: 0.0.0.0:8000)
  [2] Nyalakan IoT Python Simulator Saja
  [3] Nyalakan Flutter Mobile App Saja
  [4] Nyalakan SEMUA (Full Stack Demo) (Laravel + Simulator + Flutter)
  [5] PlatformIO: Build / Compile Firmware ESP32-C3
  [6] PlatformIO: Upload / Flash ke Board ESP32-C3
  [7] PlatformIO: Buka Serial Monitor (115200 baud)
```

> **Tips:** Pilih opsi `[4]` untuk langsung menjalankan Backend + IoT Simulator di background, lalu membuka aplikasi Flutter. Ketika aplikasi Flutter ditutup, proses background akan otomatis dimatikan.

---

## 🛠️ Opsi 2: Cara Manual (3 Terminal Terpisah)

Jika Anda ingin melihat log dari masing-masing komponen secara independen, buka **3 tab / jendela terminal terpisah**:

### 1️⃣ Terminal 1: Menjalankan Backend (Laravel)

Direktori: `Backend/`

```bash
cd Backend

# 1. Pastikan file .env sudah ada (jika belum, copy dari .env.example)
cp .env.example .env   # lewati jika .env sudah ada

# 2. Generate Application Key (hanya jika baru pertama kali setup)
php artisan key:generate

# 3. Jalankan migrasi dan seeder database awal
php artisan migrate --seed

# 4. Jalankan development server pada host 0.0.0.0 agar dapat diakses emulator & LAN
php artisan serve --host=0.0.0.0 --port=8000
```

- **URL API Lokal:** `http://127.0.0.1:8000`
- **URL API Emulator Android:** `http://10.0.2.2:8000/api`
- **Akun Uji Coba Default:**
  - **Email:** `test@example.com`
  - **Password:** `password`

---

### 2️⃣ Terminal 2: Menjalankan IoT Simulator / Hardware

Direktori: `IoT_Simulator/`

#### A. Menggunakan Software Simulator Python (Tanpa Alat Fisik)
Sangat cocok untuk demonstrasi dan testing tanpa perlu board ESP32:

```bash
cd IoT_Simulator

# Pastikan module requests terpasang
pip install requests

# Jalankan simulator
python3 simulator.py
```

Anda dapat memilih mode streaming:
- `[1]` Normal / Sejuk (UV Rendah, Suhu 27°C, VOC 65)
- `[2]` Panas Ekstrem (UV 10.5+, Suhu 38°C, VOC 120)
- `[3]` Polusi Udara / Gas VOC Tinggi (UV 3.0, Suhu 31°C, VOC 420)
- `[4]` Mode Realtime Otomatis (Default / Streaming Terus dengan fluktuasi alami)

> Simulator akan otomatis mengirimkan payload JSON data sensor ke `http://127.0.0.1:8000/api/telemetry` setiap 2 detik.

#### B. Menggunakan Hardware Fisik (ESP32-C3 via PlatformIO)
Jika menggunakan board fisik ESP32-C3:
1. Sesuaikan WiFi SSID, password, dan IP backend pada `IoT_Simulator/include/config.h`.
2. Hubungkan modul ke port USB komputer.
3. Jalankan perintah:
```bash
cd IoT_Simulator

# Compile dan upload firmware
pio run -t upload

# Buka serial monitor untuk memantau pengiriman data
pio device monitor -b 115200
```

---

### 3️⃣ Terminal 3: Menjalankan Aplikasi Mobile (Flutter)

Direktori: `FlutterApps/`

```bash
cd FlutterApps

# 1. Unduh paket dependensi pub
flutter pub get

# 2. Cek perangkat yang terhubung (Emulator Android / Linux Desktop / Chrome)
flutter devices

# 3. Jalankan aplikasi ke perangkat target
flutter run

# Atau spesifik ke target device, contoh:
# flutter run -d linux          (Desktop Linux)
# flutter run -d chrome         (Web browser)
# flutter run -d emulator-5554  (Android Emulator)
```

---

## 🌐 Konfigurasi Jaringan & Alamat IP (Network Routing)

Aplikasi Flutter dan IoT Simulator perlu terhubung ke Backend Laravel. Perhatikan konfigurasi URL berikut:

| Klien | Target URL Backend | Keterangan |
| :--- | :--- | :--- |
| **IoT Python Simulator** | `http://127.0.0.1:8000/api/telemetry` | Berjalan di mesin lokal yang sama |
| **Flutter (Linux Desktop / Web)** | `http://127.0.0.1:8000/api` | Terhubung langsung ke localhost |
| **Flutter (Android Emulator)** | `http://10.0.2.2:8000/api` | Alias default Android Emulator ke host PC |
| **HP Fisik / Modul ESP32 WiFi** | `http://<IP_LAN_PC>:8000/api` | Contoh: `http://192.168.2.19:8000/api` (dalam 1 WiFi) |

> Konfigurasi base URL Flutter terdapat di `FlutterApps/lib/services/api_service.dart`. Secara otomatis sudah mendeteksi apakah aplikasi dijalankan di Android emulator atau Desktop/Web.

---

## ❓ Troubleshooting (Kendala Umum)

1. **Port 8000 Sudah Terpakai (`Address already in use`):**
   Cari dan matikan proses yang menggunakan port 8000:
   ```bash
   lsof -i :8000
   # atau bunuh proses lama:
   kill -9 $(lsof -t -i:8000)
   ```

2. **Database Error (Connection Refused):**
   Pastikan service MySQL / MariaDB sedang aktif:
   ```bash
   sudo systemctl status mysql
   # nyalakan jika mati:
   sudo systemctl start mysql
   ```

3. **Python Simulator `ModuleNotFoundError: No module named 'requests'`:**
   Install pustaka requests untuk Python:
   ```bash
   pip3 install requests
   ```
