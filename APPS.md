# Dokumentasi Aplikasi Mobile Klimo (Flutter)

Aplikasi mobile Klimo berfungsi sebagai antarmuka utama bagi pengguna untuk memantau data lingkungan secara *real-time*, mengelola perangkat *wearable*, dan melihat riwayat paparan. Aplikasi ini dibangun menggunakan *framework* Flutter dan mendukung fitur *Dark Mode*.

## Alur Aplikasi (App Flow)

1. **Splash Screen / Login**
   - Pengguna membuka aplikasi dan disambut dengan *Splash Screen*.
   - Jika belum masuk (*login*), pengguna diarahkan ke halaman **Login Screen**.
   - Setelah berhasil *login*, pengguna masuk ke menu utama.

2. **Menu Utama (Main Navigation)**
   Aplikasi menggunakan `BottomNavigationBar` untuk navigasi antar halaman utama:
   - **Beranda (Home):** Menampilkan *dashboard* utama.
   - **Peta (Map):** Menampilkan pemetaan komunitas.
   - **Riwayat (History):** Menampilkan grafik dan data historis.
   - **Alat (Device):** Mengelola koneksi ke perangkat Klimo.
   - **Profil (Profile):** Pengaturan akun pengguna.

## Detail Fitur

### 1. Beranda (Home Screen)
Halaman ini adalah pusat informasi *real-time* yang diterima dari perangkat Klimo.
- **Ringkasan Cuaca/Kondisi:** Menampilkan lokasi dan sapaan.
- **Kartu Indeks UV:** Menampilkan tingkat radiasi UV saat ini. Terdapat tombol "Lihat Detail" yang akan mengarahkan pengguna ke **UV Detail Screen** untuk melihat *gauge* (indikator melingkar) detail tentang paparan UV, tips perlindungan, dan status aman.
- **Kartu Cuaca (Suhu & Kelembaban):** Memantau indikasi *heat stress* dari sensor SHT40.
- **Kartu Kualitas Udara:** Memantau tingkat VOC (Volatile Organic Compounds) dari sensor SGP41.

### 2. Peta (Map Screen)
- Menampilkan peta interaktif yang menunjukkan kondisi lingkungan (Heat stress, UV, Kualitas udara) di area sekitar berdasarkan data komunitas (Klimo *community mapping*).
- Membantu pengguna menghindari area dengan kondisi lingkungan yang berbahaya.

### 3. Riwayat (History Screen)
- Menampilkan grafik dan log data historis dari paparan UV, suhu, dan kualitas udara.
- Pengguna dapat memantau tren harian, mingguan, atau bulanan untuk analisis kesehatan jangka panjang.

### 4. Alat (Device Screen)
- Berfungsi untuk menghubungkan dan mengelola perangkat *wearable* Klimo.
- Menggunakan protokol BLE (Bluetooth Low Energy) untuk mengambil data langsung dari ESP32-C3 pada perangkat.
- Menampilkan status baterai perangkat, status koneksi, dan opsi kalibrasi.

### 5. Profil (Profile Screen)
- Mengelola data pribadi pengguna, preferensi aplikasi, dan pengaturan akun.
- Pengaturan tema aplikasi (*Light Mode* / *Dark Mode*).

### 6. Mode Gelap (Dark Mode)
- Seluruh antarmuka aplikasi telah mendukung *Dark Mode* secara penuh.
- Tema diatur secara terpusat melalui `AppTheme` dengan pergantian dinamis menggunakan `ValueNotifier` dan `ThemeMode`.

## Teknologi Utama
- **Framework:** Flutter (Dart)
- **State Management:** SetState & ValueNotifier (untuk tema)
- **Komunikasi IoT:** Bluetooth Low Energy (BLE) untuk terhubung ke perangkat.
- **Integrasi Backend:** RESTful API untuk sinkronisasi data riwayat dan peta komunitas.
