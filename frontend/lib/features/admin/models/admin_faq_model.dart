class AdminFaqModel {
  final int id;
  final String question;
  final String? questionAr;
  final String answer;
  final String? answerAr;
  final int sortOrder;
  final bool isActive;

  const AdminFaqModel({
    required this.id,
    required this.question,
    this.questionAr,
    required this.answer,
    this.answerAr,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory AdminFaqModel.fromJson(Map<String, dynamic> json) {
    return AdminFaqModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: (json['question'] as String? ?? '').trim(),
      questionAr: (json['question_ar'] as String?)?.trim(),
      answer: (json['answer'] as String? ?? '').trim(),
      answerAr: (json['answer_ar'] as String?)?.trim(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
