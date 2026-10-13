import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _customBaseUrl;

  /// Mengambil base URL secara cerdas:
  /// - Default production Cloudflare: https://api-klimo.tama-labs.my.id/api
  /// - Atau custom IP yang tersimpan di SharedPreferences (misal IP LAN WiFi / localhost)
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

    // Default utama mengarah ke production backend Cloudflare Tunnel
    const cloudUrl = 'https://api-klimo.tama-labs.my.id/api';

    // Fallback cek lokal jika offline/dev
    final host = (!kIsWeb && Platform.isAndroid) ? '10.0.2.2' : '127.0.0.1';
    final defaultUrl = 'http://$host:8000/api';

    try {
      final res = await http.get(Uri.parse('$cloudUrl/telemetry/latest')).timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200) {
        return cloudUrl;
      }
    } catch (_) {}

    // Coba port 8000 lokal
    try {
      final resLocal = await http.get(Uri.parse('$defaultUrl/telemetry/latest')).timeout(const Duration(milliseconds: 500));
      if (resLocal.statusCode == 200) {
        return defaultUrl;
      }
    } catch (_) {}

    return cloudUrl;
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

  /// Mengecek apakah user sudah menyelesaikan setup awal (pairing & tipe kulit)
  static Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_onboarding_completed') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Menandai apakah user sudah menyelesaikan setup awal
  static Future<void> setOnboardingCompleted(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_onboarding_completed', value);
    } catch (_) {}
  }

  /// Menyimpan tipe kulit yang dipilih pengguna
  static Future<void> saveSkinType(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_skin_type', type);

      // Sinkronkan ke profil backend jika user sedang login
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        final baseUrl = await getBaseUrl();
        await http.put(
          Uri.parse('$baseUrl/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'skin_type': type}),
        ).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  /// Mengambil tipe kulit yang tersimpan (default: Tipe IV)
  static Future<String> getSkinType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_skin_type') ?? 'Tipe IV';
    } catch (_) {
      return 'Tipe IV';
    }
  }

  /// Menyimpan nama perangkat yang terhubung
  static Future<void> saveConnectedDevice(String deviceName, {String? macAddress}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('connected_device', deviceName);

      // Daftarkan perangkat ke backend jika user sedang login
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        final baseUrl = await getBaseUrl();
        await http.post(
          Uri.parse('$baseUrl/devices'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'mac_address': macAddress ?? 'KLIMO-${deviceName.replaceAll(' ', '-').toUpperCase()}',
            'name': deviceName,
          }),
        ).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  /// Mengambil nama perangkat yang terhubung
  static Future<String> getConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('connected_device') ?? 'Klimo Wearth C3-4A1B';
    } catch (_) {
      return 'Klimo Wearth C3-4A1B';
    }
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
        final token = data['token'] ?? data['data']?['token'] ?? '';
        await saveToken(token);
        if (data['data']?['user']?['id'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', data['data']['user']['id'] as int);
        }
        if (data['data']?['user']?['skin_type'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_skin_type', data['data']['user']['skin_type'].toString());
        }
        return {'success': true, 'data': data};
      } else {
        String msg = 'Email atau kata sandi tidak cocok';
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null) {
            msg = data['message'];
          } else if (data['errors'] != null) {
            msg = data['errors'].values.first[0];
          }
        } catch (_) {}
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke Backend ($e)'};
    }
  }

  // Fungsi Registrasi Akun Baru
  static Future<Map<String, dynamic>> register(String name, String email, String password, {String? skinType}) async {
    try {
      final baseUrl = await getBaseUrl();
      final currentSkin = skinType ?? await getSkinType();
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'skin_type': currentSkin,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['data']?['token'] ?? '';
        if (token.isNotEmpty) {
          await saveToken(token);
        }
        if (data['data']?['user']?['id'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', data['data']['user']['id'] as int);
        }
        if (data['data']?['user']?['skin_type'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_skin_type', data['data']['user']['skin_type'].toString());
        }
        return {'success': true, 'data': data};
      } else {
        final data = jsonDecode(response.body);
        String msg = 'Pendaftaran gagal';
        if (data['message'] != null) {
          msg = data['message'];
        } else if (data['errors'] != null) {
          msg = data['errors'].values.first[0];
        }
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke Backend ($e)'};
    }
  }

  // Fungsi Login Akun Google via Backend Asli
  static Future<Map<String, dynamic>> loginWithGoogle() async {
    const googleEmail = 'google.user@klimo.app';
    const googlePass = 'google_klimo_oauth_pass';
    const googleName = 'Pengguna Google';

    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/login/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': googleEmail,
          'name': googleName,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['data']?['token'] ?? '';
        if (token.isNotEmpty) {
          await saveToken(token);
        }
        if (data['data']?['user']?['id'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', data['data']['user']['id'] as int);
        }
        if (data['data']?['user']?['skin_type'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_skin_type', data['data']['user']['skin_type'].toString());
        }
        return {'success': true, 'data': data};
      }
    } catch (_) {}

    // Fallback jika backend belum merestart rute baru
    final loginRes = await login(googleEmail, googlePass);
    if (loginRes['success']) {
      return loginRes;
    }

    final regRes = await register(googleName, googleEmail, googlePass);
    return regRes;
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
        final profile = data['data'];
        if (profile != null && profile['skin_type'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_skin_type', profile['skin_type'].toString());
        }
        return profile;
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

  // Fungsi Update Profil Pengguna
  static Future<Map<String, dynamic>> updateProfile(String name, {String? skinType}) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final payload = <String, dynamic>{'name': name};
      if (skinType != null) {
        payload['skin_type'] = skinType;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (skinType != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_skin_type', skinType);
        }
        return {'success': true, 'data': data['data']};
      }
    } catch (_) {}
    return {'success': false, 'message': 'Gagal memperbarui profil'};
  }

  // Fungsi Logout (Revoke Token di Server)
  static Future<bool> logout() async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
    await saveToken('');
    return true;
  }
}
