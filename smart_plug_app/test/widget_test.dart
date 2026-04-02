import 'package:flutter_test/flutter_test.dart';

import 'package:smart_plug_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartPlugApp());
    expect(find.text('Smart Plug Monitor'), findsOneWidget);
  });
}
