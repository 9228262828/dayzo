import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dayzo/main.dart';

void main() {
  test('Dayzo event type mapping uses requested badge colors', () {
    expect(
      DayzoEventType.fromTitle('Birthday dinner'),
      DayzoEventType.birthday,
    );
    expect(DayzoEventType.fromTitle('Travel to Tokyo'), DayzoEventType.travel);
    expect(DayzoEventType.fromTitle('Final exam'), DayzoEventType.exam);
    expect(DayzoEventType.fromTitle('Wedding day'), DayzoEventType.wedding);
    expect(
      DayzoEventType.fromTitle('Anniversary dinner'),
      DayzoEventType.anniversary,
    );
    expect(
      DayzoEventType.fromTitle('Project deadline'),
      DayzoEventType.deadline,
    );
    expect(DayzoEventType.fromTitle('Team meeting'), DayzoEventType.meeting);
    expect(DayzoEventType.fromTitle('Product launch'), DayzoEventType.custom);

    expect(DayzoEventType.birthday.color, Colors.orange);
    expect(DayzoEventType.travel.color, Colors.blue);
    expect(DayzoEventType.exam.color, Colors.indigo);
    expect(DayzoEventType.wedding.color, Colors.pink);
    expect(DayzoEventType.anniversary.color, Colors.green);
    expect(DayzoEventType.deadline.color, Colors.red);
    expect(DayzoEventType.meeting.color, Colors.teal);
    expect(DayzoEventType.custom.color, const Color(0xFF6A35FF));
  });

  testWidgets('Dayzo shows the improved empty state', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Dayzo'), findsWidgets);
    expect(find.text('Countdown & Event Tracker'), findsOneWidget);
    expect(find.text('No events yet'), findsOneWidget);
    expect(find.text('Create your first event'), findsOneWidget);
  });

  testWidgets('Dayzo validates event title and date fields', (
    WidgetTester tester,
  ) async {
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

  testWidgets('Dayzo event cards show type badges beside titles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DayzoEventCard(
            event: DayzoEvent(
              id: '1',
              title: 'Travel to Rome',
              date: DateTime(2030, 7, 18),
              createdAt: DateTime(2026, 6, 23),
            ),
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Travel to Rome'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);
  });
}
