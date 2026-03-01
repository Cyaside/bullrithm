import 'package:flutter_test/flutter_test.dart';

import 'package:bullrithm/presentation/app/bullrithm_app.dart';

void main() {
  testWidgets('app renders splash then shell with home page tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BullrithmApp());

    expect(find.text('Bullrithm'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    expect(find.text('Bullrithm Home'), findsOneWidget);
    expect(find.text('Home'), findsNWidgets(2));
    expect(find.text('Stocks'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);

    await tester.tap(find.text('Stocks'));
    await tester.pumpAndSettle();

    expect(find.text('Market Overview'), findsOneWidget);
  });
}
