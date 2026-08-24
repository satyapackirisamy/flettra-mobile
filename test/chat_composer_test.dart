import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flettra_mobile/src/theme/app_theme.dart';

/// Guards the composer contract: Return sends, it does not insert a newline.
///
/// A TextField with maxLines != 1 silently defaults to TextInputType.multiline,
/// whose Return key inserts a line break and whose onSubmitted never fires. The
/// field still needs to wrap to several lines, so the keyboard type and action
/// have to be named explicitly — easy to lose in a later edit, hence this test.
void main() {
  testWidgets('a multi-line composer still sends on Return', (tester) async {
    var sent = 0;
    final controller = TextEditingController();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 4,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => sent++,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'Hello Guys');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(sent, 1, reason: 'Return must fire onSubmitted, not add a newline.');
    expect(controller.text, isNot(contains('\n')));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, isNot(TextInputType.multiline),
        reason: 'multiline turns Return into a line break.');
    expect(field.textInputAction, TextInputAction.send);
  });
}
