import 'package:flutter/material.dart';

/// Centralized color palette for Flettra.
///
/// ─── Usage ────────────────────────────────────────────────────────────────
///   import 'package:flettra/src/constants/app_colors.dart';
///
///   Container(color: AppColors.primary)
///   Text('...', style: TextStyle(color: AppColors.textPrimary))
/// ──────────────────────────────────────────────────────────────────────────
abstract final class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  /// Flettra teal — primary brand color
  static const Color primary = Color(0xFFFF6B2C);
  static const Color primaryLight = Color(0xFFFF8C5A);
  static const Color primaryDark = Color(0xFFE8551A);
  static const Color primarySurface = Color(0xFFFFF3EE);
  static const Color primaryContainer = Color(0xFFFFE4D6);
  static const Color primaryBorder = Color(0xFFAADED6);

  // ── Indigo / Theme Primary (Material theme seed) ────────────────────────
  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoLight = Color(0xFF6366F1);
  static const Color indigoDark = Color(0xFF3730A3);
  static const Color indigoSurface = Color(0xFFEEF2FF);

  // ── Purple / Secondary ─────────────────────────────────────────────────
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFF8B5CF6);
  static const Color purpleSurface = Color(0xFFF3E8FF);
  static const Color purpleDark = Color(0xFF4A235A);

  // ── Blue ──────────────────────────────────────────────────────────────
  static const Color blue = Color(0xFF2563EB);
  static const Color blueLight = Color(0xFF3B82F6);
  static const Color blueSky = Color(0xFF0EA5E9);
  static const Color blueSurface = Color(0xFFEFF6FF);
  static const Color blueDark = Color(0xFF1A5276);
  static const Color blueMid = Color(0xFF2E86C1);

  // ── Green / Success ────────────────────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFF10B981);
  static const Color successMid = Color(0xFF27AE60);
  static const Color successSurface = Color(0xFFECFDF5);
  static const Color successContainer = Color(0xFF6EE7B7);
  static const Color successDark = Color(0xFF065F46);
  static const Color successDeep = Color(0xFF145A32);

  // ── Red / Error / Danger ──────────────────────────────────────────────
  static const Color error = Color(0xFFF43F5E);
  static const Color errorAlt = Color(0xFFE11D48);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFEF4444);
  static const Color dangerSurface = Color(0xFFFEF2F2);
  static const Color dangerContainer = Color(0xFFFCA5A5);

  // ── Amber / Warning ───────────────────────────────────────────────────
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color warningContainer = Color(0xFFFDE68A);

  // ── Pink ─────────────────────────────────────────────────────────────
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkAlt = Color(0xFFF43F5E);
  static const Color pinkSurface = Color(0xFFFFF1F5);

  // ── Neutrals / Text ───────────────────────────────────────────────────
  /// Deep navy — used for headlines and body text on light backgrounds
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF333333);
  static const Color textMuted = Color(0xFF555555);
  static const Color textHint = Color(0xFF999999);
  static const Color textDisabled = Color(0xFFCCCCCC);
  static const Color textLight = Color(0xFFCBD5E1);

  // ── Grays ────────────────────────────────────────────────────────────
  static const Color gray50 = Color(0xFFF8FAFC);
  static const Color gray100 = Color(0xFFF1F5F9);
  static const Color gray200 = Color(0xFFE2E8F0);
  static const Color gray300 = Color(0xFFCBD5E1);
  static const Color gray400 = Color(0xFF94A3B8);
  static const Color gray500 = Color(0xFF64748B);
  static const Color gray600 = Color(0xFF475569);
  static const Color gray700 = Color(0xFF334155);
  static const Color gray800 = Color(0xFF1E293B);
  static const Color gray900 = Color(0xFF0F172A);

  // Zinc variants (used in some screens)
  static const Color zinc100 = Color(0xFFF4F4F5);
  static const Color zinc200 = Color(0xFFE4E4E7);
  static const Color zinc400 = Color(0xFFA1A1AA);
  static const Color zinc500 = Color(0xFF71717A);
  static const Color zinc700 = Color(0xFF3F3F46);
  static const Color zinc800 = Color(0xFF27272A);
  static const Color zinc900 = Color(0xFF18181B);

  // ── Surfaces / Backgrounds ────────────────────────────────────────────
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF8F9FA);
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundAlt = Color(0xFFF7F7F8);
  static const Color backgroundDark = Color(0xFF1A1A1A);

  // ── Borders ──────────────────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE0E0E0);

  // ── Overlays / Shadows ────────────────────────────────────────────────
  static const Color shadowPrimary = Color(0x1A4F46E5);   // indigo tint shadow
  static const Color shadowDark = Color(0x1A000000);      // generic dark shadow
  static const Color overlay = Color(0x80000000);         // semi-transparent overlay
  static const Color overlayLight = Color(0x33000000);

  // ── Semantic aliases (use these in UI code for clarity) ──────────────
  static const Color ridesColor = primary;           // orange — rides feature
  static const Color groupsColor = purple;           // purple — groups feature
  static const Color buddiesColor = blue;            // blue — buddies feature
  static const Color chatColor = success;            // green — chat feature
  static const Color walletColor = warning;          // amber — wallet/payments
  static const Color analyticsColor = indigo;        // indigo — analytics
  static const Color driverColor = primary;          // orange — driver role
  static const Color passengerColor = blue;          // blue — passenger role

  // ── Gradient helpers ─────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient indigoGradient = LinearGradient(
    colors: [indigo, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [textPrimary, textSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Transparent-to-black overlay (used on hero images)
  static const LinearGradient heroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC000000)],
  );
}
