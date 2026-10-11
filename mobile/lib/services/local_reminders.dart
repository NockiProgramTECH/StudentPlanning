import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/schedule.dart';
import '../revisions/revision_planner.dart';
import '../revisions/revision_session.dart';

/// Android AlarmManager + NotificationManager via a native channel.
/// Study planning and SQLite must keep working even if this channel is absent
/// (web/desktop, or an Android APK not rebuilt since native code was added).
class LocalReminders {
  final MethodChannel _channel;
  final bool isAndroid;
  bool nativeMissing = false;

  LocalReminders({MethodChannel channel = const MethodChannel('studia/reminders'), bool? android})
      : _channel = channel,
        isAndroid = android ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  StateError get _rebuildRequired => StateError(
    'Module Android des rappels absent. Fermez l’application, puis depuis mobile/ '
    'exécutez flutter clean, flutter pub get et flutter run. Un hot reload ne suffit pas.');

  Future<bool> hasPermission() async {
    if (!isAndroid) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('hasPermission') ?? false;
      nativeMissing = false;
      return granted;
    } on MissingPluginException {
      nativeMissing = true;
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (!isAndroid) return false;
    if (nativeMissing) throw _rebuildRequired;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      nativeMissing = true;
      throw _rebuildRequired;
    }
  }

  Future<void> cancel(int id) async {
    if (!isAndroid || nativeMissing) return;
    try {
      await _channel.invokeMethod<void>('cancel', id);
    } on MissingPluginException {
      nativeMissing = true;
      // The session remains completed in SQLite even without a native alarm.
    }
  }

  Future<void> testNotification() async {
    if (!isAndroid) throw UnsupportedError('Notifications disponibles uniquement sur Android.');
    if (nativeMissing) throw _rebuildRequired;
    try {
      await _channel.invokeMethod<void>('testNotification');
    } on MissingPluginException {
      nativeMissing = true;
      throw _rebuildRequired;
    }
  }

  /// Schedules a one-off diagnostic one minute from now; no SQLite changes.
  Future<DateTime> scheduleTest() async {
    if (!isAndroid) throw UnsupportedError('Notifications disponibles uniquement sur Android.');
    if (nativeMissing) throw _rebuildRequired;
    try {
      final at = await _channel.invokeMethod<int>('scheduleTest');
      if (at == null) throw StateError('Date du test manquante.');
      return DateTime.fromMillisecondsSinceEpoch(at);
    } on MissingPluginException {
      nativeMissing = true;
      throw _rebuildRequired;
    }
  }

  Future<void> replaceForWeek(Schedule schedule, List<RevisionSession> sessions) async {
    if (!isAndroid) return;
    if (nativeMissing) throw _rebuildRequired;
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
    try {
      await _channel.invokeMethod<void>('replace', alerts);
    } on MissingPluginException {
      nativeMissing = true;
      throw _rebuildRequired;
    }
  }
}
