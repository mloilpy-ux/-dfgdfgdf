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
      theme: furryTheme,
      home: const WallpaperScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
