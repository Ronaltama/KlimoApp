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
  int _intervalSeconds = 3;

  int get intervalSeconds => _intervalSeconds;

  void setInterval(int seconds) {
    if (seconds <= 0) return;
    _intervalSeconds = seconds;
    if (_simulationTimer != null && _simulationTimer!.isActive) {
      _simulationTimer!.cancel();
      _simulationTimer = Timer.periodic(
        Duration(seconds: _intervalSeconds),
        (_) => _generateAndEmit(),
      );
    }
  }

  final _random = Random();
  Timer? _simulationTimer;
  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  BleSimMode _mode = BleSimMode.normal;
  OnTelemetryReceived? _onDataReceived;
  TelemetryRecord? _lastRecord;

  // Nilai telemetri dinamis (berubah secara halus / smooth random walk)
  double _simUv = 1.8;
  double _simTemp = 27.5;
  double _simHum = 65.0;
  int _simVoc = 55;
  int _simBattery = 88;

  // ValueNotifier untuk reaktif UI
  final _statusNotifier = StreamController<BleConnectionStatus>.broadcast();
  final _recordNotifier = StreamController<TelemetryRecord>.broadcast();

  Stream<BleConnectionStatus> get statusStream => _statusNotifier.stream;
  Stream<TelemetryRecord> get recordStream => _recordNotifier.stream;

  BleConnectionStatus get status => _status;
  TelemetryRecord? get lastRecord => _lastRecord;
  String get deviceName => _deviceName;
  BleSimMode get currentMode => _mode;
  int get batteryPercentage => _simBattery;

  String get modeName {
    switch (_mode) {
      case BleSimMode.normal:
        return 'Normal / Sejuk';
      case BleSimMode.uvExtreme:
        return 'Panas Ekstrem';
      case BleSimMode.pollution:
        return 'Polusi Udara';
      case BleSimMode.auto:
        return 'Otomatis';
    }
  }

  bool get isActive => _status == BleConnectionStatus.connected ||
                       _status == BleConnectionStatus.simulating;

  /// Mulai simulasi BLE virtual (mode demo tanpa alat fisik)
  void startSimulation({
    BleSimMode mode = BleSimMode.normal,
    OnTelemetryReceived? onData,
  }) {
    _mode = mode;
    _resetSimValuesForMode(mode);
    _onDataReceived = onData;
    _setStatus(BleConnectionStatus.scanning);

    // Simulasikan delay "scanning" 1.2 detik sebelum "tersambung"
    Future.delayed(const Duration(milliseconds: 1200), () {
      _setStatus(BleConnectionStatus.simulating);
      _simulationTimer?.cancel();
      _simulationTimer = Timer.periodic(
        Duration(seconds: _intervalSeconds),
        (_) => _generateAndEmit(),
      );
      // Langsung emit data pertama tanpa menunggu timer
      _generateAndEmit();
    });
  }

  /// Ubah mode simulasi seketika dan langsung broadcast data baru
  void changeMode(BleSimMode newMode) {
    _mode = newMode;
    _resetSimValuesForMode(newMode);
    // Langsung perbarui data telemetri agar UI responsif seketika
    _generateAndEmit();
  }

  void _resetSimValuesForMode(BleSimMode mode) {
    switch (mode) {
      case BleSimMode.normal:
        _simUv = 1.8;
        _simTemp = 27.2;
        _simHum = 65.0;
        _simVoc = 55;
        break;
      case BleSimMode.uvExtreme:
        _simUv = 10.5;
        _simTemp = 37.5;
        _simHum = 43.0;
        _simVoc = 125;
        break;
      case BleSimMode.pollution:
        _simUv = 3.2;
        _simTemp = 30.2;
        _simHum = 72.0;
        _simVoc = 435;
        break;
      case BleSimMode.auto:
        _simUv = 2.4;
        _simTemp = 28.5;
        _simHum = 60.0;
        _simVoc = 75;
        break;
    }
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
    // Fluktuasi mikro halus realistis (bukan lonjakan acak ekstrim)
    switch (mode) {
      case BleSimMode.normal:
        _simUv = (_simUv + _rnd(-0.05, 0.05)).clamp(1.2, 2.5);
        _simTemp = (_simTemp + _rnd(-0.1, 0.1)).clamp(26.0, 28.5);
        _simHum = (_simHum + _rnd(-0.2, 0.2)).clamp(60.0, 70.0);
        _simVoc = (_simVoc + _rndInt(-2, 2)).clamp(40, 85);
        break;
      case BleSimMode.uvExtreme:
        _simUv = (_simUv + _rnd(-0.08, 0.08)).clamp(9.8, 11.6);
        _simTemp = (_simTemp + _rnd(-0.1, 0.1)).clamp(36.5, 39.0);
        _simHum = (_simHum + _rnd(-0.2, 0.2)).clamp(40.0, 50.0);
        _simVoc = (_simVoc + _rndInt(-3, 3)).clamp(105, 155);
        break;
      case BleSimMode.pollution:
        _simUv = (_simUv + _rnd(-0.05, 0.05)).clamp(2.5, 3.8);
        _simTemp = (_simTemp + _rnd(-0.1, 0.1)).clamp(29.0, 31.8);
        _simHum = (_simHum + _rnd(-0.3, 0.3)).clamp(68.0, 78.0);
        _simVoc = (_simVoc + _rndInt(-4, 4)).clamp(395, 475);
        break;
      case BleSimMode.auto:
        _simUv = (_simUv + _rnd(-0.1, 0.1)).clamp(1.5, 7.5);
        _simTemp = (_simTemp + _rnd(-0.1, 0.1)).clamp(27.0, 34.0);
        _simHum = (_simHum + _rnd(-0.2, 0.2)).clamp(50.0, 80.0);
        _simVoc = (_simVoc + _rndInt(-3, 3)).clamp(45, 180);
        break;
    }

    // Simulasi baterai berkurang perlahan seiring penggunaan alat
    if (_random.nextDouble() < 0.05 && _simBattery > 20) {
      _simBattery--;
    }

    // GPS area Jakarta Pusat (bergeser dinamis mencakup area lingkungan sekitar)
    final lat = -6.200000 + (_random.nextDouble() - 0.5) * 0.003;
    final lng = 106.816666 + (_random.nextDouble() - 0.5) * 0.003;

    return TelemetryRecord(
      macAddress: _deviceMac,
      uvIndex: double.parse(_simUv.toStringAsFixed(1)),
      temperature: double.parse(_simTemp.toStringAsFixed(1)),
      humidity: double.parse(_simHum.toStringAsFixed(1)),
      voc: _simVoc,
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
