import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:student_planning/models/schedule.dart';
import 'package:student_planning/revisions/revision_session.dart';
import 'package:student_planning/screens/revision_screen.dart';
import 'package:student_planning/services/schedule_store.dart';

class MemoryStore extends ScheduleStore {
  final List<RevisionSession> sessions;
  MemoryStore(this.sessions);

  @override
  Future<Map<String, int>> previousStudyCounts(String className, DateTime weekStart) async => {};

  @override
  Future<List<RevisionSession>> revisionsFor(String className, DateTime weekStart) async => sessions;

  @override
  Future<void> replacePendingRevisions(String className, DateTime weekStart,
      List<RevisionSession> generated) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('les séances restent visibles sans canal Android des notifications', (tester) async {
    await initializeDateFormatting('fr');
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final schedule = Schedule(className: 'L2 SIR', weekStart: monday,
      courses: const [Course(subject: 'Réseaux', day: 2, start: '07:30', end: '12:30')]);
    final session = RevisionSession(id: 42, className: 'L2 SIR', weekStart: monday,
      subject: 'Réseaux', start: monday.add(const Duration(days: 6, hours: 20)),
      end: monday.add(const Duration(days: 6, hours: 20, minutes: 50)));
    await tester.pumpWidget(MaterialApp(home: RevisionScreen(
      schedule: schedule, store: MemoryStore([session]))));
    await tester.pumpAndSettle();
    expect(find.text('Réseaux'), findsOneWidget);
    expect(find.textContaining('Planning de révision indisponible'), findsNothing);
  });
}
