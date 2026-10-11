import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../demo.dart';
import '../services/planning_api.dart';
import '../services/schedule_store.dart';
import '../theme.dart';
import 'review_screen.dart';

class ImportScreen extends StatefulWidget {
  final ScheduleStore store;
  final String initialClass;
  final Future<void> Function(Schedule) onSaved;
  final bool previewMode;
  const ImportScreen({super.key, required this.store, required this.initialClass, required this.onSaved, this.previewMode = false});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late final classController = TextEditingController(text: widget.initialClass);
  late DateTime monday = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  Uint8List? bytes;
  String? filename;

  @override
  void initState() {
    super.initState();
    if (widget.previewMode) filename = 'emploi_du_temps_semaine.pdf';
  }
  bool loading = false;
  String? error;

  @override
  void dispose() { classController.dispose(); super.dispose(); }

  Future<void> pickPdf() async {
    if (widget.previewMode) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
      if (result == null) return;
      final file = result.files.single;
      if (file.size > 10 * 1024 * 1024 || file.bytes == null) {
        setState(() => error = 'PDF illisible ou trop volumineux (10 Mo maximum).');
        return;
      }
      setState(() { bytes = file.bytes; filename = file.name; error = null; });
    } catch (_) {
      setState(() => error = 'Impossible de sélectionner le fichier. Réessayez.');
    }
  }

  Future<void> chooseWeek() async {
    final date = await showDatePicker(context: context, initialDate: monday,
      firstDate: DateTime(2020), lastDate: DateTime(2100), helpText: 'Choisir un jour de la semaine');
    if (date != null) setState(() => monday = date.subtract(Duration(days: date.weekday - 1)));
  }

  Future<void> process() async {
    if (widget.previewMode) {
      await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ReviewScreen(
        schedule: demoToReview(DateTime.now()), changes: demoChanges(DateTime.now()),
        onSave: (_) async {}, previewMode: true)));
      return;
    }
    if (bytes == null || classController.text.trim().isEmpty) {
      setState(() => error = 'Sélectionnez un PDF et indiquez votre classe.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final name = classController.text.trim();
      final previous = await widget.store.previous(name, monday);
      final result = await PlanningApi().importPdf(bytes: bytes!, filename: filename!,
        className: name, weekStart: monday, previous: previous);
      if (!mounted) return;
      final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ReviewScreen(
        schedule: result.schedule, changes: result.changes, onSave: widget.onSaved)));
      if (mounted && saved == true) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Importer'), backgroundColor: canvas),
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(22, 10, 22, 30), children: [
      Text('Un PDF, un planning.', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 10),
      const Text('Transformez votre emploi du temps officiel en une semaine facile à lire.', style: TextStyle(color: muted, height: 1.5)),
      const SizedBox(height: 30),
      const Text('01  VOTRE DOCUMENT', style: TextStyle(color: teal, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      Material(color: Colors.white, borderRadius: BorderRadius.circular(22), child: InkWell(onTap: loading ? null : pickPdf,
        borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFDCE7E2))),
          child: Column(children: [
            const CircleAvatar(radius: 27, backgroundColor: mint, child: Icon(Icons.picture_as_pdf_outlined, color: teal, size: 27)),
            const SizedBox(height: 13),
            Text(filename ?? 'Choisir un fichier PDF', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 5),
            const Text('Document textuel · 10 Mo maximum', style: TextStyle(color: muted, fontSize: 12)),
          ])))),
      const SizedBox(height: 29),
      const Text('02  VOTRE CLASSE', style: TextStyle(color: teal, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      TextField(controller: classController, enabled: !loading, maxLength: 100,
        decoration: const InputDecoration(hintText: 'Ex. L2 Informatique', prefixIcon: Icon(Icons.school_outlined), counterText: '')),
      const SizedBox(height: 24),
      const Text('03  SEMAINE CONCERNÉE', style: TextStyle(color: teal, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      Material(color: Colors.white, borderRadius: BorderRadius.circular(16), child: ListTile(onTap: loading ? null : chooseWeek,
        leading: const Icon(Icons.calendar_month_outlined, color: teal),
        title: Text('Semaine du ${DateFormat('d MMMM yyyy', 'fr').format(monday)}'),
        trailing: const Icon(Icons.expand_more_rounded))),
      const SizedBox(height: 18),
      if (widget.previewMode) const Text('MODE MAQUETTE · Le document affiché est fictif. Aucun fichier n’est envoyé.',
        style: TextStyle(color: teal, fontWeight: FontWeight.w700, fontSize: 12))
      else const Text('Le texte extrait du PDF sera envoyé au fournisseur IA configuré sur le serveur. Le PDF brut ne lui est pas transmis.',
        style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 18), child: Text(error!, style: const TextStyle(color: Color(0xFFB64C4C)))),
      const SizedBox(height: 25),
      FilledButton.icon(onPressed: loading ? null : process,
        icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded),
        label: Text(loading ? 'Analyse en cours…' : widget.previewMode ? 'Voir la vérification' : 'Créer mon planning')),
    ])));
}
