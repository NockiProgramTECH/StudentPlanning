import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../demo.dart';
import '../models/course_material.dart';
import '../services/course_study_api.dart';
import '../services/planning_api.dart';
import '../services/schedule_store.dart';
import '../services/student_portal.dart';
import '../theme.dart';

class CourseStudyScreen extends StatefulWidget {
  final ScheduleStore store;
  final List<String> suggestedSubjects;
  final bool previewMode;
  final CourseStudyApi? api;

  const CourseStudyScreen({
    super.key,
    required this.store,
    this.suggestedSubjects = const [],
    this.previewMode = false,
    this.api,
  });

  @override
  State<CourseStudyScreen> createState() => _CourseStudyScreenState();
}

class _CourseStudyScreenState extends State<CourseStudyScreen> with WidgetsBindingObserver {
  late final CourseStudyApi _api = widget.api ?? CourseStudyApi();
  late final TextEditingController _tokenController = TextEditingController();
  late final TextEditingController _subjectController = TextEditingController(
    text: widget.suggestedSubjects.isNotEmpty
        ? widget.suggestedSubjects.first
        : 'Transmission des signaux analogiques',
  );

  List<CourseDocumentModel> _documents = [];
  CourseDocumentModel? _activeDocument;
  StudentAccessConfig? _accessConfig;
  bool _refreshingAccess = false;
  bool _portalOpened = false;
  String? _activeAccessToken;
  int _selectedSectionIndex = 0;
  Uint8List? _pdfBytes;
  String? _pdfFilename;
  bool _loading = true;
  bool _busyAction = false;
  String? _error;

