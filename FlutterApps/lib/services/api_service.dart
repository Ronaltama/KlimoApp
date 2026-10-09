import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _customBaseUrl;

  /// Mengambil base URL secara cerdas:
  /// - Jika di Android Emulator: http://10.0.2.2:8000/api
  /// - Jika di Linux/Desktop/Web: http://127.0.0.1:8000/api
  /// - Atau custom IP yang tersimpan di SharedPreferences (misal IP LAN WiFi)
  static Future<String> getBaseUrl() async {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('custom_base_url');
      if (saved != null && saved.isNotEmpty) {
        _customBaseUrl = saved;
        return _customBaseUrl!;
      }
    } catch (_) {}

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  /// Mengubah base URL (misal diarahkan ke IP LAN seperti http://192.168.2.19:8000/api)
  static Future<void> setCustomBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_base_url', url);
    _customBaseUrl = url;
  }

  // Simpan token login (jika diperlukan untuk request berproteksi)
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Fungsi Login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['token'] ?? '');
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Email atau password salah'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal konek ke Backend ($e)'};
    }
  }

  // Fungsi Ambil Data Sensor Terbaru (Simulasi IoT / Backend)
  static Future<Map<String, dynamic>?> getLatestTelemetry() async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/telemetry/latest'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
    } catch (_) {}
    return null;
  }

  // Fungsi Ambil Data Peta Komunitas (Heatmap)
  static Future<List<dynamic>> getHeatmapData() async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/map/heatmap'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  // Fungsi Ambil Riwayat Data
  static Future<List<dynamic>> getHistoryData() async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/telemetry/history'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  // Fungsi Ambil Profil Pengguna
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
    } catch (_) {}
    return null;
  }

  // Fungsi Ambil Daftar Perangkat (Device)
  static Future<List<dynamic>> getDevices() async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/devices'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }
}
