import 'package:flutter/material.dart';

const ink = Color(0xFF172D38);
const teal = Color(0xFF146B67);
const mint = Color(0xFFDCF0E7);
const canvas = Color(0xFFF7F6F2);
const muted = Color(0xFF74838A);
const orange = Color(0xFFECA969);

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal, surface: canvas),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(fontSize: 32, height: 1.13, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: ink),
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: ink),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
    bodyMedium: TextStyle(fontSize: 14, color: ink),
  ),
  cardTheme: CardThemeData(color: Colors.white, elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(16))),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
);
