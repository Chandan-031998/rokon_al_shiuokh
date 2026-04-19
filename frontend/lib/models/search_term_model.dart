class SearchTermModel {
  final int id;
  final String term;
  final String termType;
  final String? synonyms;
  final int? linkedCategoryId;
  final int? linkedProductId;
  final int sortOrder;
  final bool isActive;

  const SearchTermModel({
    required this.id,
    required this.term,
    required this.termType,
    this.synonyms,
    this.linkedCategoryId,
    this.linkedProductId,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory SearchTermModel.fromJson(Map<String, dynamic> json) {
    return SearchTermModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      term: (json['term'] as String? ?? '').trim(),
      termType: (json['term_type'] as String? ?? 'popular').trim(),
      synonyms: (json['synonyms'] as String?)?.trim(),
      linkedCategoryId: (json['linked_category_id'] as num?)?.toInt(),
      linkedProductId: (json['linked_product_id'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
