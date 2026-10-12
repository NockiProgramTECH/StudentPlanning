import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'demo.dart';
import 'mockups/mockup_gallery.dart';
import 'models/schedule.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'screens/planning_screen.dart';
import 'screens/revision_screen.dart';
import 'services/schedule_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  runApp(const StudentPlanningApp());
}

class StudentPlanningApp extends StatelessWidget {
  const StudentPlanningApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Studia · Mon planning', theme: appTheme(), debugShowCheckedModeBanner: false,
    home: const bool.fromEnvironment('SHOW_MOCKUPS') ? const MockupGallery() : const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final store = ScheduleStore();
  List<Schedule> saved = [];
  Schedule? activeSchedule;
  int tab = 0;
  bool busy = true;
  String? loadError;

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    try {
      final all = await store.all();
      if (mounted) {
        setState(() {
          saved = all;
          if (activeSchedule != null) {
            activeSchedule = all.where((s) =>
              s.className == activeSchedule!.className &&
              s.weekStart.year == activeSchedule!.weekStart.year &&
              s.weekStart.month == activeSchedule!.weekStart.month &&
              s.weekStart.day == activeSchedule!.weekStart.day).firstOrNull;
          }
          busy = false;
          loadError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() { busy = false; loadError = 'Lecture des plannings impossible. Réessayez.'; });
    }
  }

  Future<void> save(Schedule schedule) async {
    await store.save(schedule);
    activeSchedule = schedule;
    await refresh();
    if (mounted) setState(() => tab = 1);
  }

  void openMockups() => Navigator.of(context).push(MaterialPageRoute(builder: (routeContext) => const MockupGallery()));

  void openImport() => Navigator.of(context).push(MaterialPageRoute(builder: (routeContext) => ImportScreen(
    store: store, initialClass: saved.isEmpty ? 'L2 SIR' : saved.first.className, onSaved: save)));

  @override
  Widget build(BuildContext context) {
    if (busy) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (loadError != null) return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(loadError!), TextButton(onPressed: refresh, child: const Text('Réessayer'))])));
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final current = activeSchedule
      ?? saved.where((s) => s.weekStart.year == monday.year && s.weekStart.month == monday.month && s.weekStart.day == monday.day).firstOrNull
      ?? (saved.isEmpty ? demoSchedule(now) : saved.first);
    final pages = [
      HomeScreen(schedule: current, onImport: openImport, onPlanning: () => setState(() => tab = 1), onMockups: openMockups),
      PlanningScreen(schedule: current, onRevisions: () => setState(() => tab = 2)),
      RevisionScreen(schedule: current, store: store),
      HistoryScreen(schedules: saved, onSelect: (s) => setState(() { activeSchedule = s; tab = 1; })),
    ];
    return Scaffold(body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
        backgroundColor: Colors.white, indicatorColor: mint, destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Planning'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Révisions'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Historique'),
        ]));
  }
}
