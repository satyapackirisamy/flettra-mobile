import 'package:flutter/widgets.dart';

/// Layout primitives for Flettra.
///
/// Everything spatial in the app comes from here. Before adding a new value,
/// check whether an existing step works — the point of the scale is that there
/// are few of them.
///
/// The audit that preceded this file counted 15 ad-hoc padding values and
/// 20 distinct corner radii across 52 files. Those collapse into the 8 spacing
/// steps and 4 radii below.
abstract final class AppSpacing {
  /// 4 pt base grid. Every gap, pad and inset is a multiple of this.
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;

  /// Default screen margin. iOS and Material both use 16.
  static const double md = 16;
  static const double lg = 20;

  /// Gap between major sections on a screen.
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Horizontal inset for full-width screen content.
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: md);

  /// Padding inside a card or grouped-list row.
  static const EdgeInsets card = EdgeInsets.all(sm);
}

/// Corner radii. Four values, chosen by role rather than by size.
abstract final class AppRadius {
  /// Chips, inputs, small icon wells.
  static const double chip = 8;

  /// Cards, list groups, thumbnails.
  static const double card = 12;

  /// Bottom sheets and modals.
  static const double sheet = 20;

  /// Pills and avatars.
  static const double pill = 999;

  static const BorderRadius chipR = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius sheetR =
      BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius pillR = BorderRadius.all(Radius.circular(pill));
}

/// Minimum interactive target sizes.
///
/// The pre-redesign icon buttons were 38 pt — under both platform minimums.
/// Targets that are too small read to a tester as "the button doesn't work",
/// which is why some of the reported "broken features" were really this.
abstract final class AppTouch {
  static const double iosMin = 44;
  static const double androidMin = 48;

  /// Safe on both platforms.
  static const double min = androidMin;
}

/// Elevation.
///
/// Native lists separate with a hairline, not a drop shadow. Shadow is reserved
/// for surfaces that genuinely sit above the page.
abstract final class AppElevation {
  static const double hairline = 0.5;

  /// Sheets, the FAB, and the sticky action bar. Nothing else.
  static const double raised = 2;
}

/// Motion. Short and consistent; the app should never feel like it is waiting
/// on an animation.
abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
}
