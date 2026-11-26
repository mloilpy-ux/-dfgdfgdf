import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/content_provider.dart';
import 'providers/sources_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/logger_provider.dart';
import 'screens/wallpaper_screen.dart';
import 'theme.dart';
import 'dart:ui';
import 'services/logger_service.dart';
import 'services/background_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LoggerService.instance.init();
  FlutterError.onError = (details) {
    LoggerService.instance.log(
      '${details.exception}\n${details.stack}',
      isError: true,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LoggerService.instance.log('$error\n$stack', isError: true);
    return true;
  };
  try {
    await BackgroundSync.configure(
      (await SharedPreferences.getInstance()).getBool('backgroundSync') ?? true,
    );
  } catch (e) {
    LoggerService.instance.log('Планировщик: $e', isError: true);
  }
  final settings = SettingsProvider();
  await settings.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoggerProvider()),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => SourcesProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Furry Wallpapers',
      theme: wallpaperTheme,
      home: const WallpaperScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
