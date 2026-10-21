import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.bgDeep,
    required this.bgPanel,
    required this.bgPanel2,
    required this.overlay,
    required this.cyan,
    required this.cyanAccent,
    required this.violet,
    required this.amber,
    required this.coral,
    required this.text,
    required this.textMute,
    required this.line,
  });

  final Brightness brightness;
  final Color bgDeep;
  final Color bgPanel;

  final Color bgPanel2;

  final Color overlay;
  final Color cyan;
  final Color cyanAccent;
  final Color violet;
  final Color amber;
  final Color coral;
  final Color text;
  final Color textMute;
  final Color line;

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bgDeep: Color(0xFF0A0E1C),
    bgPanel: Color(0xFF121A2E),
    bgPanel2: Color(0xFF16213A),
    overlay: Color(0x05FFFFFF),
    cyan: Color(0xFF22D3EE),
    cyanAccent: Colors.cyanAccent,
    violet: Color(0xFF7C6FF0),
    amber: Color(0xFFF2C94C),
    coral: Color(0xFFF2734C),
    text: Color(0xFFEAF0FB),
    textMute: Color(0xFF8391AC),
    line: Color(0x17FFFFFF),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    bgDeep: Color(0xFFF4F6FB),
    bgPanel: Color(0xFFFFFFFF),
    bgPanel2: Color(0xFFFFFFFF),
    overlay: Color(0xFFFFFFFF),
    cyan: Color(0xFF0E7490),
    cyanAccent: Color(0xFF0891B2),
    violet: Color(0xFF5B4FD6),
    amber: Color(0xFFA16207),
    coral: Color(0xFFC2410C),
    text: Color(0xFF0F172A),
    textMute: Color(0xFF55627F),
    line: Color(0x260F172A),
  );
}

class AppColors {
  AppColors._();

  static AppPalette palette = AppPalette.dark;

  static bool get isDark => palette.brightness == Brightness.dark;

  static Color get bgDeep => palette.bgDeep;
  static Color get bgPanel => palette.bgPanel;
  static Color get bgPanel2 => palette.bgPanel2;
  static Color get overlay => palette.overlay;

  static Color get cyan => palette.cyan;
  static Color get cyanAccent => palette.cyanAccent;
  static Color get violet => palette.violet;
  static Color get amber => palette.amber;
  static Color get coral => palette.coral;

  static Color get text => palette.text;
  static Color get textMute => palette.textMute;
  static Color get line => palette.line;
}
