import 'package:flutter/material.dart';

const cols = [
  Color(0xFFFF9F1C), Color(0xFFFF5D8F), Color(0xFF9B7BFF), Color(0xFF2FD4C0),
  Color(0xFF5BB8FF), Color(0xFFB7E04A), Color(0xFFFF7A59),
];

Color c(int i) => cols[i % cols.length];

/// Chart mark colors — the app hues re-stepped to clear 3:1 contrast on
/// their surface (validated with the dataviz palette checks; lightness
/// band, chroma, CVD separation and contrast all pass in both modes).
/// Fixed roles by index: 0 weight/volume · 1 reps · 2 best set · 3 time ·
/// 4 distance · 5 extra. Color follows the entity, never its rank.
const chartLight = [
  Color(0xFFC26A00), Color(0xFFDB2777), Color(0xFF6D4AD8),
  Color(0xFF0D9488), Color(0xFF2563EB), Color(0xFF4D7C0F),
];

const chartDark = [
  Color(0xFFD97400), Color(0xFFF43F7E), Color(0xFF8B5CF6),
  Color(0xFF0FA595), Color(0xFF3B82F6), Color(0xFF65A30D),
];

List<Color> chartCols(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light ? chartLight : chartDark;

/// The app's brand font — bundled under assets/fonts/ and declared in
/// pubspec.yaml. Single source of truth for the family name (canvas-drawn
/// chart text needs it too; themes don't reach CustomPaint).
const appFont = 'Baloo2';

/// Semantic color tokens: status tones and on-accent ink, resolved per
/// brightness. Pages never reach for raw Colors.* when color carries
/// meaning — the day palette (cols), the chart palettes and the Material
/// scheme cover the rest.
class Tone {
  static Color positive(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light ? Colors.green.shade700 : Colors.green.shade400;

  static Color negative(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light ? Colors.red.shade700 : Colors.red.shade300;

  /// Readable ink on a saturated accent fill.
  static Color onAccent(Color bg) => bg.computeLuminance() > .5 ? Colors.black : Colors.white;
}

/// Streak flame accent.
const flame = Colors.deepOrange;

/// Motion tokens — every animation duration in the app.
abstract final class Motion {
  static const fast = Duration(milliseconds: 250);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const chart = Duration(milliseconds: 700);
}

/// The app type scale: M3 roles tuned for Baloo 2 — extra-bold where the UI
/// leans on it. Pages use these roles instead of raw font sizes, so the
/// whole app re-skins from here.
TextTheme appType(TextTheme t) => t.copyWith(
      displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );

/// Theme with the bundled brand font and the app's type scale applied.
ThemeData appTheme(Color seed, Brightness b) {
  final t = ThemeData(useMaterial3: true, colorSchemeSeed: seed, brightness: b, fontFamily: appFont);
  return t.copyWith(textTheme: appType(t.textTheme));
}

String glyph(String n) {
  final s = n.toLowerCase();
  if (RegExp(r'shoulder|delt').hasMatch(s)) return '🏔️';
  if (RegExp(r'chest|pec').hasMatch(s)) return '🛡️';
  if (RegExp(r'bicep|arm|curl').hasMatch(s)) return '💪';
  if (RegExp(r'leg|squat|quad').hasMatch(s)) return '🦵';
  if (RegExp(r'back|lat').hasMatch(s)) return '🦅';
  if (RegExp(r'core|abs').hasMatch(s)) return '🔥';
  if (RegExp(r'cardio|treadmill|jog|cycl|bike|elliptical|walk|stair|stepper').hasMatch(s)) return '🏃';
  return '⚡';
}
