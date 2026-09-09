import 'package:flutter/widgets.dart';

/// 4pt spacing scale. Every gap in the app should come from here so vertical
/// rhythm stays consistent across screens.
class AppSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Corner radii. Cards sit at [lg]; anything pill-shaped uses [pill].
class AppRadius {
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 28.0;
  static const double pill = 999.0;
  // Retained so existing call sites keep compiling.
  static const double full = 999.0;
}

/// Breakpoints and layout helpers.
///
/// The app is phone-first, but it also runs on tablets and the web. Rather
/// than stretching a phone layout across a 1400px window, content is centred
/// in a readable column and grids gain columns as width allows.
class AppBreakpoints {
  static const double tablet = 720;
  static const double desktop = 1080;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tablet;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= tablet && w < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  /// Max width of the primary content column.
  static double contentMaxWidth(BuildContext context) =>
      isPhone(context) ? double.infinity : 720;

  /// Horizontal page padding, which grows a little on bigger screens.
  static double pagePadding(BuildContext context) =>
      isPhone(context) ? AppSpacing.md : AppSpacing.xl;

  /// Column count for card grids.
  static int gridColumns(BuildContext context) {
    if (isDesktop(context)) return 3;
    if (isTablet(context)) return 2;
    return 1;
  }
}

class AppDuration {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
}
