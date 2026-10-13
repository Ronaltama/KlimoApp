# ☁️ Klimo Wearth - Backend REST API (Laravel 13)

Layanan Cloud Backend resmi untuk proyek **Klimo Wearth** (*Personal Weather & Wearable Microclimate Monitoring*), dibangun menggunakan **Laravel 13** dan **Laravel Sanctum**.

---

## 🏛️ Arsitektur & Logika Cerdas Backend

Layanan backend bertindak sebagai penyimpan data cloud, otentikasi pengguna, serta pemroses telemetri lingkungan dengan efisiensi tinggi:

### 1. Mesin Penyaringan Cerdas: Delta Threshold & Heartbeat
Untuk mencegah database MySQL penuh berlebihan (*bloating*) ketika ratusan perangkat IoT mengirimkan data setiap beberapa detik, backend mengimplementasikan **Delta Threshold Filtering**:

* **Kriteria Simpan Baris Baru**:
  * Indeks UV berubah $\ge 0.2$
  * Suhu berubah $\ge 0.3^\circ\text{C}$
  * Kelembaban berubah $\ge 1.0\%$
  * Konsentrasi Gas VOC berubah $\ge 10$
  * Pergeseran koordinat GPS $\ge 0.0001^\circ$ (~11 meter)
* **Checkpoint Heartbeat**:
  * Jika nilai sensor stabil dan tidak berubah signifikan, data dilewati (*skip*). Namun, jika sudah mencapai **5 menit (300 detik)** tanpa pencatatan, sistem otomatis menyimpan 1 baris sebagai checkpoint status alat.

### 2. Batch Sync Telemetri Offline
Mendukung sinkronisasi massal dari aplikasi mobile (*Offline-First*) melalui endpoint `POST /api/telemetry/batch`, memungkinkan HP mengunggah puluhan log pencatatan sekaligus dalam satu transaksi HTTP.

---

## 🗄️ Skema Basis Data (Database Schema)

```text
users
├── id (BIGINT, PK)
├── name (VARCHAR)
├── email (VARCHAR, UNIQUE)
├── password (VARCHAR, HASHED)
├── skin_type (VARCHAR, DEFAULT 'Tipe IV')   # Personalisasi Fitzpatrick Scale
└── timestamps

devices
├── id (BIGINT, PK)
├── user_id (BIGINT, FK -> users.id)
├── mac_address (VARCHAR, UNIQUE)            # MAC Address Hardware ESP32
├── name (VARCHAR)                           # Nama perangkat (misal Klimo-A3F2)
└── timestamps

telemetries
├── id (BIGINT, PK)
├── device_id (BIGINT, FK -> devices.id)
├── user_id (BIGINT, FK -> users.id)
├── uv_index (FLOAT)                         # Indeks radiasi UV
├── temperature (FLOAT)                      # Suhu lingkungan (°C)
├── humidity (FLOAT)                         # Kelembaban udara (%)
├── voc (INT)                                # Indeks gas organik volatil
├── latitude (DECIMAL 10,8)                  # Koordinat Lintang
├── longitude (DECIMAL 11,8)                 # Koordinat Bujur
└── timestamps (created_at = recorded_at)
```

---

## 🔑 Dokumentasi REST API

| Method | Endpoint | Fungsi | Payload / Parameter | Auth |
| :--- | :--- | :--- | :--- | :---: |
| `POST` | `/api/register` | Mendaftarkan akun baru | `name`, `email`, `password`, `skin_type` | Publik |
| `POST` | `/api/login` | Masuk ke akun | `email`, `password` | Publik |
| `POST` | `/api/login/google` | Autentikasi akun Google | `email`, `name` | Publik |
| `POST` | `/api/logout` | Revoke token aktif | - | Bearer Token |
| `GET`  | `/api/profile` | Ambil profil pengguna | - | Bearer Token |
| `PUT`  | `/api/profile` | Update nama / tipe kulit | `name` (opsional), `skin_type` (opsional) | Bearer Token |
| `GET`  | `/api/devices` | Daftar perangkat terhubung | - | Publik / Token |
| `POST` | `/api/devices` | Daftarkan perangkat baru | `mac_address`, `name` | Publik / Token |
| `POST` | `/api/telemetry` | Kirim telemetri (Delta filter)| `mac_address`, `uv_index`, `temperature`, dsb. | Publik / Token |
| `POST` | `/api/telemetry/batch` | Sinkronisasi batch offline | `readings`: `[ { mac_address, uv_index, ... } ]` | Publik / Token |
| `GET`  | `/api/telemetry/latest`| Ambil data sensor terkini | - | Publik / Token |
| `GET`  | `/api/telemetry/history`| Ambil 50 data riwayat | - | Publik / Token |
| `GET`  | `/api/map/heatmap` | Ambil 100 data spasial peta | - | Publik / Token |

---

## 🚀 Panduan Menjalankan Backend

### 1. Instalasi Dependensi
```bash
cd Backend
composer install
```

### 2. Konfigurasi Environment (`.env`)
```bash
cp .env.example .env
php artisan key:generate
```
Pastikan pengaturan basis data mengarah ke MySQL Anda:
```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=klimo_db
DB_USERNAME=root
DB_PASSWORD=
```

### 3. Migrasi Database
```bash
php artisan migrate
```

### 4. Jalankan Server Pengembangan
```bash
php artisan serve --host=0.0.0.0 --port=8000
```
> Server akan aktif dan dapat diakses dari localhost maupun perangkat HP dalam jaringan WiFi yang sama di `http://<IP_KOMPUTER>:8000`.

---

## 🧪 Pengujian Unit & Fitur (Testing)

Proyek ini telah dilengkapi dengan suite pengujian otomatis fitur autentikasi, penyaringan telemetri, dan sinkronisasi batch:

```bash
php artisan test
```

**Hasil Pengujian Saat Ini**:
* **18 Tests Passed** (100% Lulus)
* **571 Assertions Validated**
* **0 Failures / 0 Errors**
