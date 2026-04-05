import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gas_track/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTrackerRepository repository;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    repository = _FakeTrackerRepository();
  });

  testWidgets('loads the tracker dashboard', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(Cafe420(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Boiled egg'), findsOneWidget);
    expect(find.text('Egg Fry'), findsOneWidget);
    expect(find.text('Made coffee'), findsOneWidget);
    expect(find.byKey(const Key('coffee-increase')), findsOneWidget);
    expect(find.byKey(const Key('coffee-decrease')), findsOneWidget);
  });

  testWidgets('adds and removes coffee logs while keeping records in sync', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(Cafe420(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coffee-increase')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coffee-increase')));
    await tester.pumpAndSettle();

    expect(find.text('Coffee: 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coffee-decrease')));
    await tester.pumpAndSettle();

    expect(find.text('Coffee: 1'), findsOneWidget);

    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee logged'), findsOneWidget);
  });
}

class _FakeTrackerRepository implements TrackerRepository {
  final List<TrackerEvent> _events = <TrackerEvent>[];
  int _nextId = 1;

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteEvent(int id) async {
    _events.removeWhere((event) => event.id == id);
  }

  @override
  Future<TrackerEvent> insertEvent(HabitType type, DateTime loggedAt) async {
    final event = TrackerEvent(id: _nextId++, type: type, loggedAt: loggedAt);
    _events.insert(0, event);
    return event;
  }

  @override
  Future<List<TrackerEvent>> loadEvents() async {
    return List<TrackerEvent>.unmodifiable(_events);
  }
}
