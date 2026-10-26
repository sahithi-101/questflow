import 'package:flutter/material.dart';

import 'palette.dart';

abstract final class QfTheme {
  static const _display = 'Familjen';
  static const _body = 'Atkinson';

  /// Variable-weight display style (Familjen Grotesk, wght 400-700).
  static TextStyle display(double size,
      {double weight = 700, double? height, double spacing = -0.3, Color? color}) {
    return TextStyle(
      fontFamily: _display,
      fontSize: size,
      height: height,
      letterSpacing: spacing,
      color: color ?? QfColors.bistre,
      fontVariations: [FontVariation('wght', weight)],
    );
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: QfColors.bistre,
      onPrimary: QfColors.pith,
      secondary: QfColors.gamboge,
      onSecondary: QfColors.bistre,
      error: QfColors.madder,
      onError: QfColors.pith,
      surface: QfColors.pith,
      onSurface: QfColors.bistre,
    );

    final text = const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45),
      bodySmall: TextStyle(fontSize: 13, height: 1.4),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: 13),
    ).apply(
      fontFamily: _body,
      bodyColor: QfColors.bistre,
      displayColor: QfColors.bistre,
    ).copyWith(
      displaySmall: display(44, height: 1.0, spacing: -1.2),
      headlineMedium: display(28, height: 1.1, spacing: -0.6, weight: 600),
      titleLarge: display(22, height: 1.2),
      titleMedium: display(18, height: 1.25, weight: 650, spacing: -0.2),
      titleSmall: display(15, height: 1.3, weight: 650, spacing: 0),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: QfColors.lichen,
      canvasColor: QfColors.lichen,
      textTheme: text,
      fontFamily: _body,
      dividerColor: QfColors.rule,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: QfColors.gamboge,
        foregroundColor: QfColors.bistre,
        elevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: QfColors.bistre,
          foregroundColor: QfColors.pith,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: _body, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: QfColors.bistre,
        indicatorColor: QfColors.gamboge,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? QfColors.bistre
                  : QfColors.lichenDim,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: _body,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w400,
              color: states.contains(WidgetState.selected)
                  ? QfColors.pith
                  : QfColors.lichenDim,
            )),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: QfColors.bistre,
        contentTextStyle: TextStyle(fontFamily: _body, color: QfColors.pith),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
