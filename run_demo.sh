#!/usr/bin/env bash

# Warna ANSI untuk terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ROOT_DIR="/home/ronaltama/PROJECT/KlimoApp"
BACKEND_DIR="$ROOT_DIR/Backend"
IOT_DIR="$ROOT_DIR/IoT_Simulator"
FLUTTER_DIR="$ROOT_DIR/FlutterApps"

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}       KLIMO WEARTH - ECOSYSTEM DEMO RUNNER         ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo -e "Arsitektur      : Offline-First (Huawei Health Style)"
echo -e "Target Hardware : ESP32-C3 DevKit (BLE + Web Controller)"
echo -e "Hotspot ESP32   : SSID 'Klimo-Simulator' (IP: 192.168.4.1)"
echo -e "Backend Server  : http://127.0.0.1:8000/api"
echo -e "${BLUE}-----------------------------------------------------${NC}"
echo ""
echo "Pilih mode yang ingin dijalankan:"
echo -e "  [1] ${BLUE}Jalankan Aplikasi Flutter Saja${NC} (Offline-First / Demo Langsung)"
echo -e "  [2] ${CYAN}Flash Firmware ke Board ESP32${NC} (PlatformIO Upload via USB)"
echo -e "  [3] ${CYAN}Buka Serial Monitor ESP32${NC} (115200 baud)"
echo -e "  [4] ${CYAN}Kompilasi / Validasi Firmware ESP32${NC} (pio run)"
echo -e "  [5] ${GREEN}Jalankan Backend Laravel Saja${NC} (host: 0.0.0.0:8000)"
echo -e "  [6] ${GREEN}Full Stack Demo${NC} (Backend Laravel + Flutter App)"
echo -e "  [7] ${YELLOW}Jalankan Python Simulator${NC} (Backend Data Injector)"
echo -e "  [8] ${YELLOW}Info Panduan Demo Lomba & Web Controller ESP32${NC}"
echo -e "  [q] Keluar"
echo ""

read -p "Masukkan pilihan [1-8]: " choice

case $choice in
    1)
        echo -e "${BLUE}[INFO] Menjalankan Aplikasi Flutter (Mode Offline-First)...${NC}"
        cd "$FLUTTER_DIR" && flutter run
        ;;
    2)
        echo -e "${CYAN}[INFO] Mengunggah Firmware ke Board ESP32...${NC}"
        cd "$IOT_DIR" && pio run -t upload
        ;;
    3)
        echo -e "${CYAN}[INFO] Membuka Serial Monitor ESP32 (115200)...${NC}"
        cd "$IOT_DIR" && pio device monitor -b 115200
        ;;
    4)
        echo -e "${CYAN}[INFO] Melakukan Kompilasi Firmware ESP32 dengan PlatformIO...${NC}"
        cd "$IOT_DIR" && pio run
        ;;
    5)
        echo -e "${GREEN}[INFO] Menjalankan Backend Laravel di host 0.0.0.0:8000...${NC}"
        cd "$BACKEND_DIR" && php artisan serve --host=0.0.0.0 --port=8000
        ;;
    6)
        echo -e "${GREEN}[INFO] Menyalakan Backend Laravel di background (0.0.0.0:8000)...${NC}"
        cd "$BACKEND_DIR"
        php artisan serve --host=0.0.0.0 --port=8000 > /dev/null 2>&1 &
        LARAVEL_PID=$!
        echo -e "Backend aktif dengan PID: $LARAVEL_PID"

        sleep 2
        echo -e "\n${BLUE}[INFO] Menjalankan Aplikasi Flutter...${NC}"
        cd "$FLUTTER_DIR"
        flutter run

        # Cleanup saat Flutter ditutup
        echo -e "\n${YELLOW}Membersihkan proses background...${NC}"
        kill $LARAVEL_PID 2>/dev/null
        echo -e "${GREEN}Selesai.${NC}"
        ;;
    7)
        echo -e "${YELLOW}[INFO] Menjalankan IoT Python Simulator...${NC}"
        cd "$IOT_DIR" && python3 simulator.py
        ;;
    8)
        echo -e "${BLUE}=====================================================${NC}"
        echo -e "${GREEN}         PANDUAN PRAKTIS DEMO LOMBA (3 TINGKAT)       ${NC}"
        echo -e "${BLUE}=====================================================${NC}"
        echo -e "1. DEMO HARDWARE UTAMA (ESP32 Polos):"
        echo -e "   - Colok ESP32 ke USB/power bank (tanpa sensor kabel)."
        echo -e "   - Hubungkan HP/laptop ke WiFi: ${YELLOW}Klimo-Simulator${NC} (Pass: ${YELLOW}klimo123${NC})."
        echo -e "   - Buka browser: ${CYAN}http://192.168.4.1${NC} untuk menggeser slider UV/Suhu."
        echo -e "   - Buka aplikasi Flutter di HP/laptop: data slider terdeteksi secara live."
        echo ""
        echo -e "2. DEMO MANDIRI APLIKASI (Backup Tanpa Hardware):"
        echo -e "   - Buka aplikasi Flutter, klik tombol '${CYAN}Mode${NC}' di banner Beranda."
        echo -e "   - Pilih skenario (Normal, Panas Ekstrem, Polusi, atau Otomatis)."
        echo ""
        echo -e "3. PROPOSAL & LAPORAN VISUAL:"
        echo -e "   - Buka berkas diagram Wokwi di: ${CYAN}IoT_Simulator/diagram.json${NC}."
        echo -e "${BLUE}=====================================================${NC}"
        ;;
    *)
        echo "Keluar."
        exit 0
        ;;
esac
