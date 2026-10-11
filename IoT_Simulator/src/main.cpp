#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// =================================================================
// 1. IDENTITAS PERANGKAT WEARABLE
// =================================================================
#define DEVICE_MAC  "00:1B:44:11:3A:B7"
#define USER_ID     1

// =================================================================
// 2. KONFIGURASI BLUETOOTH LOW ENERGY (BLE)
// =================================================================
#define BLE_DEVICE_NAME         "Klimo-A3F2"
#define BLE_SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define BLE_CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pTelemetryCharacteristic = nullptr;
bool bleClientConnected = false;

class KlimoServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        bleClientConnected = true;
        Serial.println("[BLE] Smartphone Berhasil Terhubung!");
    }
    void onDisconnect(BLEServer* pServer) {
        bleClientConnected = false;
        Serial.println("[BLE] Smartphone Terputus. Memulai ulang siaran Bluetooth...");
        BLEDevice::startAdvertising();
    }
};

// =================================================================
// 3. KONFIGURASI WIFI SOFTAP & WEB CONTROLLER
// =================================================================
const char* AP_SSID = "Klimo-Simulator";
const char* AP_PASS = "klimo123";

WebServer server(80);

// Status sensor terkini (dikontrol penuh lewat slider web)
float currentUV = 2.0;
float currentTemp = 28.0;
float currentHum = 65.0;
int currentVOC = 55;
double currentLat = -6.200000;
double currentLng = 106.816666;

unsigned long lastTelemetryTime = 0;

