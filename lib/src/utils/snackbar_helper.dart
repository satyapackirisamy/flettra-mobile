import 'package:flutter/material.dart';
import '../theme/flettra_colors.dart';
import '../theme/app_typography.dart';

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(Icons.check_circle_rounded, color: context.c.ok, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: context.c.ok))),
    ]),
    backgroundColor: context.c.okWash,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  ));
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(Icons.error_rounded, color: context.c.bad, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: context.c.bad))),
    ]),
    backgroundColor: context.c.badWash,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  ));
}
