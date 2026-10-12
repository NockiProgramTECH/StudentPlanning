import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../theme.dart';
import 'planning_screen.dart';

class HistoryScreen extends StatelessWidget {
  final List<Schedule> schedules;
  final bool isDemo;
  final ValueChanged<Schedule>? onSelect;
  const HistoryScreen({super.key, required this.schedules, this.isDemo = false, this.onSelect});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Historique'), backgroundColor: canvas),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      Text('Vos semaines', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      const Text('Vos plannings validés restent accessibles hors connexion.', style: TextStyle(color: muted)),
      if (isDemo) const Padding(padding: EdgeInsets.only(top: 10), child: Text('APERÇU · Semaines fictives',
        style: TextStyle(color: teal, fontWeight: FontWeight.w800, fontSize: 11))),
      const SizedBox(height: 24),
      if (schedules.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24),
        child: Text('Aucun planning enregistré. Importez un PDF pour commencer.', style: TextStyle(color: muted)))),
      ...schedules.map((s) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.calendar_month_rounded, color: teal)),
        title: Text('Semaine du ${DateFormat('d MMMM yyyy', 'fr').format(s.weekStart)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${s.className}  ·  ${s.courses.length} cours'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          if (onSelect != null) {
            onSelect!(s);
          } else {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => PlanningScreen(schedule: s),
            ));
          }
        },
      )))
    ]));
}
