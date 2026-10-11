import 'package:flutter/material.dart';
import '../models/schedule.dart';
import '../theme.dart';
import '../widgets/course_card.dart';
import 'planning_screen.dart';

const changeLabels = {
  'added': 'Cours ajouté', 'removed': 'Cours supprimé',
  'time_changed': 'Horaire modifié', 'room_changed': 'Salle modifiée',
  'details_changed': 'Détails modifiés', 'uncertain': 'Changement incertain',
};

class ReviewScreen extends StatefulWidget {
  final Schedule schedule;
  final List<Change> changes;
  final Future<void> Function(Schedule) onSave;
  const ReviewScreen({super.key, required this.schedule, required this.changes, required this.onSave});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<Course> courses = [...widget.schedule.courses];
  bool saving = false;
  bool edited = false;

  Future<void> editCourse(int index) async {
    final original = courses[index];
    final subject = TextEditingController(text: original.subject);
    final start = TextEditingController(text: original.start);
    final end = TextEditingController(text: original.end);
    final room = TextEditingController(text: original.room ?? '');
    final teacher = TextEditingController(text: original.teacher ?? '');
    var day = original.day;
    String? error;
    final replacement = await showDialog<Course>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: const Text('Corriger le cours'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: subject, decoration: const InputDecoration(labelText: 'Matière')),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(value: day, decoration: const InputDecoration(labelText: 'Jour'),
            items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text(days[i]))),
            onChanged: (value) => refresh(() => day = value ?? day)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: start, decoration: const InputDecoration(labelText: 'Début (HH:mm)'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: end, decoration: const InputDecoration(labelText: 'Fin (HH:mm)'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: room, decoration: const InputDecoration(labelText: 'Salle (facultatif)')),
          const SizedBox(height: 10),
          TextField(controller: teacher, decoration: const InputDecoration(labelText: 'Enseignant (facultatif)')),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () {
            final time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
            if (subject.text.trim().isEmpty || !time.hasMatch(start.text) || !time.hasMatch(end.text) || start.text.compareTo(end.text) >= 0) {
              refresh(() => error = 'Vérifiez la matière et les heures (HH:mm).');
              return;
            }
            Navigator.pop(context, original.copyWith(subject: subject.text.trim(), day: day,
              start: start.text, end: end.text,
              room: room.text.trim().isEmpty ? null : room.text.trim(),
              teacher: teacher.text.trim().isEmpty ? null : teacher.text.trim(), needsReview: false));
          }, child: const Text('Appliquer')),
        ],
      ),
    ));
    if (replacement != null && mounted) setState(() { courses[index] = replacement; edited = true; });
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.onSave(Schedule(className: widget.schedule.className, weekStart: widget.schedule.weekStart,
        courses: courses, warnings: widget.schedule.warnings));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enregistrement impossible : $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Vérification'), backgroundColor: canvas),
    bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
      child: FilledButton.icon(onPressed: saving ? null : save,
        icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
        label: const Text('Valider et enregistrer')))),
    body: ListView(padding: const EdgeInsets.fromLTRB(22, 10, 22, 20), children: [
      Text('À vous de vérifier.', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      const Text('Relisez les cours extraits avant de les enregistrer sur votre téléphone.', style: TextStyle(color: muted)),
      const SizedBox(height: 20),
      if (widget.schedule.warnings.isNotEmpty || courses.any((c) => c.needsReview))
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFFEBD9), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('À vérifier dans le PDF', style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 6),
            ...widget.schedule.warnings.map((w) => Text('• $w', style: const TextStyle(color: ink))),
            if (courses.any((c) => c.needsReview)) const Text('• Certains cours sont signalés comme incertains.', style: TextStyle(color: ink)),
          ])),
      if (widget.changes.isNotEmpty) ...[
        const SizedBox(height: 22),
        Text('Par rapport à la semaine précédente', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('Propositions à confirmer dans les documents source.', style: TextStyle(color: muted, fontSize: 12)),
        if (edited) const Text('Cours corrigés : ces propositions n’ont pas été recalculées.', style: TextStyle(color: teal, fontSize: 12)),
        const SizedBox(height: 10),
        ...widget.changes.map((c) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(children: [
          const Icon(Icons.compare_arrows_rounded, size: 18, color: teal), const SizedBox(width: 9),
          Expanded(child: Text('${changeLabels[c.type] ?? c.type} · ${c.subject}')),
        ]))),
      ],
      const SizedBox(height: 24),
      Row(children: [Text('Cours détectés', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(), Text('${courses.length} cours', style: const TextStyle(color: muted))]),
      const SizedBox(height: 12),
      if (courses.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Aucun cours trouvé. Vérifiez votre classe et votre PDF.'))),
      ...List.generate(courses.length, (i) => Dismissible(
        key: ValueKey('${identityHashCode(courses[i])}-$i'), direction: DismissDirection.endToStart,
        background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
          color: const Color(0xFFCF6664), child: const Icon(Icons.delete_outline, color: Colors.white)),
        onDismissed: (_) => setState(() { courses.removeAt(i); edited = true; }),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 8, top: 8, bottom: 5), child: Text(days[courses[i].day - 1].toUpperCase(),
            style: const TextStyle(color: muted, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1))),
          CourseCard(course: courses[i], onTap: () => editCourse(i)),
        ]),
      )),
      const Text('Touchez un cours pour le modifier · Glissez vers la gauche pour le supprimer.',
        style: TextStyle(color: muted, fontSize: 12)),
    ]));
}
