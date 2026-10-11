import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../models/schedule.dart';

/// One validated snapshot per class/week. Never writes an unvalidated import.
class ScheduleStore {
  Database? _database;

  Future<Database> get database async => _database ??= await openDatabase(
    path.join(await getDatabasesPath(), 'student_planning.db'),
    version: 1,
    onCreate: (db, version) async => db.execute(
      'CREATE TABLE schedules (class_name TEXT NOT NULL, week_start TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(class_name, week_start))'),
  );

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
}
