#!/usr/bin/env python3
#
# simulator.py - Klimo Wearth Backend Injector
#
# CATATAN ARSITEKTUR (Offline-First / Huawei Health Style):
# =========================================================
# Script ini bukan jalur data UTAMA aplikasi. Jalur data utama adalah:
#   Alat ESP32 --[BLE]--> HP (Lokal) --[sync jika ada internet]--> Backend
#
# Script ini digunakan untuk 2 skenario khusus:
#   1. DEMO FULL-STACK di laptop: Mengisi database Backend dengan data dummy
#      sehingga fitur Peta Komunitas (Heatmap) di aplikasi bisa ditampilkan.
#   2. POPULASI AWAL BACKEND: Mengisi data awal di server cloud untuk
#      pengujian fitur komunitas multi-pengguna.
#
# Untuk demo aplikasi standalone (tanpa backend), gunakan tombol "Mode"
# di dalam aplikasi Flutter - BleSimulatorService akan men-generate
# data langsung di HP dan menyimpannya ke SQLite lokal.

import time
import random
import requests
import json
import sys

# Warna ANSI untuk tampilan terminal demo yang menarik
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
BLUE = "\033[94m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"

API_URL = "http://127.0.0.1:8000/api/telemetry"
MAC_ADDRESS = "00:1B:44:11:3A:B7"
USER_ID = 1

def print_banner():
    print(f"{CYAN}{BOLD}")
    print("================================================================")
    print("      🛰️   KLIMO WEARTH - ESP32-C3 IoT SENSOR SIMULATOR        ")
    print("================================================================")
    print(f"{RESET}")
    print(f"Target API Endpoint : {BOLD}{API_URL}{RESET}")
    print(f"Device MAC Address  : {BOLD}{MAC_ADDRESS}{RESET}")
    print(f"User ID             : {BOLD}{USER_ID}{RESET}")
    print("----------------------------------------------------------------\n")

def select_mode():
    print(f"{BOLD}Pilih Mode Demonstrasi IoT:{RESET}")
    print(f"  [1] {GREEN}Normal / Sejuk{RESET}       (UV Rendah ~1.8, Suhu 27°C, VOC 65)")
    print(f"  [2] {RED}Panas Ekstrem (UV Bahaya){RESET} (UV 10.5+, Suhu 38°C, VOC 120)")
    print(f"  [3] {YELLOW}Polusi Udara / Gas VOC Tinggi{RESET} (UV 3.0, Suhu 31°C, VOC 420)")
    print(f"  [4] {CYAN}Mode Realtime Otomatis (Default / Streaming Terus){RESET}")
    
    if len(sys.argv) > 1:
        choice = sys.argv[1]
        print(f"\nMode dipilih via argumen: {choice}")
        return choice

    try:
        choice = input(f"\nMasukkan pilihan [1-4] (default: 4): ").strip()
        if not choice:
            choice = "4"
        return choice
    except (KeyboardInterrupt, EOFError):
        print("\nKeluar.")
        sys.exit(0)

def generate_telemetry(mode):
    if mode == "1": # Normal
        uv = round(random.uniform(1.0, 2.5), 1)
        temp = round(random.uniform(26.0, 28.5), 1)
        hum = round(random.uniform(60.0, 70.0), 1)
        voc = random.randint(40, 90)
    elif mode == "2": # UV Ekstrem
        uv = round(random.uniform(10.0, 11.8), 1)
        temp = round(random.uniform(36.0, 39.5), 1)
        hum = round(random.uniform(40.0, 50.0), 1)
        voc = random.randint(100, 160)
    elif mode == "3": # VOC / Gas Bahaya
        uv = round(random.uniform(2.5, 4.0), 1)
        temp = round(random.uniform(29.0, 32.0), 1)
        hum = round(random.uniform(65.0, 80.0), 1)
        voc = random.randint(380, 480)
    else: # Otomatis / Fluktuatif
        uv = round(random.uniform(0.5, 11.5), 1)
        temp = round(random.uniform(25.0, 38.0), 1)
        hum = round(random.uniform(45.0, 85.0), 1)
        voc = random.randint(30, 450)

    # Lokasi GPS sekitaran Jakarta (bergerak sedikit tiap detik)
    lat = -6.200000 + random.uniform(-0.005, 0.005)
    lng = 106.816666 + random.uniform(-0.005, 0.005)

    return {
        "mac_address": MAC_ADDRESS,
        "user_id": USER_ID,
        "uv_index": uv,
        "temperature": temp,
        "humidity": hum,
        "voc": voc,
        "latitude": round(lat, 6),
        "longitude": round(lng, 6)
    }

def main():
    print_banner()
    mode = select_mode()
    mode_names = {
        "1": "Normal / Sejuk",
        "2": "Panas Ekstrem (UV Bahaya)",
        "3": "Polusi Udara (VOC Tinggi)",
        "4": "Otomatis Realtime"
    }
    print(f"\n{GREEN}▶ Memulai transmisi sensor [Mode: {mode_names.get(mode, 'Otomatis')}]...{RESET}")
    print(f"{YELLOW}Tekan Ctrl+C untuk berhenti.{RESET}\n")

    count = 0
    while True:
        count += 1
        payload = generate_telemetry(mode)
        now = time.strftime('%H:%M:%S')

        # Status badge visualisasi
        uv_status = f"{RED}EKSTREM{RESET}" if payload['uv_index'] >= 8 else (f"{YELLOW}SEDANG{RESET}" if payload['uv_index'] >= 4 else f"{GREEN}AMAN{RESET}")
        voc_status = f"{RED}BURUK{RESET}" if payload['voc'] >= 250 else (f"{YELLOW}SEDANG{RESET}" if payload['voc'] >= 150 else f"{GREEN}BAIK{RESET}")

        try:
            resp = requests.post(API_URL, json=payload, headers={'Content-Type': 'application/json'}, timeout=3)
            if resp.status_code in [200, 201]:
                db_action = f"{GREEN}✔ DB SAVED (201){RESET}" if resp.status_code == 201 else f"{CYAN}⚡ DB SKIPPED (200){RESET}"
                print(f"[{now}] #{count} {db_action} | "
                      f"UV: {BOLD}{payload['uv_index']}{RESET} ({uv_status}) | "
                      f"Temp: {payload['temperature']}°C | "
                      f"Hum: {payload['humidity']}% | "
                      f"VOC: {BOLD}{payload['voc']}{RESET} ({voc_status}) | "
                      f"GPS: ({payload['latitude']}, {payload['longitude']})")
            else:
                print(f"[{now}] #{count} {RED}✖ FAILED (Status: {resp.status_code}){RESET} | {resp.text}")
        except requests.exceptions.ConnectionError:
            print(f"[{now}] #{count} {RED}✖ SERVER OFFLINE!{RESET} Pastikan backend 'php artisan serve' menyala pada {API_URL}")
        except Exception as e:
            print(f"[{now}] #{count} {RED}✖ ERROR:{RESET} {e}")

        time.sleep(3)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{YELLOW}Simulasi dihentikan oleh pengguna.{RESET}")
        sys.exit(0)
