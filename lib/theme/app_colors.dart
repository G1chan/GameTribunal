import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF0B0910);
  static const surface = Color(0xFF18141F);
  static const field = Color(0xFF221C2C);
  static const primary = Color(0xFF9B70F7);
  static const lavender = Color(0xFFD7C8FF);
  // 기존 화면 코드의 의미적 이름은 유지하되, 앱 포인트 색상으로 통일합니다.
  static const red = primary;
  static const deepRed = Color(0xFF7B52D4);
  static const ink = Color(0xFFF7F4FF);
  static const muted = Color(0xFFA9A2B3);
  static const line = Color(0xFF37313F);
  static const blue = Color(0xFF78A9FF);
  static const bluePale = Color(0xFF25213A);
  static const redPale = Color(0xFF2E2345);
  static const gold = Color(0xFFFFB52E);
}
