import 'package:flutter/material.dart';
import '../demo.dart';
import '../theme.dart';
import '../screens/comparison_screen.dart';
import '../screens/course_study_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/import_screen.dart';
import '../screens/planning_screen.dart';
import '../screens/review_screen.dart';
import '../screens/revision_screen.dart';
import '../services/schedule_store.dart';

/// Gallery of actual Flutter screens. No backend call or SQLite write in preview.
class MockupGallery extends StatelessWidget {
  const MockupGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = demoSchedule(now);
    final changes = demoChanges(now);
    void open(Widget screen) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (routeContext) => screen));
    }
    final entries = <(String, String, IconData, Widget)>[
      ('01', 'Accueil', Icons.home_outlined, HomeScreen(schedule: current,
        onImport: () => open(ImportScreen(store: ScheduleStore(), initialClass: current.className,
          onSaved: (schedule) async {}, previewMode: true)),
        onPlanning: () => open(PlanningScreen(schedule: current)),
        onMockups: () => Navigator.of(context).pop())),
      ('02', 'Importer un PDF', Icons.upload_file_outlined,
        ImportScreen(store: ScheduleStore(), initialClass: current.className,
          onSaved: (schedule) async {}, previewMode: true)),
      ('03', 'Vérifier les cours', Icons.fact_check_outlined,
        ReviewScreen(schedule: demoToReview(now), changes: changes,
          onSave: (schedule) async {}, previewMode: true)),
      ('04', 'Planning hebdomadaire', Icons.calendar_month_outlined,
        PlanningScreen(schedule: current)),
      ('05', 'Comparer les semaines', Icons.compare_arrows_rounded,
        ComparisonScreen(changes: changes, isDemo: true)),
      ('06', 'Historique', Icons.history_rounded,
        HistoryScreen(schedules: [current, demoPrevious(now)], isDemo: true)),
      ('07', 'Révisions', Icons.menu_book_outlined,
        RevisionScreen(schedule: current, store: ScheduleStore(), previewMode: true)),
      ('08', 'Supports de cours & Quiz IA', Icons.quiz_outlined,
        CourseStudyScreen(store: ScheduleStore(), previewMode: true)),
    ];
    return Scaffold(appBar: AppBar(title: const Text('Studia · Maquettes'), backgroundColor: canvas),
      body: ListView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 30), children: [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(24)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PARCOURS ÉTUDIANT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9ACEC0), letterSpacing: 1.1)),
            SizedBox(height: 10),
            Text('Votre planning,\nsans effort.', style: TextStyle(color: Colors.white, fontSize: 27, height: 1.16, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            Text('Explorez les 7 écrans de la maquette. Tout est fictif : aucun PDF, réseau ou enregistrement.',
              style: TextStyle(color: Color(0xFFBECED0), height: 1.5)),
          ])),
        const SizedBox(height: 25),
        ...entries.map((entry) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: CircleAvatar(backgroundColor: mint, child: Icon(entry.$3, color: teal)),
          title: Text(entry.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('ÉCRAN ${entry.$1}', style: const TextStyle(color: muted, fontSize: 11)),
          trailing: const Icon(Icons.arrow_forward_rounded, color: teal),
          onTap: () => open(entry.$4),
        ))),
      ]));
  }
}
