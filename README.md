# KlimoApp (Klimo Wearth) 🌦️

Repository monorepo untuk proyek **Klimo Wearth** (Personal Weather & Wearable Microclimate Monitoring).

Repository ini terdiri dari dua direktori utama:
1. `FlutterApps/` — Aplikasi mobile Flutter (Starter dengan Login & Home).
2. `Backend/` — REST API Backend berbasis **Laravel 13** & Laravel Sanctum.

---

## 📁 Struktur Direktori

```text
KlimoApp/
├── Backend/          # Laravel 13 API Backend
│   ├── app/
│   ├── config/
│   ├── database/     # Migrations & Seeders (Users, Sanctum tokens)
│   ├── routes/
│   │   └── api.php   # Endpoint autentikasi (/api/login, /api/register, dsb)
│   └── ...
├── FlutterApps/      # Flutter Mobile App
│   ├── lib/
│   │   └── main.dart # Starter app dengan form login & dashboard
│   ├── pubspec.yaml
│   └── ...
├── .gitignore        # Root .gitignore untuk monorepo
└── README.md
```

---

## 🚀 Panduan Menjalankan

### 1. Backend (Laravel 13)

```bash
cd Backend

# Salin environment file jika belum ada
cp .env.example .env

# Jalankan migrasi dan seeder awal
php artisan migrate --seed

# Jalankan server lokal
php artisan serve
# Server akan berjalan di http://127.0.0.1:8000
```

> **Akun Default untuk Uji Coba:**
> - **Email:** `test@example.com`
> - **Password:** `password`

### 2. Flutter App (`FlutterApps`)

```bash
cd FlutterApps

# Unduh dependensi
flutter pub get

# Jalankan aplikasi (pilih device / emulator / linux desktop)
flutter run
```

---

## 🔑 Endpoint API Awal

| Method | Endpoint | Keterangan |
| :--- | :--- | :--- |
| `POST` | `/api/register` | Mendaftarkan akun baru |
| `POST` | `/api/login` | Login dan mendapatkan Sanctum Bearer Token |
| `GET`  | `/api/profile` | Mengambil data user yang sedang login (Bearer Token) |
| `POST` | `/api/logout` | Revoke token / logout (Bearer Token) |
