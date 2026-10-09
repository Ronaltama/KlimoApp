#!/usr/bin/env bash

# Warna ANSI
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
echo -e "${GREEN}       🌿 KLIMO WEARTH - ECOSYSTEM RUNNER DEMO       ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo -e "IP Komputer Host : ${YELLOW}127.0.0.1${NC} / LAN: ${YELLOW}192.168.2.19${NC}"
echo -e "Android Emulator : ${YELLOW}http://10.0.2.2:8000/api${NC}"
echo -e "Desktop / Web    : ${YELLOW}http://127.0.0.1:8000/api${NC}"
echo -e "${BLUE}-----------------------------------------------------${NC}"
echo ""
echo "Pilih opsi yang ingin dijalankan:"
echo -e "  [1] ${GREEN}Nyalakan Backend Laravel Saja${NC} (host: 0.0.0.0:8000)"
echo -e "  [2] ${YELLOW}Nyalakan IoT Python Simulator Saja${NC}"
echo -e "  [3] ${BLUE}Nyalakan Flutter Mobile App Saja${NC}"
echo -e "  [4] ${GREEN}Nyalakan SEMUA (Full Stack Demo)${NC} (Laravel + Simulator + Flutter)"
echo -e "  [5] ${CYAN}PlatformIO: Build / Compile Firmware ESP32-C3${NC}"
echo -e "  [6] ${CYAN}PlatformIO: Upload / Flash ke Board ESP32-C3${NC}"
echo -e "  [7] ${CYAN}PlatformIO: Buka Serial Monitor (115200 baud)${NC}"
echo -e "  [q] Keluar"
echo ""

read -p "Masukkan pilihan [1-7]: " choice

case $choice in
    1)
        echo -e "${GREEN}▶ Menjalankan Backend Laravel...${NC}"
        cd "$BACKEND_DIR" && php artisan serve --host=0.0.0.0 --port=8000
        ;;
    2)
        echo -e "${YELLOW}▶ Menjalankan IoT Sensor Simulator...${NC}"
        cd "$IOT_DIR" && python3 simulator.py
        ;;
    3)
        echo -e "${BLUE}▶ Menjalankan Flutter App...${NC}"
        cd "$FLUTTER_DIR" && flutter run
        ;;
    4)
        echo -e "${GREEN}▶ Menyalakan Backend Laravel di background (0.0.0.0:8000)...${NC}"
        cd "$BACKEND_DIR"
        php artisan serve --host=0.0.0.0 --port=8000 > /dev/null 2>&1 &
        LARAVEL_PID=$!
        echo -e "Backend berjalan dengan PID: $LARAVEL_PID"

        sleep 2
        echo -e "${YELLOW}▶ Menjalankan IoT Simulator di background...${NC}"
        cd "$IOT_DIR"
        python3 simulator.py 4 > /dev/null 2>&1 &
        IOT_PID=$!
        echo -e "IoT Simulator streaming aktif dengan PID: $IOT_PID"

        echo -e "\n${BLUE}▶ Menjalankan Flutter App...${NC}"
        cd "$FLUTTER_DIR"
        flutter run

        # Cleanup saat Flutter ditutup
        echo -e "\n${YELLOW}Membersihkan proses background...${NC}"
        kill $LARAVEL_PID 2>/dev/null
        kill $IOT_PID 2>/dev/null
        echo -e "${GREEN}Selesai.${NC}"
        ;;
    5)
        echo -e "${CYAN}▶ Melakukan Kompilasi Firmware ESP32-C3 dengan PlatformIO...${NC}"
        cd "$IOT_DIR" && pio run
        ;;
    6)
        echo -e "${CYAN}▶ Mengunggah Firmware ke Board ESP32-C3...${NC}"
        cd "$IOT_DIR" && pio run -t upload
        ;;
    7)
        echo -e "${CYAN}▶ Membuka Serial Monitor ESP32-C3 (115200)...${NC}"
        cd "$IOT_DIR" && pio device monitor -b 115200
        ;;
    *)
        echo "Keluar."
        exit 0
        ;;
esac
