import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

ThemeData buildMesTheme({
  required Brightness brightness,
  required VisualDensity visualDensity,
}) {
  final base = ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF006A67),
      brightness: brightness,
    ),
    useMaterial3: true,
    visualDensity: visualDensity,
    fontFamily: 'Microsoft YaHei',
    fontFamilyFallback: const [
      '微软雅黑',
      'Microsoft YaHei',
      'PingFang SC',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
  );
  final tokens = MesTokens.fromTheme(base);
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[tokens],
    scaffoldBackgroundColor: tokens.colors.background,
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: tokens.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: tokens.radius.md),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.colors.surfaceSubtle,
      border: OutlineInputBorder(
        borderRadius: tokens.radius.sm,
        borderSide: BorderSide(color: tokens.colors.border),
      ),
    ),
  );
}
