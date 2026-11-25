import 'package:flutter/material.dart';

const _accent = Color(0xFFAA83F7);

final ThemeData furryTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _accent),
);

final ThemeData wallpaperTheme = ThemeData(
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF15121B),
        surfaceContainerLow: const Color(0xFF1D1825),
      ),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      color: Color(0xFFF3EBFF),
      fontSize: 26,
      fontWeight: FontWeight.w700,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
  ),
);
