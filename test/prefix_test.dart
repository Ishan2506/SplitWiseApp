import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_app/widgets/common_widgets.dart';

/// A fixed prefix such as '+91' must be readable before the user taps the
/// field. Flutter's own `prefixText` is laid out with zero opacity while the
/// field is empty and unfocused, so these assert on the painted opacity
/// rather than on the widget merely existing in the tree.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// The effective opacity the prefix is painted with.
  double prefixOpacity(WidgetTester tester) {
    final opacities = tester
        .widgetList<AnimatedOpacity>(
          find.ancestor(
            of: find.text('+91 '),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .map((w) => w.opacity);
    // No fading wrapper at all means it is painted fully opaque.
    return opacities.isEmpty ? 1.0 : opacities.reduce((a, b) => a * b);
  }

  testWidgets('prefix is painted while the field is empty and unfocused',
      (tester) async {
    await tester.pumpWidget(host(
      const PSTextField(label: 'Phone', prefixText: '+91 '),
    ));
    await tester.pumpAndSettle();

    expect(find.text('+91 '), findsOneWidget);
    expect(prefixOpacity(tester), 1.0,
        reason: 'the prefix must be visible before the field is focused');
  });

  testWidgets('prefix stays visible after focusing and typing',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(
      PSTextField(
        label: 'Phone',
        prefixText: '+91 ',
        controller: controller,
      ),
    ));

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(prefixOpacity(tester), 1.0);

    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.pumpAndSettle();
    expect(prefixOpacity(tester), 1.0);
    expect(controller.text, '9876543210');
  });

  testWidgets('no stray prefix when none was given', (tester) async {
    await tester.pumpWidget(host(
      const PSTextField(label: 'Name', placeholder: 'Your name'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('+91 '), findsNothing);
    expect(find.text('Your name'), findsOneWidget);
  });
}
