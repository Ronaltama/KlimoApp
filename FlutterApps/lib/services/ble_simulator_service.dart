import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'local_data_service.dart';

/// Mode simulasi BLE (sama persis dengan mode di simulator.py)
enum BleSimMode {
  normal,       // UV rendah ~1.8, Suhu 27°C, VOC 65
  uvExtreme,    // UV 10.5+, Suhu 38°C, VOC 120
  pollution,    // UV 3.0, Suhu 31°C, VOC 420
  auto,         // Fluktuatif realistis (default)
}

/// Enum status koneksi BLE
enum BleConnectionStatus {
  disconnected,   // Alat tidak tersambung
  scanning,       // Sedang mencari alat BLE
  connected,      // Tersambung ke alat Klimo
  simulating,     // Mode simulasi virtual (demo tanpa alat fisik)
}

/// Callback saat data baru diterima dari BLE (atau simulator)
typedef OnTelemetryReceived = void Function(TelemetryRecord record);

/// Service simulasi Bluetooth BLE yang berjalan langsung di dalam Flutter.
/// Saat alat fisik tidak tersedia (demo di laptop/emulator), service ini
/// memutar data sensor yang realistis seolah-olah diterima dari wearable ESP32.
///
/// Pada alat fisik sebenarnya, service ini diganti dengan flutter_blue_plus
/// yang membaca dari BLE GATT Characteristic ESP32-C3.
class BleSimulatorService {
  static final BleSimulatorService _instance = BleSimulatorService._internal();
  factory BleSimulatorService() => _instance;
  BleSimulatorService._internal();

  static const String _deviceMac = '00:1B:44:11:3A:B7';
  static const String _deviceName = 'Klimo-A3F2';
  static const int _intervalSeconds = 3;

  final _random = Random();
  Timer? _simulationTimer;
  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  BleSimMode _mode = BleSimMode.auto;
  OnTelemetryReceived? _onDataReceived;
  TelemetryRecord? _lastRecord;

  // ValueNotifier untuk reaktif UI
  final _statusNotifier = StreamController<BleConnectionStatus>.broadcast();
  final _recordNotifier = StreamController<TelemetryRecord>.broadcast();

  Stream<BleConnectionStatus> get statusStream => _statusNotifier.stream;
  Stream<TelemetryRecord> get recordStream => _recordNotifier.stream;

  BleConnectionStatus get status => _status;
  TelemetryRecord? get lastRecord => _lastRecord;
  String get deviceName => _deviceName;
  bool get isActive => _status == BleConnectionStatus.connected ||
                       _status == BleConnectionStatus.simulating;

  /// Mulai simulasi BLE virtual (mode demo tanpa alat fisik)
  void startSimulation({
    BleSimMode mode = BleSimMode.auto,
    OnTelemetryReceived? onData,
  }) {
    _mode = mode;
    _onDataReceived = onData;
    _setStatus(BleConnectionStatus.scanning);

    // Simulasikan delay "scanning" 1.5 detik sebelum "tersambung"
    Future.delayed(const Duration(milliseconds: 1500), () {
      _setStatus(BleConnectionStatus.simulating);
      _simulationTimer?.cancel();
      _simulationTimer = Timer.periodic(
        const Duration(seconds: _intervalSeconds),
        (_) => _generateAndEmit(),
      );
      // Langsung emit data pertama tanpa menunggu timer
      _generateAndEmit();
    });
  }

  /// Ubah mode simulasi tanpa henti
  void changeMode(BleSimMode newMode) {
    _mode = newMode;
  }

  /// Hentikan simulasi / disconnect
  void stop() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _setStatus(BleConnectionStatus.disconnected);
  }

  /// Generate data sensor (mencoba membaca dari ESP32 Hardware Live terlebih dahulu)
  Future<void> _generateAndEmit() async {
    final liveRecord = await _tryFetchFromHardwareAp();
    final record = liveRecord ?? _generateRecord(_mode);
    _lastRecord = record;

    if (liveRecord != null) {
      if (_status != BleConnectionStatus.connected) {
        _setStatus(BleConnectionStatus.connected);
      }
    } else {
      if (_status != BleConnectionStatus.simulating && _status != BleConnectionStatus.scanning) {
        _setStatus(BleConnectionStatus.simulating);
      }
    }

    // Simpan otomatis ke database lokal HP
    await LocalDataService.saveRecord(record);

    // Broadcast ke semua listener (HomeScreen, dll)
    _recordNotifier.add(record);
    _onDataReceived?.call(record);
  }

  /// Membaca telemetri live dari ESP32 Web Controller jika terhubung ke WiFi Hotspot-nya
  Future<TelemetryRecord?> _tryFetchFromHardwareAp() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.4.1/status'),
      ).timeout(const Duration(milliseconds: 800));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TelemetryRecord(
          macAddress: data['mac_address'] ?? _deviceMac,
          uvIndex: (data['uv_index'] as num?)?.toDouble() ?? 0.0,
          temperature: (data['temperature'] as num?)?.toDouble() ?? 28.0,
          humidity: (data['humidity'] as num?)?.toDouble() ?? 65.0,
          voc: (data['voc'] as num?)?.toInt() ?? 55,
          latitude: (data['latitude'] as num?)?.toDouble() ?? -6.2,
          longitude: (data['longitude'] as num?)?.toDouble() ?? 106.816,
          timestamp: DateTime.now(),
        );
      }
    } catch (_) {}
    return null;
  }

  TelemetryRecord _generateRecord(BleSimMode mode) {
    double uv, temp, hum;
    int voc;

    switch (mode) {
      case BleSimMode.normal:
        uv = _rnd(1.0, 2.5);
        temp = _rnd(26.0, 28.5);
        hum = _rnd(60.0, 70.0);
        voc = _rndInt(40, 90);
        break;
      case BleSimMode.uvExtreme:
        uv = _rnd(10.0, 11.8);
        temp = _rnd(36.0, 39.5);
        hum = _rnd(40.0, 50.0);
        voc = _rndInt(100, 160);
        break;
      case BleSimMode.pollution:
        uv = _rnd(2.5, 4.0);
        temp = _rnd(29.0, 32.0);
        hum = _rnd(65.0, 80.0);
        voc = _rndInt(380, 480);
        break;
      case BleSimMode.auto:
        uv = _rnd(0.5, 11.5);
        temp = _rnd(25.0, 38.0);
        hum = _rnd(45.0, 85.0);
        voc = _rndInt(30, 450);
        break;
    }

    // GPS area Jakarta Pusat (bergerak sedikit setiap kali - simulasi pengguna bergerak)
    final lat = -6.200000 + (_random.nextDouble() - 0.5) * 0.01;
    final lng = 106.816666 + (_random.nextDouble() - 0.5) * 0.01;

    return TelemetryRecord(
      macAddress: _deviceMac,
      uvIndex: double.parse(uv.toStringAsFixed(1)),
      temperature: double.parse(temp.toStringAsFixed(1)),
      humidity: double.parse(hum.toStringAsFixed(1)),
      voc: voc,
      latitude: double.parse(lat.toStringAsFixed(6)),
      longitude: double.parse(lng.toStringAsFixed(6)),
      timestamp: DateTime.now(),
      synced: false,
    );
  }

  double _rnd(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  int _rndInt(int min, int max) =>
      min + _random.nextInt(max - min + 1);

  void _setStatus(BleConnectionStatus s) {
    _status = s;
    _statusNotifier.add(s);
  }

  void dispose() {
    stop();
    _statusNotifier.close();
    _recordNotifier.close();
  }
}
