#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "config.h"

// Objek Sensor Hardware
Adafruit_SHT4x sht40;
bool sht40_detected = false;

// Variabel Waktu Telemetri
unsigned long lastTelemetryTime = 0;

// Fungsi Menghubungkan ke WiFi
void connectWiFi() {
    if (WiFi.status() == WL_CONNECTED) return;

    Serial.print("[WiFi] Menghubungkan ke: ");
    Serial.println(WIFI_SSID);
    
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\n[WiFi] Berhasil Terhubung!");
        Serial.print("[WiFi] IP Address: ");
        Serial.println(WiFi.localIP());
        Serial.print("[WiFi] Signal (RSSI): ");
        Serial.print(WiFi.RSSI());
        Serial.println(" dBm");
    } else {
        Serial.println("\n[WiFi] Gagal terhubung (Timeout). Mode simulasi tetap berjalan.");
    }
}

// Inisialisasi Sensor Hardware
void setupSensors() {
    Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
    
    Serial.println("[Sensor] Memeriksa sensor SHT40 (Suhu & Kelembaban)...");
    if (sht40.begin(&Wire)) {
        sht40_detected = true;
        sht40.setPrecision(SHT4X_HIGH_PRECISION);
        sht40.setHeater(SHT4X_NO_HEATER);
        Serial.println("[Sensor] SHT40 Terdeteksi dan Aktif!");
    } else {
        Serial.println("[Sensor] SHT40 TIDAK ditemukan. Mengaktifkan emulasi sensor cerdas.");
    }
}

// Membaca Data Telemetri (Fisik atau Cerdas Emulasi)
void readTelemetry(float &uv, float &temp, float &hum, int &voc, double &lat, double &lng) {
    if (sht40_detected) {
        sensors_event_t humidity_event, temp_event;
        sht40.getEvent(&humidity_event, &temp_event);
        temp = temp_event.temperature;
        hum = humidity_event.relative_humidity;
    } else {
        // Fallback emulasi realistis jika modul belum dicolok
        temp = 27.5 + (random(-20, 30) / 10.0);
        hum = 65.0 + (random(-15, 15) / 10.0);
    }

    // Membaca Sensor UV (Analog atau Emulasi)
    #ifdef UV_ADC_PIN
    int rawUV = analogRead(UV_ADC_PIN);
    float voltage = (rawUV / 4095.0) * 3.3;
    uv = voltage * 10.0; // Kalibrasi index UV
    if (uv <= 0.1) {
        // Simulasi jika pin tidak ada tegangan
        uv = 1.0 + (random(0, 95) / 10.0);
    }
    #else
    uv = 1.0 + (random(0, 95) / 10.0);
    #endif

    // Nilai VOC Index (SGP41)
    voc = random(40, 350);

    // Koordinat GPS Dinamis (Area Jakarta Pusat)
    lat = -6.200000 + (random(-50, 50) / 10000.0);
    lng = 106.816666 + (random(-50, 50) / 10000.0);
}

// Mengirimkan Telemetri ke Laravel API via HTTP POST
void sendTelemetry() {
    float uv = 0, temp = 0, hum = 0;
    int voc = 0;
    double lat = 0, lng = 0;

    readTelemetry(uv, temp, hum, voc, lat, lng);

    // Siapkan Dokumen JSON (ArduinoJson v7)
    JsonDocument doc;
    doc["mac_address"] = DEVICE_MAC;
    doc["user_id"] = USER_ID;
    doc["uv_index"] = serialized(String(uv, 1));
    doc["temperature"] = serialized(String(temp, 1));
    doc["humidity"] = serialized(String(hum, 1));
    doc["voc"] = voc;
    doc["latitude"] = serialized(String(lat, 6));
    doc["longitude"] = serialized(String(lng, 6));

    String jsonString;
    serializeJson(doc, jsonString);

    Serial.println("\n------------------------------------------------");
    Serial.println("[IoT] Mengirim Paket Telemetri ESP32-C3:");
    Serial.println(jsonString);

    if (WiFi.status() == WL_CONNECTED) {
        HTTPClient http;
        http.begin(API_SERVER_URL);
        http.addHeader("Content-Type", "application/json");

        int httpResponseCode = http.POST(jsonString);

        if (httpResponseCode > 0) {
            Serial.printf("[HTTP] Respons Server: %d\n", httpResponseCode);
            String response = http.getString();
            Serial.println("[HTTP] Balasan: " + response);
        } else {
            Serial.printf("[HTTP] Gagal Kirim, Error: %s\n", http.errorToString(httpResponseCode).c_str());
        }
        http.end();
    } else {
        Serial.println("[WiFi] Tidak tersambung ke jaringan. Paket tidak dapat dikirim via HTTP.");
    }
    Serial.println("------------------------------------------------");
}

void setupBLE() {
    Serial.println("[BLE] Memulai Bluetooth Low Energy (BLE)...");
    BLEDevice::init("Klimo-A3F2");
    BLEServer *pServer = BLEDevice::createServer();
    BLEService *pService = pServer->createService("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
    pService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();
    Serial.println("[BLE] Bluetooth Aktif! Siap dipairing sebagai 'Klimo-A3F2'");
}

void setup() {
    Serial.begin(115200);
    delay(2000); // Tunggu Serial monitor aktif

    Serial.println("\n================================================");
    Serial.println("   🛰️  KLIMO WEARTH - FIRMWARE ESP32-C3  ");
    Serial.println("   Framework : PlatformIO (Arduino)            ");
    Serial.println("================================================");

    setupSensors();
    setupBLE();
    connectWiFi();
}

void loop() {
    // Reconnect WiFi jika koneksi terputus
    if (WiFi.status() != WL_CONNECTED) {
        connectWiFi();
    }

    // Eksekusi pengiriman data secara periodik
    unsigned long currentMillis = millis();
    if (currentMillis - lastTelemetryTime >= TELEMETRY_INTERVAL_MS) {
        lastTelemetryTime = currentMillis;
        sendTelemetry();
    }
}
