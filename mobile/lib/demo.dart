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
