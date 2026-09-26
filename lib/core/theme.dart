import 'package:flutter/material.dart';

const navy = Color(0xFF0A3D62);
const ink = Color(0xFF172B42);
const muted = Color(0xFF64748B);
const gold = Color(0xFFFFC300);
const canvas = Color(0xFFF4F7FB);
const line = Color(0xFFE2E8F0);

ThemeData dtsTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: navy,
    primary: navy,
    secondary: gold,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: canvas,
  dialogTheme: const DialogThemeData(
    insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      color: ink,
      letterSpacing: -0.8,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyMedium: TextStyle(fontSize: 14, color: ink, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.4),
  ),
  dividerColor: line,
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: line),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF9FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 0,
  ),
);
