# KlimoApp (Klimo Wearth) 🌦️

Repository monorepo untuk proyek **Klimo Wearth** (Personal Weather & Wearable Microclimate Monitoring).

Repository ini terdiri dari 3 direktori utama:
1. `Backend/` — REST API Backend berbasis **Laravel 13** & Laravel Sanctum.
2. `IoT_Simulator/` — Simulator Sensor Python & Firmware **ESP32-C3** (PlatformIO).
3. `FlutterApps/` — Aplikasi mobile & desktop Flutter (UI Monitoring & Dashboard).

---

## 💡 Tentang Solusi: Klimo Wearth

**Klimo Wearth** (*Personal Weather & Wearable Microclimate Monitoring*) adalah solusi pemantauan iklim mikro dan perlindungan pekerja luar ruangan (*outdoor workers*) secara *real-time*. 

Solusi ini mengintegrasikan perangkat *wearable* IoT dengan aplikasi *mobile* berarsitektur *offline-first* dan *backend cloud* untuk memantau:
* **Indeks Paparan Radiasi UV** (dengan indikator visual tingkat risiko & saran proteksi).
* **Suhu & Kelembaban** (deteksi dini risiko *Heat Stress* / kelelahan panas).
* **Kualitas Udara & Indeks Gas VOC** (pemantauan polusi udara mikro).
* **Peta Sebaran Komunitas (*Community Heatmap*)** untuk memetakan kondisi iklim mikro sekitar berdasarkan data gabungan pengguna.

---

## 🔄 Alur Solusi & Arsitektur Sistem

Sistem Klimo Wearth bekerja dengan alur terintegrasi 3 lapisan (*Hardware Wearable*, *Aplikasi Mobile*, dan *Cloud Backend*):

### 1. Arsitektur Sistem (System Architecture)
```mermaid
graph TD
    subgraph Hardware [1. Perangkat Klimo Wearable / IoT Simulator]
        ESP[ESP32-C3 Controller]
        S1[Sensor UV: LTR-390]
        S2[Sensor Suhu & RH: SHT40]
        S3[Sensor Kualitas Udara: SGP41]
        
        S1 --> ESP
        S2 --> ESP
        S3 --> ESP
    end

    subgraph Mobile [2. Aplikasi Mobile Flutter - Offline-First]
        BLE_G[BLE Client / WiFi AP Bridge]
        LocalDB[(SQLite Local DB - Offline Cache)]
        UI[Dashboard & Alert Monitor]
        SyncMgr[Background Sync Manager]
        
        BLE_G --> LocalDB
        LocalDB --> UI
        LocalDB --> SyncMgr
    end

    subgraph Backend [3. Cloud Backend - Laravel 13]
        API[REST API Sanctum]
        DB[(Database MySQL / Telemetry)]
        Heatmap[Aggregator Peta Komunitas]
        
        API --> DB
        DB --> Heatmap
    end

    ESP -- "Transmisi Real-time (BLE / AP)" --> BLE_G
    SyncMgr -- "Sinkronisasi Batch (HTTP JSON)" --> API
    Heatmap -- "Data Sebaran Wilayah" --> UI
```

### 2. Alur Pengiriman & Sinkronisasi Data (Data Flow Sequence)
```mermaid
sequenceDiagram
    autonumber
    participant W as IoT Wearable (ESP32-C3)
    participant A as Aplikasi Mobile (Flutter)
    participant B as Backend Cloud (Laravel)
    
    Note over W: Sensor mengukur kondisi lingkungan
    W->>A: Kirim data telemetri via BLE / Local AP (Interval Real-time)
    A->>A: Simpan ke SQLite Lokal & Update Tampilan Gauge UI
    
    alt Tersedia Koneksi Internet
        A->>B: POST /api/telemetry/batch (Kirim data telemetri + GPS)
        B->>B: Validasi & Simpan ke Database Cloud
        B-->>A: Status 200 OK (Sinkronisasi Berhasil)
        A->>B: GET /api/map/heatmap (Minta data sekeliling)
        B-->>A: Return JSON Heatmap Wilayah
        A->>A: Render Peta Komunitas
    else Mode Tanpa Internet (Offline)
        Note over A: Data tersimpan aman di SQLite lokal (Offline-First)
    end
```

---

## 📁 Struktur Direktori

```text
KlimoApp/
├── Backend/          # Laravel 13 API Backend
│   ├── app/
│   ├── database/     # Migrations & Seeders
│   ├── routes/api.php
│   └── ...
├── IoT_Simulator/    # Firmware ESP32-C3 & Software Simulator
│   ├── platformio.ini# Konfigurasi PlatformIO
│   ├── simulator.py  # Python sensor simulator (no hardware needed)
│   └── src/main.cpp  # Firmware C++ ESP32-C3
├── FlutterApps/      # Flutter Mobile App
│   ├── lib/          # UI, State & API Services
│   ├── pubspec.yaml
│   └── ...
├── run_demo.sh       # Script otomatis interaktif untuk menjalankan ekosistem
├── PANDUAN_MENJALANKAN.md # Panduan lengkap menjalankan seluruh komponen
└── README.md
```

---

## ⚡ Cara Menjalankan Cepat (All-in-One)

Gunakan skrip runner interaktif yang telah disediakan:

```bash
./run_demo.sh
```
Pilih opsi **`[4]`** untuk menyalakan Backend + IoT Simulator secara otomatis di background dan membuka aplikasi Flutter.

---

## 🚀 Panduan Menjalankan Manual (3 Terminal Terpisah)

Untuk melihat log setiap komponen secara jelas, buka 3 jendela terminal:

### 1. Backend (Laravel 13)
```bash
cd Backend
cp .env.example .env    # Jika belum ada
php artisan migrate --seed
php artisan serve --host=0.0.0.0 --port=8000
```
> **Akun Default untuk Uji Coba:**
> - **Email:** `test@example.com`
> - **Password:** `password`

### 2. IoT Simulator (Python / ESP32-C3)
```bash
cd IoT_Simulator
# Opsi A: Software Simulator (Python)
python3 simulator.py

# Opsi B: Hardware ESP32-C3 (PlatformIO)
pio run -t upload && pio device monitor -b 115200
```

### 3. Flutter App (`FlutterApps`)
```bash
cd FlutterApps
flutter pub get
flutter run
```

> 📖 Untuk panduan mendalam dan konfigurasi IP Emulator/Device fisik, baca [PANDUAN_MENJALANKAN.md](PANDUAN_MENJALANKAN.md).

---

## 🔑 Endpoint API Utama

| Method | Endpoint | Keterangan |
| :--- | :--- | :--- |
| `POST` | `/api/register` | Mendaftarkan akun baru |
| `POST` | `/api/login` | Login dan memperoleh Bearer Token Sanctum |
| `GET`  | `/api/profile` | Mengambil data user yang sedang login |
| `POST` | `/api/telemetry` | Mengirim data pembacaan sensor IoT (UV, Suhu, dsb.) |
| `GET`  | `/api/telemetry/history` | Riwayat data telemetri sensor |
| `POST` | `/api/logout` | Revoke token / logout |
