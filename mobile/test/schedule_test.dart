import 'package:flutter_test/flutter_test.dart';
import 'package:student_planning/models/schedule.dart';

void main() {
  test('le planning conserve les cours lors du JSON roundtrip', () {
    final schedule = Schedule(className: 'L2 Info', weekStart: DateTime(2026, 10, 12),
      courses: const [Course(subject: 'Maths', day: 1, start: '08:00', end: '10:00', room: 'A10', kind: 'assessment', deliveryMode: 'online')]);
    final copy = Schedule.fromJson(schedule.toJson());
    expect(copy.className, 'L2 Info');
    expect(copy.courses.single.room, 'A10');
    expect(copy.courses.single.kind, 'assessment');
    expect(copy.courses.single.deliveryMode, 'online');
    expect(copy.toJson()['week_start'], '2026-10-12');
    expect(copy.courses.single.copyWith(needsReview: true).room, 'A10');
    expect(copy.courses.single.copyWith(room: null).room, isNull);
  });
}
