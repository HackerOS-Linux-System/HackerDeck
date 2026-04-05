// ─────────────────────────────────────────────
//  HackerDeck — App Theme
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';

const kCyan = Color(0xFF00E5FF);
const kBg = Color(0xFF0A0E1A);
const kBg2 = Color(0xFF0D1120);
const kCard = Color(0xFF131929);

ThemeData buildTheme() {
  return ThemeData.dark().copyWith(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kCyan,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: kBg,
    cardTheme: CardThemeData(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kCyan,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
