import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'transitions.dart';

class AppColors {
  static const Color backgroundTopLeft = Color(0xFF0B132B);
  static const Color backgroundCenter = Color(0xFF0E1C3A);
  static const Color backgroundBottomRight = Color(0xFF060B1A);
  static const Color surfaceGlass = Color(0x14FFFFFF); // ~8% white
  static const Color surfaceGlassStrong = Color(0x1AFFFFFF); // ~10% white

  static const Color menuSurface = Color(0xFF0B1220);

  static const Color primary = Color(0xFF0E1A2F); // Deep dark blue
  static const Color accent = Color(0xFF2E6BFF); // Deep electric blue
  static const Color success = Color(0xFF2BB673); // Muted green
  static const Color warning = Color(0xFFF2C94C); // Muted amber
  static const Color error = Color(0xFFE06C75); // Muted desaturated red

  static const Color textPrimary = Color(0xFFEAF2FF); // soft off-white
  static const Color textSecondary = Color(0xFF9FB0CC); // muted gray-blue
  static const Color divider = Color(0x26FFFFFF); // ~15% white
}

ThemeData buildAppTheme({bool disablePageTransitions = false}) {
  final scheme = const ColorScheme.dark().copyWith(
    primary: AppColors.accent,
    secondary: AppColors.accent,
    surface: AppColors.surfaceGlass,
    background: AppColors.backgroundTopLeft,
    error: AppColors.error,
    onSurface: AppColors.textPrimary,
    onPrimary: const Color(0xFF07101F),
    onSecondary: const Color(0xFF07101F),
  );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    dividerColor: AppColors.divider,
    canvasColor: AppColors.menuSurface,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    headlineMedium: GoogleFonts.inter(
      fontWeight: FontWeight.w700,
      fontSize: 22,
      letterSpacing: -0.2,
      color: AppColors.textPrimary,
    ),
    titleLarge: GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      fontSize: 18,
      color: AppColors.textPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      color: AppColors.textPrimary,
    ),
    bodyMedium: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
    labelLarge: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
  );

  return base.copyWith(
    textTheme: textTheme,
    cardTheme: CardThemeData(
      margin: const EdgeInsets.all(12),
      elevation: 0,
      color: AppColors.surfaceGlass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: const Color(0xFF07101F),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            visualDensity: VisualDensity.comfortable,
          ).copyWith(
            overlayColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.pressed)) {
                return Colors.white.withOpacity(0.10);
              }
              if (states.contains(MaterialState.hovered)) {
                return Colors.white.withOpacity(0.06);
              }
              return null;
            }),
          ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: const Color(0xFF07101F),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: Colors.white.withOpacity(0.14)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ).copyWith(
            overlayColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.pressed)) {
                return Colors.white.withOpacity(0.08);
              }
              if (states.contains(MaterialState.hovered)) {
                return Colors.white.withOpacity(0.06);
              }
              return null;
            }),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style:
          TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ).copyWith(
            overlayColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.pressed)) {
                return AppColors.accent.withOpacity(0.14);
              }
              if (states.contains(MaterialState.hovered)) {
                return AppColors.accent.withOpacity(0.10);
              }
              return null;
            }),
          ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        padding: const MaterialStatePropertyAll(EdgeInsets.all(8)),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        overlayColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) {
            return AppColors.accent.withOpacity(0.14);
          }
          if (states.contains(MaterialState.hovered)) {
            return AppColors.accent.withOpacity(0.10);
          }
          return null;
        }),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      backgroundColor: Color(0xCC0B1220),
      contentTextStyle: TextStyle(color: Color(0xFFEAF2FF)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceGlassStrong,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.9)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceGlassStrong,
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
      labelStyle: const TextStyle(color: AppColors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: AppColors.accent.withOpacity(0.14),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      selectedIconTheme: const IconThemeData(color: AppColors.accent),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.accent,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowHeight: 44,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 56,
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      dividerThickness: 0.6,
      dataRowColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) {
          return AppColors.accent.withOpacity(0.12);
        }
        return Colors.transparent;
      }),
      headingRowColor: MaterialStateProperty.all(AppColors.surfaceGlassStrong),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceGlass,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.menuSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      textStyle: const TextStyle(color: AppColors.textPrimary),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: disablePageTransitions
            ? const NoPageTransitionsBuilder()
            : const FadeSlidePageTransitionsBuilder(),
        TargetPlatform.linux: disablePageTransitions
            ? const NoPageTransitionsBuilder()
            : const FadeSlidePageTransitionsBuilder(),
        TargetPlatform.macOS: disablePageTransitions
            ? const NoPageTransitionsBuilder()
            : const FadeSlidePageTransitionsBuilder(),
      },
    ),
  );
}
