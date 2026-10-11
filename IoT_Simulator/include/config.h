#ifndef CONFIG_H
#define CONFIG_H

// ==========================================
// PENGATURAN KONEKSI JARINGAN (WIFI)
// ==========================================
// Ganti dengan SSID dan Password WiFi di tempat Anda
#define WIFI_SSID "WIFI_NAME"
#define WIFI_PASSWORD "WIFI_PASSWORD"

// ==========================================
// PENGATURAN BACKEND LARAVEL API
// ==========================================
// Jika backend berjalan di komputer lokal (misal IP LAN: 192.168.2.19)
// Pastikan port 8000 terbuka dan backend listen di 0.0.0.0 (php artisan serve --host=0.0.0.0)
#define API_SERVER_URL "http://192.168.2.19:8000/api/telemetry"

// ==========================================
// IDENTITAS PERANGKAT (ESP32-C3)
// ==========================================
#define DEVICE_MAC "00:1B:44:11:3A:B7"
#define USER_ID 1

// ==========================================
// PIN I2C UNTUK ESP32-C3
// ==========================================
// Pin standar I2C ESP32-C3: SDA = GPIO 4, SCL = GPIO 5
#define I2C_SDA_PIN 4
#define I2C_SCL_PIN 5

// Pin Analog untuk Sensor UV Analog / Potentiometer Wokwi
#define UV_ADC_PIN 2

// Pin Analog untuk Potentiometer Suhu Wokwi
#define TEMP_ADC_PIN 3

// Interval pengiriman data ke server (milidetik)
#define TELEMETRY_INTERVAL_MS 5000

#endif // CONFIG_H
