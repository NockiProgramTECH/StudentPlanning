import 'package:flutter/material.dart';
import '../models/schedule.dart';
import '../theme.dart';
const changeLabels = {
  'added': 'Cours ajouté', 'removed': 'Cours supprimé',
  'time_changed': 'Horaire modifié', 'room_changed': 'Salle modifiée',
  'details_changed': 'Détails modifiés', 'uncertain': 'Changement incertain',
};

class ComparisonScreen extends StatelessWidget {
  final List<Change> changes;
  final bool isDemo;
  const ComparisonScreen({super.key, required this.changes, this.isDemo = false});

  String description(Change change) {
    final old = change.previous;
    final current = change.current;
    switch (change.type) {
      case 'room_changed':
        return 'Salle ${old?.room ?? '—'}  →  ${current?.room ?? '—'}';
      case 'time_changed':
        return '${old?.start ?? '—'}–${old?.end ?? '—'}  →  ${current?.start ?? '—'}–${current?.end ?? '—'}';
      case 'added':
        return current == null ? 'Nouveau cours' : 'Nouveau · ${current.start}–${current.end}';
      case 'removed':
        return old == null ? 'Cours absent' : 'Absent · auparavant ${old.start}–${old.end}';
      default:
        return 'À comparer avec le document précédent';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comparaison'), backgroundColor: canvas),
    body: ListView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 28), children: [
      Text('Ce qui change.', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      const Text('Par rapport à la semaine précédente', style: TextStyle(color: muted)),
      if (isDemo) const Padding(padding: EdgeInsets.only(top: 9), child: Text('APERÇU · Données de démonstration', style: TextStyle(color: teal, fontSize: 11, fontWeight: FontWeight.w800))),
      const SizedBox(height: 25),
      Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          const CircleAvatar(backgroundColor: Color(0xFF33515A), child: Icon(Icons.compare_arrows_rounded, color: Colors.white)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${changes.length} proposition${changes.length == 1 ? '' : 's'} à vérifier',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 3),
            const Text('Ne remplacez pas le PDF officiel.', style: TextStyle(color: Color(0xFFBECED0), fontSize: 12)),
          ])),
        ])),
      const SizedBox(height: 24),
      if (changes.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(22), child: Text('Aucun changement proposé pour cette semaine.'))),
      ...changes.map((change) => Card(margin: const EdgeInsets.only(bottom: 11), child: Padding(
        padding: const EdgeInsets.all(18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(backgroundColor: change.type == 'added' ? mint : const Color(0xFFFFEBD9),
            child: Icon(change.type == 'added' ? Icons.add_rounded : Icons.swap_horiz_rounded, color: teal)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(changeLabels[change.type] ?? 'À vérifier', style: const TextStyle(fontSize: 11, color: teal, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(change.subject, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(description(change), style: const TextStyle(color: muted, fontSize: 12)),
          ])),
        ]))),
      const SizedBox(height: 12),
      const Text('Ces différences sont des propositions calculées à partir du document et doivent être confirmées.',
        style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
    ]),
  );
}
