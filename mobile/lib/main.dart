import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'demo.dart';
import 'mockups/mockup_gallery.dart';
import 'models/schedule.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'screens/planning_screen.dart';
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
  int tab = 0;
  bool busy = true;
  String? loadError;

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    try {
      final all = await store.all();
      if (mounted) setState(() { saved = all; busy = false; loadError = null; });
    } catch (_) {
      if (mounted) setState(() { busy = false; loadError = 'Lecture des plannings impossible. Réessayez.'; });
    }
  }

  Future<void> save(Schedule schedule) async {
    await store.save(schedule);
    await refresh();
    if (mounted) setState(() => tab = 0);
  }

  void openMockups() => Navigator.of(context).push(MaterialPageRoute(builder: (routeContext) => const MockupGallery()));

  void openImport() => Navigator.of(context).push(MaterialPageRoute(builder: (routeContext) => ImportScreen(
    store: store, initialClass: saved.isEmpty ? '' : saved.first.className, onSaved: save)));

  @override
  Widget build(BuildContext context) {
    if (busy) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (loadError != null) return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(loadError!), TextButton(onPressed: refresh, child: const Text('Réessayer'))])));
    final monday = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final current = saved.where((s) => s.weekStart.year == monday.year && s.weekStart.month == monday.month && s.weekStart.day == monday.day).firstOrNull
      ?? (saved.isEmpty ? demoSchedule(DateTime.now()) : saved.first);
    final pages = [
      HomeScreen(schedule: current, onImport: openImport, onPlanning: () => setState(() => tab = 1), onMockups: openMockups),
      PlanningScreen(schedule: current),
      HistoryScreen(schedules: saved),
    ];
    return Scaffold(body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
        backgroundColor: Colors.white, indicatorColor: mint, destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Planning'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Historique'),
        ]));
  }
}
