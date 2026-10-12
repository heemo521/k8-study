import 'package:material_ui/material_ui.dart';

/// Kubernetes blue.
const _seed = Color(0xFF326CE5);
const _font = 'Inter';

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  // Full type scale (sizes from englishLike, colours from black/white).
  final typography = Typography.material2021(platform: TargetPlatform.android);
  final base = typography.englishLike
      .merge(
        brightness == Brightness.light ? typography.black : typography.white,
      )
      .apply(
        fontFamily: _font,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
  TextStyle? tight(TextStyle? s, FontWeight w) =>
      s?.copyWith(fontWeight: w, letterSpacing: -0.3);
  final text = base.copyWith(
    displayMedium: tight(base.displayMedium, FontWeight.w700),
    headlineSmall: tight(base.headlineSmall, FontWeight.w700),
    titleLarge: tight(base.titleLarge, FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 16, height: 1.5),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  const buttonText = TextStyle(
    fontFamily: _font,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: _font,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values)
          p: const FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: buttonText),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
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
