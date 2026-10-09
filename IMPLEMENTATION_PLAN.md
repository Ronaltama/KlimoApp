# Rencana Implementasi Demo Klimo (Implementation Plan)

Untuk membangun sistem ini secara menyeluruh dan bisa didemokan, kita harus memecahnya menjadi 3 tahapan (kita akan kerjakan **satu-satu** sesuai permintaan).

## Tahap 1: Demo Backend (API & Database)
Fokus: Membuat server agar siap menerima data dan mengelola pengguna.
* **Langkah 1:** Konfigurasi *database* (kita bisa gunakan SQLite untuk demo agar cepat).
* **Langkah 2:** Membuat model dan migrasi untuk tabel `users`, `devices`, dan `sensor_data` (telemetri).
* **Langkah 3:** Membuat API endpoint:
  - `POST /api/login` & `POST /api/register` (Autentikasi).
  - `POST /api/telemetry` (Untuk menerima data dari IoT/Aplikasi).
  - `GET /api/map/heatmap` (Untuk mereturn data peta komunitas).
* **Output:** Endpoint API yang bisa dites menggunakan Postman/cURL.

## Tahap 2: Demo IoT (Simulasi Perangkat Wearable)
Fokus: Menghasilkan data sensor seolah-olah berasal dari alat aslinya (ESP32).
* **Kendala Hardware:** Karena kita belum menghubungkan perangkat fisik, kita akan membuat **Simulator IoT** (bisa berupa script Python atau Node.js ringan).
* **Langkah 1:** Script akan meng-*generate* nilai *random* yang masuk akal untuk (UV Index: 0-11+, Suhu: 25-40°C, Kelembaban: 40-90%, VOC: 0-500).
* **Langkah 2:** Script akan otomatis menembak API Backend (`POST /api/telemetry`) setiap X detik untuk menyimulasikan aliran data.
* **Output:** Data buatan (*dummy data*) yang terus mengalir dan terekam di *database* Backend.

## Tahap 3: Demo Aplikasi Mobile (Flutter)
Fokus: Menghubungkan UI yang sudah kita buat dengan data dari Backend & IoT.
* **Langkah 1:** Menghubungkan form *Login* dengan `POST /api/login` (menggunakan paket `http` atau `dio`).
* **Langkah 2:** Membuat *State Management* (Provider/Riverpod/GetX) untuk menarik data dari Backend, sehingga layar Beranda tidak lagi menggunakan data *hardcode* melainkan data asli/simulasi.
* **Langkah 3:** Menghubungkan *Map Screen* agar merender pin/koordinat dari API Backend.
* **Output:** Aplikasi mobile yang bisa berinteraksi penuh dengan Backend dan merefleksikan perubahan kondisi secara *real-time*.

---

## Mari Mulai dari Tahap 1!
Apakah Anda setuju kita mulai dari **Tahap 1 (Backend Demo)** terlebih dahulu? Jika ya, saya akan mulai menuliskan *controllers* dan *routes* di folder `Backend/` kita.
