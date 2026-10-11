import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_planning/services/local_reminders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un ancien APK sans canal natif ne bloque pas les révisions', () async {
    final reminders = LocalReminders(
      channel: const MethodChannel('studia/reminders-missing-test'), android: true);
    expect(await reminders.hasPermission(), isFalse);
    expect(reminders.nativeMissing, isTrue);
    expect(reminders.requestPermission(), throwsStateError);
  });

  test('le test différé utilise le canal natif sans modifier le planning', () async {
    const channel = MethodChannel('studia/reminders-schedule-test');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return 1791734460000;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final reminders = LocalReminders(channel: channel, android: true);
    final when = await reminders.scheduleTest();
    expect(when.millisecondsSinceEpoch, 1791734460000);
    expect(calls, ['scheduleTest']);
  });

  test('sans canal natif le test différé demande une reconstruction', () async {
    final reminders = LocalReminders(
      channel: const MethodChannel('studia/reminders-absent-schedule-test'), android: true);
    await expectLater(reminders.scheduleTest(), throwsStateError);
    expect(reminders.nativeMissing, isTrue);
  });

  test('hors Android, les rappels sont désactivés sans appel natif', () async {
    final reminders = LocalReminders(android: false);
    expect(await reminders.hasPermission(), isFalse);
    expect(await reminders.requestPermission(), isFalse);
    await reminders.cancel(42);
  });
}
