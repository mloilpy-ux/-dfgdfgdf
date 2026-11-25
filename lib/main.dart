import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/content_provider.dart';
import 'providers/sources_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/logger_provider.dart';
import 'screens/wallpaper_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем провайдеры с хранилищем ДО запуска приложения
  final loggerProvider = LoggerProvider();
  final settingsProvider = SettingsProvider();
  final sourcesProvider = SourcesProvider();

  await Future.wait([
    settingsProvider.init(), // загружает SharedPreferences
    sourcesProvider.loadSources(), // загружает SQLite
  ]);

  runApp(
    MultiProvider(
      providers: [
        // #1: Logger первым — остальные могут логировать при старте
        ChangeNotifierProvider.value(value: loggerProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: sourcesProvider),

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
      theme: furryTheme,
      home: const WallpaperScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
