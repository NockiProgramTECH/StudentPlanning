import 'dart:convert';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../models/course_material.dart';
import '../models/schedule.dart';
import '../revisions/revision_session.dart';

/// One validated snapshot per class/week. Never writes an unvalidated import.
class ScheduleStore {
  Database? _database;

  Future<Database> get database async => _database ??= await openDatabase(
    path.join(await getDatabasesPath(), 'student_planning.db'),
    version: 4,
    onCreate: (db, version) async {
      await db.execute('CREATE TABLE schedules (class_name TEXT NOT NULL, week_start TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(class_name, week_start))');
      await _createRevisions(db);
      await _createCoursePacks(db);
      await _createStudentAccess(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) await _createRevisions(db);
      if (oldVersion < 3) await _createCoursePacks(db);
      if (oldVersion < 4) await _createStudentAccess(db);
    },
  );

  static Future<void> _createStudentAccess(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS student_access (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  }

  Future<String> deviceIdentifier() async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query('student_access', where: 'key = ?', whereArgs: ['device']);
      if (rows.isNotEmpty) return rows.first['value'] as String;
      final random = Random.secure();
      final id = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await txn.insert('student_access', {'key': 'device', 'value': id});
      return id;
    });
  }

  Future<String?> studentAccessToken(String server) async {
    final rows = await (await database).query('student_access',
        where: 'key = ?', whereArgs: ['token:$server']);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> saveStudentAccessToken(String server, String? token) async {
    final db = await database;
    if (token == null) {
      await db.delete('student_access', where: 'key = ?', whereArgs: ['token:$server']);
    } else {
      await db.insert('student_access', {'key': 'token:$server', 'value': token},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _createRevisions(Database db) async {
    await db.execute('CREATE TABLE revisions (id INTEGER PRIMARY KEY, class_name TEXT NOT NULL, week_start TEXT NOT NULL, subject TEXT NOT NULL, start_at TEXT NOT NULL, end_at TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE INDEX revisions_week ON revisions(class_name, week_start)');
  }

  static Future<void> _createCoursePacks(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS course_packs (id TEXT PRIMARY KEY, subject TEXT NOT NULL, updated_at TEXT NOT NULL, payload TEXT NOT NULL)');
  }

  static String _dateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  RevisionSession _session(Map<String, Object?> row) => RevisionSession(
    id: row['id'] as int, className: row['class_name'] as String,
    weekStart: DateTime.parse(row['week_start'] as String),
    subject: row['subject'] as String,
    start: DateTime.parse(row['start_at'] as String),
    end: DateTime.parse(row['end_at'] as String),
    completed: (row['completed'] as int) == 1,
  );

  Future<List<RevisionSession>> revisionsFor(String className, DateTime weekStart) async {
    final rows = await (await database).query('revisions',
      where: 'class_name = ? AND week_start = ?', whereArgs: [className, _dateKey(weekStart)],
      orderBy: 'start_at ASC');
    return rows.map(_session).toList();
  }

  Future<Map<String, int>> previousStudyCounts(String className, DateTime weekStart) async {
    final previous = weekStart.subtract(const Duration(days: 7));
    final rows = await (await database).query('revisions', columns: ['subject'],
      where: 'class_name = ? AND week_start = ? AND completed = 1',
      whereArgs: [className, _dateKey(previous)]);
    final counts = <String, int>{};
    for (final row in rows) {
      final key = (row['subject'] as String).trim().toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Regeneration keeps completed study history, replaces only pending slots.
  Future<void> replacePendingRevisions(String className, DateTime weekStart, List<RevisionSession> sessions) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('revisions', where: 'class_name = ? AND week_start = ? AND completed = 0',
        whereArgs: [className, _dateKey(weekStart)]);
      for (final session in sessions) {
        await txn.insert('revisions', {
          'id': session.id, 'class_name': className, 'week_start': _dateKey(weekStart),
          'subject': session.subject, 'start_at': session.start.toIso8601String(),
          'end_at': session.end.toIso8601String(), 'completed': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> setRevisionCompleted(int id, bool completed) async {
    await (await database).update('revisions', {'completed': completed ? 1 : 0},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Schedule>> all() async {
    final rows = await (await database).query('schedules', orderBy: 'week_start DESC');
    return rows.map((row) => Schedule.fromJson(jsonDecode(row['payload'] as String) as Map<String, dynamic>)).toList();
  }

  Future<Schedule?> previous(String className, DateTime weekStart) async {
    final previousDate = weekStart.subtract(const Duration(days: 7));
    final key = Schedule(className: className, weekStart: previousDate, courses: const []).toJson()['week_start'];
    final rows = await (await database).query('schedules', where: 'class_name = ? AND week_start = ?',
      whereArgs: [className, key], limit: 1);
    if (rows.isEmpty) return null;
    return Schedule.fromJson(jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>);
  }

  Future<void> save(Schedule schedule) async {
    if (schedule.isDemo) throw StateError('Un exemple ne peut pas être enregistré');
    await (await database).insert('schedules', {
      'class_name': schedule.className,
      'week_start': schedule.toJson()['week_start'],
      'payload': jsonEncode(schedule.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CourseDocumentModel>> courseDocuments() async {
    final rows = await (await database).query('course_packs', orderBy: 'updated_at DESC');
    return rows
        .map((r) => CourseDocumentModel.fromJson(jsonDecode(r['payload'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCourseDocument(CourseDocumentModel document) async {
    if (document.isDemo) throw StateError('Un exemple ne peut pas être enregistré');
    await (await database).insert('course_packs', {
      'id': document.id,
      'subject': document.subject,
      'updated_at': DateTime.now().toIso8601String(),
      'payload': jsonEncode(document.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
