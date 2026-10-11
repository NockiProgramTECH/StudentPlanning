const _unchanged = Object();

class Course {
  final String subject;
  final int day;
  final String start;
  final String end;
  final String? room;
  final String? teacher;
  final int? sourcePage;
  final bool needsReview;
  final String kind; // course, assessment, unknown
  final String deliveryMode; // online, in_person, unknown

  const Course({required this.subject, required this.day, required this.start,
    required this.end, this.room, this.teacher, this.sourcePage, this.needsReview = false, this.kind = 'unknown', this.deliveryMode = 'unknown'});

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    subject: json['subject'] as String, day: json['day'] as int,
    start: json['start'] as String, end: json['end'] as String,
    room: json['room'] as String?, teacher: json['teacher'] as String?,
    sourcePage: json['source_page'] as int?, needsReview: json['needs_review'] as bool? ?? false,
    kind: json['kind'] as String? ?? 'unknown', deliveryMode: json['delivery_mode'] as String? ?? 'unknown',
  );

  Map<String, dynamic> toJson() => {
    'subject': subject, 'day': day, 'start': start, 'end': end,
    'room': room, 'teacher': teacher, 'source_page': sourcePage, 'needs_review': needsReview,
    'kind': kind, 'delivery_mode': deliveryMode,
  };

  Course copyWith({String? subject, int? day, String? start, String? end,
    Object? room = _unchanged, Object? teacher = _unchanged, bool? needsReview,
    String? kind, String? deliveryMode}) => Course(
    subject: subject ?? this.subject, day: day ?? this.day,
    start: start ?? this.start, end: end ?? this.end,
    room: identical(room, _unchanged) ? this.room : room as String?,
    teacher: identical(teacher, _unchanged) ? this.teacher : teacher as String?, sourcePage: sourcePage,
    needsReview: needsReview ?? this.needsReview,
    kind: kind ?? this.kind, deliveryMode: deliveryMode ?? this.deliveryMode,
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
  final Course? previous;
  final Course? current;
  const Change(this.type, this.subject, this.needsReview, {this.previous, this.current});
  factory Change.fromJson(Map<String, dynamic> json) => Change(
    json['type'] as String, json['subject'] as String, json['needs_review'] as bool? ?? true,
    previous: json['previous'] == null ? null : Course.fromJson(json['previous'] as Map<String, dynamic>),
    current: json['current'] == null ? null : Course.fromJson(json['current'] as Map<String, dynamic>));
}
