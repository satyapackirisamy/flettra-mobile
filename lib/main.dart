import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await themeController.load();

  runApp(const FlettraApp());
}
