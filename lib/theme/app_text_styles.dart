import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const double minFontSize = 11;

  static double _legible(double size) =>
      size < minFontSize ? minFontSize : size;

  static const _displayFamily = 'SpaceGrotesk';
  static const _bodyFamily = 'Inter';
  static const _monoFamily = 'IBMPlexMono';

  static TextStyle display({
    double fontSize = 21,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.5,
  }) {
    return TextStyle(
      fontFamily: _displayFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.text,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    TextDecoration? decoration,
  }) {
    final resolved = color ?? AppColors.text;
    return TextStyle(
      fontFamily: _bodyFamily,
      fontSize: _legible(fontSize),
      fontWeight: fontWeight,
      color: resolved,
      decoration: decoration,
      decorationColor: resolved,
    );
  }

  static TextStyle mono({
    double fontSize = 10,
    Color? color,
    double letterSpacing = 1.2,
  }) {
    return TextStyle(
      fontFamily: _monoFamily,
      fontSize: _legible(fontSize),
      color: color ?? AppColors.textMute,
      letterSpacing: letterSpacing,
      fontWeight: FontWeight.w500,
    );
  }
}
