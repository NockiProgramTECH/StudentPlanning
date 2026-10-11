import 'package:flutter/services.dart';
import '../models/schedule.dart';
import '../revisions/revision_planner.dart';
import '../revisions/revision_session.dart';

/// Android AlarmManager + NotificationManager via a native channel.
/// The phone stores/reinstalls future alarms on reboot; no remote push service.
class LocalReminders {
  static const _channel = MethodChannel('studia/reminders');

  Future<bool> hasPermission() async =>
    await _channel.invokeMethod<bool>('hasPermission') ?? false;

  Future<bool> requestPermission() async =>
    await _channel.invokeMethod<bool>('requestPermission') ?? false;

  Future<void> cancel(int id) async => _channel.invokeMethod<void>('cancel', id);

  Future<void> testNotification() async => _channel.invokeMethod<void>('testNotification');

  Future<void> replaceForWeek(Schedule schedule, List<RevisionSession> sessions) async {
    final now = DateTime.now();
    final alerts = <Map<String, Object>>[];
    for (final session in sessions) {
      if (session.completed || !session.start.isAfter(now)) continue;
      alerts.add({
        'id': session.id, 'at': session.start.millisecondsSinceEpoch,
        'title': 'C’est l’heure de réviser',
        'body': 'Il est l’heure de travailler ${session.subject} pendant 50 minutes.',
        'channel': 'revisions',
      });
    }
    // Only lessons before noon are reminded, one hour before their start.
    // 07:30 → 06:30; an 07:00 lesson → 06:00.
    for (final course in schedule.courses.where((c) => int.parse(c.start.substring(0, 2)) < 12)) {
      final day = schedule.weekStart.add(Duration(days: course.day - 1));
      final start = DateTime(day.year, day.month, day.day,
        int.parse(course.start.substring(0, 2)), int.parse(course.start.substring(3)));
      final reminder = start.subtract(const Duration(hours: 1));
      if (!reminder.isAfter(now)) continue;
      alerts.add({
        'id': reminderId('course|${schedule.className}|${start.toIso8601String()}|${course.subject}'),
        'at': reminder.millisecondsSinceEpoch,
        'title': 'Cours dans 1 heure',
        'body': '${course.subject} à ${course.start}${course.room == null ? '' : ' · ${course.room}'}',
        'channel': 'courses',
      });
    }
    await _channel.invokeMethod<void>('replace', alerts);
  }
}
