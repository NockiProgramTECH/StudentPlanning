class Course {
  final String subject;
  final int day;
  final String start;
  final String end;
  final String? room;
  final String? teacher;
  final int? sourcePage;
  final bool needsReview;

  const Course({required this.subject, required this.day, required this.start,
    required this.end, this.room, this.teacher, this.sourcePage, this.needsReview = false});

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    subject: json['subject'] as String, day: json['day'] as int,
    start: json['start'] as String, end: json['end'] as String,
    room: json['room'] as String?, teacher: json['teacher'] as String?,
    sourcePage: json['source_page'] as int?, needsReview: json['needs_review'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'subject': subject, 'day': day, 'start': start, 'end': end,
    'room': room, 'teacher': teacher, 'source_page': sourcePage, 'needs_review': needsReview,
  };

  Course copyWith({String? subject, int? day, String? start, String? end,
    String? room, String? teacher, bool? needsReview}) => Course(
    subject: subject ?? this.subject, day: day ?? this.day,
    start: start ?? this.start, end: end ?? this.end,
    room: room, teacher: teacher, sourcePage: sourcePage,
    needsReview: needsReview ?? this.needsReview,
  );
}

class Schedule {
  final String className;
  final DateTime weekStart;
  final List<Course> courses;
  final List<String> warnings;
  final bool isDemo;

  const Schedule({required this.className, required this.weekStart,
    required this.courses, this.warnings = const [], this.isDemo = false});

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
    className: json['class_name'] as String,
    weekStart: DateTime.parse(json['week_start'] as String),
    courses: (json['courses'] as List).map((c) => Course.fromJson(c as Map<String, dynamic>)).toList(),
    warnings: (json['warnings'] as List? ?? []).cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'class_name': className,
    'week_start': '${weekStart.year.toString().padLeft(4, '0')}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}',
    'courses': courses.map((c) => c.toJson()).toList(),
    'warnings': warnings,
  };
}

class Change {
  final String type;
  final String subject;
  final bool needsReview;
  const Change(this.type, this.subject, this.needsReview);
  factory Change.fromJson(Map<String, dynamic> json) => Change(
    json['type'] as String, json['subject'] as String, json['needs_review'] as bool? ?? true);
}
