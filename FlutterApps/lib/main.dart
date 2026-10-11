import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/setup/device_pairing_screen.dart';
import 'screens/setup/skin_type_screen.dart';
import 'screens/main_screen.dart';
import 'screens/uv_detail_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'KlimoApp',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/pairing': (context) => const DevicePairingScreen(),
            '/skin_type': (context) => const SkinTypeScreen(),
            '/main': (context) => const MainScreen(),
            '/uv_detail': (context) => const UVDetailScreen(),
          },
        );
      },
    );
  }
}
