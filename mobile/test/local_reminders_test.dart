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

  test('hors Android, les rappels sont désactivés sans appel natif', () async {
    final reminders = LocalReminders(android: false);
    expect(await reminders.hasPermission(), isFalse);
    expect(await reminders.requestPermission(), isFalse);
    await reminders.cancel(42);
  });
}