// =================================================================
// 4. TAMPILAN WEB CONTROLLER (HTML + CSS + JAVASCRIPT SLIDER)
// =================================================================
const char INDEX_HTML[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Klimo Wearth - IoT Hardware Controller</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body { background: #0f172a; color: #f8fafc; padding: 16px; display: flex; justify-content: center; }
    .card { background: #1e293b; max-width: 480px; width: 100%; border-radius: 16px; padding: 24px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }
    h1 { font-size: 20px; font-weight: 700; color: #38bdf8; margin-bottom: 4px; }
    p.sub { font-size: 13px; color: #94a3b8; margin-bottom: 20px; }
    .badge { display: inline-block; padding: 4px 10px; border-radius: 999px; font-size: 11px; font-weight: 600; margin-bottom: 16px; background: #0369a1; color: #e0f2fe; }
    .sensor-group { margin-bottom: 18px; }
    .sensor-header { display: flex; justify-content: space-between; font-size: 14px; font-weight: 600; margin-bottom: 6px; }
    .sensor-val { color: #38bdf8; font-weight: 700; }
    input[type=range] { width: 100%; height: 6px; border-radius: 4px; background: #334155; outline: none; -webkit-appearance: none; accent-color: #38bdf8; }
    .presets { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; margin: 20px 0 16px; }
    button { padding: 10px 8px; border-radius: 10px; border: 1px solid #475569; background: #334155; color: #f8fafc; font-size: 12px; font-weight: 600; cursor: pointer; transition: 0.15s; }
    button:hover { background: #475569; }
    .btn-hot { border-color: #ef4444; color: #fca5a5; }
    .btn-pol { border-color: #f59e0b; color: #fde68a; }
    .btn-norm { border-color: #10b981; color: #a7f3d0; }
    .btn-send { width: 100%; padding: 12px; background: #0284c7; color: white; border: none; border-radius: 12px; font-size: 14px; font-weight: 700; cursor: pointer; }
    .status-box { margin-top: 16px; padding: 10px; border-radius: 8px; background: #0f172a; font-size: 12px; color: #94a3b8; text-align: center; border: 1px dashed #334155; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">ESP32 HARDWARE SIMULATOR</div>
    <h1>Klimo Wearth Controller</h1>
    <p class="sub">Ubah slider di bawah untuk memancarkan data ke Bluetooth HP</p>

    <div class="sensor-group">
      <div class="sensor-header">
        <span>Indeks Radiasi UV</span>
        <span class="sensor-val" id="uvVal">2.0</span>
      </div>
      <input type="range" id="uv" min="0" max="12" step="0.1" value="2.0" oninput="updateVal('uv')">
    </div>

    <div class="sensor-group">
      <div class="sensor-header">
        <span>Suhu Lingkungan (°C)</span>
        <span class="sensor-val" id="tempVal">28.0°C</span>
      </div>
      <input type="range" id="temp" min="18" max="45" step="0.5" value="28.0" oninput="updateVal('temp')">
    </div>

    <div class="sensor-group">
      <div class="sensor-header">
        <span>Kelembaban Udara (%)</span>
        <span class="sensor-val" id="humVal">65.0%</span>
      </div>
      <input type="range" id="hum" min="20" max="95" step="1" value="65.0" oninput="updateVal('hum')">
    </div>

    <div class="sensor-group">
      <div class="sensor-header">
        <span>Kualitas Udara Gas VOC (Index)</span>
        <span class="sensor-val" id="vocVal">55</span>
      </div>
      <input type="range" id="voc" min="20" max="500" step="5" value="55" oninput="updateVal('voc')">
    </div>

    <div class="presets">
      <button class="btn-norm" onclick="applyPreset(1.8, 27.0, 68, 50)">Normal</button>
      <button class="btn-hot" onclick="applyPreset(11.5, 38.5, 38, 120)">UV Ekstrem</button>
      <button class="btn-pol" onclick="applyPreset(3.2, 31.0, 52, 420)">Polusi Gas</button>
    </div>

    <button class="btn-send" onclick="sendData()">Kirimkan ke Bluetooth HP</button>
    <div class="status-box" id="status">Status: Siap memancarkan Bluetooth</div>
  </div>

  <script>
    function updateVal(type) {
      const v = document.getElementById(type).value;
      if (type === 'temp') document.getElementById('tempVal').innerText = v + '°C';
      else if (type === 'hum') document.getElementById('humVal').innerText = v + '%';
      else document.getElementById(type + 'Val').innerText = v;
      sendData();
    }

    function applyPreset(u, t, h, v) {
      document.getElementById('uv').value = u;
      document.getElementById('temp').value = t;
      document.getElementById('hum').value = h;
      document.getElementById('voc').value = v;
      updateVal('uv');
      updateVal('temp');
      updateVal('hum');
      updateVal('voc');
    }

    function sendData() {
      const u = document.getElementById('uv').value;
      const t = document.getElementById('temp').value;
      const h = document.getElementById('hum').value;
      const v = document.getElementById('voc').value;
      
      fetch(`/set?uv=${u}&temp=${t}&hum=${h}&voc=${v}`)
        .then(res => res.json())
        .then(data => {
          document.getElementById('status').innerText = 'Terkirim via Bluetooth: ' + new Date().toLocaleTimeString();
        })
        .catch(err => {
          document.getElementById('status').innerText = 'Mengirim data...';
        });
    }
  </script>
</body>
</html>
)rawliteral";

// =================================================================
// 5. PENGIRIMAN DATA VIA BLUETOOTH GATT NOTIFICATION
// =================================================================
void broadcastTelemetry() {
    JsonDocument doc;
    doc["mac_address"] = DEVICE_MAC;
    doc["user_id"] = USER_ID;
    doc["uv_index"] = serialized(String(currentUV, 1));
    doc["temperature"] = serialized(String(currentTemp, 1));
    doc["humidity"] = serialized(String(currentHum, 1));
    doc["voc"] = currentVOC;
    doc["latitude"] = serialized(String(currentLat, 6));
    doc["longitude"] = serialized(String(currentLng, 6));

    String jsonString;
    serializeJson(doc, jsonString);

    Serial.println("\n------------------------------------------------");
    Serial.println("[IoT] Data Telemetri Disiarkan via Bluetooth:");
    Serial.println(jsonString);

    if (pTelemetryCharacteristic != nullptr) {
        pTelemetryCharacteristic->setValue(jsonString.c_str());
        pTelemetryCharacteristic->notify();
        Serial.println("[BLE] Paket terkirim ke Bluetooth Smartphone.");
    }
    Serial.println("------------------------------------------------");
}

void handleRoot() {
    server.send_P(200, "text/html", INDEX_HTML);
}

void handleSet() {
    if (server.hasArg("uv")) currentUV = server.arg("uv").toFloat();
    if (server.hasArg("temp")) currentTemp = server.arg("temp").toFloat();
    if (server.hasArg("hum")) currentHum = server.arg("hum").toFloat();
    if (server.hasArg("voc")) currentVOC = server.arg("voc").toInt();

    broadcastTelemetry();

    String res = "{\"status\":\"ok\",\"uv\":" + String(currentUV, 1) + 
                 ",\"temp\":" + String(currentTemp, 1) + 
                 ",\"hum\":" + String(currentHum, 1) + 
                 ",\"voc\":" + String(currentVOC) + "}";
    server.send(200, "application/json", res);
}

void handleStatus() {
    String res = "{\"status\":\"ok\",\"mac_address\":\"" + String(DEVICE_MAC) + 
                 "\",\"uv_index\":" + String(currentUV, 1) + 
                 ",\"temperature\":" + String(currentTemp, 1) + 
                 ",\"humidity\":" + String(currentHum, 1) + 
                 ",\"voc\":" + String(currentVOC) + 
                 ",\"latitude\":" + String(currentLat, 6) + 
                 ",\"longitude\":" + String(currentLng, 6) + "}";
    server.send(200, "application/json", res);
}

void setupBLE() {
    Serial.println("[BLE] Mengaktifkan Bluetooth Low Energy...");
    BLEDevice::init(BLE_DEVICE_NAME);
    BLEServer *pServer = BLEDevice::createServer();
    pServer->setCallbacks(new KlimoServerCallbacks());

    BLEService *pService = pServer->createService(BLE_SERVICE_UUID);
    pTelemetryCharacteristic = pService->createCharacteristic(
        BLE_CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTelemetryCharacteristic->addDescriptor(new BLE2902());
    pService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(BLE_SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();

    Serial.print("[BLE] Bluetooth Aktif! Siap di-scan di HP dengan nama: '");
    Serial.print(BLE_DEVICE_NAME);
    Serial.println("'");
}

void setupWiFiAP() {
    Serial.println("[WiFi] Mengaktifkan Hotspot Web Controller...");
    WiFi.mode(WIFI_AP);
    WiFi.softAP(AP_SSID, AP_PASS);

    Serial.print("[WiFi] Hotspot SSID : ");
    Serial.println(AP_SSID);
    Serial.print("[WiFi] Password     : ");
    Serial.println(AP_PASS);
    Serial.print("[WiFi] Buka di Browser: http://");
    Serial.println(WiFi.softAPIP());

    server.on("/", HTTP_GET, handleRoot);
    server.on("/set", HTTP_GET, handleSet);
    server.on("/status", HTTP_GET, handleStatus);
    server.begin();
    Serial.println("[Web] Server Controller Aktif di port 80!");
}

void setup() {
    Serial.begin(115200);
    delay(1500);

    Serial.println("\n================================================");
    Serial.println("   KLIMO WEARTH - PURE HARDWARE CONTROLLER DEMO ");
    Serial.println("   100% Bebas Sensor Fisik (Zero Hardware Wire) ");
    Serial.println("================================================");

    setupBLE();
    setupWiFiAP();
}

void loop() {
    server.handleClient();

    // Broadcast periodik setiap 3 detik agar aplikasi HP terus menerima data terkini
    unsigned long currentMillis = millis();
    if (currentMillis - lastTelemetryTime >= 3000) {
        lastTelemetryTime = currentMillis;
        broadcastTelemetry();
    }
}
