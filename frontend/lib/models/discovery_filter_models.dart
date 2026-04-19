class DiscoveryFilterValueModel {
  final int id;
  final int groupId;
  final String value;
  final String? valueAr;
  final String slug;
  final int sortOrder;
  final bool isActive;
  final int productCount;
  final List<int> productIds;

  const DiscoveryFilterValueModel({
    required this.id,
    required this.groupId,
    required this.value,
    this.valueAr,
    required this.slug,
    this.sortOrder = 0,
    this.isActive = true,
    this.productCount = 0,
    this.productIds = const <int>[],
  });

  factory DiscoveryFilterValueModel.fromJson(Map<String, dynamic> json) {
    final productIds = json['product_ids'];
    return DiscoveryFilterValueModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      groupId: (json['group_id'] as num?)?.toInt() ?? 0,
      value: (json['value'] as String? ?? '').trim(),
      valueAr: (json['value_ar'] as String?)?.trim(),
      slug: (json['slug'] as String? ?? '').trim(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      productIds: productIds is List
          ? productIds.map((item) => (item as num?)?.toInt() ?? 0).toList()
          : const <int>[],
    );
  }
}

class DiscoveryFilterGroupModel {
  final int id;
  final String name;
  final String slug;
  final String filterType;
  final int sortOrder;
  final bool isActive;
  final bool isPublic;
  final int valueCount;
  final List<int> categoryIds;
  final List<DiscoveryFilterValueModel> values;

  const DiscoveryFilterGroupModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.filterType,
    this.sortOrder = 0,
    this.isActive = true,
    this.isPublic = true,
    this.valueCount = 0,
    this.categoryIds = const <int>[],
    this.values = const <DiscoveryFilterValueModel>[],
  });

  factory DiscoveryFilterGroupModel.fromJson(Map<String, dynamic> json) {
    final categoryIds = json['category_ids'];
    final values = json['values'];
    return DiscoveryFilterGroupModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      slug: (json['slug'] as String? ?? '').trim(),
      filterType: (json['filter_type'] as String? ?? 'multi_select').trim(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isPublic: json['is_public'] as bool? ?? true,
      valueCount: (json['value_count'] as num?)?.toInt() ?? 0,
      categoryIds: categoryIds is List
          ? categoryIds.map((item) => (item as num?)?.toInt() ?? 0).toList()
          : const <int>[],
      values: values is List
          ? values
              .whereType<Map<String, dynamic>>()
              .map(DiscoveryFilterValueModel.fromJson)
              .toList()
          : const <DiscoveryFilterValueModel>[],
    );
  }
}
