class AdminFaqModel {
  final int id;
  final String question;
  final String answer;
  final int sortOrder;
  final bool isActive;

  const AdminFaqModel({
    required this.id,
    required this.question,
    required this.answer,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory AdminFaqModel.fromJson(Map<String, dynamic> json) {
    return AdminFaqModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: (json['question'] as String? ?? '').trim(),
      answer: (json['answer'] as String? ?? '').trim(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
