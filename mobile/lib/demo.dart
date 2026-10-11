import 'models/schedule.dart';

/// Clearly marked sample data for the first launch, never submitted to the API.
Schedule demoSchedule(DateTime now) {
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  return Schedule(className: 'L2 Informatique', weekStart: monday, isDemo: true, courses: const [
    Course(subject: 'Mathématiques', day: 1, start: '08:30', end: '10:00', room: 'B204', teacher: 'Mme Laurent'),
    Course(subject: 'Algorithmique', day: 1, start: '10:30', end: '12:00', room: 'Lab 03', teacher: 'M. Diallo'),
    Course(subject: 'Anglais', day: 2, start: '09:00', end: '10:30', room: 'C112'),
    Course(subject: 'Bases de données', day: 2, start: '14:00', end: '16:00', room: 'Lab 01'),
    Course(subject: 'Réseaux', day: 3, start: '08:00', end: '10:00', room: 'A103'),
    Course(subject: 'Architecture', day: 4, start: '10:00', end: '12:00', room: 'B201'),
    Course(subject: 'Projet tutoré', day: 5, start: '13:30', end: '16:00', room: 'Lab 03'),
  ]);
}


Schedule demoPrevious(DateTime now) {
  final current = demoSchedule(now);
  return Schedule(className: current.className,
    weekStart: current.weekStart.subtract(const Duration(days: 7)),
    isDemo: true, courses: [
      const Course(subject: 'Mathématiques', day: 1, start: '08:30', end: '10:00', room: 'B204'),
      const Course(subject: 'Algorithmique', day: 1, start: '10:30', end: '12:00', room: 'Lab 02'),
      const Course(subject: 'Anglais', day: 2, start: '09:00', end: '10:30', room: 'C112'),
      const Course(subject: 'Réseaux', day: 3, start: '08:00', end: '10:00', room: 'A103'),
    ]);
}

Schedule demoToReview(DateTime now) {
  final current = demoSchedule(now);
  return Schedule(className: current.className, weekStart: current.weekStart,
    isDemo: true, warnings: const ['Salle du cours d’Algorithmique à confirmer.'],
    courses: current.courses.map((course) => course.subject == 'Algorithmique'
      ? course.copyWith(needsReview: true) : course).toList());
}

List<Change> demoChanges(DateTime now) {
  final old = demoPrevious(now);
  final current = demoSchedule(now);
  return [
    Change('room_changed', 'Algorithmique', true,
      previous: old.courses[1], current: current.courses[1]),
    Change('added', 'Bases de données', true, current: current.courses[3]),
    Change('added', 'Projet tutoré', true, current: current.courses[6]),
  ];
}
