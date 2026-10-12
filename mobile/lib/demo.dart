import 'models/course_material.dart';
import 'models/schedule.dart';

/// Clearly marked sample data for the first launch, never submitted to the API.
Schedule demoSchedule(DateTime now) {
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  return Schedule(className: 'L2 SIR', weekStart: monday, isDemo: true, courses: const [
    Course(subject: 'Mathématiques', day: 1, start: '08:30', end: '10:00', room: 'B204', teacher: 'Mme Laurent'),
    Course(subject: 'Algorithmique', day: 1, start: '10:30', end: '12:00', room: 'Lab 03', teacher: 'M. Diallo'),
    Course(subject: 'Anglais', day: 2, start: '09:00', end: '10:30', room: 'C112'),
    Course(subject: 'Bases de données', day: 2, start: '14:00', end: '16:00', room: 'Lab 01', kind: 'course', deliveryMode: 'online'),
    Course(subject: 'Réseaux', day: 3, start: '08:00', end: '10:00', room: 'A103', kind: 'assessment'),
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

CourseDocumentModel demoCourseDocument() => const CourseDocumentModel(
  id: 'demo_l2sir_tsa',
  subject: 'Transmission des signaux analogiques',
  title: 'Support · Modulations AM et FM (DÉMO)',
  filename: 'cours_modulations_demo.pdf',
  pageCount: 6,
  totalChars: 4200,
  isDemo: true,
  sections: [
    CourseSectionModel(
      index: 0,
      title: 'Chapitre 1 : Modulation d’amplitude (AM)',
      pageStart: 1,
      pageEnd: 3,
      pages: [1, 2, 3],
      content: '[Page 1]\nPrincipe de la porteuse et enveloppe AM.',
      charCount: 2100,
      questionsGenerated: 2,
      questionsAnswered: 1,
      correctAnswers: 1,
    ),
    CourseSectionModel(
      index: 1,
      title: 'Chapitre 2 : Modulation de fréquence (FM)',
      pageStart: 4,
      pageEnd: 6,
      pages: [4, 5, 6],
      content: '[Page 4]\nExcursion en fréquence et règle de Carson.',
      charCount: 2100,
      questionsGenerated: 0,
      questionsAnswered: 0,
      correctAnswers: 0,
    ),
  ],
  progress: CourseProgressModel(
    totalSections: 2,
    generatedSections: 1,
    completedSections: 0,
    nextSectionIndex: 0,
    totalQuestions: 2,
    answeredQuestions: 1,
    correctAnswers: 1,
    scorePercent: 100,
  ),
  questions: [
    CourseQuestionModel(
      id: 1,
      sectionIndex: 0,
      prompt: 'Quelle condition sur l’indice de modulation m évite la surmodulation en AM ?',
      choices: ['m <= 1', 'm > 2', 'm = 0 uniquement', 'La porteuse est supprimée'],
      correctIndex: 0,
      explanation: 'Pour conserver une détection d’enveloppe sans distorsion, l’indice m doit rester inférieur ou égal à 1 (voir page 2).',
      sourcePage: 2,
      selectedIndex: 0,
      isCorrect: true,
    ),
    CourseQuestionModel(
      id: 2,
      sectionIndex: 0,
      prompt: 'Où se trouve l’information utile dans un signal modulé en amplitude ?',
      choices: ['Dans la phase uniquement', 'Dans les bandes latérales autour de la porteuse', 'Dans le continu', 'Uniquement à fréquence nulle'],
      correctIndex: 1,
      explanation: 'Le spectre AM comporte la porteuse et deux bandes latérales symétriques portant l’information (voir page 3).',
      sourcePage: 3,
    ),
  ],
);

