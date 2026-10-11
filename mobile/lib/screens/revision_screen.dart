import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../revisions/revision_planner.dart';
import '../revisions/revision_session.dart';
import '../services/local_reminders.dart';
import '../services/schedule_store.dart';
import '../theme.dart';

class RevisionScreen extends StatefulWidget {
  final Schedule schedule;
  final ScheduleStore store;
  const RevisionScreen({super.key, required this.schedule, required this.store});

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  final reminders = LocalReminders();
  List<RevisionSession> sessions = [];
  Map<String, int> lastWeek = {};
  bool loading = true;
  bool permission = false;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  @override
  void didUpdateWidget(covariant RevisionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedule != widget.schedule) {
      final sameWeek = oldWidget.schedule.className == widget.schedule.className &&
        oldWidget.schedule.weekStart.year == widget.schedule.weekStart.year &&
        oldWidget.schedule.weekStart.month == widget.schedule.weekStart.month &&
        oldWidget.schedule.weekStart.day == widget.schedule.weekStart.day;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load(regenerate: sameWeek && oldWidget.schedule.courses != widget.schedule.courses);
      });
    }
  }

  bool get expired => !widget.schedule.weekStart.add(const Duration(days: 7)).isAfter(DateTime.now());

  Future<void> load({bool regenerate = false}) async {
    if (widget.schedule.isDemo) {
      if (mounted) setState(() { loading = false; sessions = []; });
      return;
    }
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final schedule = widget.schedule;
      final previous = await widget.store.previousStudyCounts(schedule.className, schedule.weekStart);
      var stored = await widget.store.revisionsFor(schedule.className, schedule.weekStart);
      if (!expired && (stored.isEmpty || regenerate)) {
        final generated = planRevisions(schedule, lastWeekCompleted: previous,
          alreadyCompleted: stored.where((s) => s.completed).toList());
        await widget.store.replacePendingRevisions(schedule.className, schedule.weekStart, generated);
        stored = await widget.store.revisionsFor(schedule.className, schedule.weekStart);
      }
      final allowed = await reminders.hasPermission();
      if (allowed && !expired) await reminders.replaceForWeek(schedule, stored);
      if (mounted) setState(() { sessions = stored; lastWeek = previous;
        permission = allowed; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = 'Planning de révision indisponible : $e'; loading = false; });
    }
  }

  Future<void> enableReminders() async {
    try {
      final granted = await reminders.requestPermission();
      if (granted) await reminders.replaceForWeek(widget.schedule, sessions);
      if (mounted) setState(() { permission = granted; error = granted ? null : 'Autorisez les notifications dans les paramètres du téléphone.'; });
    } catch (e) {
      if (mounted) setState(() => error = 'Notifications indisponibles : $e');
    }
  }

  Future<void> mark(RevisionSession session) async {
    try {
      await widget.store.setRevisionCompleted(session.id, !session.completed);
      if (!session.completed && permission) await reminders.cancel(session.id);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = 'Impossible de modifier la séance : $e');
    }
  }

  Future<void> regenerate() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Recalculer les révisions ?'),
      content: const Text('Les séances terminées seront conservées. Les séances restantes et leurs rappels seront remplacés.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Recalculer'))],
    ));
    if (confirmed == true) await load(regenerate: true);
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final completed = sessions.where((s) => s.completed).length;
    return Scaffold(appBar: AppBar(title: const Text('Mes révisions'), backgroundColor: canvas,
      actions: [if (!schedule.isDemo && !expired) IconButton(tooltip: 'Recalculer les séances',
        onPressed: loading ? null : regenerate, icon: const Icon(Icons.refresh_rounded))]),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 32), children: [
        Text('Du temps pour\napprendre.', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 9),
        Text('Semaine du ${DateFormat('d MMMM yyyy', 'fr').format(schedule.weekStart)} · ${schedule.className}',
          style: const TextStyle(color: muted)),
        const SizedBox(height: 24),
        if (schedule.isDemo) const Card(child: Padding(padding: EdgeInsets.all(22),
          child: Text('Importez puis validez votre vrai emploi du temps pour générer vos créneaux de révision. Aucun rappel ne part du planning DÉMO.')))
        else if (loading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else ...[
          if (expired) const Card(child: Padding(padding: EdgeInsets.all(18),
            child: Text('Cette semaine est terminée. Importez un nouvel emploi du temps pour programmer de nouvelles séances.'))),
          if (!permission && !expired)
            Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Rappels désactivés', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text('Activez les notifications locales pour les cours du matin et les séances de révision.',
                  style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 10),
                TextButton.icon(onPressed: enableReminders, icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Activer les rappels')),
              ])),
          if (permission && !expired) TextButton.icon(
            onPressed: () async {
              try {
                await reminders.testNotification();
              } catch (e) {
                if (mounted) setState(() => error = 'Test de notification impossible : $e');
              }
            },
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Tester une notification locale')),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!,
            style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 17),
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              const Icon(Icons.menu_book_rounded, color: Color(0xFF9ACEC0)), const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$completed / ${sessions.length} séances terminées',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text('50 min par séance · pause de 10 min', style: TextStyle(color: Color(0xFFBCCCD0), fontSize: 12)),
              ])),
            ])),
          const SizedBox(height: 18),
          if (lastWeek.isNotEmpty) Text('La semaine passée : ${lastWeek.entries.map((e) => '${e.key} ${e.value}×').join(' · ')}',
            style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 9),
          if (sessions.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20),
            child: Text('Aucune séance à placer : vérifiez le planning ou choisissez une semaine à venir.'))),
          ...List.generate(sessions.length, (index) {
            final s = sessions[index];
            final previousDate = index == 0 ? null : sessions[index - 1].start;
            final newDay = previousDate == null || previousDate.day != s.start.day ||
              previousDate.month != s.start.month || previousDate.year != s.start.year;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (newDay) Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 9),
                child: Text(DateFormat('EEEE d MMMM', 'fr').format(s.start).toUpperCase(),
                  style: const TextStyle(color: teal, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1))),
              Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                leading: CircleAvatar(backgroundColor: s.start.hour >= 20 ? const Color(0xFFE8E9FA) : mint,
                  child: Icon(s.start.hour >= 20 ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                    size: 20, color: teal)),
                title: Text(s.subject, style: TextStyle(fontWeight: FontWeight.w800,
                  decoration: s.completed ? TextDecoration.lineThrough : null)),
                subtitle: Text('${DateFormat('HH:mm').format(s.start)} – ${DateFormat('HH:mm').format(s.end)} · ${s.start.hour >= 20 ? 'À la maison' : 'Créneau libre'}'),
                trailing: Checkbox(value: s.completed, onChanged: (_) => mark(s)),
              )),
            ]);
          }),
          const SizedBox(height: 16),
          const Text('Cours du matin : rappel 1 h avant. Révisions : rappel au début. Android peut différer une alerte si les alarmes exactes sont désactivées.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
        ],
      ])),
    );
  }
}
