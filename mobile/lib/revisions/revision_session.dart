/// A locally planned study session. Only completed sessions count next week.
class RevisionSession {
  final int id;
  final String className;
  final DateTime weekStart;
  final String subject;
  final DateTime start;
  final DateTime end;
  final bool completed;

  const RevisionSession({required this.id, required this.className,
    required this.weekStart, required this.subject, required this.start,
    required this.end, this.completed = false});

  RevisionSession copyWith({bool? completed}) => RevisionSession(
    id: id, className: className, weekStart: weekStart, subject: subject,
    start: start, end: end, completed: completed ?? this.completed);

  Map<String, dynamic> toJson() => {
    'id': id, 'class_name': className,
    'week_start': weekStart.toIso8601String().substring(0, 10),
    'subject': subject, 'start': start.toIso8601String(),
    'end': end.toIso8601String(), 'completed': completed,
  };

  factory RevisionSession.fromJson(Map<String, dynamic> json) => RevisionSession(
    id: json['id'] as int, className: json['class_name'] as String,
    weekStart: DateTime.parse(json['week_start'] as String),
    subject: json['subject'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    completed: json['completed'] as bool? ?? false,
  );
}
