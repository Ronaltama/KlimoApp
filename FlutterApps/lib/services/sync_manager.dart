import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'local_data_service.dart';

/// Status sinkronisasi cloud
enum SyncStatus {
  idle,       // Tidak ada proses sinkronisasi
  syncing,    // Sedang mengupload ke cloud
  success,    // Upload berhasil
  noInternet, // Tidak ada internet, data ditahan di lokal
  error,      // Gagal upload
}

/// SyncManager mengelola pengiriman data dari lokal HP ke Backend Cloud.
/// Cara kerja: seperti WhatsApp yang menyimpan pesan lokal dulu,
/// kemudian mengirim ketika koneksi internet tersedia.
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  SyncStatus _status = SyncStatus.idle;
  bool _isSyncing = false;
  int _pendingCount = 0;
  Timer? _syncTimer;

  final _statusController = StreamController<SyncStatus>.broadcast();
  final _pendingController = StreamController<int>.broadcast();

  Stream<SyncStatus> get statusStream => _statusController.stream;
  Stream<int> get pendingCountStream => _pendingController.stream;
  SyncStatus get status => _status;
  int get pendingCount => _pendingCount;

  /// Inisialisasi dan mulai auto-sync setiap 30 detik
  void initialize() {
    _updatePendingCount();
    // Cek dan sync setiap 30 detik
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
    // Langsung coba sync saat pertama kali
    syncNow();
  }

  /// Coba sinkronisasi data pending ke Backend Cloud sekarang
  Future<void> syncNow() async {
    if (_isSyncing) return;

    // Cek koneksi internet
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasInternet = connectivityResult.any(
      (r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi,
    );

    if (!hasInternet) {
      _setStatus(SyncStatus.noInternet);
      await _updatePendingCount();
      return;
    }

    final pending = await LocalDataService.getPendingSync(limit: 50);
    if (pending.isEmpty) {
      _setStatus(SyncStatus.idle);
      return;
    }

    _isSyncing = true;
    _setStatus(SyncStatus.syncing);

    try {
      final baseUrl = await _getBaseUrl();
      final token = await _getToken();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 1;

      final payloadList = pending.map((r) => r.toApiPayload(userId: userId)).toList();

      // Coba kirim sekaligus via Batch Sync endpoint
      final batchResponse = await http.post(
        Uri.parse('$baseUrl/telemetry/batch'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'readings': payloadList}),
      ).timeout(const Duration(seconds: 10));

      if (batchResponse.statusCode == 200 || batchResponse.statusCode == 201) {
        final syncedIds = pending.where((r) => r.id != null).map((r) => r.id!).toList();
        await LocalDataService.markAsSynced(syncedIds);
        _setStatus(SyncStatus.success);
      } else {
        // Fallback: kirim satu per satu jika server lama belum mendukung batch
        final syncedIds = <int>[];
        for (final record in pending) {
          final payload = record.toApiPayload(userId: userId);
          final response = await http.post(
            Uri.parse('$baseUrl/telemetry'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200 || response.statusCode == 201) {
            if (record.id != null) syncedIds.add(record.id!);
          }
        }

        if (syncedIds.isNotEmpty) {
          await LocalDataService.markAsSynced(syncedIds);
        }
        _setStatus(SyncStatus.success);
      }
    } catch (_) {
      _setStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
      await _updatePendingCount();
    }
  }

  /// Periksa apakah internet tersedia
  static Future<bool> isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any(
        (r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _updatePendingCount() async {
    _pendingCount = await LocalDataService.countPendingSync();
    _pendingController.add(_pendingCount);
  }

  Future<String> _getBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('custom_base_url');
      if (saved != null && saved.isNotEmpty) return saved;
    } catch (_) {}
    return 'https://api-klimo.tama-labs.my.id/api';
  }

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (_) {
      return null;
    }
  }

  void _setStatus(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void dispose() {
    _syncTimer?.cancel();
    _statusController.close();
    _pendingController.close();
  }
}
