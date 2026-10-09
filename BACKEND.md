# Dokumentasi Backend Klimo (Laravel)

Sistem backend Klimo berfungsi sebagai pusat data (Data Center) dan API (*Application Programming Interface*) yang menghubungkan aplikasi mobile Klimo dengan basis data *cloud*. Backend ini dibangun menggunakan *framework* Laravel.

## Alur Backend (Backend Flow)

1. **Registrasi dan Autentikasi Pengguna**
   - Aplikasi mobile mengirimkan kredensial (email/password) melalui API ke backend.
   - Backend memverifikasi data dan menghasilkan *Token Akses* (menggunakan Laravel Sanctum atau Passport) untuk sesi pengguna.
   - Token ini digunakan oleh aplikasi mobile untuk mengakses *endpoint* yang dilindungi.

2. **Penerimaan Data Sensor (IoT Data Ingestion)**
   - Perangkat wearable Klimo (ESP32-C3) mengumpulkan data lingkungan (UV dari LTR-390, Suhu/Kelembaban dari SHT40, VOC dari SGP41).
   - **Alur Utama:** Perangkat mengirimkan data secara lokal via BLE ke aplikasi mobile Flutter. Aplikasi mobile bertindak sebagai *gateway* dan meneruskan data tersebut ke API Backend beserta informasi lokasi GPS dari *smartphone*.
   - **Alur Alternatif (WiFi):** Jika ESP32-C3 terhubung ke WiFi, perangkat dapat langsung melakukan POST HTTP request ke *endpoint* IoT di backend.

3. **Pemrosesan dan Penyimpanan Data**
   - Backend menerima payload data (JSON).
   - Validasi struktur data dan nilai sensor.
   - Menyimpan data ke dalam basis data relasional (MySQL/PostgreSQL), mengaitkannya dengan `user_id` dan `device_id`.
   - Memicu algoritma analisis untuk mendeteksi anomali atau kondisi bahaya (misalnya tingkat UV ekstrem atau VOC tinggi). Jika terdeteksi, backend dapat memicu pengiriman *Push Notification* (misalnya via Firebase Cloud Messaging) kembali ke pengguna.

4. **Agregasi Data Komunitas (Community Mapping)**
   - Backend secara berkala mengagregasi data dari seluruh pengguna aktif berdasarkan koordinat geografis.
   - Mengkalkulasi rata-rata indeks UV, *heat stress*, dan polusi udara di berbagai wilayah.
   - Menyediakan *endpoint* khusus untuk aplikasi mobile agar dapat menampilkan Peta Komunitas (Map Screen) secara *real-time*.

## Daftar Fitur dan Endpoint Utama API

### 1. Modul Autentikasi (Authentication)
- `POST /api/register` : Mendaftarkan akun baru.
- `POST /api/login` : Autentikasi dan mendapatkan *token*.
- `POST /api/logout` : Menghapus sesi token.

### 2. Modul Pengguna & Profil (User & Profile)
- `GET /api/user/profile` : Mengambil data profil pengguna.
- `PUT /api/user/profile` : Memperbarui data pengguna.

### 3. Modul Perangkat (Device Management)
- `POST /api/devices/register` : Mendaftarkan perangkat Klimo baru ke akun pengguna.
- `GET /api/devices` : Melihat daftar perangkat yang dimiliki.
- `PUT /api/devices/{id}/settings` : Memperbarui pengaturan kalibrasi atau preferensi perangkat.

### 4. Modul Data Sensor (Telemetry Data)
- `POST /api/telemetry` : Endpoint untuk mengunggah rekaman data sensor (UV, Suhu, Kelembaban, Kualitas Udara).
- `GET /api/telemetry/history` : Mengambil riwayat data sensor pengguna dengan parameter filter (harian, mingguan, bulanan) untuk ditampilkan pada grafik riwayat di aplikasi.

### 5. Modul Peta Komunitas (Community Map)
- `GET /api/map/heatmap` : Mengambil agregasi data lingkungan berdasarkan radius lokasi (*bounding box*) untuk dirender pada Peta di aplikasi mobile.

## Teknologi Utama
- **Framework:** Laravel (PHP)
- **Database:** MySQL / PostgreSQL
- **Autentikasi API:** Laravel Sanctum
- **Komunikasi:** RESTful API dengan format JSON
- **Notifikasi:** Terintegrasi dengan FCM (Firebase Cloud Messaging) untuk peringatan dini.
