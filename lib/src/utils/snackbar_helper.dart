import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF059669)))),
    ]),
    backgroundColor: const Color(0xFFECFDF5),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  ));
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_rounded, color: Color(0xFFDC2626), size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)))),
    ]),
    backgroundColor: const Color(0xFFFEF2F2),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  ));
}
