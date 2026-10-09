# 🛰️ Klimo Wearth - Firmware ESP32-C3 (PlatformIO)

Proyek ini adalah firmware resmi untuk wearable IoT **Klimo Wearth** berbasis **ESP32-C3** (RISC-V) menggunakan ekosistem **PlatformIO (Arduino Framework)**.

---

## 📁 Struktur Direktori

```text
IoT_Simulator/
├── platformio.ini         # Konfigurasi PlatformIO (Board: ESP32-C3 DevKitM-1)
├── include/
│   └── config.h           # Konfigurasi WiFi, URL Backend, dan Pinout
├── src/
│   └── main.cpp           # Kode Utama Firmware (I2C Sensor, WiFi, JSON HTTP POST)
├── simulator.py           # Simulator software Python (untuk testing tanpa hardware)
└── README.md
```

---

## 🔌 Rangkaian Pinout Hardware (Wiring)

Sensor berkomunikasi melalui bus **I2C** bersama:

| Pin ESP32-C3 | Pin Sensor (SHT40 / LTR-390 / SGP41) | Keterangan |
| :--- | :--- | :--- |
| **3V3** | VCC / VIN | Tegangan 3.3V |
| **GND** | GND | Ground |
| **GPIO 4** | SDA | Serial Data I2C |
| **GPIO 5** | SCL | Serial Clock I2C |
| **GPIO 2** *(Opsional)* | OUT / AOUT | Input Analog jika menggunakan sensor UV analog |

> **Fitur Cerdas (Smart Sensor Fallback):**
> Firmware telah dilengkapi deteksi otomatis. Jika modul sensor fisik belum terpasang, firmware secara otomatis beralih ke simulasi pembacaan lingkungan realistis sehingga pengujian koneksi WiFi & transmisi ke server tetap berjalan lancar.

---

## ⚙️ Konfigurasi (`include/config.h`)

Sebelum mengunggah ke board, buka [include/config.h](include/config.h) dan sesuaikan:

```cpp
#define WIFI_SSID       "NAMA_WIFI_ANDA"
#define WIFI_PASSWORD   "PASSWORD_WIFI"

// Arahkan ke IP komputer Anda jika backend berjalan lokal
#define API_SERVER_URL  "http://192.168.2.19:8000/api/telemetry"
```

---

## 🚀 Perintah PlatformIO (CLI)

Jalankan perintah ini di dalam direktori `IoT_Simulator/`:

### 1. Kompilasi Firmware
```bash
pio run
```

### 2. Upload / Flash ke Board ESP32-C3
Colokkan kabel USB-C dari ESP32-C3 ke komputer, lalu:
```bash
pio run -t upload
```

### 3. Buka Serial Monitor (Melihat Log Realtime)
```bash
pio device monitor -b 115200
```

### 4. Upload & Buka Monitor Sekaligus
```bash
pio run -t upload && pio device monitor -b 115200
```

---

## 💻 Alternatif: Software Simulator (Python)
Jika sedang presentasi atau tidak membawa modul ESP32-C3 fisik:
```bash
python3 simulator.py
```
*(Menyediakan 4 pilihan skenario: Normal, UV Ekstrem, Polusi Gas VOC, dan Realtime Fluktuatif).*
