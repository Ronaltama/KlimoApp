import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Model satu record data sensor dari alat/BLE
class TelemetryRecord {
  final int? id;
  final String macAddress;
  final double uvIndex;
  final double temperature;
  final double humidity;
  final int voc;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final bool synced; // apakah sudah diunggah ke backend cloud

  const TelemetryRecord({
    this.id,
    required this.macAddress,
    required this.uvIndex,
    required this.temperature,
    required this.humidity,
    required this.voc,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.synced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mac_address': macAddress,
      'uv_index': uvIndex,
      'temperature': temperature,
      'humidity': humidity,
      'voc': voc,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory TelemetryRecord.fromMap(Map<String, dynamic> map) {
    return TelemetryRecord(
      id: map['id'] as int?,
      macAddress: map['mac_address'] as String? ?? '',
      uvIndex: (map['uv_index'] as num?)?.toDouble() ?? 0.0,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (map['humidity'] as num?)?.toDouble() ?? 0.0,
      voc: (map['voc'] as num?)?.toInt() ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      synced: (map['synced'] as int? ?? 0) == 1,
    );
  }

  /// Konversi ke format JSON yang dikirim ke Backend Laravel
  Map<String, dynamic> toApiPayload({int userId = 1}) {
    return {
      'mac_address': macAddress,
      'user_id': userId,
      'uv_index': uvIndex,
      'temperature': temperature,
      'humidity': humidity,
      'voc': voc,
      'timestamp': timestamp.toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}

/// Service untuk penyimpanan data sensor secara lokal di HP menggunakan SQLite
/// Berperan seperti "database internal" pada Huawei Health / Garmin Connect
class LocalDataService {
  static Database? _db;

  /// Buka atau buat database SQLite lokal di HP
  static Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'klimo_local.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE telemetry (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mac_address TEXT NOT NULL,
            uv_index REAL NOT NULL,
            temperature REAL NOT NULL,
            humidity REAL NOT NULL,
            voc INTEGER NOT NULL,
            latitude REAL,
            longitude REAL,
            timestamp TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Cek apakah record perlu disimpan ke database lokal berdasarkan
  /// perubahan nilai (Delta Threshold) atau batas waktu (Heartbeat).
  static bool shouldSaveRecord(TelemetryRecord newRecord, TelemetryRecord? lastRecord) {
    if (lastRecord == null) return true;

    // Heartbeat: jika sudah 60 detik tidak ada data yang disimpan, simpan sebagai checkpoint
    final diffSeconds = newRecord.timestamp.difference(lastRecord.timestamp).inSeconds.abs();
    if (diffSeconds >= 60) return true;

    // Delta Threshold: jika ada perubahan signifikan
    final uvDiff = (newRecord.uvIndex - lastRecord.uvIndex).abs();
    final tempDiff = (newRecord.temperature - lastRecord.temperature).abs();
    final humDiff = (newRecord.humidity - lastRecord.humidity).abs();
    final vocDiff = (newRecord.voc - lastRecord.voc).abs();

    return uvDiff >= 0.2 || tempDiff >= 0.3 || humDiff >= 1.0 || vocDiff >= 10;
  }

  /// Simpan data sensor ke SQLite lokal jika ada perubahan nilai atau heartbeat.
  /// Mengembalikan true jika data benar-benar disimpan ke database.
  static Future<bool> saveRecord(TelemetryRecord record) async {
    final latest = await getLatest();
    if (!shouldSaveRecord(record, latest)) {
      return false; // Nilai stabil di bawah ambang batas, lewati insert ke SQLite
    }

    final db = await database;
    await db.insert(
      'telemetry',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Batasi history lokal maksimal 500 record untuk hemat memori HP
    await _pruneOldRecords(db, maxCount: 500);
    return true;
  }

  /// Ambil satu data sensor terbaru (untuk Dashboard)
  static Future<TelemetryRecord?> getLatest() async {
    final db = await database;
    final results = await db.query(
      'telemetry',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return TelemetryRecord.fromMap(results.first);
  }

  /// Ambil riwayat data sensor untuk History Screen (max 100 record terbaru)
  static Future<List<TelemetryRecord>> getHistory({int limit = 100}) async {
    final db = await database;
    final results = await db.query(
      'telemetry',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map((e) => TelemetryRecord.fromMap(e)).toList();
  }

  /// Ambil data yang belum tersinkron ke Backend Cloud (untuk SyncManager)
  static Future<List<TelemetryRecord>> getPendingSync({int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'telemetry',
      where: 'synced = 0',
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return results.map((e) => TelemetryRecord.fromMap(e)).toList();
  }

  /// Tandai record sebagai sudah tersinkron ke Backend Cloud
  static Future<void> markAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholder = ids.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE telemetry SET synced = 1 WHERE id IN ($placeholder)',
      ids,
    );
  }

  /// Hitung berapa record yang belum tersinkron
  static Future<int> countPendingSync() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM telemetry WHERE synced = 0',
    );
    return (result.first['count'] as int? ?? 0);
  }

  /// Hapus record lama jika melebihi maxCount untuk hemat memori HP
  static Future<void> _pruneOldRecords(Database db, {int maxCount = 500}) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM telemetry'),
    ) ?? 0;

    if (count > maxCount) {
      await db.rawDelete('''
        DELETE FROM telemetry WHERE id IN (
          SELECT id FROM telemetry ORDER BY timestamp ASC LIMIT ${count - maxCount}
        )
      ''');
    }
  }

  /// Hapus semua data lokal (untuk tombol reset/logout)
  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('telemetry');
  }
}
