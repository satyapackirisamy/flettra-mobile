import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/app.dart';
import 'src/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // DM Sans ships in the bundle (see pubspec `fonts:` and `google_fonts/`).
  // Without this the package still reaches out to fonts.gstatic.com on first
  // launch and text cannot paint until that round trip finishes — a large part
  // of the "app feels slow" feedback.
  GoogleFonts.config.allowRuntimeFetching = false;

  await themeController.load();

  runApp(const FlettraApp());
}
