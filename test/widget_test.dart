import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gas_track/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('increase button logs coffee and saves a record', (tester) async {
    await tester.pumpWidget(const KitchenTallyApp());
    await tester.pumpAndSettle();

    expect(find.text('Today: 0'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('coffee-increase')));
    await tester.pumpAndSettle();

    expect(find.text('Today: 1'), findsOneWidget);
    expect(find.text('Coffee: 1'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Records'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Coffee logged'), findsOneWidget);
  });

  testWidgets('decrease button removes the latest coffee record', (
    tester,
  ) async {
    await tester.pumpWidget(const KitchenTallyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coffee-increase')));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coffee-decrease')));
    await tester.pumpAndSettle();

    expect(find.text('Today: 0'), findsWidgets);
    expect(find.text('Coffee: 0'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Records'), 300);
    await tester.pumpAndSettle();

    expect(find.text('No records yet'), findsOneWidget);
    expect(find.text('Coffee logged'), findsNothing);
  });
}
