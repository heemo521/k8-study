import 'package:material_ui/material_ui.dart';

const _seed = Color(0xFF2F6FDE);

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: Typography.material2021(platform: TargetPlatform.android).black
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
          bodyMedium: const TextStyle(fontSize: 16, height: 1.45),
        ),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  );
}

final lightTheme = _theme(Brightness.light);
final darkTheme = _theme(Brightness.dark);

/// Colours for answer feedback that read well in both themes.
extension FeedbackColors on ColorScheme {
  Color get correct => brightness == Brightness.light
      ? const Color(0xFF1B7F3B)
      : const Color(0xFF7AD99A);
  Color get correctContainer => brightness == Brightness.light
      ? const Color(0xFFDDF5E4)
      : const Color(0xFF173D25);
  Color get wrong => error;
  Color get wrongContainer => errorContainer;
}
