import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dayzo/main.dart';

void main() {
  testWidgets('Dayzo shows the improved empty state', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Dayzo'), findsWidgets);
    expect(find.text('Countdown & Event Tracker'), findsOneWidget);
    expect(find.text('No events yet'), findsOneWidget);
    expect(find.text('Create your first event'), findsOneWidget);
  });

  testWidgets('Dayzo validates event title and date fields', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an event title'), findsOneWidget);
    expect(find.text('Choose a date'), findsOneWidget);
  });
}