  String get _effectiveToken => (_activeAccessToken ?? '').trim();
  bool get _hasAccess => _accessConfig != null &&
      (_accessConfig!.freeAccess || _effectiveToken.isNotEmpty);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDocuments();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    if (widget.previewMode) {
      final demo = demoCourseDocument();
      if (mounted) {
        setState(() {
          _documents = [demo];
          _activeDocument = demo;
          _selectedSectionIndex = 0;
          _loading = false;
        });
      }
      return;
    }
    try {
      final stored = await widget.store.courseDocuments();
      await _refreshAccess();
      if (mounted) {
        setState(() {
          _documents = stored;
          _activeDocument = stored.isNotEmpty ? stored.first : null;
          _selectedSectionIndex = _activeDocument?.progress.nextSectionIndex ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger l’espace étudiant sur cet appareil.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _portalOpened) {
      _portalOpened = false;
      _refreshAccess();
    }
  }

  Future<void> _refreshAccess() async {
    if (widget.previewMode || _refreshingAccess) return;
    _refreshingAccess = true;
    try {
      _api.deviceIdentifier = await widget.store.deviceIdentifier();
      final config = await _api.accessConfig();
      var token = await widget.store.studentAccessToken(_api.baseUrl);
      if (!config.freeAccess && token != null) {
        try {
          await _api.checkAccess(token);
        } on CourseApiException catch (e) {
          if (e.statusCode != 401 && e.statusCode != 403) rethrow;
          await widget.store.saveStudentAccessToken(_api.baseUrl, null);
          token = null;
        }
      }
      if (mounted) setState(() {
        _accessConfig = config;
        _activeAccessToken = token;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() {
        _accessConfig = null; // Offline/invalid config must never imply free access.
        _error = 'Espace étudiant indisponible. Vérifiez votre connexion puis réessayez.';
      });
    } finally {
      _refreshingAccess = false;
    }
  }

  Future<void> _openPortal() async {
    final config = _accessConfig;
    if (config == null) return;
    try {
      _portalOpened = true;
      await StudentPortal.open(apiUri(_api.baseUrl, config.portalPath));
    } catch (_) {
      _portalOpened = false;
      if (mounted) setState(() => _error = 'Impossible d’ouvrir le portail étudiant dans le navigateur.');
    }
  }

  Future<void> _handleAccessError(Object error) async {
    if (error is CourseApiException && (error.statusCode == 401 || error.statusCode == 403)) {
      await widget.store.saveStudentAccessToken(_api.baseUrl, null);
      if (mounted) setState(() => _activeAccessToken = null);
      await _refreshAccess();
    }
    if (mounted) setState(() => _error = formatApiError(error));
  }

  Future<void> _pickCoursePdf() async {
    if (widget.previewMode) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null) return;
      final file = result.files.single;
      if (file.size > 10 * 1024 * 1024 || file.bytes == null) {
        setState(() => _error = 'Support PDF illisible ou trop volumineux (10 Mo max, 30 pages max).');
        return;
      }
      setState(() {
        _pdfBytes = file.bytes;
        _pdfFilename = file.name;
        _error = null;
      });
    } catch (_) {
      setState(() => _error = 'Impossible de sélectionner le support PDF.');
    }
  }

  Future<void> _finalizeAccess() async {
    if (widget.previewMode) return;
    final key = _tokenController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Saisissez votre code d’accès ou e-mail étudiant.');
      return;
    }
    setState(() {
      _busyAction = true;
      _error = null;
    });
    try {
      final info = await _api.activateAccess(
        accessCode: key,
        deviceIdentifier: _api.deviceIdentifier,
      );
      if (!info.valid || info.status != 'active' || info.accessToken.isEmpty) {
        throw StateError('Accès étudiant non reconnu.');
      }
      await widget.store.saveStudentAccessToken(_api.baseUrl, info.accessToken);
      if (mounted) setState(() {
        _activeAccessToken = info.accessToken;
        _tokenController.clear();
      });
    } catch (e) {
      await _handleAccessError(e);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _importCourseSupport() async {
    if (widget.previewMode) return;
    if (_pdfBytes == null || _pdfFilename == null) {
      setState(() => _error = 'Choisissez d’abord un support de cours PDF (distinct de l’emploi du temps).');
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      setState(() => _error = 'Indiquez la matière du support de cours.');
      return;
    }
    if (!_hasAccess) {
      setState(() => _error = 'Finalisez votre accès étudiant pour importer ce support.');
      return;
    }
    setState(() {
      _busyAction = true;
      _error = null;
    });
    try {
      final imported = await _api.importCoursePdf(
        accessToken: _effectiveToken,
        bytes: _pdfBytes!,
        filename: _pdfFilename!,
        subject: _subjectController.text.trim(),
      );
      await widget.store.saveCourseDocument(imported);
      final docs = await widget.store.courseDocuments();
      if (mounted) {
        setState(() {
          _documents = docs;
          _activeDocument = imported;
          _selectedSectionIndex = 0;
          _pdfBytes = null;
          _pdfFilename = null;
        });
      }
    } catch (e) {
      await _handleAccessError(e);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _generateSectionQuiz(int sectionIndex, {bool regenerate = false}) async {
    final doc = _activeDocument;
    if (doc == null) return;

    if (widget.previewMode) {
      final sampleQ = CourseQuestionModel(
        id: 100 + sectionIndex,
        sectionIndex: sectionIndex,
        prompt: 'Selon la règle de Carson, de quoi dépend la largeur de bande FM ?',
        choices: const [
          'De l’excursion en fréquence et de la fréquence modulante maximale',
          'Uniquement de la phase initiale',
          'Uniquement de la résistance de charge',
          'Elle est toujours nulle',
        ],
        correctIndex: 0,
        explanation: 'La formule de Carson B = 2(Δf + fm) lie la bande passante à l’excursion Δf et à fm (voir page 5).',
        sourcePage: 5,
      );
      final updatedList = [
        ...doc.questions.where((q) => q.sectionIndex != sectionIndex),
        sampleQ,
      ];
      setState(() => _activeDocument = doc.withUpdatedQuestions(updatedList));
      return;
    }

    if (!_hasAccess) {
      setState(() => _error = 'Finalisez votre accès étudiant pour générer les questions.');
      return;
    }
    setState(() {
      _busyAction = true;
      _error = null;
    });
    try {
      final generated = await _api.generateSectionQuestions(
        accessToken: _effectiveToken,
        documentId: doc.id,
        sectionIndex: sectionIndex,
        count: 3,
        regenerate: regenerate,
      );
      final merged = [
        ...doc.questions.where((q) => q.sectionIndex != sectionIndex),
        ...generated,
      ];
      final updated = doc.withUpdatedQuestions(merged);
      await widget.store.saveCourseDocument(updated);
      final docs = await widget.store.courseDocuments();
      if (mounted) {
        setState(() {
          _activeDocument = updated;
          _documents = docs;
        });
      }
    } catch (e) {
      await _handleAccessError(e);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _answerQuestion(CourseQuestionModel question, int choiceIndex) async {
    final doc = _activeDocument;
    if (doc == null) return;

    var isCorrect = choiceIndex == question.correctIndex;
    var explanation = question.explanation;
    var sourcePage = question.sourcePage;

    if (!widget.previewMode && _hasAccess) {
      try {
        final evaluation = await _api.submitAnswer(
          accessToken: _effectiveToken,
          documentId: doc.id,
          questionId: question.id,
          selectedIndex: choiceIndex,
        );
        isCorrect = evaluation['is_correct'] as bool? ?? isCorrect;
        explanation = evaluation['explanation'] as String? ?? explanation;
        sourcePage = evaluation['source_page'] as int? ?? sourcePage;
      } catch (_) {
        // Keep local grading & SQLite persistence working even if connection drops mid-quiz.
      }
    }

    final updatedQuestions = [
      for (final q in doc.questions)
        if (q.id == question.id)
          CourseQuestionModel(
            id: q.id,
            sectionIndex: q.sectionIndex,
            prompt: q.prompt,
            choices: q.choices,
            correctIndex: q.correctIndex,
            explanation: explanation,
            sourcePage: sourcePage,
            selectedIndex: choiceIndex,
            isCorrect: isCorrect,
          )
        else
          q,
    ];
    final updatedDoc = doc.withUpdatedQuestions(updatedQuestions);
    if (!widget.previewMode) {
      await widget.store.saveCourseDocument(updatedDoc);
      _documents = await widget.store.courseDocuments();
    }
    if (mounted) {
      setState(() => _activeDocument = updatedDoc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _activeDocument;
    final currentSection = doc != null && _selectedSectionIndex < doc.sections.length
        ? doc.sections[_selectedSectionIndex]
        : null;
    final sectionQuestions = doc == null
        ? const <CourseQuestionModel>[]
        : doc.questions.where((q) => q.sectionIndex == _selectedSectionIndex).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Supports & Quiz IA'), backgroundColor: canvas),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
                children: [
                  Text('Révisez vos supports,\nsection par section.', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    widget.previewMode
                        ? 'DÉMO : aperçu fictif de l’espace étudiant (extraction par sections, QCM progressif et références aux pages).'
                        : 'Importez un support de cours PDF (max 10 Mo, 30 pages). Les questions sont générées progressivement par section sur le serveur avec quotas d’utilisation.',
                    style: const TextStyle(color: muted, height: 1.5),
                  ),
                  if (!widget.previewMode) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDCE7E2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Espace étudiant L2 SIR',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          if (_accessConfig == null) ...[
                            const SizedBox(height: 12),
                            OutlinedButton(onPressed: _refreshAccess,
                                child: const Text('Réessayer')),
                          ] else if (!_accessConfig!.freeAccess && !_hasAccess) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _busyAction ? null : _openPortal,
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Ouvrir le portail étudiant'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _tokenController,
                              enabled: !_busyAction,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: "Code d'accès ou e-mail étudiant",
                                prefixIcon: Icon(Icons.school_outlined),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _busyAction ? null : _finalizeAccess,
                              child: const Text('Finaliser mon accès'),
                            ),
                          ],
                          if (_hasAccess) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _subjectController,
                              enabled: !_busyAction,
                              decoration: const InputDecoration(
                                labelText: 'Matière L2 SIR',
                                prefixIcon: Icon(Icons.menu_book_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _busyAction ? null : _pickCoursePdf,
                                    icon: const Icon(Icons.upload_file_outlined),
                                    label: Text(_pdfFilename ?? 'Choisir un PDF de cours'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton(
                                  onPressed: _busyAction ? null : _importCourseSupport,
                                  child: Text(_busyAction ? 'Import…' : 'Découper'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFB64C4C), fontWeight: FontWeight.w600)),
                    ),
                  if (_documents.length > 1) ...[
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      value: doc?.id,
                      decoration: const InputDecoration(labelText: 'Support sélectionné'),
                      items: _documents
                          .map((d) => DropdownMenuItem(value: d.id, child: Text('${d.subject} · ${d.title}')))
                          .toList(),
                      onChanged: (id) {
                        final chosen = _documents.where((d) => d.id == id).firstOrNull;
                        if (chosen != null) {
                          setState(() {
                            _activeDocument = chosen;
                            _selectedSectionIndex = chosen.progress.nextSectionIndex ?? 0;
                          });
                        }
                      },
                    ),
                  ],
                  if (doc != null) ...[
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${doc.subject.toUpperCase()} · ${doc.pageCount} PAGES',
                            style: const TextStyle(color: Color(0xFF9ACEC0), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.9),
                          ),
                          const SizedBox(height: 8),
                          Text(doc.title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(
                            'Sections terminées : ${doc.progress.completedSections}/${doc.progress.totalSections}  ·  '
                            'Score : ${doc.progress.correctAnswers}/${doc.progress.answeredQuestions} (${doc.progress.scorePercent} %)',
                            style: const TextStyle(color: Color(0xFFBCCCD0), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Sections du support', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ...doc.sections.map((sec) {
                      final selected = sec.index == _selectedSectionIndex;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: selected ? mint : Colors.white,
                        child: ListTile(
                          onTap: () => setState(() => _selectedSectionIndex = sec.index),
                          leading: CircleAvatar(
                            backgroundColor: selected ? teal : mint,
                            child: Text(
                              '${sec.index + 1}',
                              style: TextStyle(color: selected ? Colors.white : teal, fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Text(sec.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                            'Pages ${sec.pageStart}–${sec.pageEnd} · '
                            '${sec.questionsAnswered}/${sec.questionsGenerated} rép. (${sec.correctAnswers} justes)',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: teal),
                        ),
                      );
                    }),
                    if (currentSection != null) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Questions · ${currentSection.title}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busyAction || (!widget.previewMode && !_hasAccess)
                                ? null
                                : () => _generateSectionQuiz(
                                      currentSection.index,
                                      regenerate: sectionQuestions.isNotEmpty,
                                    ),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                            label: Text(
                              sectionQuestions.isEmpty
                                  ? 'Générer les questions'
                                  : 'Régénérer la section',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (sectionQuestions.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Aucune question générée pour cette section. Appuyez sur « Générer les questions » pour interroger uniquement cette section et économiser votre quota IA.',
                              style: TextStyle(color: muted),
                            ),
                          ),
                        ),
                      ...sectionQuestions.map((q) {
                        final answered = q.selectedIndex != null;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: mint,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Page ${q.sourcePage}',
                                        style: const TextStyle(color: teal, fontSize: 11, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (answered)
                                      Text(
                                        q.isCorrect == true ? 'Exact' : 'À revoir',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: q.isCorrect == true ? teal : const Color(0xFFB64C4C),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(q.prompt, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink)),
                                const SizedBox(height: 10),
                                ...List.generate(q.choices.length, (idx) {
                                  final isSelected = q.selectedIndex == idx;
                                  final isRightChoice = answered && q.correctIndex == idx;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        backgroundColor: isRightChoice
                                            ? mint
                                            : (isSelected && q.isCorrect == false)
                                                ? const Color(0xFFFFEBD9)
                                                : Colors.white,
                                      ),
                                      onPressed: _busyAction ? null : () => _answerQuestion(q, idx),
                                      child: Text(q.choices[idx]),
                                    ),
                                  );
                                }),
                                if (answered) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: canvas,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Explication (réf. page ${q.sourcePage}) : ${q.explanation}',
                                      style: const TextStyle(color: ink, fontSize: 13, height: 1.45),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}
