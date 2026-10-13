@echo off
setlocal enabledelayedexpansion
title KLIMO WEARTH - ECOSYSTEM DEMO RUNNER (WINDOWS)

set "ROOT_DIR=%~dp0"
set "BACKEND_DIR=%ROOT_DIR%Backend"
set "IOT_DIR=%ROOT_DIR%IoT_Simulator"
set "FLUTTER_DIR=%ROOT_DIR%FlutterApps"

:menu
cls
echo =====================================================
echo        KLIMO WEARTH - ECOSYSTEM DEMO RUNNER (WINDOWS)
echo =====================================================
echo Arsitektur      : Offline-First (Local SQLite + Sync Cloud)
echo Target Hardware : ESP32-C3 DevKit (BLE + Web Controller)
echo Hotspot ESP32   : SSID 'Klimo-Simulator' (IP: 192.168.4.1)
echo Backend Server  : http://127.0.0.1:8000/api
echo -----------------------------------------------------
echo.
echo Pilih mode yang ingin dijalankan:
echo   [1] Jalankan Aplikasi Flutter Saja (Windows / Android)
echo   [2] Jalankan Backend Laravel Saja (host: 0.0.0.0:8000)
echo   [3] Full Stack Demo (Backend Laravel di background + Flutter App)
echo   [4] Flash Firmware ke Board ESP32 (PlatformIO Upload via USB)
echo   [5] Buka Serial Monitor ESP32 (115200 baud)
echo   [6] Kompilasi / Validasi Firmware ESP32 (pio run)
echo   [7] Jalankan Python Simulator (Backend Data Injector)
echo   [8] Info Panduan Demo Lomba ^& Web Controller ESP32
echo   [q] Keluar
echo.

set /p choice="Masukkan pilihan [1-8]: "

if "%choice%"=="1" goto run_flutter
if "%choice%"=="2" goto run_backend
if "%choice%"=="3" goto run_fullstack
if "%choice%"=="4" goto flash_esp32
if "%choice%"=="5" goto monitor_esp32
if "%choice%"=="6" goto compile_esp32
if "%choice%"=="7" goto run_python
if "%choice%"=="8" goto info_guide
if /i "%choice%"=="q" goto end
goto menu

:run_flutter
echo.
echo [INFO] Menjalankan Aplikasi Flutter...
cd /d "%FLUTTER_DIR%"
flutter run
pause
goto menu

:run_backend
echo.
echo [INFO] Menjalankan Backend Laravel di host 0.0.0.0:8000...
cd /d "%BACKEND_DIR%"
php artisan serve --host=0.0.0.0 --port=8000
pause
goto menu

:run_fullstack
echo.
echo [INFO] Menyalakan Backend Laravel di jendela terpisah...
cd /d "%BACKEND_DIR%"
start "Klimo Laravel Backend" cmd /k "php artisan serve --host=0.0.0.0 --port=8000"
timeout /t 2 >nul
echo [INFO] Menjalankan Aplikasi Flutter...
cd /d "%FLUTTER_DIR%"
flutter run
pause
goto menu

:flash_esp32
echo.
echo [INFO] Mengunggah Firmware ke Board ESP32...
cd /d "%IOT_DIR%"
pio run -t upload
pause
goto menu

:monitor_esp32
echo.
echo [INFO] Membuka Serial Monitor ESP32 (115200)...
cd /d "%IOT_DIR%"
pio device monitor -b 115200
pause
goto menu

:compile_esp32
echo.
echo [INFO] Melakukan Kompilasi Firmware ESP32 dengan PlatformIO...
cd /d "%IOT_DIR%"
pio run
pause
goto menu

:run_python
echo.
echo [INFO] Menjalankan IoT Python Simulator...
cd /d "%IOT_DIR%"
python simulator.py
pause
goto menu

:info_guide
cls
echo =====================================================
echo          PANDUAN PRAKTIS DEMO LOMBA (3 TINGKAT)
echo =====================================================
echo 1. DEMO HARDWARE UTAMA (ESP32 Polos):
echo    - Colok ESP32 ke USB/power bank (tanpa sensor kabel).
echo    - Hubungkan HP/laptop ke WiFi: Klimo-Simulator (Pass: klimo123).
echo    - Buka browser: http://192.168.4.1 untuk menggeser slider UV/Suhu.
echo    - Buka aplikasi Flutter di HP/laptop: data slider terdeteksi secara live.
echo.
echo 2. DEMO MANDIRI APLIKASI (Backup Tanpa Hardware):
echo    - Buka aplikasi Flutter, masuk via tombol 'Demo Mode' di Login.
echo    - Atau di Profil, aktifkan 'Simulasi Lingkungan' dan pilih skenario
echo      (Otomatis, Normal/Sejuk, Panas Ekstrem, Polusi Udara).
echo.
echo 3. PROPOSAL ^& LAPORAN VISUAL:
echo    - Buka berkas diagram Wokwi di: IoT_Simulator\diagram.json.
echo =====================================================
echo.
pause
goto menu

:end
echo Keluar.
exit /b 0
