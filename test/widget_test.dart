import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flettra_mobile/src/app.dart';
import 'package:flettra_mobile/src/theme/flettra_colors.dart';

/// Replaces the generated "Counter increments" template test, which asserted on
/// a counter this app has never had and so had been failing since the initial
/// commit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    // AuthCheck reads the stored session on build. No platform in a widget
    // test, so answer as "nothing stored" and let it settle on signed-out.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      return switch (call.method) {
        'readAll' => <String, String>{},
        'containsKey' => false,
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  testWidgets('app root builds with both themes and clamps text scaling',
      (tester) async {
    await tester.pumpWidget(const FlettraApp());
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, isNotNull);
    expect(app.darkTheme, isNotNull,
        reason: 'Dark mode must be wired up at the root.');
    expect(app.theme!.extension<FlettraColors>(), isNotNull);
    expect(app.darkTheme!.extension<FlettraColors>(), isNotNull);

    // An unbounded textScaler overflows every fixed-height row in the app.
    final context = tester.element(find.byType(MaterialApp));
    final scaler = MediaQuery.textScalerOf(context);
    expect(scaler.scale(100), lessThanOrEqualTo(130.0));
  });
}
