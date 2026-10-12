class CourseSectionModel {
  final int index;
  final String title;
  final int pageStart;
  final int pageEnd;
  final List<int> pages;
  final String content;
  final int charCount;
  final int questionsGenerated;
  final int questionsAnswered;
  final int correctAnswers;

  const CourseSectionModel({
    required this.index,
    required this.title,
    required this.pageStart,
    required this.pageEnd,
    required this.pages,
    required this.content,
    required this.charCount,
    this.questionsGenerated = 0,
    this.questionsAnswered = 0,
    this.correctAnswers = 0,
  });

  factory CourseSectionModel.fromJson(Map<String, dynamic> json) => CourseSectionModel(
    index: json['index'] as int,
    title: json['title'] as String,
    pageStart: json['page_start'] as int,
    pageEnd: json['page_end'] as int,
    pages: (json['pages'] as List).cast<int>(),
    content: json['content'] as String? ?? '',
    charCount: json['char_count'] as int? ?? 1,
    questionsGenerated: json['questions_generated'] as int? ?? 0,
    questionsAnswered: json['questions_answered'] as int? ?? 0,
    correctAnswers: json['correct_answers'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'index': index,
    'title': title,
    'page_start': pageStart,
    'page_end': pageEnd,
    'pages': pages,
    'content': content,
    'char_count': charCount,
    'questions_generated': questionsGenerated,
    'questions_answered': questionsAnswered,
    'correct_answers': correctAnswers,
  };
}

class CourseQuestionModel {
  final int id;
  final int sectionIndex;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final String explanation;
  final int sourcePage;
  final int? selectedIndex;
  final bool? isCorrect;

  const CourseQuestionModel({
    required this.id,
    required this.sectionIndex,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
    required this.sourcePage,
    this.selectedIndex,
    this.isCorrect,
  });

  CourseQuestionModel copyWith({int? selectedIndex, bool? isCorrect}) => CourseQuestionModel(
    id: id,
    sectionIndex: sectionIndex,
    prompt: prompt,
    choices: choices,
    correctIndex: correctIndex,
    explanation: explanation,
    sourcePage: sourcePage,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    isCorrect: isCorrect ?? this.isCorrect,
  );

  factory CourseQuestionModel.fromJson(Map<String, dynamic> json) => CourseQuestionModel(
    id: json['id'] as int,
    sectionIndex: json['section_index'] as int,
    prompt: json['prompt'] as String,
    choices: (json['choices'] as List).cast<String>(),
    correctIndex: json['correct_index'] as int,
    explanation: json['explanation'] as String,
    sourcePage: json['source_page'] as int,
    selectedIndex: json['selected_index'] as int?,
    isCorrect: json['is_correct'] as bool?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'section_index': sectionIndex,
    'prompt': prompt,
    'choices': choices,
    'correct_index': correctIndex,
    'explanation': explanation,
    'source_page': sourcePage,
    'selected_index': selectedIndex,
    'is_correct': isCorrect,
  };
}

class CourseProgressModel {
  final int totalSections;
  final int generatedSections;
  final int completedSections;
  final int? nextSectionIndex;
  final int totalQuestions;
  final int answeredQuestions;
  final int correctAnswers;
  final int scorePercent;

  const CourseProgressModel({
    required this.totalSections,
    this.generatedSections = 0,
    this.completedSections = 0,
    this.nextSectionIndex = 0,
    this.totalQuestions = 0,
    this.answeredQuestions = 0,
    this.correctAnswers = 0,
    this.scorePercent = 0,
  });

  factory CourseProgressModel.fromJson(Map<String, dynamic> json) => CourseProgressModel(
    totalSections: json['total_sections'] as int,
    generatedSections: json['generated_sections'] as int? ?? 0,
    completedSections: json['completed_sections'] as int? ?? 0,
    nextSectionIndex: json['next_section_index'] as int?,
    totalQuestions: json['total_questions'] as int? ?? 0,
    answeredQuestions: json['answered_questions'] as int? ?? 0,
    correctAnswers: json['correct_answers'] as int? ?? 0,
    scorePercent: json['score_percent'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'total_sections': totalSections,
    'generated_sections': generatedSections,
    'completed_sections': completedSections,
    'next_section_index': nextSectionIndex,
    'total_questions': totalQuestions,
    'answered_questions': answeredQuestions,
    'correct_answers': correctAnswers,
    'score_percent': scorePercent,
  };
}

class CourseDocumentModel {
  final String id;
  final String subject;
  final String title;
  final String filename;
  final int pageCount;
  final int totalChars;
  final List<CourseSectionModel> sections;
  final CourseProgressModel progress;
  final List<CourseQuestionModel> questions;
  final bool isDemo;

  const CourseDocumentModel({
    required this.id,
    required this.subject,
    required this.title,
    required this.filename,
    required this.pageCount,
    required this.totalChars,
    required this.sections,
    required this.progress,
    this.questions = const [],
    this.isDemo = false,
  });

  factory CourseDocumentModel.fromJson(Map<String, dynamic> json) => CourseDocumentModel(
    id: json['id'] as String,
    subject: json['subject'] as String,
    title: json['title'] as String,
    filename: json['filename'] as String,
    pageCount: json['page_count'] as int,
    totalChars: json['total_chars'] as int,
    sections: (json['sections'] as List)
        .map((s) => CourseSectionModel.fromJson(s as Map<String, dynamic>))
        .toList(),
    progress: CourseProgressModel.fromJson(json['progress'] as Map<String, dynamic>),
    questions: ((json['questions'] as List?) ?? const [])
        .map((q) => CourseQuestionModel.fromJson(q as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'title': title,
    'filename': filename,
    'page_count': pageCount,
    'total_chars': totalChars,
    'sections': sections.map((s) => s.toJson()).toList(),
    'progress': progress.toJson(),
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  /// Recomputes section counters and document progress after local/remote question or answer updates.
  CourseDocumentModel withUpdatedQuestions(List<CourseQuestionModel> updatedQuestions) {
    final updatedSections = sections.map((sec) {
      final secQuestions = updatedQuestions.where((q) => q.sectionIndex == sec.index).toList();
      final answered = secQuestions.where((q) => q.selectedIndex != null).length;
      final correct = secQuestions.where((q) => q.isCorrect == true).length;
      return CourseSectionModel(
        index: sec.index,
        title: sec.title,
        pageStart: sec.pageStart,
        pageEnd: sec.pageEnd,
        pages: sec.pages,
        content: sec.content,
        charCount: sec.charCount,
        questionsGenerated: secQuestions.length,
        questionsAnswered: answered,
        correctAnswers: correct,
      );
    }).toList();

    final genSecs = updatedSections.where((s) => s.questionsGenerated > 0).length;
    final compSecs = updatedSections
        .where((s) => s.questionsGenerated > 0 && s.questionsAnswered >= s.questionsGenerated)
        .length;
    int? nextSec;
    for (final s in updatedSections) {
      if (s.questionsGenerated == 0 || s.questionsAnswered < s.questionsGenerated) {
        nextSec = s.index;
        break;
      }
    }
    final totalQ = updatedQuestions.length;
    final answeredQ = updatedQuestions.where((q) => q.selectedIndex != null).length;
    final correctQ = updatedQuestions.where((q) => q.isCorrect == true).length;
    final pct = answeredQ > 0 ? ((correctQ * 100) / answeredQ).round() : 0;

    return CourseDocumentModel(
      id: id,
      subject: subject,
      title: title,
      filename: filename,
      pageCount: pageCount,
      totalChars: totalChars,
      sections: updatedSections,
      progress: CourseProgressModel(
        totalSections: updatedSections.length,
        generatedSections: genSecs,
        completedSections: compSecs,
        nextSectionIndex: nextSec,
        totalQuestions: totalQ,
        answeredQuestions: answeredQ,
        correctAnswers: correctQ,
        scorePercent: pct,
      ),
      questions: updatedQuestions,
      isDemo: isDemo,
    );
  }
}

class AccessActivationModel {
  final bool valid;
  final String studentId;
  final String accessToken;
  final String maskedKey;
  final String status;
  final String? expiresAt;
  final int activationCount;
  final int? maxActivations;
  final int? activationsRemaining;
  final String? productName;
  final int documentsToday;
  final int maxDocumentsPerDay;
  final int quizRequestsToday;
  final int maxQuizRequestsPerDay;

  const AccessActivationModel({
    required this.valid,
    required this.studentId,
    required this.accessToken,
    required this.maskedKey,
    required this.status,
    this.expiresAt,
    this.activationCount = 0,
    this.maxActivations,
    this.activationsRemaining,
    this.productName,
    this.documentsToday = 0,
    this.maxDocumentsPerDay = 5,
    this.quizRequestsToday = 0,
    this.maxQuizRequestsPerDay = 20,
  });

  factory AccessActivationModel.fromJson(Map<String, dynamic> json) {
    final quota = (json['quota'] as Map<String, dynamic>?) ?? const {};
    return AccessActivationModel(
      valid: json['valid'] as bool? ?? true,
      studentId: json['student_id'] as String? ?? '',
      accessToken: json['access_token'] as String? ?? '',
      maskedKey: json['masked_key'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      expiresAt: json['expires_at'] as String?,
      activationCount: json['activation_count'] as int? ?? 0,
      maxActivations: json['max_activations'] as int?,
      activationsRemaining: json['activations_remaining'] as int?,
      productName: json['product_name'] as String?,
      documentsToday: quota['documents_today'] as int? ?? 0,
      maxDocumentsPerDay: quota['max_documents_per_day'] as int? ?? 5,
      quizRequestsToday: quota['quiz_requests_today'] as int? ?? 0,
      maxQuizRequestsPerDay: quota['max_quiz_requests_per_day'] as int? ?? 20,
    );
  }
}

