import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/content_item.dart';
import 'models/content_source.dart';
import 'providers/content_provider.dart';
import 'providers/sources_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/logger_provider.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ContentItemAdapter());
  Hive.registerAdapter(ContentSourceAdapter());
  Hive.registerAdapter(SourceTypeAdapter());
  await Hive.openBox<ContentItem>('contents');
  await Hive.openBox<ContentSource>('sources');
  await Hive.openBox<String>('seen');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SourcesProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LoggerProvider()),
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
      title: 'Furry Content Hub',
      theme: furryTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
