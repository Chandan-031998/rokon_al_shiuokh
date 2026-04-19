class FaqModel {
  final int id;
  final String question;
  final String answer;
  final String? questionAr;
  final String? answerAr;
  final int sortOrder;
  final bool isActive;

  const FaqModel({
    required this.id,
    required this.question,
    required this.answer,
    this.questionAr,
    this.answerAr,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory FaqModel.fromJson(Map<String, dynamic> json) {
    return FaqModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: (json['question'] as String? ?? '').trim(),
      answer: (json['answer'] as String? ?? '').trim(),
      questionAr: (json['question_ar'] as String?)?.trim(),
      answerAr: (json['answer_ar'] as String?)?.trim(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
