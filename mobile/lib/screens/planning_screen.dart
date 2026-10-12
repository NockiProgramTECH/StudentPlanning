import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../theme.dart';
import '../widgets/course_card.dart';

const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

class PlanningScreen extends StatefulWidget {
  final Schedule schedule;
  final VoidCallback? onRevisions;
  const PlanningScreen({super.key, required this.schedule, this.onRevisions});
  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  int selected = 1; // Show Monday first, including when opening a past week.

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final courses = schedule.courses.where((c) => c.day == selected).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return Scaffold(appBar: AppBar(title: const Text('Mon planning'), backgroundColor: canvas,
      actions: [Padding(padding: const EdgeInsets.only(right: 20), child: Center(child: Text(schedule.className,
        style: const TextStyle(color: teal, fontWeight: FontWeight.w700, fontSize: 12))))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 32), children: [
        Text('Ma semaine', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 5),
        Text('Du ${DateFormat('d MMM', 'fr').format(schedule.weekStart)} au ${DateFormat('d MMM yyyy', 'fr').format(schedule.weekStart.add(const Duration(days: 6)))}',
          style: const TextStyle(color: muted)),
        if (schedule.isDemo) const Padding(padding: EdgeInsets.only(top: 8), child: Text('APERÇU · Données de démonstration', style: TextStyle(color: teal, fontWeight: FontWeight.w800, fontSize: 11))),
        const SizedBox(height: 26),
        SizedBox(height: 78, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: 7,
          separatorBuilder: (_, index) => const SizedBox(width: 9), itemBuilder: (context, index) {
            final day = index + 1;
            final active = day == selected;
            final hasCourses = schedule.courses.any((c) => c.day == day);
            final date = schedule.weekStart.add(Duration(days: index));
            return InkWell(onTap: () => setState(() => selected = day), borderRadius: BorderRadius.circular(18),
              child: Container(width: 49, decoration: BoxDecoration(color: active ? teal : Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(days[index].substring(0, 3), style: TextStyle(color: active ? Colors.white70 : muted, fontSize: 11)),
                  const SizedBox(height: 5),
                  Text('${date.day}', style: TextStyle(color: active ? Colors.white : ink, fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Container(width: 5, height: 5, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasCourses ? (active ? Colors.white : teal) : Colors.transparent,
                  )),
                ])),
            );
          })),
        const SizedBox(height: 30),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(days[selected - 1], style: Theme.of(context).textTheme.headlineMedium),
          Text('${courses.length} cours', style: const TextStyle(color: muted)),
        ]),
        const SizedBox(height: 16),
        if (courses.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(26),
          child: Text('Aucun cours prévu ce jour-là. Profitez de votre temps libre !', style: TextStyle(color: muted)))),
        ...courses.map((c) => CourseCard(course: c)),
        if (widget.onRevisions != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.onRevisions,
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Voir mes révisions'),
          ),
        ],
      ]));
  }
}
