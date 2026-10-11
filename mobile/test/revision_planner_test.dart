import 'package:flutter_test/flutter_test.dart';
import 'package:student_planning/models/schedule.dart';
import 'package:student_planning/revisions/revision_planner.dart';

void main() {
  final monday = DateTime(2026, 10, 12);
  final schedule = Schedule(className: 'L2 SIR', weekStart: monday, courses: const [
    Course(subject: 'Mathématiques', day: 2, start: '07:30', end: '12:30'),
    Course(subject: 'Réseaux', day: 3, start: '07:30', end: '12:30'),
    Course(subject: 'Réseaux', day: 3, start: '14:00', end: '18:00'),
    Course(subject: 'Mathématiques', day: 6, start: '07:30', end: '12:30'),
  ]);
  final beforeWeek = DateTime(2026, 10, 11);

  test('places studies in free space, evenings and weekend, without class overlap', () {
    final sessions = planRevisions(schedule, now: beforeWeek);
    expect(sessions, isNotEmpty);
    expect(sessions.any((s) => s.start.hour == 20), isTrue);
    expect(sessions.any((s) => s.start.weekday == 7), isTrue);
    for (final session in sessions) {
      expect(session.end.difference(session.start).inMinutes, 50);
      expect(session.end.hour < 22 || (session.end.hour == 22 && session.end.minute <= 30), isTrue);
      final sameDay = schedule.courses.where((c) => c.day == session.start.weekday);
      for (final course in sameDay) {
        final start = DateTime(session.start.year, session.start.month, session.start.day,
          int.parse(course.start.substring(0, 2)), int.parse(course.start.substring(3)));
        final end = DateTime(session.start.year, session.start.month, session.start.day,
          int.parse(course.end.substring(0, 2)), int.parse(course.end.substring(3)));
        expect(session.start.isBefore(end) && start.isBefore(session.end), isFalse);
      }
    }
  });

  test('prioritizes a subject less studied last week', () {
    final sessions = planRevisions(schedule, now: beforeWeek,
      lastWeekCompleted: {'mathématiques': 5, 'réseaux': 0});
    expect(sessions.first.subject, 'Réseaux');
    expect(reminderId('study'), reminderId('study'));
    expect(reminderId('study'), isNot(reminderId('other')));
  });

  test('never builds notifications or studies from demonstration data', () {
    final demo = Schedule(className: schedule.className, weekStart: monday,
      courses: schedule.courses, isDemo: true);
    expect(planRevisions(demo, now: beforeWeek), isEmpty);
  });
}
