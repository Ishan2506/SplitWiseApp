import 'package:flutter/material.dart';

/// PaisaSplit design system.
///
/// The palette is taken from the Splitly reference: a near-black ink used for
/// primary actions, a single pink accent reserved for emphasis, and a cool
/// grey-violet neutral ramp for surfaces. Light mode only — there is no dark
/// theme, so every colour here can be used unconditionally.
class AppColors {
  // Brand
  static const Color primaryAccent = Color(0xFFE8305C); // pink accent
  static const Color primaryDark = Color(0xFFD92553); // pressed / emphasis
  static const Color primaryLight = Color(0xFFFFE3EC); // tinted fill
  static const Color primarySurface = Color(0xFFFFF5F8); // faintest tint
  static const Color primaryBorder = Color(0xFFF7DEE6);

  // Ink — the near-black used for primary buttons and the tab bar.
  static const Color ink = Color(0xFF0E0E10);
  static const Color textPrimary = Color(0xFF0E0E10);
  static const Color textSecondary = Color(0xFF5B5560);
  static const Color textTertiary = Color(0xFF7A747F);
  static const Color muted = Color(0xFF8A8490);

  // Surfaces
  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFFAF9FB); // app canvas
  static const Color bgSubtle = Color(0xFFF4F2F6); // chips, icon tiles
  static const Color inputBg = Color(0xFFF6F4F7);
  static const Color bgLight = Color(0xFFFFF5F8); // tinted panel

  // Borders
  static const Color border = Color(0xFFECE8EF);
  static const Color borderStrong = Color(0xFFE2DDE4);
  static const Color borderLight = Color(0xFFEFEBF1);

  // Semantic — owed (positive) and owe (negative) read as green / pink.
  static const Color success = Color(0xFF1D7A4C);
  static const Color successLight = Color(0xFFEEF7F1);
  static const Color successBorder = Color(0xFFD9ECDF);
  static const Color negative = Color(0xFFD92553);
  static const Color negativeLight = Color(0xFFFFFAFB);
  static const Color negativeBorder = Color(0xFFF2DDE4);
  static const Color warning = Color(0xFFB26A00);
  static const Color warningLight = Color(0xFFFFF7E8);
  static const Color error = Color(0xFFD92553);

  // Avatar tints, cycled by index so members keep a stable colour.
  static const List<Color> avatarTints = [
    Color(0xFFF6E2EA),
    Color(0xFFEFE4EA),
    Color(0xFFE8DEE7),
    Color(0xFFE4E8F0),
    Color(0xFFE6EFE9),
    Color(0xFFF2EAE0),
  ];
  static const List<Color> avatarInk = [
    Color(0xFFB3697F),
    Color(0xFFA68D99),
    Color(0xFF9C8A9C),
    Color(0xFF7C8AA6),
    Color(0xFF6F9280),
    Color(0xFFA8916F),
  ];
}

/// Elevation presets. Shadows stay soft and tinted rather than pure black so
/// cards sit on the canvas without looking cut out of it.
class AppShadow {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A2A1A28),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x142A1A28),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> overlay = [
    BoxShadow(
      color: Color(0x242A1A28),
      blurRadius: 44,
      offset: Offset(0, 18),
    ),
  ];
}

class AppTheme {
  /// The one and only theme. Dark mode was removed deliberately: balances are
  /// colour-coded and the accent loses its meaning on a dark canvas.
  static ThemeData lightTheme() {
    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
        height: 1.05,
        color: AppColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        height: 1.08,
        color: AppColors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
        height: 1.12,
        color: AppColors.textPrimary,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.muted,
      ),
    );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgSecondary,
      primaryColor: AppColors.primaryAccent,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryAccent,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.ink,
        onSecondary: Colors.white,
        surface: AppColors.bgPrimary,
        onSurface: AppColors.textPrimary,
        surfaceContainerLowest: AppColors.bgPrimary,
        surfaceContainerLow: AppColors.bgSecondary,
        surfaceContainer: AppColors.bgSubtle,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
        error: AppColors.error,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgSecondary,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primaryAccent, 1.5),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.5),
        disabledBorder: border(AppColors.borderLight),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textTertiary,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryAccent,
        ),
        hintStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.muted,
        ),
        errorStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.error,
        ),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.bgSubtle,
          disabledForegroundColor: AppColors.muted,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.bgPrimary,
          disabledForegroundColor: AppColors.muted,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
          side: const BorderSide(color: AppColors.borderStrong),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryAccent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          highlightColor: AppColors.bgSubtle,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgPrimary,
        selectedColor: AppColors.ink,
        checkmarkColor: Colors.white,
        disabledColor: AppColors.bgSubtle,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        side: const BorderSide(color: AppColors.border),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodySmall,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        dragHandleSize: Size(40, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        actionTextColor: AppColors.primaryLight,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: AppColors.textSecondary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryAccent,
        linearTrackColor: AppColors.bgSubtle,
        circularTrackColor: AppColors.bgSubtle,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primaryAccent
              : AppColors.borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.primaryAccent,
        dividerColor: AppColors.border,
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
