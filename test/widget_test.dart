import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_app/main.dart';

void main() {
  testWidgets('SplitWiseApp load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SplitWiseApp());

    // Verify that the title "SplitWise Premium" is present
    expect(find.text('SplitWise Premium'), findsOneWidget);
  });
}
