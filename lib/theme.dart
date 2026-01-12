import 'package:flutter/material.dart';

final ThemeData furryTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepOrange,
    secondary: Colors.purple,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.deepOrange.shade50,
  ),
);
