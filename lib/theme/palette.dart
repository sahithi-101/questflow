import 'package:flutter/material.dart';

import '../models/quest.dart';

/// "Lichen & Madder": named after natural dye pigments rather than UI-kit
/// colours. Tasks = madder, events = woad, quests = moss.
abstract final class QfColors {
  // Surfaces and ink
  static const lichen = Color(0xFFD9DECB); // app background
  static const pith = Color(0xFFECEFE0); // raised surfaces
  static const bistre = Color(0xFF2A2A1F); // ink + sidebar
  static const bistreSoft = Color(0xFF55574A); // secondary text on lichen/pith
  static const lichenDim = Color(0xFFA9AE9A); // secondary text on bistre
  static const rule = Color(0xFFBFC4AF); // hairlines on lichen/pith

  // Item kinds
  static const madder = Color(0xFFB0444A); // tasks
  static const woad = Color(0xFF3E6275); // events
  static const moss = Color(0xFF55782F); // quests, "target reached"

  // Accent
  static const gamboge = Color(0xFFDDA520);

  // Quest heat states (spec section 4)
  static const ash = Color(0xFFBEC0B0); // zero progress
  static const partialLight = Color(0xFFD3DDB0);
  static const partialDeep = Color(0xFF8FAE5C);
  static const mulberry = Color(0xFF6E3B66); // above target

  /// Colour for one quest day. [ratio] is value / target, used only for
  /// partial progress.
  static Color heat(DayState state, {double ratio = 0}) {
    switch (state) {
      case DayState.none:
        return ash;
      case DayState.partial:
        return Color.lerp(partialLight, partialDeep, ratio.clamp(0.0, 1.0))!;
      case DayState.target:
        return moss;
      case DayState.over:
        return mulberry;
      case DayState.future:
      case DayState.outside:
        return Colors.transparent;
    }
  }
}
