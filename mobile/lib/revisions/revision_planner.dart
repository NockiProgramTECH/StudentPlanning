import '../models/schedule.dart';
import 'revision_session.dart';

/// Stable notification IDs across launches; never rely on Dart's process hashCode.
int reminderId(String key) {
  var hash = 2166136261;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

DateTime _at(DateTime day, int hour, [int minute = 0]) =>
    DateTime(day.year, day.month, day.day, hour, minute);

bool _overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
    aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

/// Pure and offline: 50-minute sessions + 10-minute breaks.
/// Daytime free space (09–12, 14–18) and evening (20–22:30), including weekends.
/// Limits keep the plan realistic: up to 2/day during the week, 3/day at weekends.
List<RevisionSession> planRevisions(Schedule schedule, {
  Map<String, int> lastWeekCompleted = const {},
  List<RevisionSession> alreadyCompleted = const [],
  DateTime? now,
}) {
  if (schedule.isDemo) return [];
  final currentTime = now ?? DateTime.now();
  final monday = DateTime(schedule.weekStart.year, schedule.weekStart.month, schedule.weekStart.day);
  final subjects = <String, String>{};
  for (final course in schedule.courses) {
    if (course.subject.trim().isNotEmpty) {
      subjects.putIfAbsent(course.subject.trim().toLowerCase(), () => course.subject.trim());
    }
  }
  if (subjects.isEmpty) return [];
  final plannedCounts = <String, int>{};
  for (final previous in alreadyCompleted) {
    final key = previous.subject.trim().toLowerCase();
    plannedCounts[key] = (plannedCounts[key] ?? 0) + 1;
  }
  final result = <RevisionSession>[];
  for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
    final day = monday.add(Duration(days: dayIndex));
    final dayCourses = schedule.courses.where((c) => c.day == dayIndex + 1).toList();
    final busy = <(DateTime, DateTime)>[
      for (final c in dayCourses)
        (_at(day, int.parse(c.start.substring(0, 2)), int.parse(c.start.substring(3))),
         _at(day, int.parse(c.end.substring(0, 2)), int.parse(c.end.substring(3)))),
      for (final done in alreadyCompleted)
        if (done.start.year == day.year && done.start.month == day.month && done.start.day == day.day)
          (done.start, done.end),
    ];
    final weekend = dayIndex >= 5;
    final maxForDay = weekend ? 3 : 2;
    final daytime = <DateTime>[
      for (final hour in [9, 10, 11, 14, 15, 16, 17]) _at(day, hour),
    ];
    final evening = <DateTime>[_at(day, 20), _at(day, 21)];
    var count = alreadyCompleted.where((s) => s.start.year == day.year &&
      s.start.month == day.month && s.start.day == day.day).length;
    String? lastSubject;
    // A daytime session and an evening session, then one extra daytime slot
    // at weekends if free. When daytime is full, use a second evening slot.
    final pools = weekend ? [daytime, evening, daytime] : [daytime, evening, evening];
    for (final pool in pools) {
      if (count >= maxForDay) break;
      DateTime? slot;
      for (final candidate in pool) {
        final end = candidate.add(const Duration(minutes: 50));
        if (!candidate.isAfter(currentTime)) continue;
        if (busy.any((interval) => _overlaps(candidate.subtract(const Duration(minutes: 10)),
          end.add(const Duration(minutes: 10)), interval.$1, interval.$2))) continue;
        slot = candidate;
        break;
      }
      if (slot == null) continue;
      final keys = subjects.keys.toList()..sort((a, b) {
        int weight(String key) {
          final last = lastWeekCompleted[key] ?? 0;
          final thisWeek = plannedCounts[key] ?? 0;
          final repeatedToday = key == lastSubject ? 100 : 0;
          final nextCourse = schedule.courses.any((c) => c.subject.trim().toLowerCase() == key &&
            c.day >= dayIndex + 1 && c.day <= dayIndex + 3);
          final upcomingAssessment = schedule.courses.any((c) => c.subject.trim().toLowerCase() == key &&
            c.kind == 'assessment' && c.day >= dayIndex + 1 && c.day <= dayIndex + 2);
          return last + thisWeek * 2 + repeatedToday - (nextCourse ? 1 : 0) - (upcomingAssessment ? 2 : 0);
        }
        final order = weight(a).compareTo(weight(b));
        return order != 0 ? order : a.compareTo(b);
      });
      final key = keys.first;
      final start = slot;
      final end = start.add(const Duration(minutes: 50));
      final id = reminderId('revision|${schedule.className}|${start.toIso8601String()}|$key');
      final session = RevisionSession(id: id, className: schedule.className,
        weekStart: monday, subject: subjects[key]!, start: start, end: end);
      result.add(session);
      busy.add((start, end));
      plannedCounts[key] = (plannedCounts[key] ?? 0) + 1;
      lastSubject = key;
      count++;
    }
  }
  return result..sort((a, b) => a.start.compareTo(b.start));
}
