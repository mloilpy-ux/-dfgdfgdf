import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'providers/source_provider.dart';
import 'providers/content_provider.dart';
import 'providers/settings_provider.dart';
import 'services/database_service.dart';
import 'services/logger_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runZonedGuarded(() async {
    try {
      await DatabaseService.instance.database;
      LoggerService.instance.log('✅ Database initialized');
    } catch (e) {
      LoggerService.instance.log('❌ Database error: $e', isError: true);
    }

    runApp(const MyApp());
  }, (error, stack) {
    LoggerService.instance.log('💥 App Error: $error\n$stack', isError: true);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SourceProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Furry Content Hub',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFF6B35),
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFF6B35),
                brightness: Brightness.dark,
              ),
            ),
            themeMode: settings.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
