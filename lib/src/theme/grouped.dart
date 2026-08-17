import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'flettra_colors.dart';

/// A raised group of rows sitting on the recessed canvas.
///
/// This is the shape that makes an app read as an app: content collected into
/// planes rather than floated on a flat white page with a drop shadow under it.
/// iOS calls it an inset grouped table, Material 3 calls it a surface
/// container — same idea, and every phone the user already owns is full of it.
///
/// Elevation here comes from the tone difference against
/// [FlettraColors.surfaceSunken], not from a shadow. Shadow stays reserved for
/// things that genuinely float: the FAB, sheets, the sticky action bar.
class GroupedCard extends StatelessWidget {
  const GroupedCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
    this.padding = EdgeInsets.zero,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  /// Clip children to the rounded corners. Needed when the group's first or
  /// last child paints its own background (a row highlight, a thumbnail).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: margin,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: c.ruleSoft),
      ),
      child: child,
    );
  }
}

/// A small uppercase label above a [GroupedCard].
///
/// Deliberately quiet: it names a group, it is not a heading. Use sentence-case
/// [AppTypography.heading] when the label is genuinely the section's title.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md + AppSpacing.xxs, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 11,
          height: 14 / 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: c.ink3,
        ),
      ),
    );
  }
}
