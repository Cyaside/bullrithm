import 'package:flutter_test/flutter_test.dart';

import 'package:bullrithm/presentation/app/bullrithm_app.dart';

void main() {
  testWidgets('app renders stock screen shell', (WidgetTester tester) async {
    await tester.pumpWidget(const BullrithmApp());

    expect(find.text('Market Overview'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
  });
}
