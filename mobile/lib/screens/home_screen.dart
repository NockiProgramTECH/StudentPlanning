import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../theme.dart';
import '../widgets/course_card.dart';

class HomeScreen extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onImport;
  final VoidCallback onPlanning;
  final VoidCallback? onMockups;
  const HomeScreen({super.key, required this.schedule, required this.onImport, required this.onPlanning, this.onMockups});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayCourses = schedule.courses.where((c) => c.day == today.weekday).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), children: [
      Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 22)),
        const SizedBox(width: 10),
        const Text('studia.', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: ink, letterSpacing: -1)),
        const Spacer(),
        if (onMockups != null) IconButton(tooltip: 'Voir les maquettes', onPressed: onMockups,
          icon: const Icon(Icons.dashboard_customize_outlined, color: teal))
        else const CircleAvatar(backgroundColor: mint, child: Icon(Icons.person_outline_rounded, color: teal)),
      ]),
      const SizedBox(height: 34),
      Text(DateFormat('EEEE d MMMM', 'fr').format(today).toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: teal)),
      const SizedBox(height: 10),
      Text('Votre semaine,\nen toute clarté.', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 10),
      Text(schedule.isDemo ? 'Découvrez l’application avec un exemple de planning.' : 'Retrouvez tous vos cours au même endroit.',
        style: const TextStyle(color: muted, height: 1.5)),
      const SizedBox(height: 26),
      Container(padding: const EdgeInsets.all(23), decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(26)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF9ACEC0), size: 17),
            const SizedBox(width: 8),
            Text('SEMAINE DU ${DateFormat('d MMMM', 'fr').format(schedule.weekStart).toUpperCase()}',
              style: const TextStyle(color: Color(0xFF9ACEC0), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 16),
          Text(schedule.className, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('${schedule.courses.length} cours cette semaine${schedule.isDemo ? '  ·  DÉMO' : ''}',
            style: const TextStyle(color: Color(0xFFBCCCD0), fontSize: 13)),
          const SizedBox(height: 22),
          OutlinedButton.icon(onPressed: onPlanning, icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Voir mon planning'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF768B93)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)))),
        ])),
      const SizedBox(height: 28),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("Aujourd'hui", style: Theme.of(context).textTheme.headlineMedium),
        Text('${todayCourses.length} cours', style: const TextStyle(color: muted, fontSize: 13)),
      ]),
      const SizedBox(height: 14),
      if (todayCourses.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Pas de cours aujourd’hui.', style: TextStyle(color: muted)))),
      ...todayCourses.take(3).map((c) => CourseCard(course: c, onTap: onPlanning)),
      const SizedBox(height: 18),
      Material(color: mint, borderRadius: BorderRadius.circular(22), child: InkWell(onTap: onImport,
        borderRadius: BorderRadius.circular(22), child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.upload_file_rounded, color: teal)),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nouveau planning ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink)),
            SizedBox(height: 4), Text('Importez votre emploi du temps PDF', style: TextStyle(fontSize: 12, color: muted)),
          ])),
          const Icon(Icons.arrow_forward_rounded, color: teal),
        ])))),
    ])));
  }
}
